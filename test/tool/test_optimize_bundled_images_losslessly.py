import io
import json
from pathlib import Path
import random
import shutil
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import zlib

from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tool'))
import optimize_bundled_images_losslessly as optimizer


def png(*, palette=False):
    image = Image.new('P' if palette else 'RGBA', (48, 40))
    if palette:
        image.putpalette([0, 0, 0, 220, 90, 30] + [0] * 762)
        image.paste(1, (10, 10, 40, 30))
        image.info['transparency'] = bytes([0, 200])
    else:
        image.paste((130, 80, 20, 140), (5, 5, 35, 30))
    info = PngImagePlugin.PngInfo()
    info.add_text('author', 'existing photo')
    info.add(b'teSt', b'opaque metadata must survive')
    output = io.BytesIO()
    image.save(output, format='PNG', pnginfo=info,
               icc_profile=b'original ICC profile', compress_level=0)
    return output.getvalue()


def extra_png_chunk(data, kind, payload):
    raw = (struct.pack('>I', len(payload)) + kind + payload
           + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff))
    rows = optimizer.png_chunks(data)
    return optimizer.PNG_SIGNATURE + rows[0][2] + raw + b''.join(row[2] for row in rows[1:])


class LosslessBundledImageTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name).resolve()
        (self.root / 'assets').mkdir()
        (self.root / 'candidates').mkdir()
        self.root_patch = patch.object(optimizer, 'ROOT', self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.addCleanup(self.directory.cleanup)

    def prepare(self, data, name='photo.png'):
        (self.root / 'assets' / name).write_bytes(data)
        return optimizer.prepare_one((f'assets/{name}', str(self.root / 'candidates'),
                                      shutil.which('jpegtran'), 1))

    def test_png_pixels_alpha_palette_color_profile_and_opaque_metadata_survive(self):
        for palette in [False, True]:
            with self.subTest(palette=palette):
                original = png(palette=palette)
                row = self.prepare(original)
                self.assertEqual(row['status'], 'candidate', row)
                candidate = Path(row['candidate']).read_bytes()
                self.assertLess(len(candidate), len(original))
                self.assertEqual(optimizer.png_metadata(original), optimizer.png_metadata(candidate))
                self.assertEqual(optimizer.pixels(original), optimizer.pixels(candidate))

    def test_provenance_and_animation_are_preserved_byte_for_byte(self):
        for kind, payload in [(b'caBX', b'signed C2PA data'), (b'dSIG', b'signature'),
                              (b'acTL', struct.pack('>II', 1, 1))]:
            with self.subTest(kind=kind):
                original = extra_png_chunk(png(), kind, payload)
                row = self.prepare(original)
                self.assertEqual(row['status'], 'preserved')
                self.assertEqual((self.root / 'assets/photo.png').read_bytes(), original)

    def test_corrupt_crc_is_rejected_without_changing_source(self):
        original = bytearray(png())
        original[29] ^= 1
        row = self.prepare(bytes(original))
        self.assertEqual(row['reason'], 'validation_rejected')
        self.assertEqual((self.root / 'assets/photo.png').read_bytes(), original)

    def test_pixel_or_metadata_changes_are_rejected(self):
        original = png()
        with self.assertRaises(ValueError):
            optimizer.verify(original, png(palette=True), '.png')
        candidate = extra_png_chunk(original, b'teSt', b'new metadata')
        with self.assertRaises(ValueError):
            optimizer.verify(original, candidate, '.png')

    def test_jpeg_entropy_rewrite_keeps_pixels_icc_and_exif(self):
        if not shutil.which('jpegtran'):
            self.skipTest('jpegtran is unavailable')
        rng = random.Random(7)
        image = Image.frombytes('RGB', (96, 96), bytes(rng.randrange(256) for _ in range(96 * 96 * 3)))
        output = io.BytesIO()
        exif = Image.Exif()
        exif[0x112] = 1
        image.save(output, format='JPEG', quality=94, optimize=False,
                   exif=exif, icc_profile=b'original ICC profile')
        original = output.getvalue()
        row = self.prepare(original, 'photo.jpg')
        self.assertEqual(row['status'], 'candidate', row)
        candidate = Path(row['candidate']).read_bytes()
        self.assertEqual(optimizer.jpeg_metadata(original), optimizer.jpeg_metadata(candidate))
        self.assertEqual(optimizer.pixels(original), optimizer.pixels(candidate))

    def test_jpeg_jumbf_provenance_is_never_reencoded(self):
        output = io.BytesIO()
        Image.new('RGB', (16, 16)).save(output, format='JPEG')
        data = output.getvalue()
        payload = b'JP\x00\x01JUMBF C2PA provenance'
        original = data[:2] + b'\xff\xeb' + struct.pack('>H', len(payload) + 2) + payload + data[2:]
        row = self.prepare(original, 'photo.jpg')
        self.assertEqual(row['reason'], 'signed_provenance')
        self.assertEqual((self.root / 'assets/photo.jpg').read_bytes(), original)

    def report(self, row):
        path = self.root / 'report.json'
        path.write_text(json.dumps({'files': [row], 'candidateFiles': 1,
                                    'savedBytes': row['savedBytes'],
                                    'backupDirectory': str(self.root / 'originals')}))
        return path

    def test_apply_backs_up_original_keeps_path_and_can_resume(self):
        original = png()
        row = self.prepare(original)
        report = self.report(row)
        optimizer.apply_report(report)
        source = self.root / row['path']
        self.assertEqual(optimizer.digest(source.read_bytes()), row['afterSha256'])
        self.assertEqual((self.root / 'originals' / row['beforeSha256']).read_bytes(), original)
        optimizer.apply_report(report)
        self.assertEqual(optimizer.digest(source.read_bytes()), row['afterSha256'])
        self.assertTrue(json.loads(report.read_text())['applied'])

    def test_stale_source_aborts_batch_before_any_replacement(self):
        row = self.prepare(png())
        report = self.report(row)
        stale = b'new user edit'
        (self.root / row['path']).write_bytes(stale)
        with self.assertRaises(ValueError):
            optimizer.apply_report(report)
        self.assertEqual((self.root / row['path']).read_bytes(), stale)
        self.assertFalse((self.root / 'originals' / row['beforeSha256']).exists())


if __name__ == '__main__':
    unittest.main()

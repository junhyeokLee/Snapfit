import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
import pack_web_fonts as pack


class FontManifestRewriteTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.output = self.root / 'build/web'
        self.asset = 'assets/fonts/Complete.ttf'
        source = self.root / self.asset
        source.parent.mkdir(parents=True)
        source.write_bytes(b'\x00\x01\x00\x00' + b'original-font-fixture')
        digest = pack.sha256(source)
        self.source_filename = digest[:20] + '.ttf'
        encoded_bytes = b'wOF2' + b'packed-font-fixture'
        self.filename = hashlib.sha256(encoded_bytes).hexdigest()[:20] + '.woff2'
        encoded = self.root / pack.PACK_FONTS_RELATIVE / self.filename
        encoded.parent.mkdir(parents=True)
        encoded.write_bytes(encoded_bytes)
        self.entry = {
            'sourceAsset': self.asset, 'sourceSha256': digest,
            'sourceBytes': source.stat().st_size,
            'packedFile': self.filename, 'packedSha256': pack.sha256(encoded),
            'packedBytes': encoded.stat().st_size,
            'equivalence': {
                'version': pack.QUALITY_VERSION, 'passed': True,
                'sourceSemanticSha256': 'a' * 64,
                'decodedSemanticSha256': 'a' * 64,
            },
        }
        self.report = {'version': 1, 'generator': pack.GENERATOR,
                       'entries': [self.entry]}
        self.write_report()
        self.manifest = [
            {'family': 'Original', 'fonts': [{'asset': self.asset, 'weight': 600}]},
            {'family': 'Legacy alias', 'fonts': [{'asset': self.asset}]},
            {'family': 'MaterialIcons', 'fonts': [{'asset': 'fonts/MaterialIcons-Regular.otf'}]},
        ]
        (self.output / 'assets').mkdir(parents=True)
        (self.output / 'assets/web_fonts').mkdir()
        self.path = self.output / 'assets/FontManifest.json'
        self.path.write_text(json.dumps(self.manifest))
        legacy = self.output / 'assets' / self.asset
        legacy.parent.mkdir(parents=True)
        shutil.copy2(source, legacy)
        shutil.copy2(encoded, self.output / 'assets/web_fonts' / self.filename)

    def write_report(self):
        (self.root / pack.PACK_RELATIVE).write_text(json.dumps(self.report))

    def rewrite(self):
        return pack.rewrite_web_font_manifest(self.output, root=self.root)

    def test_aliases_weights_icons_and_legacy_bytes_are_preserved(self):
        original = (self.output / 'assets' / self.asset).read_bytes()
        result = self.rewrite()
        actual = json.loads(self.path.read_text())
        expected = copy.deepcopy(self.manifest)
        for family in expected[:2]:
            family['fonts'][0]['asset'] = 'web_fonts/' + self.source_filename
        self.assertEqual(actual, expected)
        self.assertEqual((self.output / 'assets' / self.asset).read_bytes(), original)
        self.assertEqual(result['documentFontFiles'], 1)
        self.assertTrue(result['legacyPathsPreserved'])
        self.assertEqual(result['delivery'], 'original')
        self.assertEqual(result['fontFormat'], 'sfnt')
        self.assertEqual(result['sourceBytes'], result['packedBytes'])
        delivered = result['deliveryFiles'][0]
        self.assertEqual(delivered['sourceSha256'], delivered['packedSha256'])
        self.assertEqual(delivered['sha256'], self.entry['sourceSha256'])
        self.assertEqual((self.output / 'assets' / delivered['asset']).read_bytes(), original)

    def test_woff2_is_only_an_explicit_experiment(self):
        result = pack.rewrite_web_font_manifest(self.output, 'woff2', root=self.root)
        actual = json.loads(self.path.read_text())
        self.assertEqual(actual[0]['fonts'][0]['asset'], 'web_fonts/' + self.filename)
        self.assertEqual(result['delivery'], 'woff2')
        self.assertEqual(result['fontFormat'], 'woff2')
        self.assertEqual(result['deliveryFiles'][0]['packedSha256'], self.entry['packedSha256'])

    def test_switching_delivery_keeps_old_woff2_and_original_urls(self):
        pack.rewrite_web_font_manifest(self.output, 'woff2', root=self.root)
        result = self.rewrite()
        self.assertEqual(result['delivery'], 'original')
        folder = self.output / 'assets/web_fonts'
        self.assertEqual(pack.sha256(folder / self.filename), self.entry['packedSha256'])
        self.assertEqual(pack.sha256(folder / self.source_filename), self.entry['sourceSha256'])
        self.assertEqual(json.loads(self.path.read_text())[0]['fonts'][0]['asset'],
                         'web_fonts/' + self.source_filename)

    def test_unknown_delivery_cannot_mutate_manifest(self):
        original = self.path.read_bytes()
        with self.assertRaisesRegex(pack.FontPackError, 'Unknown web font delivery'):
            pack.rewrite_web_font_manifest(self.output, 'auto', root=self.root)
        self.assertEqual(self.path.read_bytes(), original)

    def test_rewrite_is_idempotent(self):
        self.rewrite()
        original = self.path.read_bytes()
        self.rewrite()
        self.assertEqual(self.path.read_bytes(), original)

    def test_changed_source_requires_regeneration_without_mutating_manifest(self):
        previous = self.path.read_bytes()
        (self.root / self.asset).write_bytes(b'different')
        with self.assertRaisesRegex(pack.FontPackError, 'source changed'):
            self.rewrite()
        self.assertEqual(self.path.read_bytes(), previous)

    def test_changed_package_is_rejected(self):
        (self.root / pack.PACK_FONTS_RELATIVE / self.filename).write_bytes(b'wOF2tampered')
        with self.assertRaisesRegex(pack.FontPackError, 'Packaged font changed'):
            self.rewrite()

    def test_web_font_is_copied_from_verified_committed_input(self):
        destination = self.output / 'assets/web_fonts' / self.source_filename
        self.assertFalse(destination.exists())
        self.rewrite()
        self.assertEqual(pack.sha256(destination), self.entry['sourceSha256'])

    def test_missing_legacy_font_cannot_hide_behind_packaged_font(self):
        (self.output / 'assets' / self.asset).unlink()
        with self.assertRaisesRegex(pack.FontPackError, 'Legacy font path'):
            self.rewrite()

    def test_new_document_font_fails_before_manifest_change(self):
        self.manifest.append({'family': 'New', 'fonts': [
            {'asset': 'assets/fonts/New.ttf'}]})
        self.path.write_text(json.dumps(self.manifest))
        previous = self.path.read_bytes()
        with self.assertRaisesRegex(pack.FontPackError, 'needs a web pack'):
            self.rewrite()
        self.assertEqual(self.path.read_bytes(), previous)

    def test_quality_mismatch_is_rejected(self):
        self.entry['equivalence']['decodedSemanticSha256'] = 'b' * 64
        self.write_report()
        with self.assertRaisesRegex(pack.FontPackError, 'semantic equivalence'):
            self.rewrite()

    def test_parent_escape_is_rejected(self):
        self.entry['sourceAsset'] = 'assets/fonts/../../outside.ttf'
        self.write_report()
        with self.assertRaisesRegex(pack.FontPackError, 'Unsafe document font'):
            self.rewrite()

    def test_hash_named_file_must_match_original_identity(self):
        self.entry['packedFile'] = 'other.woff2'
        self.write_report()
        with self.assertRaisesRegex(pack.FontPackError, 'Invalid packaged path'):
            self.rewrite()


HAS_FONTTOOLS = importlib.util.find_spec('fontTools') is not None


@unittest.skipUnless(HAS_FONTTOOLS, 'generation-only FontTools dependency')
class FontSemanticEquivalenceTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.source = Path(self.folder.name) / 'original.ttf'
        self.packed = Path(self.folder.name) / 'packed.woff2'
        from fontTools.fontBuilder import FontBuilder
        from fontTools.pens.ttGlyphPen import TTGlyphPen
        from fontTools.ttLib.tables.ttProgram import Program
        fb = FontBuilder(1000, isTTF=True)
        order = ['.notdef', 'A', 'hangul']
        fb.setupGlyphOrder(order)
        fb.setupCharacterMap({65: 'A', 0xAC00: 'hangul'})
        glyphs = {}
        for name in order:
            pen = TTGlyphPen(None)
            if name != '.notdef':
                pen.moveTo((20, 0))
                pen.lineTo((280, 700))
                pen.lineTo((540, 0))
                pen.closePath()
            glyphs[name] = pen.glyph()
            glyphs[name].program = Program()
            glyphs[name].program.fromBytecode([0xB0, 0x00, 0x2F] if name == 'A' else [])
        fb.setupGlyf(glyphs)
        fb.setupHorizontalMetrics({name: (600, 20) for name in order})
        fb.setupHorizontalHeader(ascent=800, descent=-200)
        fb.setupNameTable({'familyName': 'Complete Fixture', 'styleName': 'Regular',
                          'uniqueFontIdentifier': 'Fixture', 'fullName': 'Fixture',
                          'psName': 'Fixture', 'copyright': 'Fixture License'})
        fb.setupOS2(sTypoAscender=800, sTypoDescender=-200,
                    usWinAscent=800, usWinDescent=200)
        fb.setupPost()
        fb.setupMaxp()
        fb.save(self.source)
        pack._encode(self.source, self.packed, transform=True)

    def test_complete_glyphs_metrics_hints_and_names_roundtrip(self):
        result = pack.validate_equivalence(self.source, self.packed)
        self.assertTrue(result['passed'])
        self.assertEqual(result['glyphCount'], 3)
        self.assertEqual(result['unicodeMappingCount'], 2)
        self.assertIn('name', result['tableDigests'])
        self.assertIn('glyf', result['tableDigests'])
        self.assertIn('hmtx', result['tableDigests'])

    def alter(self, change):
        from fontTools.ttLib import TTFont
        with TTFont(self.source, recalcBBoxes=False, recalcTimestamp=False) as font:
            change(font)
            font.save(self.source)

    def test_changed_advance_width_is_detected(self):
        self.alter(lambda font: font['hmtx'].metrics.update({'A': (601, 20)}))
        with self.assertRaisesRegex(pack.FontPackError, 'hmtx'):
            pack.validate_equivalence(self.source, self.packed)

    def test_changed_outline_coordinate_is_detected(self):
        def change(font):
            font['glyf']['A'].coordinates[0] = (21, 0)
        self.alter(change)
        with self.assertRaisesRegex(pack.FontPackError, 'glyf'):
            pack.validate_equivalence(self.source, self.packed)

    def test_changed_hint_program_is_detected(self):
        def change(font):
            font['glyf']['A'].program.fromBytecode([0xB0, 0x01, 0x2F])
        self.alter(change)
        with self.assertRaisesRegex(pack.FontPackError, 'glyf'):
            pack.validate_equivalence(self.source, self.packed)

    def test_removed_korean_character_is_detected(self):
        def change(font):
            for table in font['cmap'].tables:
                table.cmap.pop(0xAC00, None)
        self.alter(change)
        with self.assertRaisesRegex(pack.FontPackError, 'cmap'):
            pack.validate_equivalence(self.source, self.packed)


if __name__ == '__main__':
    unittest.main()

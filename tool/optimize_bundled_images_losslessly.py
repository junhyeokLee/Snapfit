#!/usr/bin/env python3
"""Prepare and verify smaller image encodings without changing asset paths.

Preparation never changes source files. Applying a prepared report rechecks its
input hashes and pixel/metadata equivalence, backs up each original by SHA-256,
then atomically replaces only smaller files. Signed/provenance-bearing images
and animations are deliberately left untouched.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ProcessPoolExecutor
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import zlib
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def png_chunks(data: bytes) -> list[tuple[bytes, bytes, bytes]]:
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError('Invalid PNG signature')
    rows = []
    position = 8
    while position < len(data):
        if position + 12 > len(data):
            raise ValueError('Truncated PNG chunk')
        length = struct.unpack('>I', data[position:position + 4])[0]
        end = position + 12 + length
        raw = data[position:end]
        if len(raw) != length + 12:
            raise ValueError('Truncated PNG data')
        kind, payload = raw[4:8], raw[8:-4]
        crc = struct.unpack('>I', raw[-4:])[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError('Invalid PNG CRC')
        rows.append((kind, payload, raw))
        position = end
        if kind == b'IEND':
            if position != len(data):
                raise ValueError('Trailing PNG bytes must be preserved')
            break
    if not rows or rows[0][0] != b'IHDR' or rows[-1][0] != b'IEND':
        raise ValueError('Incomplete PNG')
    if not any(kind == b'IDAT' for kind, _, _ in rows):
        raise ValueError('Missing PNG image data')
    return rows


def png_metadata(data: bytes) -> list[bytes]:
    return [raw for kind, _, raw in png_chunks(data) if kind != b'IDAT']


def replace_png_idat(original: bytes, compressed: bytes) -> bytes:
    rows = png_chunks(original)
    replacement = (struct.pack('>I', len(compressed)) + b'IDAT' + compressed
                   + struct.pack('>I', zlib.crc32(b'IDAT' + compressed) & 0xffffffff))
    result, written = [PNG_SIGNATURE], False
    for kind, _, raw in rows:
        if kind == b'IDAT':
            if not written:
                result.append(replacement)
                written = True
        else:
            result.append(raw)
    return b''.join(result)


def jpeg_metadata(data: bytes) -> list[tuple[int, bytes]]:
    if not data.startswith(b'\xff\xd8'):
        raise ValueError('Invalid JPEG signature')
    result, position = [], 2
    while position < len(data):
        if data[position] != 0xff:
            raise ValueError('Invalid JPEG marker')
        while position < len(data) and data[position] == 0xff:
            position += 1
        if position >= len(data):
            raise ValueError('Truncated JPEG marker')
        marker = data[position]
        position += 1
        if marker == 0xd9:
            if position != len(data):
                raise ValueError('Trailing JPEG bytes must be preserved')
            return result
        if marker in [0x01, 0xd8] or 0xd0 <= marker <= 0xd7:
            continue
        if position + 2 > len(data):
            raise ValueError('Truncated JPEG segment')
        length = struct.unpack('>H', data[position:position + 2])[0]
        if length < 2 or position + length > len(data):
            raise ValueError('Invalid JPEG segment size')
        payload = data[position + 2:position + length]
        position += length
        if 0xe0 <= marker <= 0xef or marker == 0xfe:
            result.append((marker, payload))
        if marker == 0xda:
            while True:
                next_marker = data.find(b'\xff', position)
                if next_marker < 0 or next_marker + 1 >= len(data):
                    raise ValueError('Truncated JPEG scan')
                kind = data[next_marker + 1]
                if kind == 0 or 0xd0 <= kind <= 0xd7:
                    position = next_marker + 2
                    continue
                position = next_marker
                break
    raise ValueError('Missing JPEG end marker')


def protected_reason(data: bytes, suffix: str) -> str | None:
    if suffix == '.png':
        rows = png_chunks(data)
        if any(kind in {b'acTL', b'fcTL', b'fdAT'} for kind, _, _ in rows):
            return 'animation'
        if any(kind in {b'caBX', b'dSIG'} or b'c2pa' in payload.lower()
               or b'jumb' in payload.lower() for kind, payload, _ in rows
               if kind != b'IDAT'):
            return 'signed_provenance'
        if any(kind[0] & 32 == 0 and kind not in {b'IHDR', b'PLTE', b'IDAT', b'IEND'}
               for kind, _, _ in rows):
            return 'unknown_critical_chunk'
    else:
        if any((marker == 0xeb and payload.startswith(b'JP'))
               or b'c2pa' in payload.lower() or b'jumb' in payload.lower()
               for marker, payload in jpeg_metadata(data)):
            return 'signed_provenance'
    return None


def pixels(data: bytes) -> dict:
    with Image.open(io.BytesIO(data)) as image:
        image.load()
        return {'mode': image.mode, 'size': list(image.size),
                'sha256': digest(image.tobytes()),
                'iccSha256': digest(image.info.get('icc_profile', b'')),
                'exifSha256': digest(image.info.get('exif', b''))}


def verify(original: bytes, candidate: bytes, suffix: str) -> dict:
    if pixels(original) != pixels(candidate):
        raise ValueError('Decoded pixels, dimensions, mode or color metadata differ')
    if suffix == '.png':
        if png_metadata(original) != png_metadata(candidate):
            raise ValueError('PNG metadata or IHDR changed')
    elif jpeg_metadata(original) != jpeg_metadata(candidate):
        raise ValueError('JPEG metadata changed')
    return pixels(original)


def prepare_one(arguments: tuple[str, str, str | None, int]) -> dict:
    source_name, candidate_dir, jpegtran, minimum = arguments
    path = ROOT / source_name
    original = path.read_bytes()
    suffix, sha = path.suffix.lower(), digest(original)
    row = {'path': source_name, 'beforeBytes': len(original), 'beforeSha256': sha}
    try:
        reason = protected_reason(original, suffix)
        if reason:
            return {**row, 'status': 'preserved', 'reason': reason}
        options = [('original', original)]
        if suffix == '.png':
            chunks = png_chunks(original)
            raw = zlib.decompress(b''.join(payload for kind, payload, _ in chunks
                                           if kind == b'IDAT'))
            options.append(('original_filters_zlib9', replace_png_idat(original, zlib.compress(raw, 9))))
            with Image.open(io.BytesIO(original)) as image:
                image.load()
                buffer = io.BytesIO()
                image.save(buffer, format='PNG', optimize=True, compress_level=9)
            filtered = png_chunks(buffer.getvalue())
            # Keep the original bit depth, color type, interlace, and palette.
            structural = lambda rows: [(kind, payload) for kind, payload, _ in rows
                                        if kind in {b'IHDR', b'PLTE'}]
            if structural(chunks) == structural(filtered):
                encoded = b''.join(payload for kind, payload, _ in filtered if kind == b'IDAT')
                options.append(('pillow_filters_zlib9', replace_png_idat(original, encoded)))
        elif jpegtran:
            for progressive in [False, True]:
                command = [jpegtran, '-copy', 'all', '-optimize']
                if progressive:
                    command.append('-progressive')
                output = subprocess.run(command + [str(path)], capture_output=True, check=True).stdout
                options.append(('jpeg_progressive' if progressive else 'jpeg_entropy', output))
        else:
            return {**row, 'status': 'preserved', 'reason': 'jpegtran_unavailable'}
        method, candidate = min(options, key=lambda option: len(option[1]))
        if len(original) - len(candidate) < minimum:
            return {**row, 'status': 'preserved', 'reason': 'already_compact'}
        proof = verify(original, candidate, suffix)
        destination = Path(candidate_dir) / sha
        destination.write_bytes(candidate)
        return {**row, 'status': 'candidate', 'method': method,
                'afterBytes': len(candidate), 'afterSha256': digest(candidate),
                'savedBytes': len(original) - len(candidate), 'pixelProof': proof,
                'candidate': str(destination)}
    except Exception as error:
        return {**row, 'status': 'preserved', 'reason': 'validation_rejected',
                'detail': f'{type(error).__name__}: {error}'}


def apply_report(report_path: Path) -> None:
    report = json.loads(report_path.read_text())
    backup = Path(report['backupDirectory'])
    backup.mkdir(parents=True, exist_ok=True)
    # Validate the entire batch before changing the first file. A stopped apply
    # can resume, provided already-written files and their backups still match.
    for row in report['files']:
        if row['status'] != 'candidate':
            continue
        path = (ROOT / row['path']).resolve()
        if not path.is_relative_to(ROOT / 'assets'):
            raise ValueError('Only repository asset paths can be replaced')
        current, candidate = path.read_bytes(), Path(row['candidate']).read_bytes()
        current_sha = digest(current)
        if current_sha == row['afterSha256']:
            original = (backup / row['beforeSha256']).read_bytes()
        else:
            original = current
        if (current_sha not in {row['beforeSha256'], row['afterSha256']}
                or digest(original) != row['beforeSha256']
                or digest(candidate) != row['afterSha256']):
            raise ValueError(f"Stale source/candidate: {row['path']}")
        if len(candidate) >= len(original) or protected_reason(original, path.suffix.lower()):
            raise ValueError(f"Unsafe candidate: {row['path']}")
        verify(original, candidate, path.suffix.lower())
    # Finish every durable backup before the first source replacement.
    for row in report['files']:
        if row['status'] != 'candidate':
            continue
        path = ROOT / row['path']
        original = path.read_bytes()
        if digest(original) == row['afterSha256']:
            continue
        if digest(original) != row['beforeSha256']:
            raise ValueError(f"Source changed during apply: {row['path']}")
        saved = backup / row['beforeSha256']
        if saved.exists():
            if digest(saved.read_bytes()) != row['beforeSha256']:
                raise ValueError('Invalid existing backup')
        else:
            with saved.open('wb') as file:
                file.write(original)
                file.flush()
                os.fsync(file.fileno())
    for row in report['files']:
        if row['status'] != 'candidate':
            continue
        path = ROOT / row['path']
        if digest(path.read_bytes()) == row['afterSha256']:
            continue
        if digest(path.read_bytes()) != row['beforeSha256']:
            raise ValueError(f"Source changed during apply: {row['path']}")
        temporary = path.with_name(path.name + '.lossless-tmp')
        try:
            with temporary.open('wb') as file:
                file.write(Path(row['candidate']).read_bytes())
                file.flush()
                os.fsync(file.fileno())
            os.chmod(temporary, path.stat().st_mode)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)
    report['applied'] = True
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'applied': True, 'changedFiles': report['candidateFiles'],
                      'savedBytes': report['savedBytes']}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default='output/asset-lossless-20261029')
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--minimum-saving', type=int, default=1024)
    parser.add_argument('--asset-list-from-apk')
    parser.add_argument('--apply-report', type=Path)
    args = parser.parse_args()
    if args.apply_report:
        apply_report(args.apply_report.resolve())
        return
    output = (ROOT / args.output).resolve()
    candidates = output / 'candidates'
    candidates.mkdir(parents=True, exist_ok=True)
    bundled = None
    if args.asset_list_from_apk:
        with zipfile.ZipFile(ROOT / args.asset_list_from_apk) as archive:
            prefix = 'assets/flutter_assets/'
            bundled = {name[len(prefix):] for name in archive.namelist() if name.startswith(prefix)}
    paths = [path for path in (ROOT / 'assets').rglob('*') if path.is_file()
             and path.suffix.lower() in {'.png', '.jpg', '.jpeg'}
             and (bundled is None or str(path.relative_to(ROOT)) in bundled)]
    groups = {}
    for path in sorted(paths):
        groups.setdefault(digest(path.read_bytes()), []).append(str(path.relative_to(ROOT)))
    jobs = [(names[0], str(candidates), shutil.which('jpegtran'), args.minimum_saving)
            for names in groups.values()]
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        unique_results = list(pool.map(prepare_one, jobs))
    rows = []
    for result in unique_results:
        for name in groups[result['beforeSha256']]:
            rows.append({**result, 'path': name})
    report = {'applied': False, 'assetPathsPreserved': True,
              'backupDirectory': str(output / 'originals'), 'files': rows,
              'inputFiles': len(rows), 'uniqueImages': len(groups),
              'candidateFiles': sum(row['status'] == 'candidate' for row in rows),
              'beforeBytes': sum(row['beforeBytes'] for row in rows),
              'savedBytes': sum(row.get('savedBytes', 0) for row in rows)}
    destination = output / 'report.json'
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: value for key, value in report.items() if key != 'files'}))
    print(destination)


if __name__ == '__main__':
    main()

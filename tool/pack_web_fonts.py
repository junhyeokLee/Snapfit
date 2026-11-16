#!/usr/bin/env python3
"""Address complete, original document fonts by content for web delivery.

Generation: python -m pip install -r tool/requirements-web-fonts.txt
            python tool/pack_web_fonts.py --pack
Normal builds import rewrite_web_font_manifest using the standard library only.
The default delivery copies the original sfnt bytes. The committed WOFF2 pack is
retained for explicit experiments and old-tab compatibility; browser measurements
showed that decoding it can be slower despite smaller downloads. Native keeps TTF.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ProcessPoolExecutor, as_completed
import copy
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
PACK_RELATIVE = Path('tool/web_font_pack/manifest.json')
PACK_FONTS_RELATIVE = Path('tool/web_font_pack/fonts')
GENERATOR = {'fonttools': '4.61.1', 'brotli': '1.2.0'}
QUALITY_VERSION = 2
HEX = re.compile(r'^[0-9a-f]{64}$')


class FontPackError(RuntimeError):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def _source_path(root: Path, asset: str) -> Path:
    path = PurePosixPath(asset)
    if (path.is_absolute() or '..' in path.parts or
            not asset.startswith('assets/fonts/') or
            path.suffix.lower() not in {'.ttf', '.otf'}):
        raise FontPackError(f'Unsafe document font path: {asset}')
    source = root / asset
    if not source.resolve().is_relative_to((root / 'assets/fonts').resolve()):
        raise FontPackError(f'Font escapes the source directory: {asset}')
    return source


def _require_supported_empty_glyphs(font) -> None:
    # Some legacy sfnt files place phantom-point instructions in zero-contour
    # glyphs. FontTools' glyf object omits these, so refuse those inputs rather
    # than letting an object-level comparison silently miss their instructions.
    if 'glyf' not in font:
        return
    raw = font.reader['glyf']
    offsets = font['loca'].locations
    for start, end in zip(offsets, offsets[1:]):
        data = raw[start:end]
        if len(data) >= 12 and struct.unpack('>h', data[:2])[0] == 0:
            if struct.unpack('>H', data[10:12])[0] != 0:
                raise FontPackError('Zero-contour glyph hints require preserving the original font')


def _table_quality(font) -> dict[str, str]:
    """Compare every table, permitting only WOFF2 container normalization.

    W3C WOFF2 requires head.flags bit 11 and removal of DSIG. No signed DSIG is
    accepted here. Loca offsets/checksum are representation details. OpenType
    OVERLAP_SIMPLE is a glyph flag on its first point; duplicate copies on later
    points have no additional meaning and are not represented by WOFF2.
    All outlines, coordinates, bounding boxes, instructions, metrics, cmaps,
    names/licenses, layout and variation data remain part of the comparison.
    https://www.w3.org/TR/WOFF2/#DataTables
    https://learn.microsoft.com/en-us/typography/opentype/spec/glyf
    """
    from fontTools.misc.xmlWriter import XMLWriter
    if 'DSIG' in font and font['DSIG'].usNumSigs:
        raise FontPackError('A signed DSIG requires an explicit packaging decision')
    if 'glyf' in font:
        glyf = font['glyf']
        hint_digest = hashlib.sha256()
        for name in font.getGlyphOrder():
            glyph = glyf[name]
            instructions = glyph.program.getBytecode() if hasattr(glyph, 'program') else b''
            hint_digest.update(len(instructions).to_bytes(4, 'big'))
            hint_digest.update(instructions)
            if glyph.numberOfContours > 0:
                for index in range(1, len(glyph.flags)):
                    glyph.flags[index] &= ~0x40
    # Decode loca/glyf with the original index format before normalizing the
    # representation field for comparison.
    head = font['head']
    head.checkSumAdjustment = 0
    head.flags &= ~(1 << 11)
    head.indexToLocFormat = 0
    result = {
        'GlyphOrder': hashlib.sha256(json.dumps(
            font.getGlyphOrder(), ensure_ascii=False,
            separators=(',', ':'),
        ).encode()).hexdigest(),
        'sfntVersion': hashlib.sha256(font.sfntVersion.encode('latin1')).hexdigest(),
    }
    if 'glyf' in font:
        result['glyfHintBytecode'] = hint_digest.hexdigest()
    for tag in sorted(set(font.keys()) - {'GlyphOrder', 'DSIG', 'loca'}):
        if tag not in {'head', 'glyf'}:
            # Read the source table bytes, avoiding XML's escaping/replacement
            # of unusual name/license strings or legacy layout structures.
            # These tables undergo no WOFF2 transform and must be byte-exact.
            result[tag] = hashlib.sha256(font.reader[tag]).hexdigest()
            continue
        output = io.StringIO()
        font[tag].toXML(XMLWriter(output, newlinestr='\n'), font)
        result[tag] = hashlib.sha256(output.getvalue().encode()).hexdigest()
    return result


def validate_equivalence(source: Path, packed: Path) -> dict:
    from fontTools.ttLib import TTFont
    with TTFont(source, recalcBBoxes=False, recalcTimestamp=False) as original:
        _require_supported_empty_glyphs(original)
        signed = 'DSIG' in original and original['DSIG'].usNumSigs > 0
        if signed:
            raise FontPackError(f'Signed DSIG is not modified: {source}')
        empty_dsig = 'DSIG' in original
        tags = sorted(set(original.keys()) - {'GlyphOrder', 'DSIG'})
        glyph_count = len(original.getGlyphOrder())
        cmap_count = len(original.getBestCmap() or {})
        before = _table_quality(original)
    with TTFont(packed, recalcBBoxes=False, recalcTimestamp=False) as decoded:
        _require_supported_empty_glyphs(decoded)
        if decoded.flavor != 'woff2':
            raise FontPackError(f'Not a WOFF2 font: {packed}')
        if sorted(set(decoded.keys()) - {'GlyphOrder', 'DSIG'}) != tags:
            raise FontPackError(f'Font table inventory changed: {source}')
        after = _table_quality(decoded)
    changed = sorted(tag for tag in set(before) | set(after)
                     if before.get(tag) != after.get(tag))
    if changed:
        raise FontPackError(f'Font semantics changed in {source.name}: {changed}')
    quality_digest = hashlib.sha256(json.dumps(
        before, sort_keys=True, separators=(',', ':'),
    ).encode()).hexdigest()
    return {
        'version': QUALITY_VERSION, 'passed': True,
        'sourceSemanticSha256': quality_digest,
        'decodedSemanticSha256': quality_digest,
        'tableDigests': before, 'glyphCount': glyph_count,
        'unicodeMappingCount': cmap_count, 'emptyDsigRemoved': empty_dsig,
    }


def _encode(source: Path, output: Path, *, transform: bool) -> None:
    from fontTools.ttLib import TTFont
    from fontTools.ttLib.woff2 import WOFF2FlavorData
    with TTFont(source, recalcBBoxes=False, recalcTimestamp=False) as font:
        if 'DSIG' in font:
            if font['DSIG'].usNumSigs:
                raise FontPackError(f'Signed DSIG is not modified: {source}')
            del font['DSIG']
        font.flavor = 'woff2'
        if not transform:
            font.flavorData = WOFF2FlavorData(transformedTables=set())
        font.save(output, reorderTables=False)


def _pack_one(args: tuple[str, str]) -> dict:
    root = Path(args[0])
    asset = args[1]
    source = _source_path(root, asset)
    original_sha = sha256(source)
    temporary = root / PACK_FONTS_RELATIVE / f'{original_sha}.partial.{os.getpid()}'
    cached = None
    if (root / PACK_RELATIVE).is_file():
        metadata = json.loads((root / PACK_RELATIVE).read_text())
        for entry in metadata.get('entries', []):
            if entry.get('sourceAsset') == asset and entry.get('sourceSha256') == original_sha:
                candidate = root / PACK_FONTS_RELATIVE / entry['packedFile']
                if candidate.is_file() and sha256(candidate) == entry['packedSha256']:
                    cached = candidate
    if cached is not None:
        equivalence = validate_equivalence(source, cached)
        packed_sha = sha256(cached)
        destination = cached
    else:
        try:
            _encode(source, temporary, transform=True)
            try:
                equivalence = validate_equivalence(source, temporary)
            except FontPackError:
                # Preserve unusual/legacy outline encodings rather than
                # accepting a lossy transform merely to obtain a smaller file.
                _encode(source, temporary, transform=False)
                equivalence = validate_equivalence(source, temporary)
            packed_sha = sha256(temporary)
            destination = root / PACK_FONTS_RELATIVE / (packed_sha[:20] + '.woff2')
            if destination.exists() and sha256(destination) != packed_sha:
                raise FontPackError('Packaged font hash prefix collision')
            temporary.replace(destination)
        finally:
            temporary.unlink(missing_ok=True)
    if sha256(source) != original_sha:
        raise FontPackError(f'Original changed during packaging: {asset}')
    return {
        'sourceAsset': asset, 'sourceSha256': original_sha,
        'sourceBytes': source.stat().st_size,
        'packedFile': destination.name, 'packedSha256': packed_sha,
        'packedBytes': destination.stat().st_size,
        'equivalence': equivalence,
    }


def pack_fonts(manifest: Path, *, root: Path = ROOT, workers: int = 4) -> dict:
    import fontTools
    import brotli
    actual = {'fonttools': fontTools.__version__, 'brotli': brotli.__version__}
    if actual != GENERATOR:
        raise FontPackError(f'Use pinned requirements-web-fonts.txt: {actual}')
    families = json.loads(manifest.read_text())
    assets = sorted({font['asset'] for family in families for font in family['fonts']
                     if font['asset'].startswith('assets/fonts/')})
    if not assets:
        raise FontPackError('No document fonts found in the Flutter manifest')
    prefixes = {}
    for asset in assets:
        digest = sha256(_source_path(root, asset))
        if digest[:20] in prefixes and prefixes[digest[:20]] != digest:
            raise FontPackError('Font name hash prefix collision')
        prefixes[digest[:20]] = digest
    (root / PACK_FONTS_RELATIVE).mkdir(parents=True, exist_ok=True)
    entries = []
    with ProcessPoolExecutor(max_workers=workers) as pool:
        jobs = {pool.submit(_pack_one, (str(root), asset)): asset for asset in assets}
        for job in as_completed(jobs):
            result = job.result()
            entries.append(result)
            print(f"{len(entries)}/{len(assets)} {result['sourceAsset']}: "
                  f"{result['sourceBytes']} -> {result['packedBytes']}", flush=True)
    report = {
        'version': 1, 'generator': GENERATOR,
        'policy': 'Complete fonts; no subsetting, hint removal or original edits.',
        'normalizedContainerFields': [
            'head.checkSumAdjustment', 'head.flags bit 11', 'loca encoding',
            'head.indexToLocFormat', 'duplicate non-first OVERLAP_SIMPLE flags',
            'empty DSIG (never a signed DSIG)',
        ],
        'sourceBytes': sum(entry['sourceBytes'] for entry in entries),
        'packedBytes': sum(entry['packedBytes'] for entry in entries),
        'entries': sorted(entries, key=lambda entry: entry['sourceAsset']),
    }
    destination = root / PACK_RELATIVE
    temporary = destination.with_suffix('.partial')
    temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(destination)
    return report


def load_verified_pack(*, root: Path = ROOT) -> dict[str, dict]:
    report = json.loads((root / PACK_RELATIVE).read_text())
    if report.get('version') != 1 or report.get('generator') != GENERATOR:
        raise FontPackError('Unknown or unverified font package version')
    result = {}
    for entry in report.get('entries', []):
        asset = entry['sourceAsset']
        source = _source_path(root, asset)
        digest = entry['sourceSha256']
        filename = entry['packedFile']
        if (not HEX.fullmatch(digest) or not HEX.fullmatch(entry['packedSha256']) or
                filename != entry['packedSha256'][:20] + '.woff2'):
            raise FontPackError(f'Invalid packaged path/digest: {asset}')
        if asset in result:
            raise FontPackError(f'Duplicate font mapping: {asset}')
        if source.stat().st_size != entry['sourceBytes'] or sha256(source) != digest:
            raise FontPackError(f'Font source changed; regenerate web pack: {asset}')
        packed = root / PACK_FONTS_RELATIVE / filename
        if (packed.stat().st_size != entry['packedBytes'] or
                sha256(packed) != entry['packedSha256'] or
                packed.read_bytes()[:4] != b'wOF2'):
            raise FontPackError(f'Packaged font changed: {filename}')
        quality = entry.get('equivalence', {})
        if (quality.get('version') != QUALITY_VERSION or
                quality.get('passed') is not True or
                not HEX.fullmatch(quality.get('sourceSemanticSha256', '')) or
                quality.get('sourceSemanticSha256') != quality.get('decodedSemanticSha256')):
            raise FontPackError(f'Missing semantic equivalence: {asset}')
        result[asset] = entry
    if not result:
        raise FontPackError('The font package is empty')
    return result


def rewrite_web_font_manifest(
    output: Path,
    delivery: str = 'original',
    *,
    root: Path = ROOT,
) -> dict:
    """Deliver byte-identical sfnt by default, retaining every legacy font path.

    WOFF2 is an explicit experiment, not an automatic payload optimization:
    smaller files do not guarantee a faster first frame on the pinned renderer.
    """
    if delivery not in {'original', 'woff2'}:
        raise FontPackError(f'Unknown web font delivery: {delivery}')
    mapping = load_verified_pack(root=root)
    manifest_path = output / 'assets/FontManifest.json'
    original = json.loads(manifest_path.read_text())
    families = copy.deepcopy(original)
    delivered = {}
    for family in families:
        for font in family['fonts']:
            asset = font['asset']
            if asset.startswith('web_fonts/'):
                matching = [entry for entry in mapping.values()
                            if asset in {
                                'web_fonts/' + entry['packedFile'],
                                'web_fonts/' + entry['sourceSha256'][:20] +
                                PurePosixPath(entry['sourceAsset']).suffix.lower(),
                            }]
                if not matching:
                    raise FontPackError(f'Unknown packaged font: {asset}')
                asset = matching[0]['sourceAsset']
            elif not asset.startswith('assets/fonts/'):
                continue  # SDK/plugin icons are tree-shaken anew on each build.
            if asset not in mapping:
                raise FontPackError(f'New document font needs a web pack: {asset}')
            entry = mapping[asset]
            legacy = output / 'assets' / asset
            if not legacy.is_file() or sha256(legacy) != entry['sourceSha256']:
                raise FontPackError(f'Legacy font path was not preserved: {asset}')
            if delivery == 'original':
                payload = _source_path(root, asset)
                payload_sha = entry['sourceSha256']
                payload_bytes = entry['sourceBytes']
                filename = payload_sha[:20] + PurePosixPath(asset).suffix.lower()
                font_format = 'sfnt'
            else:
                payload = root / PACK_FONTS_RELATIVE / entry['packedFile']
                payload_sha = entry['packedSha256']
                payload_bytes = entry['packedBytes']
                filename = entry['packedFile']
                font_format = 'woff2'
            packed = output / 'assets/web_fonts' / filename
            packed.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(payload, packed)
            if packed.stat().st_size != payload_bytes or sha256(packed) != payload_sha:
                raise FontPackError(f'Web font copy was corrupted: {packed.name}')
            font['asset'] = 'web_fonts/' + filename
            delivered[asset] = {
                'sourceAsset': asset, 'asset': font['asset'],
                'sourceSha256': entry['sourceSha256'],
                'packedSha256': payload_sha, 'sha256': payload_sha,
                'bytes': payload_bytes, 'format': font_format,
            }
    manifest_path.write_text(json.dumps(families, ensure_ascii=False) + '\n')
    return {
        'delivery': delivery,
        'fontFormat': 'sfnt' if delivery == 'original' else 'woff2',
        'documentFontFiles': len(delivered),
        'sourceBytes': sum(mapping[asset]['sourceBytes'] for asset in delivered),
        'packedBytes': sum(item['bytes'] for item in delivered.values()),
        'legacyPathsPreserved': True,
        'deliveryFiles': [delivered[asset] for asset in sorted(delivered)],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack', action='store_true')
    parser.add_argument('--manifest', type=Path,
                        default=ROOT / 'build/review-web/assets/FontManifest.json')
    parser.add_argument('--workers', type=int, default=4)
    args = parser.parse_args()
    if args.pack:
        result = pack_fonts(args.manifest, workers=args.workers)
        print(json.dumps({key: value for key, value in result.items()
                          if key != 'entries'}, indent=2))
    else:
        entries = load_verified_pack()
        print(f'Verified {len(entries)} complete web font mappings')


if __name__ == '__main__':
    main()

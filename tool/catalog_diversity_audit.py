#!/usr/bin/env python3
"""Report source diversity from current catalog snapshots, without rendering.

Only primary IDs in the detail manifest are audited. Each book is decompressed
once and then released; images are streamed into SHA-256 without decoding.
This is a source-fact check, not a visual-quality or publication approval.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
from typing import Any, Iterable, Iterator
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_NEW_IDS = tuple(str(-number) for number in range(9772, 9786))
CATEGORY_OVERRIDES = {'-9301': '웨딩', '-9305': '커플·기념일', '-9502': '여행'}
DEFAULT_TOPICS = (
    '웨딩', '여행', '일상', '성장·육아', '가족·친구', '커플·기념일',
    '반려동물', '스포츠·도전', '졸업·새출발', '동아리', '취미·기록',
)


def normalize_reference(value: str) -> str:
    value = value.strip().replace('\\', '/')
    if value.startswith('asset:'):
        value = value[6:]
    if value.startswith('assets/'):
        return str(PurePosixPath(unquote(urlsplit(value).path)))
    return value


def _first(*values: Any) -> Any:
    return next((value for value in values if value is not None), None)


def material_layers(document: dict[str, Any]) -> Iterator[dict[str, Any]]:
    """Mirror template_material_layers.dart, including payloads and variants."""
    pages = [document] if isinstance(document.get('layers'), list) else []
    cover = document.get('cover')
    if isinstance(cover, dict):
        pages.append(cover)
    pages.extend(page for page in document.get('pages', []) if isinstance(page, dict))
    for page in pages:
        for base in page.get('layers', []):
            if not isinstance(base, dict):
                continue
            candidates = [base]
            overrides = base.get('aspectOverrides')
            if isinstance(overrides, dict):
                candidates.extend({**base, **override} for override in overrides.values()
                                  if isinstance(override, dict))
            for candidate in candidates:
                payload = candidate.get('payload')
                payload = payload if isinstance(payload, dict) else {}
                style = candidate.get('style')
                style_map = style if isinstance(style, dict) else {}
                raw_type = str(candidate.get('type') or 'image').lower()
                kind = ('decoration' if raw_type in {'decoration', 'background'}
                        else raw_type if raw_type in {'text', 'sticker'} else 'image')
                yield {
                    **payload,
                    **{key: value for key, value in candidate.items() if value is not None},
                    'type': kind,
                    'frame': _first(candidate.get('frame'), candidate.get('imageBackground'),
                                    payload.get('imageBackground')),
                    'style': _first(style, candidate.get('frame'),
                                    candidate.get('imageBackground'), payload.get('imageBackground'),
                                    payload.get('imageTemplate')),
                    'wordArtId': _first(candidate.get('wordArtId'), payload.get('wordArtId'),
                                        style_map.get('wordArtId')),
                    'textFillImageUrl': _first(candidate.get('textFillImageUrl'),
                                               payload.get('textFillImageUrl'),
                                               style_map.get('textFillImageUrl')),
                }
    variants = document.get('variants', {})
    children = variants.values() if isinstance(variants, dict) else variants
    if isinstance(children, Iterable):
        for variant in children:
            if isinstance(variant, dict):
                yield from material_layers(variant)


def _constructor_arguments(source: str, constructor: str) -> Iterator[str]:
    """Read literal catalog constructor calls, without executing Dart code."""
    for match in re.finditer(r'\b' + re.escape(constructor) + r'\s*\(', source):
        start = match.end()
        depth, quote, escaped = 1, None, False
        for index in range(start, len(source)):
            char = source[index]
            if quote:
                if escaped:
                    escaped = False
                elif char == '\\':
                    escaped = True
                elif char == quote:
                    quote = None
            elif char in "'\"":
                quote = char
            elif char == '(':
                depth += 1
            elif char == ')':
                depth -= 1
                if depth == 0:
                    yield source[start:index]
                    break


def material_registry(root: Path) -> tuple[set[str], dict[str, str], dict[str, str]]:
    ids: set[str] = set()
    by_value: dict[str, str] = {}
    included: dict[str, str] = {}
    for path in (root / 'lib/core/templates').glob('*.dart'):
        source = path.read_text()
        if 'StudioDecorationSpec(' in source:
            for arguments in _constructor_arguments(source, 'StudioDecorationSpec'):
                identity = re.match(r"\s*(['\"])([^'\"]+)\1\s*,", arguments)
                if not identity:
                    continue
                decoration = identity[2]
                ids.add(decoration)
                by_value[f'deco:{decoration}@1.0'] = f'sticker:{decoration}'
                asset = re.search(r"\bassetPath:\s*(['\"])([^'\"]+)\1", arguments)
                if asset:
                    by_value[normalize_reference(asset[2])] = f'sticker:{decoration}'
        mapping = re.search(r'\bkeepsakeFrameIncludedMaterials\s*=\s*\{([^}]+)\}', source)
        if mapping:
            included.update(re.findall(r"['\"]([^'\"]+)['\"]\s*:\s*['\"]([^'\"]+)['\"]",
                                       mapping[1]))
    return ids, by_value, included


def inspect_document(document: dict[str, Any], decoration_ids: set[str],
                     material_values: dict[str, str], frame_included: dict[str, str]
                     ) -> tuple[set[str], set[str], set[str]]:
    photos: set[str] = set()
    frames: set[str] = set()
    materials: set[str] = set()
    for layer in material_layers(document):
        style = layer.get('style')
        if isinstance(style, str) and style in decoration_ids:
            materials.add(f'sticker:{style}')
        references = {normalize_reference(layer[field])
                      for field in ('imageUrl', 'previewUrl', 'originalUrl')
                      if isinstance(layer.get(field), str) and layer[field]}
        fill = layer.get('textFillImageUrl')
        for reference in references | ({normalize_reference(fill)} if isinstance(fill, str) else set()):
            if reference in material_values:
                materials.add(material_values[reference])
        word_art = layer.get('wordArtId')
        if isinstance(word_art, str) and word_art:
            materials.add(f'phrase:collage-{word_art}')
        if layer['type'] != 'image':
            continue
        photos.update(reference for reference in references if reference not in material_values)
        frame = layer.get('frame')
        if isinstance(frame, str) and frame not in {'', 'none'}:
            key = f'frame:{frame}'
            frames.add(key)
            materials.add(key)
            if frame in frame_included:
                materials.add(frame_included[frame])
    return photos, frames, materials


def _topics(root: Path) -> list[str]:
    path = root / 'lib/core/templates/template_catalog_categories.dart'
    if not path.is_file():
        return list(DEFAULT_TOPICS)
    match = re.search(r'\btemplateTopicOrder\s*=\s*\[([^]]*)\]', path.read_text())
    if not match:
        raise ValueError('Cannot find the stable topic order')
    return re.findall(r"['\"]([^'\"]+)['\"]", match[1])


def _category(document: dict[str, Any], identity: str) -> str | None:
    category = document.get('category')
    if isinstance(category, str) and category.strip():
        return category.strip()
    variants = document.get('variants', {})
    children = variants.values() if isinstance(variants, dict) else variants
    if isinstance(children, Iterable):
        for variant in children:
            if isinstance(variant, dict):
                category = variant.get('category')
                if isinstance(category, str) and category.strip():
                    return category.strip()
    return CATEGORY_OVERRIDES.get(identity)


def _shared(owners: dict[str, set[str]]) -> list[dict[str, Any]]:
    return [{'key': key, 'bookCount': len(books), 'bookIds': sorted(books, key=int)}
            for key, books in sorted(owners.items(), key=lambda row: (-len(row[1]), row[0]))
            if len(books) > 1]


def audit_catalog(root: Path, new_ids: set[str], minimum_per_topic: int = 10,
                  expected_topics: Iterable[str] | None = None) -> dict[str, Any]:
    root = root.resolve()
    directory = root / 'assets/templates/detail_documents'
    manifest = json.loads((directory / 'manifest.json').read_text())
    layout = manifest['layoutRevision']
    if not isinstance(layout, str) or not re.fullmatch(r'[a-z0-9_-]+', layout):
        raise ValueError('Invalid detail layout revision')
    primary_ids = {identity for identity in manifest['documents']
                   if re.fullmatch(r'-\d+', identity)}
    decoration_ids, material_values, frame_included = material_registry(root)
    topics = list(expected_topics) if expected_topics is not None else _topics(root)
    counts: Counter[str] = Counter()
    photo_owners: dict[str, set[str]] = defaultdict(set)
    frame_owners: dict[str, set[str]] = defaultdict(set)
    kit_owners: dict[str, set[str]] = defaultdict(set)
    summaries: list[dict[str, Any]] = []
    issues: list[dict[str, Any]] = []
    for identity in sorted(primary_ids, key=int, reverse=True):
        revision = manifest.get('artworkRevisions', {}).get(identity)
        if revision is not None and (not isinstance(revision, str)
                                     or not re.fullmatch(r'[a-f0-9]{16}', revision)):
            raise ValueError(f'Invalid artwork revision for {identity}')
        filename = f'{identity}.{layout}{"." + revision if revision else ""}.json.gz'
        with gzip.open(directory / filename, 'rb') as handle:
            raw = handle.read()
        digest = hashlib.sha256(raw).hexdigest()
        if digest != manifest['documents'][identity]:
            issues.append({'code': 'document_digest_mismatch', 'bookId': identity})
        document = json.loads(raw)
        del raw
        category = _category(document, identity)
        if category is None:
            issues.append({'code': 'unknown_category', 'bookId': identity})
        else:
            counts[category] += 1
        photos, frames, actual = inspect_document(document, decoration_ids, material_values, frame_included)
        for photo in photos:
            photo_owners[photo].add(identity)
        for frame in frames:
            frame_owners[frame].add(identity)
        for material in actual:
            kit_owners[material].add(identity)
        if identity in new_ids:
            declared = {key for key in document.get('includedMaterialKeys', []) if isinstance(key, str)}
            if actual != declared:
                issues.append({'code': 'new_inventory_mismatch', 'bookId': identity,
                               'declaredButUnused': sorted(declared - actual),
                               'usedButUndeclared': sorted(actual - declared)})
            summaries.append({'id': identity, 'title': document.get('title'),
                              'category': category, 'samplePhotoCount': len(photos),
                              'samplePhotos': sorted(photos), 'actualKitKeys': sorted(actual),
                              'declaredKitKeys': sorted(declared), 'inventoryMatches': actual == declared})
        del document
    missing_new = sorted(new_ids - primary_ids, key=int)
    if missing_new:
        issues.append({'code': 'new_books_not_in_current_manifest', 'bookIds': missing_new})
    for topic in topics:
        if counts[topic] < minimum_per_topic:
            issues.append({'code': 'category_below_minimum', 'category': topic,
                           'count': counts[topic], 'minimum': minimum_per_topic})
    for key, owners in photo_owners.items():
        if owners & new_ids and len(owners) > 1:
            issues.append({'code': 'new_photo_path_reused', 'path': key,
                           'bookIds': sorted(owners, key=int)})
    hash_owners: dict[str, set[str]] = defaultdict(set)
    hash_paths: dict[str, set[str]] = defaultdict(set)
    image_hashes: dict[str, str] = {}
    unhashed: list[str] = []
    for reference, owners in photo_owners.items():
        path = (root / reference).resolve()
        if not reference.startswith('assets/') or not path.is_relative_to(root / 'assets'):
            unhashed.append(reference)
            if owners & new_ids:
                issues.append({'code': 'new_photo_not_local_asset', 'path': reference})
            continue
        if not path.is_file():
            issues.append({'code': 'missing_sample_photo', 'path': reference,
                           'bookIds': sorted(owners, key=int)})
            continue
        hasher = hashlib.sha256()
        with path.open('rb') as handle:
            for block in iter(lambda: handle.read(256 * 1024), b''):
                hasher.update(block)
        digest = hasher.hexdigest()
        image_hashes[reference] = digest
        hash_owners[digest].update(owners)
        hash_paths[digest].add(reference)
    for digest, owners in hash_owners.items():
        if owners & new_ids and (len(owners) > 1 or len(hash_paths[digest]) > 1):
            issues.append({'code': 'new_photo_content_reused', 'sha256': digest,
                           'paths': sorted(hash_paths[digest]), 'bookIds': sorted(owners, key=int)})
    for key, owners in kit_owners.items():
        if owners & new_ids and len(owners) > 1:
            issues.append({'code': 'new_kit_reused', 'productKey': key,
                           'bookIds': sorted(owners, key=int)})
    return {
        'schemaVersion': 1, 'sourceFactsOnly': True, 'passed': not issues,
        'scope': 'current primary detail-manifest IDs; page-count variants and historical files excluded',
        'currentPrimaryBookCount': len(primary_ids),
        'excludedPageCountVariants': len(manifest['documents']) - len(primary_ids),
        'minimumPerTopic': minimum_per_topic, 'configuredTopics': topics,
        'categoryCounts': dict(sorted(counts.items())),
        'newBookIds': sorted(new_ids, key=int, reverse=True), 'newBooks': summaries,
        'reuse': {'samplePaths': _shared(photo_owners),
                  'sampleContent': [{'sha256': digest, 'bookCount': len(owners),
                                     'bookIds': sorted(owners, key=int),
                                     'paths': sorted(hash_paths[digest])}
                                    for digest, owners in sorted(hash_owners.items())
                                    if len(owners) > 1 or len(hash_paths[digest]) > 1],
                  'frames': _shared(frame_owners), 'kitProducts': _shared(kit_owners)},
        'sampleAssetSHA256': image_hashes, 'unhashedNonLocalReferences': sorted(unhashed),
        'issues': issues,
        'limitations': ['No visual quality, font-fit, photograph similarity or print approval is inferred.',
                        'Content duplication means identical SHA-256 bytes; recompressed or near-identical images require visual review.',
                        'One book is read at a time; image bytes are streamed without image decoding.'],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--minimum-per-topic', type=int, default=10)
    parser.add_argument('--new-ids', default=','.join(DEFAULT_NEW_IDS))
    parser.add_argument('--output', type=Path,
                        default=Path('output/diversity-expansion-20261103/diversity-audit.json'))
    args = parser.parse_args()
    if args.minimum_per_topic < 0:
        parser.error('--minimum-per-topic must be nonnegative')
    new_ids = {identity.strip() for identity in args.new_ids.split(',') if identity.strip()}
    if any(not re.fullmatch(r'-\d+', identity) for identity in new_ids):
        parser.error('--new-ids requires comma-separated negative numeric IDs')
    try:
        report = audit_catalog(ROOT, new_ids, args.minimum_per_topic)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'Catalog diversity audit could not read its sources: {error}')
        return 2
    output = args.output if args.output.is_absolute() else ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"Catalog diversity source audit: {report['currentPrimaryBookCount']} books, "
          f"{len(report['issues'])} issues; {output}")
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

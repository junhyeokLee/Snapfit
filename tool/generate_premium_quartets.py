#!/usr/bin/env python3
"""Compile reviewed editorial briefs into small, stable native catalogs."""
import argparse
import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/premium-four-per-topic-20261103'


def dart(v):
    return json.dumps(v, ensure_ascii=False).replace('$', r'\$')


def write(relative, content):
    (ROOT / relative).write_text(content, encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--partial', action='store_true')
    args = parser.parse_args()
    specs = sorted([s for path in OUT.glob('specs-*.json') for s in json.loads(path.read_text())], key=lambda s: abs(s['catalogId']))
    assert len({s['id'] for s in specs}) == len(specs)
    assert len({s['catalogId'] for s in specs}) == len(specs)
    assert len({s['title'] for s in specs}) == len(specs)
    assert len({s['motifCode'] for s in specs}) == len(specs)
    assert len({tuple(s['layoutSequence']) for s in specs}) == len(specs)
    if not args.partial:
        assert len(specs) == 44
        assert {s['catalogId'] for s in specs} == set(range(-9801,-9845,-1))
        assert set(collections.Counter(s['category'] for s in specs).values()) == {4}
        for category in {s['category'] for s in specs}:
            assert len({s['coverMode'] for s in specs if s['category']==category})==4
    books, metadata, decorations, arts, frames, styles, previews, keys, frame_books = [], [], [], [], [], [], [], [], []
    for s in specs:
        identity, cid = s['id'], abs(s['catalogId'])
        k = cid - 9801
        assert 0 <= k < 44
        assert len(s['chapters']) == len(s['notes']) == len(s['layoutSequence']) == 16
        assert len(set(s['layoutSequence'])) == 16
        assert s['layoutSequence'][0] == 0 and s['layoutSequence'][-1] == 31
        assert {3, 9, 19, 29} <= set(s['layoutSequence'])
        assert len(s['photoScenes']) == 6 and len(s['cards']) == 4
        assert len(set(s['paperKinds'])) == len(set(s['frameKinds'])) == 2
        assert all(0 <= kind < 16 for kind in s['paperKinds']+s['frameKinds'])
        assert 0 <= s['coverMode'] < 16
        assert len(set(s['chapters'])) == len(set(s['notes'])) == 16
        assert all(len(card)==3 for card in s['cards'])
        assert s['price'] == 2500
        fa, fb = f'pq{cid}a', f'pq{cid}b'
        photos = [f'assets/templates/premium_quartets_2026/{identity}/{i:02}.jpg' for i in range(1, 7)]
        body = dict(id=identity, catalogId=s['catalogId'], title=s['title'], category=s['category'], englishTitle=s['englishTitle'], subtitle=s['subtitle'], coverStyle=s['coverMode'], paperLabel=s['materialLabels']['paper'], motifLabel=s['materialLabels']['motif'], ink=s['ink'], tint=s['tint'], accent=s['accent'], photoAssets=photos, chapters=s['chapters'], notes=s['notes'], photoFrames=[fa, fb], photoAspectRatios=[1.5]*6, additionalMaterialKeys=[f'sticker:{identity}-vellum', f'sticker:{identity}-keepsake', f'phrase:collage-{identity}-caption'], spreadOrder=s['layoutSequence'], innerPages=32, discoveryTags=['프리미엄', '32쪽', '전용 소재 8종', s['title']])
        books.append('  StoryEdition(\n' + ''.join(f'    {key}: {dart(val)},\n' for key, val in body.items()) + '    isPremium: true, exclusivePhotography: true, qualityRevision: premiumQuartetRevision,\n  ),')
        spec = {key: s[key] for key in ['id', 'title', 'category', 'motifCode', 'ink', 'tint', 'accent', 'paperAccent', 'paperKinds', 'headline', 'tagline', 'font', 'secondaryFont', 'cards', 'phrase2']}
        spec['style'] = k
        metadata.append(f'  {dart(identity)}: PremiumQuartetSpec(\n' + ''.join(f'    {key}: {dart(val)},\n' for key, val in spec.items()) + '  ),')
        keys.append(f'template:{identity}')
        for suffix, category, ratio, width in [('paper', 'paper', 1.25, .7), ('vellum', 'paper', 1.25, .7), ('motif', 'sticker', 1.0, .32), ('keepsake', 'sticker', 1.0, .40)]:
            path = f", assetPath: {dart('assets/sticker/premium_quartets_2026/' + identity + '.webp')}" if suffix == 'keepsake' else ''
            decorations.append(f'  StudioDecorationSpec({dart(identity + "-" + suffix)}, {dart(s["materialLabels"][suffix])}, StudioDecorationCategory.{category}, {ratio}, {width}{path}, collection: {dart(s["title"])}),')
            keys.append(f'sticker:{identity}-{suffix}')
        for suffix, text, height, label in [('', s['headline'], 320, 'title'), ('-caption', s['phrase2'], 220, 'caption')]:
            arts.append(f'  StudioWordArt({dart(identity + suffix)}, {dart(s["materialLabels"][label])}, {dart(text)}, canvasSize: Size(500, {height})),')
            keys.append(f'phrase:collage-{identity}{suffix}')
        for n, frame in enumerate([fa, fb]):
            label = s['materialLabels']['frameA' if n == 0 else 'frameB']
            frames.append('  PremiumQuartetFrameSpec(' + ', '.join(dart(v) for v in [frame, label, s['frameKinds'][n], k, s['ink'], s['tint'], s['accent']]) + '),')
            styles.append(f'  ImageFrameStyle(key: {dart(frame)}, label: {dart(label)}, subtitle: {dart(s["title"] + "의 전용 사진 마운트")}, category: "artistic"),')
            previews.append(f'  {dart(frame)}: {dart(photos[1 if n == 0 else 4])},')
            keys.append(f'frame:{frame}')
            frame_books.append(f'  {dart(frame)}: {dart(identity)},')
    write('lib/core/templates/premium_quartet_catalog.g.dart', "part of 'story_edition_catalog.dart';\n\nconst premiumQuartetEditions = <StoryEdition>[\n" + '\n'.join(books) + '\n];\n\nconst premiumQuartetSpecsById = <String, PremiumQuartetSpec>{\n' + '\n'.join(metadata) + '\n};\n')
    write('lib/core/templates/premium_quartet_material_catalog.g.dart', "part of 'studio_decoration_catalog.dart';\n\nconst premiumQuartetDecorations = <StudioDecorationSpec>[\n" + '\n'.join(decorations) + '\n];\n')
    write('lib/core/templates/premium_quartet_word_art_catalog.g.dart', "part of 'studio_word_art_catalog.dart';\n\nconst premiumQuartetWordArts = <StudioWordArt>[\n" + '\n'.join(arts) + '\n];\n')
    write('lib/core/templates/premium_quartet_frame_catalog.g.dart', "part of 'premium_quartet_frame_catalog.dart';\n\nconst premiumQuartetFrames = <PremiumQuartetFrameSpec>[\n" + '\n'.join(frames) + '\n];\n\nconst premiumQuartetFrameBookIds = <String,String>{\n' + '\n'.join(frame_books) + '\n};\n')
    write('lib/shared/widgets/premium_quartet_frame_styles.g.dart', "part of 'image_frame_style_picker.dart';\n\nconst premiumQuartetFrameStyles = <ImageFrameStyle>[\n" + '\n'.join(styles) + '\n];\n')
    write('lib/core/templates/premium_quartet_preview_photos.g.dart', "part of 'frame_preview_photos.dart';\n\nconst premiumQuartetPreviewPhotos = <String,String>{\n" + '\n'.join(previews) + '\n};\n')
    write('lib/core/templates/premium_quartet_frame_keys.g.dart', "part of 'studio_photo_frame_catalog.dart';\n\nconst premiumQuartetPhotoFrames = <String>{\n" + '\n'.join(f'  {dart(key[6:])},' for key in keys if key.startswith('frame:')) + '\n};\n')
    write('lib/features/point_shop/domain/premium_quartet_release_keys.g.dart', "part of 'point_shop_catalog_release.dart';\n\nconst premiumQuartetReleasedProductKeys = <String>{\n" + '\n'.join(f'  {dart(key)},' for key in keys) + '\n};\n')
    (OUT / 'specs.json').write_text(json.dumps(specs, ensure_ascii=False, indent=2) + '\n')
    (OUT / 'product-keys.json').write_text(json.dumps(keys, ensure_ascii=False, indent=2) + '\n')
    # Flutter asset directories are explicit; never bundle the large authoring originals.
    pubspec = ROOT / 'pubspec.yaml'
    text = pubspec.read_text()
    for folder in ['assets/sticker/premium_quartets_2026/'] + [f'assets/templates/premium_quartets_2026/{s["id"]}/' for s in specs]:
        if f'    - {folder}\n' not in text:
            text = text.replace('  assets:\n', f'  assets:\n    - {folder}\n', 1)
        (ROOT / folder).mkdir(parents=True, exist_ok=True)
    pubspec.write_text(text)
    print(f'Generated {len(specs)} premium books / {len(keys)} products.')


if __name__ == '__main__':
    main()

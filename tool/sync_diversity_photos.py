#!/usr/bin/env python3
"""Save delivered original photos and small book proofs one image at a time."""
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'output/diversity-expansion-20261103'


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def main():
    records = json.loads((OUTPUT / 'source-records.json').read_text())
    for file in sorted(OUTPUT.glob('photo-batch-*.json')):
        records.extend(json.loads(file.read_text()))
    unique = {}
    for record in records:
        if 'path' not in record:
            continue
        key = (record['id'], record['index'])
        if key in unique and unique[key]['path'] != record['path']:
            raise ValueError(f'Conflicting originals for {key}')
        unique[key] = record
    evidence = []
    books = {}
    for (book, index), record in sorted(unique.items()):
        source = Path(record['path'])
        original = OUTPUT / 'originals' / book / f'{index:02}.png'
        asset = ROOT / 'assets/templates/diversity_editions_2026' / book / f'{index:02}.jpg'
        original.parent.mkdir(parents=True, exist_ok=True)
        asset.parent.mkdir(parents=True, exist_ok=True)
        source_hash = digest(source)
        if original.exists():
            assert digest(original) == source_hash, f'Original changed: {book}/{index}'
        else:
            shutil.copyfile(source, original)
        with Image.open(source) as image:
            assert image.size == (1536, 1024), (book, index, image.size)
            if not asset.exists():
                rgb = image.convert('RGB')
                rgb.save(asset, quality=90, optimize=True)
                rgb.close()
        entry = dict(id=book, index=index, source=str(source),
                     original=str(original.relative_to(ROOT)),
                     asset=str(asset.relative_to(ROOT)),
                     sourceSHA256=source_hash, assetSHA256=digest(asset),
                     width=1536, height=1024)
        evidence.append(entry)
        books.setdefault(book, []).append(entry)
    (OUTPUT / 'artwork-provenance.json').write_text(json.dumps(dict(
        generator='built-in image_gen', originalsPreserved=True, records=evidence,
    ), indent=2))
    for book, photos in books.items():
        proof = OUTPUT / f'{book}-photography.jpg'
        if len(photos) != 5 or proof.exists():
            continue
        sheet = Image.new('RGB', (1500, 230), '#eee8dc')
        draw = ImageDraw.Draw(sheet)
        for record in sorted(photos, key=lambda item: item['index']):
            with Image.open(ROOT / record['asset']) as image:
                thumb = ImageOps.contain(image, (290, 194))
                x = (record['index'] - 1) * 300 + 5
                sheet.paste(thumb, (x, 28))
                draw.text((x, 7), f"{book}/{record['index']}", fill='#222222')
                thumb.close()
        sheet.save(proof, quality=90)
        sheet.close()
    print(f'Saved {len(evidence)}/70 exclusive photos; {sum(len(v) == 5 for v in books.values())}/14 full sets.')


if __name__ == '__main__':
    main()

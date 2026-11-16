#!/usr/bin/env python3
"""Deliver originals as small assets, one image at a time without retouching."""
import hashlib
import json
import os
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/premium-four-per-topic-20261103'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    proof = OUT / 'artwork-provenance.json'
    previous = {(r['id'], r['kind'], r['index']): r for r in json.loads(proof.read_text()).get('records', [])} if proof.exists() else {}
    records = [record for path in sorted(OUT.glob('image-records-*.json')) for record in json.loads(path.read_text())]
    unique, evidence = {}, []
    for record in records:
        if 'path' not in record:
            continue
        key = record['id'], record['kind'], record['index']
        if key in unique:
            assert unique[key]['path'] == record['path'], key
        unique[key] = record
    hashes = set()
    for (book, kind, index), record in sorted(unique.items()):
        source = Path(record['path'])
        assert source.is_file(), source
        source_hash = digest(source)
        original = OUT / 'originals' / book / (f'{index:02}.{source_hash[:16]}.png' if kind == 'photo' else f'keepsake.{source_hash[:16]}.png')
        original.parent.mkdir(parents=True, exist_ok=True)
        changed = (previous.get((book,kind,index),{}).get('sourceSHA256') != source_hash
                   or previous.get((book,kind,index),{}).get('derivation') != 'premium-native-assets-v1')
        assert source_hash not in hashes, f'Duplicate source: {book}/{kind}/{index}'
        hashes.add(source_hash)
        if not original.exists():
            try:
                os.link(source, original)
            except OSError:
                shutil.copyfile(source, original)
        assert digest(original) == source_hash, original
        asset = (ROOT / 'assets/templates/premium_quartets_2026' / book / f'{index:02}.jpg'
                 if kind == 'photo' else ROOT / 'assets/sticker/premium_quartets_2026' / f'{book}.webp')
        asset.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(original) as image:
            width, height = image.size
            if kind == 'photo':
                assert image.size == (1536, 1024), (book, index, image.size)
                if not asset.exists() or changed:
                    with image.convert('RGB') as rgb:
                        rgb.save(asset, quality=90, optimize=True)
            else:
                assert width == height, (book, 'cutout should be square', image.size)
                assert 'A' in image.getbands(), (book, 'missing transparency')
                assert image.getchannel('A').getextrema()[0] == 0, (book, 'opaque background')
                silhouette = image.getchannel('A').point(lambda value: 255 if value > 16 else 0).getbbox()
                assert silhouette and min(silhouette[0], silhouette[1], width-silhouette[2], height-silhouette[3]) > 1, (book, 'cutout touches the edge', silhouette)
                if not asset.exists() or changed:
                    image.save(asset, format='WEBP', lossless=True, method=4, exact=True)
                with Image.open(asset) as delivered:
                    assert delivered.convert('RGBA').tobytes() == image.convert('RGBA').tobytes(), book
        evidence.append(dict(id=book, kind=kind, index=index, original=str(original.relative_to(ROOT)),
            asset=str(asset.relative_to(ROOT)), width=width, height=height,
            sourceSHA256=source_hash, assetSHA256=digest(asset), prompt=record.get('prompt'),
            derivation='premium-native-assets-v1'))
    (OUT / 'artwork-provenance.json').write_text(json.dumps(dict(generator='built-in image_gen',
        originalsPreserved=True, photographsRetouched=False, records=evidence), ensure_ascii=False, indent=2)+'\n')
    books = {row['id'] for row in evidence}
    for book in sorted(books):
        photos = [row for row in evidence if row['id'] == book and row['kind'] == 'photo']
        path = OUT / f'{book}-photography.jpg'
        changed_book = any(previous.get((row['id'],row['kind'],row['index']),{}).get('sourceSHA256') != row['sourceSHA256'] or previous.get((row['id'],row['kind'],row['index']),{}).get('derivation') != row['derivation'] for row in evidence if row['id'] == book)
        if len(photos) != 6 or (path.exists() and not changed_book):
            continue
        with Image.new('RGB', (1440, 540), '#eee8dc') as sheet:
            draw = ImageDraw.Draw(sheet)
            for row in photos:
                with Image.open(ROOT / row['asset']) as photo:
                    thumb = ImageOps.contain(photo, (470, 235))
                    x, y = ((row['index']-1)%3)*480+5, ((row['index']-1)//3)*270+25
                    sheet.paste(thumb,(x,y)); thumb.close()
                    draw.text((x,y-18),f'{book}/{row["index"]}',fill='#222222')
            sheet.save(path,quality=88)
    print(f'Delivered {sum(r["kind"]=="photo" for r in evidence)}/264 photos and {sum(r["kind"]=="cutout" for r in evidence)}/44 cutouts.')


if __name__ == '__main__':
    main()

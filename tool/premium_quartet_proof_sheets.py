#!/usr/bin/env python3
"""Small inspection sheets from native proofs; original proof PNGs are kept."""
import argparse
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps
from premium_quartet_paths import review_root

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/premium-four-per-topic-20261103'


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--ids',default='')
    args=parser.parse_args()
    selected=set(args.ids.split(',')) if args.ids else set()
    specs=json.loads((OUT/'specs.json').read_text())
    previews=dict(re.findall(r"'([^']+)': '([^']+)'",
        (ROOT/'lib/core/templates/catalog_preview_assets.g.dart').read_text()))
    completed=[]
    for spec in specs:
        identity=str(spec['catalogId'])
        if selected and identity not in selected:
            continue
        directory=review_root()/identity
        metadata=directory/'review.json'
        if not metadata.exists():
            continue
        proof=json.loads(metadata.read_text())
        assert proof['captures']==51,identity
        with Image.new('RGB',(1600,1800),'#eeeae2') as sheet:
            draw=ImageDraw.Draw(sheet)
            draw.text((15,10),f'{identity} / 32 inner pages / square native proofs',fill='#222')
            for n in range(16):
                source=directory/f'square-spread-{n+1}.png'
                with Image.open(source) as image:
                    thumb=ImageOps.contain(image,(780,195))
                    x,y=(n%2)*800+10,(n//2)*220+30
                    sheet.paste(thumb,(x,y));thumb.close()
                    draw.text((x,y+198),f'{n*2+1:02}-{n*2+2:02} / role {spec["layoutSequence"][n]}',fill='#333')
            sheet.save(directory/'square-layout-sheet.jpg',quality=89)
        with Image.new('RGB',(1500,530),'#eeeae2') as sheet:
            for n,aspect in enumerate(['square','landscape4x3','landscape5x4']):
                with Image.open(directory/f'{aspect}-cover.png') as image:
                    thumb=ImageOps.contain(image,(490,500))
                    sheet.paste(thumb,(n*500+5,15));thumb.close()
            sheet.save(directory/'cover-ratios.jpg',quality=90)
        completed.append(identity)
        book=spec['id']
        frame=f'pq{abs(spec["catalogId"])}'
        materials=[f'frame:{frame}a',f'frame:{frame}b',
            *(f'sticker:{book}-{kind}' for kind in ['paper','vellum','motif','keepsake']),
            f'phrase:collage-{book}',f'phrase:collage-{book}-caption']
        if all(key in previews and (ROOT/previews[key]).is_file() for key in materials):
            with Image.new('RGB',(1440,600),'#eeeae2') as sheet:
                draw=ImageDraw.Draw(sheet)
                for n,key in enumerate(materials):
                    with Image.open(ROOT/previews[key]) as material:
                        with Image.new('RGBA',material.size,'#f7f5f2') as backing:
                            backing.alpha_composite(material.convert('RGBA'))
                            thumb=ImageOps.contain(backing.convert('RGB'),(280,260))
                        x,y=(n%4)*360+30,(n//4)*300+10
                        sheet.paste(thumb,(x,y));thumb.close()
                        draw.text((x,y+267),key.split(':',1)[0]+f' / {n+1}',fill='#222')
                sheet.save(directory/'material-kit.jpg',quality=90)
    complete_books=sorted(path.parent.name for path in review_root().glob('*/review.json')
        if json.loads(path.read_text()).get('captures')==51)
    (OUT/'native-review-index.json').write_text(json.dumps(dict(completeBooks=complete_books,
        capturesPerBook=51,fullProofPngsPreserved=True),indent=2)+'\n')
    print(f'Inspection sheets: {len(completed)} books; full native proofs retained.')


if __name__=='__main__':
    main()

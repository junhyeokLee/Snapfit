#!/usr/bin/env python3
"""Reject stale proof documents or changed photographs before store release."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from premium_quartet_paths import review_root

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/premium-four-per-topic-20261103'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--allow-incomplete',action='store_true')
    args=parser.parse_args()
    specs=json.loads((OUT/'specs.json').read_text())
    manifest=json.loads((ROOT/'assets/templates/detail_documents/manifest.json').read_text())
    results=[]
    for spec in specs:
        identity=str(spec['catalogId'])
        directory=review_root()/identity
        path=directory/'review.json'
        problems=[]
        if not path.exists():
            problems.append('not-rendered')
        else:
            proof=json.loads(path.read_text())
            if proof.get('documentSHA256')!=manifest['documents'][identity]:
                problems.append('stale-document')
            if proof.get('captures')!=51 or proof.get('photoDecodesVerified') is not True:
                problems.append('incomplete-native-captures')
            if len(proof.get('assetSHA256',{}))!=7:
                problems.append('unverified-asset-bytes')
            for asset,expected in proof.get('assetSHA256',{}).items():
                if not (ROOT/asset).is_file() or sha(ROOT/asset)!=expected:
                    problems.append('changed-asset:'+asset)
            for aspect in ['square','landscape4x3','landscape5x4']:
                for name in ['cover']+[f'spread-{i}' for i in range(1,17)]:
                    capture=directory/f'{aspect}-{name}.png'
                    if not capture.is_file():
                        problems.append('missing-capture:'+capture.name)
                        continue
                    with capture.open('rb') as stream:
                        header=stream.read(24)
                    if header[:8]!=b'\x89PNG\r\n\x1a\n' or min(struct.unpack('>II',header[16:24]))<=0:
                        problems.append('invalid-capture:'+capture.name)
        results.append(dict(id=identity,title=spec['title'],passed=not problems,issues=problems))
    result=dict(books=len(results),passed=sum(r['passed'] for r in results),capturesPerBook=51,
        currentDocumentAndAssetsRequired=True,results=results)
    (OUT/'native-proof-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(f'Current native proofs: {result["passed"]}/{result["books"]} books.')
    if not args.allow_incomplete:
        assert result['passed']==44,result


if __name__=='__main__':
    main()

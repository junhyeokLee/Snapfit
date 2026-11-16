#!/usr/bin/env python3
"""Export only current, reviewed books, sequentially with bounded image caches."""
import argparse
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/premium-four-per-topic-20261103'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ids', required=True)
    args = parser.parse_args()
    selected = set(map(int, args.ids.split(',')))
    subprocess.run(['python3', 'tool/verify_premium_quartet_proofs.py', '--allow-incomplete'], cwd=ROOT, check=True)
    proofs = {int(row['id']): row for row in json.loads((OUT / 'native-proof-validation.json').read_text())['results']}
    assert selected and all(proofs[identity]['passed'] for identity in selected), selected
    specs = [row for row in json.loads((OUT / 'specs.json').read_text()) if row['catalogId'] in selected]
    assert len(specs) == len(selected)
    keys = []
    for spec in specs:
        book = spec['id']
        frame = f'pq{abs(spec["catalogId"])}'
        keys.extend([f'frame:{frame}a', f'frame:{frame}b',
            *(f'sticker:{book}-{kind}' for kind in ['paper', 'vellum', 'motif', 'keepsake']),
            f'phrase:collage-{book}', f'phrase:collage-{book}-caption'])
    assert len(keys) == len(set(keys)) == len(selected) * 8
    stem = 'preview-batch-' + '-'.join(str(abs(value)) for value in sorted(selected, reverse=True))
    base = ['flutter', 'test', '--no-pub', '--concurrency=1']
    selection = '--dart-define=EXPORT_TEMPLATE_IDS=' + ','.join(map(str, sorted(selected, reverse=True)))
    commands = [
        ('thumbnails', base + ['--dart-define=EXPORT_CATALOG=true', selection,
            '--dart-define=EXPORT_MATERIAL_KEYS=' + ','.join(keys), 'test/tool/catalog_thumbnail_export_test.dart']),
        ('editorial', base + ['--dart-define=EXPORT_EDITORIAL=true', selection,
            'test/tool/catalog_editorial_export_test.dart']),
    ]
    os.nice(10)
    for name, command in commands:
        with (OUT / f'{stem}-{name}.log').open('w') as log:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
        print(f'{name}: {len(selected)} books complete.', flush=True)
    checkpoint = OUT / 'preview-exported-books.json'
    completed = set(json.loads(checkpoint.read_text())) if checkpoint.exists() else set()
    completed.update(selected)
    checkpoint.write_text(json.dumps(sorted(completed, reverse=True), indent=2) + '\n')


if __name__ == '__main__':
    main()

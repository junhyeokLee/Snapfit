#!/usr/bin/env python3
"""Export catalog facts from existing authored snapshots without font layout.

Use --check in release validation to detect stale catalog metadata. This never
generates documents, rewrites artwork or touches customer data.
"""
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'lib/core/data/catalog_template_metadata.g.dart'


def generate() -> str:
    previews = {}
    source = (ROOT / 'lib/core/data/catalog_preview_documents.g.dart').read_text()
    for match in re.finditer(r'\s*(-\d+):\s*\n\s*("(?:[^"\\]|\\.)*"),', source):
        previews[int(match[1])] = json.loads(json.loads(match[2]))
    if not previews:
        raise RuntimeError('No exported catalog previews were found')
    directory = ROOT / 'assets/templates/detail_documents'
    manifest = json.loads((directory / 'manifest.json').read_text())
    layout = manifest['layoutRevision']
    if not isinstance(layout, str) or not re.fullmatch(r'[a-z0-9_-]+', layout):
        raise RuntimeError('Invalid detail layout revision')
    facts = {}
    for template_id, preview in previews.items():
        document_id = str(template_id)
        artwork = manifest.get('artworkRevisions', {}).get(document_id)
        if artwork is not None and not re.fullmatch(r'[a-f0-9]{16}', artwork):
            raise RuntimeError(f'Invalid detail artwork revision: {document_id}')
        revision = f'{layout}.{artwork}' if artwork is not None else layout
        path = directory / f'{document_id}.{revision}.json.gz'
        raw = gzip.decompress(path.read_bytes())
        digest = hashlib.sha256(raw).hexdigest()
        if digest != manifest['documents'].get(document_id):
            raise RuntimeError(f'Detail snapshot differs from manifest: {document_id}')
        if artwork is not None and not digest.startswith(artwork):
            raise RuntimeError(f'Detail artwork fingerprint is stale: {document_id}')
        document = json.loads(raw)
        nodes = [document, *document.get('variants', {}).values()]
        ratios = set()
        for node in nodes:
            width = node.get('designWidth', node.get('metadata', {}).get('designWidth'))
            height = node.get('designHeight', node.get('metadata', {}).get('designHeight'))
            if isinstance(width, (float, int)) and isinstance(height, (float, int)) and height > 0:
                ratios.add(width / height)
        facts[str(template_id)] = {
            'profile': preview['profile'],
            'ratios': sorted(ratios),
        }
    encoded = json.dumps(facts, ensure_ascii=False, indent=2)
    return (
        '// Generated from the shipped preview and complete detail snapshots.\n'
        '// Run tool/generate_catalog_template_metadata.py after catalog exports.\n'
        "const catalogTemplateMetadataJson = r'''\n" + encoded + "\n''';\n"
    )


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    content = generate()
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_text() != content:
            raise SystemExit('Catalog template metadata is stale; regenerate after catalog exports')
        print('Catalog template metadata matches the shipped snapshots')
    else:
        OUTPUT.write_text(content)
        print(OUTPUT.relative_to(ROOT))

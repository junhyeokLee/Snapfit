#!/usr/bin/env python3
"""Verify the deployed storefront and every new delivered file, read-only."""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import re
import ssl
import urllib.request
from urllib.parse import urlsplit
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/premium-four-per-topic-20261103'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--build', type=Path, default=ROOT / 'build/review-web')
    parser.add_argument('--url', default='https://snapfit-c719d.web.app')
    args = parser.parse_args()
    specs = json.loads((OUT / 'specs.json').read_text())
    rows = json.loads((OUT / 'price-rows.json').read_text())
    provenance = json.loads((OUT / 'artwork-provenance.json').read_text())['records']
    assert len(specs) == 44 and len(rows) == 396 and len(provenance) == 308
    previews = dict(re.findall(r"'([^']+)': '([^']+)'",
        (ROOT / 'lib/core/templates/catalog_preview_assets.g.dart').read_text()))
    editorial = dict(re.findall(r"(-\d+): '([^']+)'",
        (ROOT / 'lib/core/templates/catalog_editorial_assets.g.dart').read_text()))
    manifest = json.loads((ROOT / 'assets/templates/detail_documents/manifest.json').read_text())
    files = {'index.html', 'snapfit-web-build.json'}
    previous = json.loads((OUT / 'previous-books-public-files.json').read_text())
    prior_bootstraps = {row['path'] for row in previous['checks']
        if re.fullmatch(r'flutter_bootstrap\.[a-f0-9]+\.js', row['path'])}
    files.update(row['path'] for row in previous['checks']
        if re.fullmatch(r'(main\.[a-f0-9]+\.dart\.js|flutter_bootstrap\.[a-f0-9]+\.js)', row['path']))
    for spec in specs:
        identity = str(spec['catalogId'])
        files.add('assets/' + previews['template:' + identity])
        files.add('assets/' + editorial[identity])
        revision = manifest['artworkRevisions'][identity]
        files.add(f'assets/assets/templates/detail_documents/{identity}.{manifest["layoutRevision"]}.{revision}.json.gz')
    for row in rows:
        if row['kind'] != 'template':
            files.add('assets/' + previews[row['product_key']])
    files.update('assets/' + record['asset'] for record in provenance)
    build = json.loads((args.build / 'snapfit-web-build.json').read_text())
    files.update([build['main_file'], build['bootstrap_file']])
    assert build['main_sha256'] == sha(args.build / build['main_file'])
    assert build['bootstrap_sha256'] == sha(args.build / build['bootstrap_file'])
    context = ssl.create_default_context(cafile='/etc/ssl/cert.pem')

    def verify(relative):
        # Cached HTML is intentionally redirected to the new startup script.
        # The old main remains immutable for already running browser tabs.
        redirected_startup = relative in prior_bootstraps and relative != build['bootstrap_file']
        local = args.build / (build['bootstrap_file'] if redirected_startup else relative)
        expected = sha(local)
        if relative.startswith('assets/'):
            source = ROOT / relative.removeprefix('assets/')
            assert sha(source) == expected, ('build differs from reviewed source', relative)
        request = urllib.request.Request(args.url.rstrip('/') + '/' + relative,
            headers={'Cache-Control': 'no-cache', 'Accept-Encoding': 'identity'})
        digest = hashlib.sha256()
        size = 0
        with urllib.request.urlopen(request, context=context, timeout=60) as response:
            content_type = response.headers.get('Content-Type', '')
            resolved_url = response.geturl()
            if redirected_startup:
                assert urlsplit(resolved_url).path == '/' + build['bootstrap_file'], (relative, resolved_url)
            while chunk := response.read(128 * 1024):
                digest.update(chunk)
                size += len(chunk)
        actual = digest.hexdigest()
        # Hosting's missing-file fallback can return index.html with status 200.
        assert actual == expected, (relative, expected, actual, content_type)
        return dict(path=relative, bytes=size, sha256=actual, contentType=content_type,
            resolvedURL=resolved_url, compatibilityRedirect=redirected_startup)

    # Stream at most three files at once; never retain remote media in memory.
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        checks = list(pool.map(verify, sorted(files)))
    result = dict(verifiedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        url=args.url, books=44, materials=352, artworkFiles=308,
        allMatch=True, build=build, count=len(checks), checks=checks)
    (OUT / 'public-files.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f'Public storefront files verified: {len(checks)} exact SHA256 matches.')


if __name__ == '__main__':
    main()

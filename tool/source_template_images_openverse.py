#!/usr/bin/env python3
"""Source free/commercial-use candidate images for Snapfit templates via Openverse.

This does NOT blindly approve images. It downloads candidates with provenance so
Hermes/human review can reject logos, readable text, identifiable faces, bad
composition, or license/release concerns before wiring them into templates.

No API key is required for Openverse. Results can include CC BY images, so
attribution is required unless the license is CC0/PDM.
"""
from __future__ import annotations

import argparse
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parents[1]
BRIEFS = ROOT / 'assets/templates/_art_direction/template_image_briefs.json'
UA = 'Snapfit template image sourcing bot/1.0 (commercial-use metadata review; no bulk redistribution)'
OPENVERSE = 'https://api.openverse.engineering/v1/images/'

QUERY_OVERRIDES = {
    'jeju_travel_v1': [
        'airport friends luggage back view travel',
        'car window iced coffee road trip hand',
        'cafe table coffee dessert sunglasses hand travel',
        'friends walking beach back view travel',
        'market hands food tangerines travel',
        'guesthouse suitcase bed camera hat travel',
        'sunset couple silhouette taking photo coast',
        'travel photo dump instant photos shells hand',
    ],
    'wedding_editorial_v1': [
        'wedding couple back view veil candid',
        'wedding bouquet hands walking',
        'wedding rings invitation flowers detail',
        'wedding veil hands close up',
        'wedding table candle flowers detail',
        'wedding couple silhouette window',
    ],
    'save_the_date_v1': [
        'couple hands card flowers engagement',
        'wedding stationery flowers hands',
        'engagement ring coffee flowers detail',
        'couple walking back view engagement',
        'wedding date card hands no text',
    ],
    'soft_babybook_v1': [
        'baby feet parent hands blanket',
        'baby hand parent hand blanket',
        'nursery toy blanket soft light',
        'baby milestone card hands no text',
        'family silhouette window baby room',
    ],
    'family_weekend_v1': [
        'family walking back view park picnic',
        'child hands drawing table home',
        'family dining table home toys',
        'parent child hands park',
        'family picnic blanket snacks hands',
    ],
    'film_diary_v1': [
        'hands film camera cafe table',
        'friends walking street back view film',
        'printed photos tape diary flatlay',
        'coffee camera strap table hands',
        'bus window silhouette travel film',
    ],
    'minimal_editorial_v1': [
        'hands arranging book flower table minimal',
        'window chair quiet lifestyle person crop',
        'fabric clothing detail hands minimal',
        'table setting flowers hands editorial',
        'person back view gallery street minimal',
    ],
    'anniversary_days_v1': [
        'couple hands cake flowers anniversary',
        'birthday cake candle hands couple',
        'instant photos couple table flowers',
        'restaurant table hands flowers date',
        'couple walking street back view anniversary',
    ],
    'scrapbook_v1': [
        'hands arranging printed photos tape scrapbook',
        'desk flatlay receipts coffee photos hands',
        'friends back view candid street travel',
        'polaroid pile hand tape diary',
        'ticket cafe detail hands scrapbook',
    ],
}


def slugify(s: str) -> str:
    return re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_')[:80]


def template_slug(template_id: str) -> str:
    return re.sub(r'_v\d+$', '', template_id)


def request_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode('utf-8'))


def search(query: str, page_size: int, page: int = 1) -> list[dict]:
    params = {
        'q': query,
        'license_type': 'commercial',
        'page_size': str(page_size),
        'page': str(page),
    }
    url = OPENVERSE + '?' + urllib.parse.urlencode(params)
    data = request_json(url)
    return data.get('results', [])


def ext_from_result(result: dict) -> str:
    url = result.get('url') or result.get('thumbnail') or ''
    path = urllib.parse.urlparse(url).path.lower()
    for ext in ['.jpg', '.jpeg', '.png', '.webp']:
        if path.endswith(ext):
            return '.jpg' if ext == '.jpeg' else ext
    return '.jpg'


def download(url: str, dest: Path) -> bool:
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    try:
        with urllib.request.urlopen(req, timeout=45) as r:
            ctype = r.headers.get('content-type', '')
            data = r.read(12_000_000)
    except (HTTPError, URLError, TimeoutError, ValueError) as exc:
        print(f'WARN download failed: {url} ({exc})')
        return False
    if not ctype.startswith('image/') and not data.startswith((b'\xff\xd8', b'\x89PNG', b'RIFF')):
        print(f'WARN non-image skipped: {url} content-type={ctype}')
        return False
    dest.write_bytes(data)
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--template', default='jeju_travel_v1', help='Template ID, or all')
    ap.add_argument('--per-role', type=int, default=2, help='Candidates to download per query/role')
    ap.add_argument('--search-size', type=int, default=12, help='Openverse search results inspected per query')
    ap.add_argument('--dry-run', action='store_true', help='Print candidates without downloading')
    args = ap.parse_args()

    briefs = json.loads(BRIEFS.read_text())
    template_ids = list(briefs['templates']) if args.template == 'all' else [args.template]
    all_meta = {
        'source': 'Openverse',
        'downloadedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'reviewStatus': 'candidates-only-needs-human-visual-and-license-review',
        'commercialUseNote': 'Openverse license_type=commercial filters out non-commercial licenses, but each image still requires license/attribution/model-property release review before app release.',
        'templates': {},
    }

    for tid in template_ids:
        if tid not in briefs['templates']:
            raise SystemExit(f'Unknown template: {tid}')
        slug = template_slug(tid)
        out_dir = ROOT / 'assets/templates' / slug / 'images/free_stock_candidates'
        out_dir.mkdir(parents=True, exist_ok=True)
        queries = QUERY_OVERRIDES.get(tid) or [briefs['templates'][tid]['cover'], *briefs['templates'][tid].get('pages', [])]
        tmeta = {'templateId': tid, 'title': briefs['templates'][tid]['title'], 'candidates': []}
        print(f'== {tid} -> {out_dir.relative_to(ROOT)} ==')
        for role_index, query in enumerate(queries, start=1):
            print(f'query {role_index}: {query}')
            try:
                results = search(query, args.search_size)
            except Exception as exc:
                print(f'WARN search failed: {query} ({exc})')
                continue
            kept = 0
            for result in results:
                if kept >= args.per_role:
                    break
                image_url = result.get('url') or result.get('thumbnail')
                if not image_url:
                    continue
                ext = ext_from_result(result)
                fname = f'{role_index:02d}_{slugify(query)}__{kept+1}{ext}'
                rel = Path('assets/templates') / slug / 'images/free_stock_candidates' / fname
                item = {
                    'roleIndex': role_index,
                    'query': query,
                    'asset': str(rel),
                    'title': result.get('title'),
                    'creator': result.get('creator'),
                    'provider': result.get('provider'),
                    'license': result.get('license'),
                    'licenseVersion': result.get('license_version'),
                    'foreignLandingUrl': result.get('foreign_landing_url'),
                    'imageUrl': image_url,
                    'status': 'candidate-needs-review',
                    'reviewChecklist': ['commercial license still valid', 'attribution recorded if required', 'no readable text/logo/brand', 'no identifiable face unless release is verified', 'fits page role and emotional direction'],
                }
                if args.dry_run:
                    print('  candidate', item['license'], item['provider'], item['title'], item['foreignLandingUrl'])
                    tmeta['candidates'].append(item)
                    kept += 1
                    continue
                if download(image_url, ROOT / rel):
                    print('  saved', rel)
                    tmeta['candidates'].append(item)
                    kept += 1
        all_meta['templates'][tid] = tmeta
        meta_path = out_dir / 'openverse_candidates.json'
        meta_path.write_text(json.dumps(tmeta, ensure_ascii=False, indent=2) + '\n')
        print('metadata', meta_path.relative_to(ROOT))

    if args.template == 'all':
        all_path = ROOT / 'assets/templates/_art_direction/openverse_candidate_batch.json'
        all_path.write_text(json.dumps(all_meta, ensure_ascii=False, indent=2) + '\n')
        print('batch metadata', all_path.relative_to(ROOT))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())

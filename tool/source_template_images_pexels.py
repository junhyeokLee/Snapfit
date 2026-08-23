#!/usr/bin/env python3
"""Source Snapfit template image candidates from Pexels.

Requires a free PEXELS_API_KEY from https://www.pexels.com/api/ .
This avoids OpenAI API billing and user file uploads while still allowing
Hermes to download images directly into the repo.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parents[1]
BRIEFS = ROOT / 'assets/templates/_art_direction/template_image_briefs.json'
API = 'https://api.pexels.com/v1/search'
UA = 'Snapfit template sourcing/1.0'

QUERY_OVERRIDES = {
    'jeju_travel_v1': [
        'airport travel friends luggage back view',
        'road trip car window iced coffee travel',
        'cafe table coffee dessert hand travel',
        'friends walking beach back view',
        'market food hands tangerines travel',
        'hotel room suitcase camera travel',
        'couple silhouette sunset coast phone',
        'travel photos flatlay hand shells',
    ],
    'wedding_editorial_v1': [
        'wedding couple back view veil', 'wedding bouquet hands', 'wedding rings flowers invitation', 'wedding veil close up hands', 'wedding table candles flowers', 'wedding couple silhouette window'
    ],
    'save_the_date_v1': [
        'engagement couple hands card flowers', 'wedding stationery flowers hands', 'engagement ring flowers coffee', 'couple walking back view engagement', 'wedding venue couple back view'
    ],
    'soft_babybook_v1': [
        'baby feet parent hands blanket', 'baby hand parent hand', 'nursery toys blanket', 'baby milestone card hands', 'family baby window silhouette'
    ],
    'family_weekend_v1': [
        'family walking park back view picnic', 'child hands drawing table', 'family dining table home', 'parent child hands park', 'family picnic blanket snacks'
    ],
    'film_diary_v1': [
        'hands film camera cafe table', 'friends walking street back view', 'printed photos tape diary', 'coffee camera strap table', 'bus window silhouette travel'
    ],
    'minimal_editorial_v1': [
        'hands book flower table minimal', 'window chair lifestyle person', 'fabric clothing detail hands', 'minimal table setting flowers', 'person back view gallery street'
    ],
    'anniversary_days_v1': [
        'couple hands cake flowers anniversary', 'cake candle hands couple', 'instant photos couple table flowers', 'restaurant table hands date', 'couple walking street back view'
    ],
    'scrapbook_v1': [
        'hands arranging printed photos', 'desk flatlay photos coffee hands', 'friends back view candid street', 'polaroid pile hand tape', 'ticket cafe detail hands'
    ],
}


def slugify(s: str) -> str:
    return re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_')[:80]


def template_slug(template_id: str) -> str:
    return re.sub(r'_v\d+$', '', template_id)


def pexels_search(query: str, per_page: int) -> list[dict]:
    key = os.environ.get('PEXELS_API_KEY')
    if not key:
        raise SystemExit('PEXELS_API_KEY is not set. Create a free key at https://www.pexels.com/api/ and export it in the VPS/container shell.')
    params = urllib.parse.urlencode({'query': query, 'orientation': 'portrait', 'per_page': str(per_page)})
    req = urllib.request.Request(API + '?' + params, headers={'Authorization': key, 'User-Agent': UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode()).get('photos', [])
    except HTTPError as exc:
        detail = exc.read().decode('utf-8', 'replace')
        raise SystemExit(f'Pexels search failed: HTTP {exc.code} {exc.reason}\n{detail}') from exc


def download(url: str, dest: Path) -> bool:
    try:
        req = urllib.request.Request(url, headers={'User-Agent': UA})
        with urllib.request.urlopen(req, timeout=45) as r:
            data = r.read(15_000_000)
    except (HTTPError, URLError, TimeoutError, ValueError) as exc:
        print(f'WARN download failed: {url} ({exc})')
        return False
    dest.write_bytes(data)
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--template', default='jeju_travel_v1', help='Template ID, or all')
    ap.add_argument('--per-role', type=int, default=2)
    ap.add_argument('--search-size', type=int, default=8)
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()
    briefs = json.loads(BRIEFS.read_text())
    template_ids = list(briefs['templates']) if args.template == 'all' else [args.template]
    for tid in template_ids:
        slug = template_slug(tid)
        out_dir = ROOT / 'assets/templates' / slug / 'images/pexels_candidates'
        out_dir.mkdir(parents=True, exist_ok=True)
        queries = QUERY_OVERRIDES.get(tid) or [briefs['templates'][tid]['cover'], *briefs['templates'][tid].get('pages', [])]
        meta = {
            'templateId': tid,
            'title': briefs['templates'][tid]['title'],
            'source': 'Pexels',
            'license': 'Pexels License; verify current terms before release: https://www.pexels.com/license/',
            'downloadedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'reviewStatus': 'candidates-only-needs-human-visual-review',
            'candidates': [],
        }
        print(f'== {tid} -> {out_dir.relative_to(ROOT)} ==')
        for role_index, query in enumerate(queries, 1):
            print('query', role_index, query)
            photos = pexels_search(query, max(args.search_size, args.per_role))
            kept = 0
            for photo in photos:
                if kept >= args.per_role:
                    break
                src = photo.get('src') or {}
                url = src.get('large2x') or src.get('large') or src.get('original')
                if not url:
                    continue
                rel = Path('assets/templates') / slug / 'images/pexels_candidates' / f'{role_index:02d}_{slugify(query)}__{kept+1}.jpg'
                item = {
                    'roleIndex': role_index,
                    'query': query,
                    'asset': str(rel),
                    'pexelsId': photo.get('id'),
                    'photographer': photo.get('photographer'),
                    'photographerUrl': photo.get('photographer_url'),
                    'sourceUrl': photo.get('url'),
                    'imageUrl': url,
                    'status': 'candidate-needs-review',
                    'reviewChecklist': ['fits emotional/page role', 'no logo/brand/readable text', 'no identifiable face unless acceptable under license/context', 'crop works with layout safe zones'],
                }
                if args.dry_run:
                    print('  candidate', item['pexelsId'], item['photographer'], item['sourceUrl'])
                    meta['candidates'].append(item)
                    kept += 1
                elif download(url, ROOT / rel):
                    print('  saved', rel)
                    meta['candidates'].append(item)
                    kept += 1
        (out_dir / 'pexels_candidates.json').write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n')
        print('metadata', (out_dir / 'pexels_candidates.json').relative_to(ROOT))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())

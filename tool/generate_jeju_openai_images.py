#!/usr/bin/env python3
"""Generate Snapfit Jeju template images with OpenAI gpt-image-1.

Requires OPENAI_API_KEY in the environment. Do not paste API keys into chat.
Outputs PNG files and a metadata JSON next to the assets.

Art direction: real-person travel snapshots, not generic scenery. Use people
from behind, hands, cafe/food/detail objects, car-window and guesthouse moments,
while avoiding recognizable faces, logos, brands, or readable text.
"""
from __future__ import annotations
import base64, json, os, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_META = ROOT / 'assets/templates/jeju_travel/images/generated_ai/openai_generation_metadata.json'
API = 'https://api.openai.com/v1/images/generations'

DATA = {
  'model': 'gpt-image-1',
  'size': '1024x1536',
  'quality': 'high',
  'n': 1,
}
NEG = ' No logos, no brands, no readable copyrighted signage, no famous landmarks with restricted property issues, no recognizable faces, no celebrity likeness, no watermark, no text embedded in image, no generic empty landscape-only photos.'
IMAGES = [
  ('assets/templates/jeju_travel/images/generated_ai/jeju_airport_arrival_snap.png', 'Realistic smartphone travel snapshot, two Korean friends seen from behind at an airport window just before a Jeju trip, small carry-on suitcase, boarding pass in hand but no readable text, soft morning light, candid everyday composition, premium but natural, no recognizable faces, no logos, no brand signage, no watermark, vertical 3:4. Feels like a real person took it during travel, not a generic landscape.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_rental_car_window_snap.png', 'Realistic candid travel photo from inside a rental car on a fictional Jeju-inspired coastal road, friend in passenger seat partly visible from behind, hand holding an iced coffee near the window, ocean and low volcanic hill outside, natural smartphone perspective, slight motion feeling, no readable signs, no logos, no recognizable face, vertical 3:4, warm sea-blue and sand palette.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_cafe_table_snap.png', 'Realistic casual cafe table snapshot from a Jeju trip, two coffee cups, tangerine dessert, sunglasses, camera strap, and a blank paper ticket on a wooden table by a bright window, one person’s hand lightly entering frame, no readable text, no brands, no logos, natural daylight, premium lifestyle photo but still like a real traveler took it, vertical 3:4.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_beach_friends_back_snap.png', 'Realistic travel photo of two friends from behind walking on a quiet Jeju-inspired beach, one holding sandals and a phone, wind in hair, casual clothes, ocean in background but people are the main subject, candid smartphone photo feeling, no visible faces, no logos, no readable text, warm natural colors, vertical 3:4.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_market_hands_snap.png', 'Realistic candid close-up from a Jeju-style local market, hands holding a small paper tray of street food and tangerines, blurred travel companion in background with face turned away, no readable signage, no brands, no logos, natural smartphone snapshot, lively but tasteful editorial color, vertical 3:4.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_guesthouse_mirror_snap.png', 'Realistic cozy guesthouse travel snapshot, open suitcase on bed, sun hat, film camera, postcards with no readable text, partial mirror reflection of traveler from shoulder down only, warm afternoon window light, no recognizable face, no logos, no brands, natural personal travel diary feeling, vertical 3:4.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_sunset_couple_silhouette_snap.png', 'Realistic candid sunset photo of a couple or two friends seen as small silhouettes from behind on a fictional Jeju-inspired coastal path, one person holding a phone up to take a photo, coral sky, ocean and grass around them, human travel memory first, landscape second, no faces, no logos, no readable text, vertical 3:4, premium emotional closing image.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_photo_dump_detail_snap.png', 'Realistic overhead photo dump flatlay from a Jeju trip: instant photos with blank white borders, rental car key without logo, sunscreen tube with no label, tangerines, shells, cafe receipt with no readable text, friend’s hand arranging photos, natural messy-but-curated smartphone diary aesthetic, vertical 3:4.'),
]

def call(prompt: str) -> bytes:
    key = os.environ.get('OPENAI_API_KEY')
    if not key:
        raise SystemExit('OPENAI_API_KEY is not set. Export it in the VPS/container shell and rerun.')
    payload = dict(DATA, prompt=prompt + NEG)
    req = urllib.request.Request(API, data=json.dumps(payload).encode(), headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=180) as resp:
        body = json.loads(resp.read().decode())
    b64 = body['data'][0].get('b64_json')
    if not b64:
        raise RuntimeError(f'No b64_json returned: {body}')
    return base64.b64decode(b64)

def main() -> int:
    meta = {
        'provider': 'OpenAI',
        'model': DATA['model'],
        'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'artDirection': 'real-person Jeju travel snapshots: friends from behind, hands, cafe, food, car-window, guesthouse, photo-dump details; no generic scenery-only set',
        'assets': [],
    }
    for asset, prompt in IMAGES:
        path = ROOT / asset
        path.parent.mkdir(parents=True, exist_ok=True)
        print(f'generating {asset}...')
        path.write_bytes(call(prompt))
        meta['assets'].append({'asset': asset, 'prompt': prompt, 'status': 'generated-needs-human-review'})
    OUT_META.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n')
    print(OUT_META)
    return 0
if __name__ == '__main__':
    raise SystemExit(main())

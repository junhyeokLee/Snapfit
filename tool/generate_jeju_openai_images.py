#!/usr/bin/env python3
"""Generate Snapfit template images with OpenAI gpt-image-1.

Requires OPENAI_API_KEY in the environment. Do not paste API keys into chat.
Outputs PNG files and a metadata JSON next to the assets.
"""
from __future__ import annotations
import base64, json, os, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPT_DOC = ROOT / 'docs/JEJU_TRAVEL_AI_IMAGE_PROMPTS.md'
OUT_META = ROOT / 'assets/templates/jeju_travel/images/generated_ai/openai_generation_metadata.json'
API = 'https://api.openai.com/v1/images/generations'

DATA = {
  'model': 'gpt-image-1',
  'size': '1024x1536',
  'quality': 'high',
  'n': 1,
}
NEG = ' No logos, no brands, no readable copyrighted signage, no famous landmarks with restricted property issues, no recognizable faces, no celebrity likeness, no watermark, no text embedded in image.'
IMAGES = [
  ('assets/templates/jeju_travel/images/generated_ai/jeju_aerial_hero.png', 'Premium editorial travel photography for a mobile photobook template: aerial view of a fictional Jeju-inspired volcanic island coastline, turquoise ocean, soft morning haze, sandy beige and sea-blue palette, cinematic but natural, no people, no buildings with logos, no text, high-end magazine cover image, vertical 3:4 composition, generous negative space near lower third.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_oreum_morning.png', 'Designer-grade travel magazine photo, fictional Jeju-inspired green volcanic oreum hill at morning light, winding walking path, sea visible in distance, calm atmosphere, natural colors, no people, no signage, no text, vertical 3:4, premium stock photography feel.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_ocean_wave.png', 'Close coastal ocean scene for premium travel photobook, turquoise waves meeting pale sand and black volcanic rocks, soft sunlight, no people, no text, no logo, high-end editorial stock photo, vertical 3:4 composition.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_basalt_detail.png', 'Premium detail photograph of black volcanic basalt rocks and white sea foam, Jeju-inspired coastline but fictional, tactile texture, elegant muted tones, no people, no text, no watermark, vertical 3:4, suitable for paid travel magazine template interior page.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_sunset_silhouette.png', 'Cinematic fictional island coastline sunset, warm coral sky, calm sea, soft silhouette of grass and distant hill, no recognizable people, no text, no logos, high-end travel magazine closing page image, vertical 3:4, refined premium mood.'),
  ('assets/templates/jeju_travel/images/generated_ai/jeju_ticket_cafe_detail.png', 'Premium travel detail photo: blank paper ticket, coffee cup, and small shell on a warm cafe table by a window with sea-blue light, no readable text, no logo, no brand, hands not visible, editorial still life, vertical 3:4, refined beige and coral palette.'),
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
    meta = {'provider': 'OpenAI', 'model': DATA['model'], 'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'assets': []}
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

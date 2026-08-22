# 제주의 기록 AI Image Generation Prompts

이 문서는 `제주의 기록` 템플릿을 상업 배포 가능한 이미지 세트로 교체하기 위한 GPT 이미지 생성 프롬프트와 provenance 기준입니다.

- Target provider: OpenAI `gpt-image-1` or equivalent licensed image-generation provider
- Required output: vertical 3:4 PNG, no logo, no readable text, no recognizable people
- Production rule: 생성 결과물은 사람 검수 후 `_licenses/jeju_travel_sources.md`에 provider/job id/terms snapshot/status를 기록해야 합니다.

```json
{
  "templateId": "jeju_travel_v1",
  "provider": "openai-gpt-image-1",
  "commercial_use_note": "Generated images may be used commercially subject to the active OpenAI terms and the user/org compliance policy. Keep this file plus generated asset metadata as the provenance record.",
  "negative_prompt": "No logos, no brands, no readable copyrighted signage, no famous landmarks with restricted property issues, no recognizable faces, no celebrity likeness, no watermark, no text embedded in image.",
  "images": [
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_aerial_hero.png",
      "role": "cover / aerial hero",
      "prompt": "Premium editorial travel photography for a mobile photobook template: aerial view of a fictional Jeju-inspired volcanic island coastline, turquoise ocean, soft morning haze, sandy beige and sea-blue palette, cinematic but natural, no people, no buildings with logos, no text, high-end magazine cover image, vertical 3:4 composition, generous negative space near lower third."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_oreum_morning.png",
      "role": "oreum / morning landscape",
      "prompt": "Designer-grade travel magazine photo, fictional Jeju-inspired green volcanic oreum hill at morning light, winding walking path, sea visible in distance, calm atmosphere, natural colors, no people, no signage, no text, vertical 3:4, premium stock photography feel."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_ocean_wave.png",
      "role": "ocean / postcard page",
      "prompt": "Close coastal ocean scene for premium travel photobook, turquoise waves meeting pale sand and black volcanic rocks, soft sunlight, shallow atmospheric depth, no people, no text, no logo, high-end editorial stock photo, vertical 3:4 composition."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_basalt_detail.png",
      "role": "basalt / texture detail",
      "prompt": "Premium detail photograph of black volcanic basalt rocks and white sea foam, Jeju-inspired coastline but fictional, tactile texture, elegant muted tones, no people, no text, no watermark, vertical 3:4, suitable for paid travel magazine template interior page."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_sunset_silhouette.png",
      "role": "sunset / closing image",
      "prompt": "Cinematic fictional island coastline sunset, warm coral sky, calm sea, soft silhouette of grass and distant hill, no recognizable people, no text, no logos, high-end travel magazine closing page image, vertical 3:4, refined premium mood."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_ticket_cafe_detail.png",
      "role": "ticket/cafe detail optional",
      "prompt": "Premium travel detail photo: blank paper ticket, coffee cup, and small shell on a warm cafe table by a window with sea-blue light, no readable text, no logo, no brand, hands not visible, editorial still life, vertical 3:4, refined beige and coral palette."
    }
  ]
}
```

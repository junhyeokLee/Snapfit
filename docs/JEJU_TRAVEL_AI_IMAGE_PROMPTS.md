# 제주의 기록 AI Image Generation Prompts

이 문서는 `제주의 기록` 템플릿을 상업 배포 가능한 이미지 세트로 교체하기 위한 GPT 이미지 생성 프롬프트와 provenance 기준입니다.

## Art direction

핵심은 **실제 사람들이 여행 중 휴대폰으로 찍는 느낌의 스냅 사진**입니다. 단순 풍경/바다/파도/아침 풍경만 있으면 안 됩니다. 각 컷에는 다음 중 하나가 보여야 합니다.

- 친구/커플/가족의 뒷모습 또는 얼굴이 식별되지 않는 실루엣
- 손, 티켓, 커피, 음식, 카메라, 캐리어, 숙소 소품 같은 여행의 흔적
- 차창, 카페 테이블, 시장 음식, 숙소 거울, 포토덤프 flatlay 같은 실제 사용자가 찍을 법한 장면
- 풍경은 배경이 되고, 사진의 주인공은 “사람이 다녀간 여행 기록”이어야 함

## Safety / commercial-use requirements

- Target provider: OpenAI `gpt-image-1` or equivalent licensed image-generation provider
- Required output: vertical 3:4 PNG
- No logo, no brand, no readable text, no recognizable face, no celebrity likeness
- Production rule: 생성 결과물은 사람 검수 후 `_licenses/jeju_travel_sources.md`에 provider/job id/terms snapshot/status를 기록해야 합니다.

```json
{
  "templateId": "jeju_travel_v1",
  "provider": "openai-gpt-image-1",
  "commercial_use_note": "Generated images may be used commercially subject to the active OpenAI terms and the user/org compliance policy. Keep this file plus generated asset metadata as the provenance record.",
  "art_direction": "실제 여행자가 휴대폰으로 찍은 듯한 제주 여행 스냅. 사람의 흔적/손/뒷모습/소품/음식/카페/숙소/차창/동행이 보여야 하며, 단순 풍경 컷만으로 구성하지 않는다.",
  "negative_prompt": "No logos, no brands, no readable copyrighted signage, no famous landmarks with restricted property issues, no recognizable faces, no celebrity likeness, no watermark, no text embedded in image, no generic empty landscape-only photos.",
  "images": [
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_airport_arrival_snap.png",
      "role": "cover / arrival snapshot with people",
      "prompt": "Realistic smartphone travel snapshot, two Korean friends seen from behind at an airport window just before a Jeju trip, small carry-on suitcase, boarding pass in hand but no readable text, soft morning light, candid everyday composition, premium but natural, no recognizable faces, no logos, no brand signage, no watermark, vertical 3:4. Feels like a real person took it during travel, not a generic landscape."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_rental_car_window_snap.png",
      "role": "route / car window memory",
      "prompt": "Realistic candid travel photo from inside a rental car on a fictional Jeju-inspired coastal road, friend in passenger seat partly visible from behind, hand holding an iced coffee near the window, ocean and low volcanic hill outside, natural smartphone perspective, slight motion feeling, no readable signs, no logos, no recognizable face, vertical 3:4, warm sea-blue and sand palette."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_cafe_table_snap.png",
      "role": "cafe / food detail snapshot",
      "prompt": "Realistic casual cafe table snapshot from a Jeju trip, two coffee cups, tangerine dessert, sunglasses, camera strap, and a blank paper ticket on a wooden table by a bright window, one person’s hand lightly entering frame, no readable text, no brands, no logos, natural daylight, premium lifestyle photo but still like a real traveler took it, vertical 3:4."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_beach_friends_back_snap.png",
      "role": "beach / friends snapshot",
      "prompt": "Realistic travel photo of two friends from behind walking on a quiet Jeju-inspired beach, one holding sandals and a phone, wind in hair, casual clothes, ocean in background but people are the main subject, candid smartphone photo feeling, no visible faces, no logos, no readable text, warm natural colors, vertical 3:4."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_market_hands_snap.png",
      "role": "local market / hands and food detail",
      "prompt": "Realistic candid close-up from a Jeju-style local market, hands holding a small paper tray of street food and tangerines, blurred travel companion in background with face turned away, no readable signage, no brands, no logos, natural smartphone snapshot, lively but tasteful editorial color, vertical 3:4."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_guesthouse_mirror_snap.png",
      "role": "guesthouse / mirror and luggage snapshot",
      "prompt": "Realistic cozy guesthouse travel snapshot, open suitcase on bed, sun hat, film camera, postcards with no readable text, partial mirror reflection of traveler from shoulder down only, warm afternoon window light, no recognizable face, no logos, no brands, natural personal travel diary feeling, vertical 3:4."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_sunset_couple_silhouette_snap.png",
      "role": "sunset / closing human moment",
      "prompt": "Realistic candid sunset photo of a couple or two friends seen as small silhouettes from behind on a fictional Jeju-inspired coastal path, one person holding a phone up to take a photo, coral sky, ocean and grass around them, human travel memory first, landscape second, no faces, no logos, no readable text, vertical 3:4, premium emotional closing image."
    },
    {
      "asset": "assets/templates/jeju_travel/images/generated_ai/jeju_photo_dump_detail_snap.png",
      "role": "contact sheet / photo dump detail",
      "prompt": "Realistic overhead photo dump flatlay from a Jeju trip: instant photos with blank white borders, rental car key without logo, sunscreen tube with no label, tangerines, shells, cafe receipt with no readable text, friend’s hand arranging photos, natural messy-but-curated smartphone diary aesthetic, vertical 3:4."
    }
  ]
}
```

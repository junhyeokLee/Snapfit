# JEJU_TRAVEL Image Assets

이 폴더는 `JEJU_TRAVEL` 템플릿에서 사용하는 피그마 승인 이미지 export 파일을 저장하는 위치다.

운영 원칙:
- 최종 운영 이미지는 Figma 승인본 export -> CDN 업로드를 기준으로 한다.
- 로컬 파일은 fallback 및 검수용이다.
- 최종 JSON에는 `figma.com/api/mcp/asset/...` 를 직접 넣지 않는다.

초기 필수 파일 목록:

- `cover_full_bleed.png`
- `p01_opening_editorial.png`
- `p03_coastal_frame.png`
- `p05_postcard_grid_a.png`
- `p05_postcard_grid_b.png`
- `p07_spotlight_place.png`
- `p08_photo_strip_a.png`
- `p08_photo_strip_b.png`
- `p10_sunset_poster.png`
- `p12_ending_full_bleed.png`

참고:
- Figma 노드와 업로드 경로는 `/Users/devsheep/SnapFit/SnapFit/assets/templates/jeju_travel/export_checklist.json` 기준으로 관리한다.

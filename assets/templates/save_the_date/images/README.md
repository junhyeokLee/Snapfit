# SAVE_THE_DATE Image Assets

이 폴더는 `SAVE_THE_DATE` 템플릿에서 사용하는 피그마 원본 이미지를 저장하는 위치다.

파일이 아래 이름으로 존재하면 생성 스크립트는 자동으로 `asset:assets/templates/save_the_date/images/...` 경로를 JSON에 기록한다.
파일이 없으면 임시로 Figma MCP asset URL을 사용한다.

필수 파일 목록:

- `cover_full_bleed.png`
- `p01_arch_editorial.png`
- `p02_circle_card.png`
- `p03_strip_editorial.png`
- `p10_photo_notes_left.png`
- `p10_photo_notes_center.png`
- `p10_photo_notes_bottom.png`
- `p12_closing_photo.png`

주의:

- 최종 운영 반영 전에는 이 폴더를 모두 채우는 것을 원칙으로 한다.
- 최종 검수 전 `store_latest.json` 과 `save_the_date_store.json` 안에 `figma.com/api/mcp/asset` 가 남아 있으면 안 된다.
- Firebase Storage 업로드 대상 경로와 Figma 노드 목록은 `assets/templates/save_the_date/export_checklist.json` 를 기준으로 관리한다.

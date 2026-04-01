# Template QA Checklist

## Preflight

- 템플릿 ID/이름/메타데이터 누락 없음
- `templateJson.metadata` 필수 키 존재:
  - `style`, `difficulty`, `recommendedPhotoCount`, `mood`, `tags`, `heroTextSafeArea`
- 프리뷰 이미지 4장 매핑 완료
- 프리뷰 이미지 URL 중복 없음(동일 템플릿 내)
- 페이지 수 12~24 범위 확인
- 출시 게이트 실행 통과: `dart run tool/template_release_gate.dart`

## Visual Match

- 미리보기와 실제 적용 결과의 레이아웃 차이 없음
- 타이틀/본문 텍스트 크기 비율 동일
- 프레임/스티커 위치 차이 없음
- 히어로 텍스트가 `heroTextSafeArea` 안에 위치
- 텍스트/배경 대비 가독성 유지(밝은 배경+밝은 텍스트 금지)

## Aspect Check

- 세로형 캔버스에서 정상
- 정사각형 캔버스에서 정상
- 가로형 캔버스에서 정상

## Performance Check

- 템플릿 패널 스크롤 시 끊김 없음
- 프리뷰 이미지 로딩 중 레이아웃 점프 없음
- 적용 시 편집기 프레임 드랍 없음

## Hotfix Targets (2026-03-24)

- `pack_landscape_minimal_wide_001` (스카이 인비테이션)
- `pack_square_birthday_snap_001` (데이트 커버)
- `pack_square_mood_card_001` (메리지 스퀘어)
- `pack_landscape_poster_board_002` (와이드 미니멀 표지)
- `data_ref_miricar_001` (레퍼런스 미리카)
- `data_ref_seasons_001` (레퍼런스 시즌즈)
- `data_premium_blob_gallery_001` (블랍 갤러리)

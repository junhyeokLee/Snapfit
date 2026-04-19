# Firebase Template CDN Playbook

## 목적

현재 SnapFit 코드베이스는 `firebase_storage` 를 이미 사용 중이므로,
템플릿 운영 이미지의 1차 CDN origin도 Firebase Storage로 통일한다.
이 문서는 템플릿 이미지를 Firebase Storage에 어떻게 저장하고,
어떤 URL을 최종 JSON에 기록해야 하는지 정리한 운영 기준이다.

## 기본 방향

- 원본 작업: Figma
- fallback: `assets/templates/<slug>/images/...`
- 운영 origin: Firebase Storage
- 최종 반영: Firebase Storage 공개 URL 또는 그 위에 연결된 CDN URL

## 저장 경로 규칙

템플릿 이미지는 `albums/...` 와 섞지 않고 템플릿 전용 prefix 아래에 저장한다.

권장 경로:

- `templates/save_the_date/v1/cover_full_bleed.png`
- `templates/save_the_date/v1/p01_arch_editorial.png`
- `templates/save_the_date/v1/p02_circle_card.png`
- `templates/save_the_date/v1/p03_strip_editorial.png`
- `templates/save_the_date/v1/p10_photo_notes_left.png`
- `templates/save_the_date/v1/p10_photo_notes_center.png`
- `templates/save_the_date/v1/p10_photo_notes_bottom.png`
- `templates/save_the_date/v1/p12_closing_photo.png`

## 버전 규칙

- 이미지 수정 시 기존 파일 overwrite보다 `v2`, `v3` 식의 버전 분리 우선
- 롤백 가능해야 함
- store JSON은 항상 특정 버전 경로를 명시해야 함

예:

- `templates/save_the_date/v1/...`
- `templates/save_the_date/v2/...`

## 최종 JSON에 기록할 URL

최종 JSON에는 아래 둘 중 하나만 허용한다.

1. Firebase Storage download URL
2. Firebase Storage 앞단 CDN URL

금지:

- `figma.com/api/mcp/asset/...`
- `asset:...` 만 단독으로 운영 URL로 사용하는 방식
- `picsum`, `unsplash`, `pexels`

`asset:` 경로는 fallback 으로만 남길 수 있다.

## 업로드 후 권장 매핑

- `coverImageUrl` -> `templates/<slug>/<version>/cover_full_bleed.png`
- `previewImages[0]` -> 커버와 동일
- 이미지 레이어의 `imageUrl`, `previewUrl`, `originalUrl` -> 같은 운영 원본 URL

즉, 템플릿 JSON에서 서로 다른 필드가 같은 이미지를 가리킬 때는 동일한 CDN URL을 써야 한다.

## 운영 절차

1. Figma master 승인
2. 이미지 export
3. `assets/templates/<slug>/images/` 에 fallback 저장
4. `upload_template_assets_to_firebase.dart` 로 Firebase Storage `templates/<slug>/<version>/...` 경로 업로드
5. 업로드 결과 URL 확인
6. `cdn_manifest.json` 생성
7. `replace_template_asset_urls_with_cdn.dart` 로 JSON 치환
8. `template_release_gate.dart` 실행
9. 서버 publish

## 자동 업로드

```bash
dart run tool/upload_template_assets_to_firebase.dart \
  --template-slug=save_the_date
```

이 스크립트는 다음을 한 번에 수행한다.

- `firebase login:list --json` 에서 현재 로그인 토큰 읽기
- `export_checklist.json` 기준으로 필수 파일 검사
- Firebase Storage multipart upload
- `firebaseStorageDownloadTokens` 메타데이터 설정
- `cdn_manifest.json` 생성

## 업로드 검수 기준

- 각 URL이 앱 외부에서도 200 응답인지
- 스토어 카드와 상세 커버가 같은 원본을 보는지
- 실제 편집 진입 화면에서 같은 이미지가 보이는지
- `store_latest.json` 안에 금지 URL이 남아 있지 않은지

## SAVE_THE_DATE 1차 운영 결론

`SAVE_THE_DATE` 는 우선 아래 8개 파일만 Firebase Storage에 올리면 된다.

- `cover_full_bleed.png`
- `p01_arch_editorial.png`
- `p02_circle_card.png`
- `p03_strip_editorial.png`
- `p10_photo_notes_left.png`
- `p10_photo_notes_center.png`
- `p10_photo_notes_bottom.png`
- `p12_closing_photo.png`

이 8개가 들어오면 현재 파이프라인으로 CDN 매니페스트 생성, JSON 치환, 릴리즈 게이트까지 바로 이어갈 수 있다.

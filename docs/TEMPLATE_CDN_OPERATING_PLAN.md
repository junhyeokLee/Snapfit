# Template CDN Operating Plan

## 결정

템플릿 운영 이미지는 앞으로 `Figma 승인본 -> export -> CDN 업로드 -> JSON 반영` 흐름으로 관리한다.
현재 앱에는 `firebase_storage` 가 이미 연결되어 있으므로, 가장 빠른 1차 운영안은 Firebase Storage를 origin으로 쓰고 공개 CDN URL을 템플릿 JSON에 기록하는 방식이다.

## 왜 이 방식이 맞는가

- 앱 재배포 없이 이미지 교체 가능
- 템플릿별 버전 관리가 쉬움
- 피그마 임시 URL 404 문제 제거
- 스토어/상세/편집기/읽기 화면의 이미지 소스를 통일 가능
- 롤백과 QA 비교가 쉬움

## 권장 경로 규칙

- 템플릿 슬러그: `save_the_date`
- 버전: `v1`, `v2`, `v3`
- CDN 키:
  - `templates/save_the_date/v1/cover_full_bleed.png`
  - `templates/save_the_date/v1/p01_arch_editorial.png`
  - `templates/save_the_date/v1/p02_circle_card.png`

## 운영 원칙

- 최종 JSON에는 `figma.com/api/mcp/asset/...` 저장 금지
- 최종 JSON에는 `picsum`, `unsplash`, `pexels` 저장 금지
- 최종 이미지 경로는 CDN URL 우선
- 로컬 asset은 fallback 전용
- 이미지가 바뀌면 기존 파일 overwrite 보다 버전 경로 분리 우선

## 추천 운영안

### 1차: 현재 인프라 재사용

- 이미지 origin: Firebase Storage
- 공개 URL: Firebase Storage download URL 또는 연결된 공개 CDN URL
- 장점: 현재 코드베이스와 가장 잘 맞고 바로 적용 가능
- 단점: download URL 정책이 섞이면 경로 규칙이 지저분해질 수 있음
- 상세 운영 규칙: `docs/FIREBASE_TEMPLATE_CDN_PLAYBOOK.md`

### 2차: 이상적인 운영안

- 이미지 origin: 전용 object storage
- 배포 경로: 고정 CDN 도메인
- 예: `https://cdn.snapfit.app/templates/save_the_date/v1/cover_full_bleed.png`
- 장점: 템플릿 운영 경로가 깔끔하고 버전 관리가 명확함

## 실제 릴리즈 절차

1. Figma에서 최종 승인
2. 이미지 export
3. `assets/templates/<slug>/images/` 에 fallback 저장
4. CDN 업로드
5. CDN 매니페스트 생성
6. store JSON의 `asset:` 경로를 CDN URL로 일괄 치환
7. release gate 실행
8. 서버 publish

## 추가한 도구

- `tool/build_template_cdn_manifest.dart`
  - 로컬 이미지 폴더를 기준으로 CDN 매니페스트 생성
- `tool/replace_template_asset_urls_with_cdn.dart`
  - store JSON 내부 `asset:` 경로를 CDN URL로 일괄 치환

## 예시 명령어

```bash
dart run tool/build_template_cdn_manifest.dart \
  --template-slug=save_the_date \
  --version=v1 \
  --cdn-base-url=https://cdn.snapfit.app

dart run tool/replace_template_asset_urls_with_cdn.dart \
  --input=assets/templates/generated/store_latest.json \
  --manifest=assets/templates/save_the_date/cdn_manifest.json \
  --output=assets/templates/generated/store_latest.json

dart run tool/template_release_gate.dart \
  --store-json=assets/templates/generated/store_latest.json
```

## SAVE_THE_DATE 적용 메모

- `SAVE_THE_DATE` 는 피그마 master 기준 이미지만 사용
- 기존 SAVE_THE_DATE 이미지 섞임 금지
- 첫 커버, 스토어 카드, 상세 커버, 실제 편집 진입 결과가 같은 CDN 원본을 봐야 한다
- 실제 export 대상 목록: `assets/templates/save_the_date/export_checklist.json`

# Figma Image Asset Rules

## 목적

템플릿 제작 시 피그마에 배치된 이미지를 앱에서 동일하게 보여주기 위한 고정 규칙이다.
핵심 원칙은 "피그마에서 보이는 이미지를 앱이 직접 접근 가능한 CDN URL 또는 로컬 fallback asset으로 치환한 뒤 JSON에 반영한다" 이다.

## CDN이란

- CDN(Content Delivery Network)은 이미지 파일을 여러 지역의 캐시 서버를 통해 빠르고 안정적으로 내려주는 정적 파일 배포 방식이다.
- 운영에서는 보통 `S3/R2/GCS + CDN(CloudFront/Cloudflare CDN 등)` 조합으로 사용한다.
- 앱 입장에서는 "항상 열리는 공개 이미지 URL" 이고, 템플릿 입장에서는 "앱 재배포 없이 교체 가능한 이미지 저장소" 라고 보면 된다.

## 절대 금지

- `https://www.figma.com/api/mcp/asset/...` URL을 앱 런타임용 이미지 URL로 직접 저장하지 않는다.
- 임시 확인용 `picsum`, `unsplash`, `pexels` URL을 최종 템플릿 JSON에 남기지 않는다.
- 피그마에 없는 샘플 이미지를 임의로 끼워 넣지 않는다.

## 이유

- Figma MCP가 반환하는 asset URL은 Codex/Figma MCP 세션용 임시 자산일 수 있다.
- 이 URL은 앱 런타임 또는 일반 네트워크 환경에서 `404`가 날 수 있다.
- 따라서 템플릿 JSON에 그대로 저장하면 스토어, 상세, 실제 생성 화면에서 이미지 깨짐, fallback, 캐시 꼬임이 발생한다.

## 최종 허용 소스

- 앱이 직접 접근 가능한 CDN 운영 이미지 URL
- `asset:assets/...` fallback 경로

최종 템플릿 JSON의 `imageUrl`, `previewUrl`, `originalUrl`, `coverImageUrl`, `previewImages` 는 위 두 종류만 허용한다.
운영 기본값은 CDN URL이고, 로컬 asset은 fallback 또는 오프라인 개발 검수용으로만 유지한다.

## 최종 운영 워크플로우

1. Figma에서 최종 승인된 master 프레임과 이미지 노드를 확정한다.
2. 각 이미지 노드를 export 한다.
3. export 결과를 템플릿 전용 스토리지 경로에 업로드한다.
4. CDN 공개 URL을 발급한다.
5. 템플릿 JSON의 모든 이미지 필드에 CDN URL을 기록한다.
6. 같은 파일을 로컬 fallback asset에도 저장한다.
7. handoff JSON, store JSON, latest JSON을 다시 생성한다.
8. 앱에서 스토어 카드, 상세, 편집기, 읽기 화면을 모두 검수한다.

## 표준 업로드 경로 규칙

- 템플릿 슬러그 예시: `save_the_date`
- 권장 CDN 키 규칙:
  - `templates/save_the_date/v1/cover_full_bleed.png`
  - `templates/save_the_date/v1/p01_arch_editorial.png`
  - `templates/save_the_date/v1/p02_circle_card.png`
  - `templates/save_the_date/v1/p10_photo_notes_left.png`
- 권장 로컬 fallback 경로:
  - `assets/templates/save_the_date/images/cover_full_bleed.png`
  - `assets/templates/save_the_date/images/p01_arch_editorial.png`
  - `assets/templates/save_the_date/images/p02_circle_card.png`
  - `assets/templates/save_the_date/images/p10_photo_notes_left.png`

## JSON 기록 규칙

- 1순위: CDN URL
- 2순위: 로컬 fallback asset
- 동일 이미지에 대해 `imageUrl`, `previewUrl`, `originalUrl` 은 같은 운영 원본을 가리켜야 한다.
- 커버는 `coverImageUrl` 과 첫 페이지 cover layer가 같은 원본을 써야 한다.
- `previewImages` 는 실제 페이지 순서와 동일한 이미지 원본을 써야 한다.

예시:

- 운영 URL: `https://cdn.snapfit.app/templates/save_the_date/v1/cover_full_bleed.png`
- fallback URL: `asset:assets/templates/save_the_date/images/cover_full_bleed.png`

## 버전 규칙

- 이미지 교체가 발생하면 `v1`, `v2`, `v3` 처럼 경로 버전을 올린다.
- 기존 URL을 덮어쓰는 방식보다 버전 경로를 분리하는 방식을 우선한다.
- 롤백이 가능해야 하며, JSON은 항상 특정 버전 경로를 명시해야 한다.

## SAVE_THE_DATE 운영 규칙

- `SAVE_THE_DATE` 는 반드시 현재 피그마 master 기준으로만 재생성한다.
- 기존 `SAVE_THE_DATE` 와 제목이 같더라도 오래된 이미지나 레이아웃을 재사용하지 않는다.
- `store_latest.json` 안에는 `SAVE_THE_DATE` 엔트리가 하나만 존재해야 한다.
- `SAVE_THE_DATE` 의 이미지 자산은 모두 동일한 템플릿 폴더 안에 모은다.
- `SAVE_THE_DATE` 의 최종 배포 이미지는 CDN URL로 관리하고, 로컬 asset은 fallback 세트로만 유지한다.

## 검수 체크리스트

- 스토어 카드 이미지가 피그마 커버와 동일한가
- 템플릿 상세 상단 커버가 피그마 커버와 동일한가
- 페이지 미리보기 이미지가 피그마 페이지와 동일한가
- 실제 생성 화면에서 이미지가 잘리거나 축소되지 않는가
- 피그마에 없는 이미지가 한 장도 없는가
- 최종 JSON에 `figma.com/api/mcp/asset`, `picsum`, `unsplash`, `pexels` 가 남아 있지 않은가
- 최종 JSON의 이미지 URL이 CDN 경로 또는 fallback asset 경로만 사용하는가
- 동일 템플릿 이미지가 버전 경로로 분리되어 롤백 가능한가

## 실무 메모

- Figma MCP asset URL은 "원본 식별용" 으로만 사용한다.
- 실제 배포/앱 반영은 항상 "CDN URL + 로컬 fallback asset" 구조로 끝낸다.

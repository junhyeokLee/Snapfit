# Template Factory Automation

## 목적

기존 템플릿과 겹치지 않도록(디자인/문구/미리보기 이미지) 신규 템플릿을 주기적으로 자동 생성합니다.

## 생성기

- 스크립트: `tool/template_factory.dart`
- 기본 출력: `assets/templates/generated/latest.json`
- 레지스트리: `assets/templates/generated/template_factory_registry.json`

## 운영 원칙 (실서비스)

- 디자인 원본은 Figma(SSOT)로 고정
- 앱 반영물은 handoff -> `templateJson` 생성 경로만 허용
- 모든 템플릿은 `templateJson.metadata` 필수:
  - `style`
  - `difficulty`
  - `recommendedPhotoCount`
  - `mood`
  - `tags`
  - `heroTextSafeArea`

## 중복 방지 기준

- 이름: 정규화(소문자/공백 정리) 후 중복 금지
- 문구: 레이어 텍스트 토큰 Jaccard 유사도 임계치 초과 시 차단
- 이미지: 기존 프리뷰 URL과 동일 URL 사용 금지
- 디자인: 레이어 fingerprint Jaccard 유사도 임계치 초과 시 차단

## 실행 방법 (로컬)

```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/template_factory.dart --count=3
```

## Figma 핸드오프 즉시 반영 (디자이너 협업)

디자이너가 전달한 핸드오프 JSON을 아래 명령으로 앱 반영 포맷으로 변환할 수 있습니다.

```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/build_store_templates_from_handoff.dart \
  --input=assets/templates/save_the_date_handoff.json \
  --output=assets/templates/generated/store_latest.json \
  --pages=12
```

상세 규칙은 `docs/FIGMA_TEMPLATE_HANDOFF_GUIDE.md`를 참고하세요.

스토어(커버+페이지)용 템플릿 JSON까지 자동 생성하려면 (`pages[]` 우선, `layers[]` fallback):

```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/build_store_templates_from_handoff.dart \
  --input=assets/templates/save_the_date_handoff.json \
  --output=assets/templates/generated/store_latest.json \
  --pages=12
```

앱 스토어는 `assets/templates/generated/store_latest.json`을 우선 로드합니다.

실서비스 운영 규칙:
- `templateJson.schemaVersion` 필수 (신규는 `2`)
- `templateId`, `version`, `lifecycleStatus` 필수
- `pages[].layoutId`, `pages[].role`, `pages[].recommendedPhotoCount` 필수
- `layers[]` 단일 입력은 레거시 호환용으로만 허용

스토어 템플릿 DB 동기화(필수):

```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/publish_store_templates_to_server.dart \
  --input=assets/templates/generated/store_latest.json \
  --base-url=http://54.253.3.176 \
  --admin-key=$SNAPFIT_PUSH_ADMIN_KEY
```

룰:
- 스토어에 노출되는 템플릿은 반드시 서버 DB 등록본이어야 함
- 미등록 템플릿은 좋아요/사용하기/통계 연동 대상에서 제외됨

옵션:

- `--count=3` 생성 개수
- `--seed=1234` 재현 가능한 랜덤 시드
- `--output=assets/templates/generated/latest.json` 출력 경로
- `--catalog=assets/templates/design_templates_v1.json` 기준 카탈로그 경로
- `--constants=lib/core/constants/design_templates.dart` 기존 프리뷰 URL 소스 경로

## 앱 반영 방식

`designTemplateCatalogProvider`에서 아래 순서로 병합 로딩합니다.

1. 기본 내장 템플릿
2. 서버 `/api/design-templates`
3. `assets/templates/design_templates_v1.json`
4. `assets/templates/generated/latest.json` (자동 생성 결과)

즉, 생성 후 앱 재실행하면 자동 배치가 템플릿 패널에 반영됩니다.

## 주간 자동 실행

- 워크플로: `.github/workflows/template-factory.yml`
- 매주 월요일 09:00 (KST) 자동 실행
- 중복 조건 통과분만 `generated/latest.json` 갱신 후 자동 커밋
- 생성 직후 `/api/notifications/topic` 호출로 `snapfit_template_new` 푸시 + 인박스 적재

필수 GitHub Secrets:

- `SNAPFIT_API_BASE_URL` (예: `http://54.253.3.176`)
- `SNAPFIT_PUSH_ADMIN_KEY` (백엔드 `snapfit.push.admin-key`)

## 즉시 테스트 (오늘 바로)

```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/template_factory.dart --count=3
SNAPFIT_API_BASE_URL=http://54.253.3.176 \
SNAPFIT_PUSH_ADMIN_KEY=YOUR_ADMIN_KEY \
./scripts/test_template_update_notification.sh 3
```

앱 측 확인:

- 알림 설정에서 `전체 알림` + `새 템플릿 알림` ON
- 앱 포그라운드/백그라운드에서 푸시 수신 확인
- 알림 화면 인박스에 "새 템플릿 업데이트" 항목 적재 확인

## 출시 게이트 (필수)

배포 전 아래 명령을 반드시 통과해야 합니다.

```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/template_release_gate.dart
```

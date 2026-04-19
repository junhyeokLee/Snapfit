# Template Asset Pipeline Standard

## 목표

템플릿마다 임시 방식으로 이미지 경로를 관리하지 않고,
모든 템플릿이 동일한 자산 구조와 릴리즈 단계를 따르도록 표준화한다.

## 공통 구조

각 템플릿은 아래 3개 파일을 가진다.

1. `assets/templates/<slug>/images/`
   - 로컬 fallback 이미지 폴더
2. `assets/templates/<slug>/export_checklist.json`
   - Figma export 대상과 Firebase Storage 경로를 정의
3. `assets/templates/<slug>/cdn_manifest.json`
   - 실제 운영 CDN URL 매핑 결과

추가로, 템플릿별 시각 정합 규칙은 아래 전역 파일에서 관리한다.

4. `assets/templates/workspace/template_parity_rules.json`
   - 줄바꿈, 금지 배경, 커버 간격 등 Figma 1:1 정합 규칙
5. `assets/templates/workspace/template_registry.json`
   - 승인 템플릿 목록과 잠금 상태

## 전역 설정

전역 CDN 설정은 아래 파일을 기준으로 한다.

- `assets/templates/workspace/template_cdn_config.json`

여기에는 provider, bucket, 금지 URL 패턴, 허용 URL 종류가 들어간다.

## 릴리즈 표준 절차

1. Figma master 승인
2. `export_checklist.json` 기준 이미지 export
3. `images/` 에 fallback 저장
4. Firebase Storage 업로드
5. `cdn_manifest.json` 생성
6. `validate_template_asset_pipeline.dart` 검증
7. `replace_template_asset_urls_with_cdn.dart` 로 템플릿별 store JSON 치환
8. `merge_generated_template_into_store.dart` 로 `store_latest.json` 안전 병합
9. `template_registry_guard.dart` 로 승인 템플릿 회귀 검증
10. `template_release_gate.dart` 실행
11. 서버 publish

`template_release_gate.dart` 는 이제 이미지/URL 검증만이 아니라
`template_parity_rules.json` 의 규칙도 같이 검사한다.
`template_registry_guard.dart` 는 승인된 기존 템플릿이 빠지거나
`asset:` 경로로 되돌아가는 경우를 실패로 처리한다.

## 스크립트

반복 작업은 아래 스크립트로 통일한다.

```bash
./scripts/template_asset_pipeline.sh \
  --template-slug=save_the_date \
  --version=v1 \
  --cdn-base-url=https://cdn.snapfit.app
```

Firebase 업로드만 먼저 수행하고 싶다면 아래 스크립트를 직접 쓴다.

```bash
dart run tool/upload_template_assets_to_firebase.dart \
  --template-slug=save_the_date
```

## 유지보수 원칙

- 템플릿별 예외 규칙을 코드에 박지 않는다
- 예외가 필요하면 `export_checklist.json` 또는 manifest 데이터에 반영한다
- 시각 정합 규칙은 `template_parity_rules.json` 에 추가한다
- 승인 완료된 템플릿은 `template_registry.json` 에 등록하고 잠근다
- URL 정책은 전역 설정과 release gate에서 통제한다
- 로컬 fallback, Firebase 경로, 최종 CDN URL이 서로 추적 가능해야 한다
- 업로드 결과는 항상 `cdn_manifest.json` 으로 남겨서 재현 가능해야 한다

## 확장 원칙

- 새 템플릿 추가 시 slug만 바꿔 같은 구조를 재사용한다
- 새 provider 도입 시 `template_cdn_config.json` 과 manifest 생성 규칙만 바꾸고,
  템플릿 데이터 구조는 유지한다
- 저장소를 Firebase에서 다른 CDN으로 옮겨도 `export_checklist.json` 과 store JSON 포맷은 유지한다

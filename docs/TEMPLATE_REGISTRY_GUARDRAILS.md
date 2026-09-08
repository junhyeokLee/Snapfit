# Template Registry Guardrails

> 2026-09-08: 아래 내용은 구 서버 게시 파이프라인의 보존 문서다.
> 현재 앱의 공개 카탈로그는 `authoredCollections`의 승인된 무료 37종만 사용한다.
> 기존 35종에 바람을 수집한 여행과 함께여서 좋은 날을 추가했다. 구 시안을 복원하지 않는다.
> 최신 확장 범위는 `docs/prose_free_and_luminous_candidate.md`에 기록한다. 새 유료 후보는 미등록이다.
> `store_latest.json` 병합이나 구 승인 잠금 목록이 공개 노출을 허용하지 않는다.
> 새 공개 상품은 `docs/free_template_baseline.md`의 기준에 따라 별도로 승인해야 한다.

## 목표

새 템플릿을 추가하거나 기존 템플릿을 수정할 때,
이미 승인된 템플릿이 `store_latest.json` 에서 사라지거나,
`asset:` 경로로 되돌아가거나,
다른 템플릿 작업 때문에 다시 깨지는 문제를 방지한다.

## 핵심 원칙

1. 생성기는 템플릿별 산출물만 만든다.
2. 공용 `store_latest.json` 은 생성기가 직접 덮어쓰지 않는다.
3. 공용 스토어 병합은 `merge_generated_template_into_store.dart` 로만 한다.
4. 승인된 템플릿은 `template_registry.json` 에 `status=approved`, `locked=true` 로 등록한다.
5. 승인된 템플릿이 빠지거나 `asset:` 경로로 남아 있으면 배포를 막는다.

## 관리 파일

- `assets/templates/workspace/template_registry.json`
  - 승인 템플릿 목록
  - `slug`, `templateId`, `title`, `status`, `locked`
- `assets/templates/generated/<slug>_store.json`
  - 템플릿별 생성 결과
- `assets/templates/generated/store_latest.json`
  - 최종 운영 병합 결과

## 권장 플로우

```bash
cd /Users/devsheep/SnapFit/SnapFit

dart run tool/generate_<slug>_refined.dart

bash ./scripts/template_asset_pipeline.sh \
  --template-slug=<slug> \
  --template-store-json=assets/templates/generated/<slug>_store.json

dart run tool/publish_store_templates_to_server.dart \
  --input=assets/templates/generated/store_latest.json \
  --supabase-url=https://rrbhxdtriummqpztpjrk.supabase.co
```

## 보호 장치

- `tool/merge_generated_template_into_store.dart`
  - 개별 템플릿 산출물을 `store_latest.json` 에 안전 병합
- `tool/template_registry_guard.dart`
  - 승인 템플릿 누락
  - 중복 templateId
  - 승인 템플릿의 `asset:` cover/preview/templateJson
  를 실패로 처리

## 현재 승인 잠금 템플릿

- `save_the_date_v1`
- `jeju_travel_v1`
- `family_weekend_v1`
- `anniversary_days_v1`

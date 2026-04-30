# Figma -> Template JSON Approval Pipeline

## Goal

디자인 원본(Figma)과 앱 반영물(templateJson)의 불일치를 줄이고, 배포 품질을 고정합니다.

## Workflow

1. Design
- 디자이너가 Figma 프레임 제작
- 프레임에 필수 메모: `style`, `mood`, `difficulty`, `recommendedPhotoCount`
- 제작 규격은 `docs/FIGMA_3RATIO_MASTER_SPEC.md` 고정
- 레이어 네이밍/타입 매핑은 `docs/FIGMA_LAYER_NAMING_AND_MAPPING_RULES.md` 고정

2. Handoff
- 핸드오프 JSON 작성 (`docs/FIGMA_TEMPLATE_HANDOFF_GUIDE.md` 기준)
- 명령으로 변환:

```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/build_store_templates_from_handoff.dart \
  --input=assets/templates/save_the_date_handoff.json \
  --output=assets/templates/generated/store_latest.json \
  --pages=12
```

3. Normalize
- 템플릿 JSON 루트에 `metadata` 보강
- 페이지 수를 12..24에 맞춤

4. Gate
- 출시 게이트 실행:

```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/template_release_gate.dart
```

5. Manual QA
- 스토어 미리보기와 실제 적용 결과를 비교
- 체크리스트: `docs/TEMPLATE_QA_CHECKLIST.md`

6. Publish
- 게이트 통과 + 수동 QA 승인 후만 배포

## Approval Rules

- Designer approval: visual fidelity / art direction
- PM approval: category strategy / launch priority
- Engineer approval: gate pass / runtime safety

## Rollback

- 문제 템플릿은 `weeklyScore`를 즉시 하향
- 스토어 상단 고정 해제
- 다음 배포 전까지 숨김 또는 교체

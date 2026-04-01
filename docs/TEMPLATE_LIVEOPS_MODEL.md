# Template LiveOps Model (Production)

## 1) Design SSOT

- Single source of truth: Figma file
- Engineering source of truth for runtime: `templateJson` generated from Figma handoff
- Rule: do not hand-edit production template layout in app code except emergency hotfix

## 2) Template Spec Contract

Every production template must include `templateJson.metadata`:

- `style`: string (ex. `wedding_editorial`)
- `difficulty`: int `1..5`
- `recommendedPhotoCount`: int `1..24`
- `mood`: string (ex. `romantic_soft`)
- `tags`: string array (non-empty)
- `heroTextSafeArea`: `{x,y,width,height}` with ratio values `0..1`
- `sourceBottomSheetTemplateIds`: bottomsheet 템플릿 id 배열
- `applyScope`: 항상 `cover_and_pages`
- `bottomSheetReferenceMode`: 항상 `style_and_tone_only`

정책:

- 바텀시트 템플릿은 현재 페이지에만 적용
- 스토어 템플릿은 커버+전체 페이지에 적용
- 스토어 템플릿은 바텀시트 템플릿의 스타일/톤을 참조해 생성

## 3) Release Gate

Run before release:

```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/template_release_gate.dart
```

Hard fail checks:

- metadata contract missing/invalid
- page count out of range (12..24)
- page without image layer
- broken image URL (cover/preview/core layers)

Soft warning checks:

- text overflow risk heuristic
- preview vs applied page-image mismatch risk

## 4) Store Ranking / Improvement Loop

Current ranking inputs:

- `weeklyScore`
- `likeCount`
- `userCount`
- `isBest` / `isNew`
- metadata completeness bonus

Policy:

- top-quality 12 templates always first
- low-score templates are naturally demoted
- weekly curation should replace low performers with newly validated templates

## 5) Design Quality Policy

Priority:

1. Art-direction first (type, color, overlay, frame depth)
2. Curated 12 first (quality over volume)
3. Preview and applied render parity enforced

## 6) KPI Tracking (next)

Track per template:

- CTR (store card click-through)
- Apply rate
- Subscription conversion rate
- Completion rate (album finished)

Recommended event keys:

- `template_impression`
- `template_click`
- `template_apply`
- `template_checkout_start`
- `template_checkout_success`
- `template_album_complete`

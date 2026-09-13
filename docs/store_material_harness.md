# Store / material optimization harness

Scope: store catalog cards, material chooser, catalog-derived state and point-shop access. Baseline: origin/main b6c890d. No redesign, template reduction, price changes, server/security changes or detail/editor/print quality changes approved.

Run `python3 tool/store_material_harness.py --phase baseline` (then phase1/phase2/phase3). Focus a RED/GREEN behavior with `--test test/optimization/<name>_test.dart`. Exit status propagates; machine-readable reports and Flutter JSON events are in `build/store_material_harness/<phase>/`. Never update golden files to accommodate this optimization.

## Invariants / per-phase gates
- [x] Baseline existing behavioral and golden tests green.
- [x] Phase1: bounded revision-aware parsed preview cache; invalid input fallback; eviction; repeat-mount parse-count budget; display×DPR decode budget without editor/print changes; only visible material preview construction; existing focused goldens unchanged.
- [x] Phase2: derived catalog/search/category/sort providers; per-key price/owned/favorite selectors; latest-save ordering, serialized persistence, rollback and account scoping preserved; unrelated-key notification budget.
- [x] Phase3: insertion parsing/calculation/dispatch belongs to VM/use case; injectable purchase Notifier handles server validation, duplicate taps, cancellation, topup return, account changes, timeout and errors; view owns dialogs/navigation only.
- [x] Full local tests, analyzer, full-tree formatting, generated parity and diff check.
- [ ] PR CI: verify the checks for the exact pushed SHA before merging.

## Measurement interpretation
Deterministic tests count parsing, preview creation and selected-provider notifications. These measure work avoided, not milliseconds or device FPS. Existing golden tests protect approved pixels. Do not invent profile data.

## Reproducible evidence
- `python3 tool/store_material_harness.py --phase final`: focused regression/golden suite plus every optimization test. `--test test` runs the full Flutter suite. Use `--flutter /absolute/path/to/flutter` in service environments with a reduced PATH.
- `python3 tool/store_material_quality.py`: generated-source hash parity, full-tree format check, analyzer, Supabase code-only readiness, template quality, diff check. Reports/logs: `build/store_material_harness/quality/`.
- CI executes the focused harness after the full suite and uploads its JSON events/report.
- Baseline source was re-executed from an untouched `git archive origin/main` at `build/store-material-baseline/`: **240 passed**. The first background baseline attempt could not locate Flutter on the service PATH; the recovered baseline used the absolute executable. No golden updates.
- Final focused run `final-child`: **262 passed**. Measured first material screen: **376 eager preview constructions → 15 lazy constructions**; after a 700 logical-pixel scroll, **35 cumulative**. This is debug widget construction counting, not raster timing.
- Full frozen-source run `full-final-child`: **1462 passed**, exit 0, no errors; existing goldens unchanged. Machine-readable summary is committed in `docs/validation/store-material-optimization.json`.
- Cache fixture: **101 requests → 1 parse** for the same revision. Revision change and capacity-2 eviction are separately asserted; production cover/word-art caches each have capacity 48.
- Material PNG fixture source width **1254**; requested list decode width **240** for width 80 at DPR 3. Editor/print does not opt in. This is a requested decode budget, not measured GPU memory.
- Unrelated favorite/price/owned changes cause **0 selected-key notifications** in provider tests; ordering remains newest saved first. Favorites remain device-local as before, ownership/purchase remain account-scoped.

## Regression fixes caught by the harness
1. Nested ProviderScope overrides initially escaped derived price selectors. Explicit dependency declarations restored correct prices and the existing store golden.
2. Standalone artwork galleries have no app ProviderScope. Their public embedding API now supplies a fallback scope only when absent; the normal app does not allocate extra containers.
3. Applying store decode resizing to the creation hub changed raster pixels. Decode limiting is now an explicit store-only opt-in; creation/detail/export retain their existing decode behavior and the creation-hub golden passes unchanged.
4. A category disappearing on refresh must stay reset to All even if it returns later. The derived result and view listener preserve this pre-existing behavior without mutation inside catalog computation.

## Remaining device protocol
On the same physical device, profile build, fixed data and gesture: capture cold and warm store entry, scroll down/up, all material tabs, search, favorite and price arrival. Record DevTools UI/raster p95/p99, allocations/GC/image cache uploads, build/paint ranges. Exclude idle frames from scrolling measurements. Device profiling requires an attached device; automated gate is independent of that external requirement.

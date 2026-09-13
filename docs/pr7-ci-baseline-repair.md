# PR 7 CI baseline repair

Approved product baseline: `origin/main` at `4bcc0a551f333d364d837dc2f9a2e6ecc3796fc0`.
Repair starts from PR head `7afcc50018914c3780f81aae45eb0d401fb88486`.

## Reproduced failures

On Linux with Flutter 3.47.1 / Dart 3.13.1, the unmodified PR produced
**1415 passed, 34 failed, 1 skipped** (`pr7-red.log`). No production design code
is changed by this test repair.

- Six AI typography goldens and six AI design review goldens: text/icon
  rasterization differences. Baseline, actual and isolated differences were
  inspected for all aspect/orientation combinations; layout and content agree.
- Creation hub, photo fill, setup, cover type, invitation and store card goldens:
  reviewed baseline/actual/diff images retain main's existing layouts and copy.
- AI split flow: missing Riverpod scope after catalog integration; use controlled
  point catalog and ownership providers, not a live shop. The start catalog,
  theme cards and range/point copy already exist on approved main. Load Material
  icons in the harness. The review screen differs only by the now-rendered back
  icon. AI design review additionally loads its explicit NotoSans CTA font.
- Cover/editor controls: `스티커` became `꾸미기` on main. Retain tool existence,
  selection, toggling and callback assertions with current labels.
- Photo range: use main's `참고할 사진 범위` and current explanatory copy; retain
  range selection and server/advanced privacy behavior assertions.
- Page editor: main intentionally uses a modal layer sheet in portrait and an
  inline rail in landscape. The old test asserted the opposite. Its synthetic
  surface also disagreed with the view's MediaQuery orientation. Set actual view
  dimensions and DPR, scroll to the tool before tapping, assert real sheet
  opening/dismissal, and retain the landscape canvas/rail geometry test.
  Both workspace and layer-sheet images were reviewed before regeneration.
- App boot smoke: initialize offline Supabase and mocked Firebase core, mock the
  native purchase boundary, and assert app mount plus purchase startup/recovery.
  Never bypass initialization in production or swallow unexpected test errors.

## Golden review environment

Goldens are exact comparisons, generated on **Linux / Flutter 3.47.1** to match
GitHub Actions. No tolerance increase, skipped test, golden comparator override
or assertion removal is used to turn failures green. Run golden tests on this
same environment when updating approved visuals. Bundled fonts must be loaded
explicitly in widget tests; their production registration alone is insufficient.

Local review evidence (`pr7-*-review*.png`) and test/quality logs (`pr7-*.log`)
are retained in the repair worktree, not committed as application assets.

## Local verification

- Full non-update test run: **1449 passed, 0 failed, 1 existing skip**
  (`pr7-full-green.log`, 7m44s).
- `flutter analyze`: no issues.
- `dart format --output=none --set-exit-if-changed lib test`: 468 files,
  zero changed.
- `dart run build_runner build --delete-conflicting-outputs`: zero outputs;
  generated production source diff is empty.
- Supabase code-only readiness audit and template quality audit: passed;
  template audit reports nine templates and zero issues.
- CI workflows both pin Flutter 3.47.1 so exact goldens use the reviewed renderer.

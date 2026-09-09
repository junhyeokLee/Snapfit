# Premium Volume Page Policy

## Counts

Counts exclude the cover. A spread always contains two inner pages.

| Category | Collection | Basic | Extended / Default |
| --- | --- | --- | --- |
| Wedding | `vow-keepsake` | 24 | 32 |
| Travel | `luminous-edition` | 24 | 36 |
| Daily | `daily-cabinet` | 24 | 24 |
| Baby | `first-year-keepsake` | 24 | 36 |
| Family | `table-stories` | 24 | 32 |
| Couple | `two-tickets` | 24 | 32 |
| Pet | `walk-and-nap` | 24 | 24 |

`PremiumVolume` is the shared source for supported counts, document generation,
catalog labels, and preview selection. Unsupported counts fail explicitly rather
than silently padding a document or dropping pages.

## Composition

The seven approved eight-page studies remain unchanged. Wedding additionally
retains its previous 20-page extension. New spread pairs are independently
authored in the `authored_volume_*` parts, inserted at named narrative points,
and retain stable layer identities across basic and extended editions.

The 24-page edition contains the same compositions as the longer edition, with
only page positions and folios changing. Extensions add stories in the middle;
the existing closing spread remains last in every edition. Selected pairs reverse
their reading order explicitly to vary the rhythm. No automatic filler, copied
free-template layouts, or recoloring loop creates additional pages.

All covers, photos, text, frames, paper, and decorations remain native editable
layers. Local sample photos are replaceable slots and are reused in some spreads;
they are not a claim of a unique-photo production album or cleared resale rights.
All editions support portrait, square, and landscape album formats.

## Preview

Open `/?catalog=premium&revision=volumes2436#/premium-studies` on the preview server.
The edition menu offers the 24-page basic edition, a 32/36-page extended edition
where available, and the approved eight-page reference. Wedding also offers its
previous 20-page extension. Edited copy and album ratio persist across switching.
Chapter labels and page ranges come from the selected document, not static labels.

## Release Boundary

The 2026-09-09 request to proceed to sale approves the basic and extended designs.
Expanded artwork uses `approvalStatus: approved-volume-design` and an explicit
design-only approval scope. This does not approve prices or clear material rights.
`catalogPublishable` remains false and `accessTier` is unassigned. The seven volumes
are being registered as inactive point-shop drafts; this is separate from customer
store publication. See `premium_volume_sales_registration.md` for registration
status, the proposed package, remaining delivery work and pricing evidence.
The existing 37-item customer catalog and its server price overrides are unchanged.

Physical-device checks, replacement-photo diversity, asset/font distribution rights,
delivery and payment QA, and confirmed pricing still precede paid release.
Physical print proofs remain pending separately; the proposed digital template
purchase does not include printing.

## Verification

`test/design/heirloom_studies_test.dart` checks all 12 new edition variants in
three album ratios: 1,044 native-rendered pages including covers. Invariants cover
exact counts, unique layer identities, approved-baseline preservation, identical
basic/extended compositions, chapter bounds, closing spreads, text bounds,
unintended overlap, photo-slot clearing, serialization, and material aspect ratios.

Export with `--dart-define=EXPORT_EDITION=true`. Page PNGs, spreads, three-spread
review bands, contact sheets, and JSON documents are written to
`output/template-preview/<id>-<count>/<aspect>/`.

`tool/template_studio/verify_premium_volumes.cjs` exercises all seven routes at
390x844, 844x390, and 1440x900. It checks actual canvas pixels, chapter navigation,
basic/extended/reference switching, edited copy retention, endings, catalog return,
and browser/HTTP/backend API errors. Its default run samples three spreads per
book; `ALL_SPREADS=true` checks every spread. Native tests render every page.
Screenshots and reports go to `output/template-preview/premium-volumes/browser/`.

The original baseline and wedding 20-page verifiers explicitly select their old
edition instead of depending on the current preview default.

### Completed Check: 2026-09-09

- Focused volume suite: 62 tests passed after final layout and metadata changes.
  All 1,044 new-edition pages were rendered using the native template renderer.
- Whole-book visual review varied selected spread orders, corrected sample-photo
  captions, and moved letter copy onto the actual fitted paper bounds in all
  three ratios. Cotton-paper typography no longer relies on page-level offsets.
- The supplemental regression run passed 214 cases and exposed three outdated
  free-catalog count/menu expectations. Those expectations were corrected without
  changing the 37 free templates; all 23 cases in the affected two files then
  passed. Other tested areas include decorations, favorites, prior editions,
  copy editing, free previews, and shared material insertion.
- Targeted analysis reported no issues. The Flutter web release build succeeded.
- Browser verification passed all 21 category/viewport combinations, including
  canvas pixel checks, sampled chapter jumps, final spreads, title editing,
  24/32/36/8-page switching, retained copy, and catalog return. There were no
  JavaScript errors, HTTP failures, or generation API requests in the full run.
  See `output/template-preview/premium-volumes/browser/report.json` and screenshots.
- The existing local preview server at port 4323 serves the updated build.
  These checks do not grant print approval, expanded-design approval, or paid
  catalog publication.

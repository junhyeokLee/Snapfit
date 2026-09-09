# Category Premium Studies

## Current Editions: 24-36 Inner Pages

All seven categories now have a 24-inner-page basic edition. Wedding, family,
and couple also have 32-page editions; travel and baby also have 36-page editions.
Page counts exclude the cover. Each preview defaults to its longest edition.
The edition menu preserves edited copy and album ratio when switching between
24 pages, the extended edition, and the approved eight-page baseline. Wedding
also retains its previous 20-page extension for comparison.

See `premium_volume_page_policy.md` for the current counts, assembly invariants,
review scope, and verification commands. The eight-page and wedding 20-page
sections below document preserved earlier stages, not current preview defaults.

## Approved Baseline

All seven eight-inner-page studies were approved on 2026-09-09. The approved
`luminous-edition` travel study remains the minimum visual reference. Artwork in
all seven studies and the archived travel 20-page edition remains unchanged.
The six category studies are independently authored, not six
recolored copies of the travel album. The existing 37 free collections are not
removed, repriced, or republished.

Exact pre-expansion documents are preserved at
`tool/template_studio/archives/approved-category-studies/<id>/<aspect>.json`
(seven books, three ratios). Live study metadata records
`approvalStatus: approved-design-study`; the original snapshots retain their
historical metadata. Tests compare all cover, inner-page, and chapter artwork
against the snapshots, not merely image counts or layout names.

## Collection Map

| Topic | Study | Concept and spread sequence |
| --- | --- | --- |
| 웨딩 | 약속을 묶은 책 / `vow-keepsake` | Ribbon-bound portrait and invitation; botanical mat and stitched vows; reception and guests; keepsakes and garden letter |
| 여행 | 둘만의 여행 / `luminous-edition` | Approved eight-page travel study, unchanged |
| 일상 | 하루의 수집함 / `daily-cabinet` | Window and collecting pocket; bookmark and reading card; shopping receipt and picnic roundel; company and closing file |
| 성장·육아 | 너의 첫 계절 / `first-year-keepsake` | Hand and birth record; development timeline and portrait; small objects and inventory; first birthday and letter |
| 가족·친구 | 우리 집 식탁 / `table-stories` | Linen table and menu; cooking and recipe; company and picnic; table details and next gathering |
| 커플·기념일 | 둘이 모은 장면 / `two-tickets` | Ticket pair and film frames; cafe and note; anniversary and keepsakes; walking portrait and next ticket |
| 반려동물 | 산책하고 낮잠 / `walk-and-nap` | Park and passport; walking log and name-tag portrait; nap and walking kit; quiet roundel and tomorrow's notebook |

Each new study contains one full-photo cover and eight inner pages. All support
portrait, square, and landscape albums. Group photographs fit their original 3:2
composition within bounded regions rather than cropping faces to fill a page.
Landscape cinema pages arrange the two frames beside each other to preserve heads.

## Editable Assets

Six new matte materials are in the shared editor decoration registry:
`heirloomVowPaper`, `heirloomLibraryCard`, `heirloomGrowthRuler`,
`heirloomTableLinen`, `heirloomCinemaStub`, and `heirloomPetTag`.
They retain their native physical ratios, support the existing decoration picker
and persistent favorites, and are also displayed in the material review gallery.
Page-level text and photograph slots remain native editable layers, not flattened
screenshots. Fonts and sample photographs use the existing local asset library.
The studies are authored assets, not live AI-generated output or AI fallback data.

## Preview and Release Boundary

`/premium-studies` shows all seven approved studies with category filters and favorites.
Each detail route supports page browsing, three album ratios, title/date/byline/
letter editing, prepared empty photo slots, and material inspection. Favorites
reuse device-local catalog storage and appear newest first within the active topic.

The candidates are explicitly unpublished: `intendedTier: premium`,
`accessTier: unassigned`, `catalogPublishable: false`, and
`approvalStatus: approved-design-study`. They are not inserted into the paid store,
and no price or payment behavior is added. Design approval does not automatically
approve distribution rights, print output, pricing, or sale registration.

## Wedding Full Edition

`buildVowKeepsakeEdition` expands the wedding study to a cover and 20 inner pages.
The approved first six pages are retained verbatim; the approved final spread
moves to pages 19-20 with only folios and page/layer identities renumbered. The
new 12 pages cover arrival, ceremony, guests' letters, florist details, reception,
and the couple's quiet evening. They have different compositions rather than
repeating or recoloring an approved page.

At this earlier stage, `/vow-keepsake` defaulted to the 20-page edition. Its menu
switches to the approved eight-page baseline on the same route, preserving edited
copy and album ratio. Every page is authored for portrait, square, and landscape.
New editable materials are registered in the shared decoration picker, favorites,
and material gallery: `heirloomVowEnvelope`, `heirloomVowPlaceCard`, and
`heirloomVowSeal`. Photos, text, and decorations remain separate editable layers.

The extension uses `editionId: vow-keepsake-20` and
`approvalStatus: extension-awaiting-review`. Approval of the original study is not
represented as approval of the additional 12 pages. Explicit release gates keep
extension review, print proof, distribution rights, and pricing pending. Other
categories were still approved eight-page studies before the 24-36-page expansion.

Native renders and documents are in `output/template-preview/vow-keepsake-20/`.
Run the browser verifier with `REVIEW_EDITION=vow-keepsake-20` to test all ten
spreads, three screen/album ratios, baseline/extension switching, copy editing,
empty photo slots, and new-material favorites. The default verifier still tests
the six eight-page category baselines.

Before sale: review every spread, expand approved studies without repeating
layouts, validate typography after user copy changes, test diverse replacement
photos including groups, verify print/export edges and material resolution, and
approve asset/font rights for the actual distribution model. No claim of exceeding
competitors' quality is made solely from automated checks.

## Verification

- `test/design/heirloom_studies_test.dart`: metadata isolation, category coverage,
  all 162 new rendered pages (six books x nine pages x three ratios), distinct page
  roles, layer serialization, photo clearing, material aspect ratios, text bounds,
  unintended text/photo overlap, and mobile/landscape catalog favorites.
- Rendered pages, four spreads, contact sheets and JSON documents are exported to
  `output/template-preview/<study>/<aspect>/` with `EXPORT_EDITION=true`.
- `tool/template_studio/verify_heirloom_studies.cjs`: real browser canvas checks
  at 390x844, 844x390 and 1440x900; all six books and four spreads; ratio selection;
  editable copy; category filtering; favorite persistence; JS/HTTP/API failures.
- Existing luminous, archive, free-catalog, material, favorites, and identity tests
  remain part of regression verification.

No backend API credit is required to preview or edit these authored studies.

### Original Study Check

- Regression suite: 204 tests passed. Subsequent composition/catalog adjustments
  passed the focused 21-test suite again; targeted analysis reported no issues.
- All 18 study/ratio combinations were rendered and visually inspected. Review
  corrected landscape group-photo bounds, cropped infant timeline photos,
  landscape cinema head crops, a letter near its paper edge, and thumbnail scale.
- Browser: six studies at each of 390x844, 844x390 and 1440x900 passed page and
  copy-edit checks. Mobile/landscape catalog return and favorite persistence passed
  in the full run. The desktop material-return check was rerun successfully after
  making the automation tolerate Flutter's hovered `Back Back` semantic label.
  This was a test-locator correction, not a navigation implementation change.
- The full-run log is preserved as `full-matrix-before-selector-fix.log`; the
  successful desktop rerun is recorded in `1440-report.json`, alongside screenshots
  in `output/template-preview/heirloom-studies/browser/`.
- Browser runs observed no backend-generation API requests. Native/Flutter-web
  rendering was verified; physical-device and print-production approval are still
  release gates, not claims of this design study.

### Wedding Expansion Check

- Focused expansion checks plus the existing regression suite: 211 tests passed.
  Targeted analysis of 12 template, material, preview, and test files was clean.
- Snapshot equality verifies all 21 approved category/ratio documents. Wedding
  keeps its approved first six inner pages and closing spread without visual edits.
- All 21 wedding pages in each of three ratios rendered through the app's native
  template renderer. Review corrected a place-card caption extending beyond its
  paper, an overlapping specimen label, and an excessively tall portrait mount.
  A second whole-book review changed the reception page to a linen-backed round
  setting and the evening page to an envelope/postcard composition, avoiding
  repetition of the approved panorama and closing letter. The focused 25-test
  suite and targeted analysis passed again after this refinement.
- All 66 registered materials passed picker/editor/preview rendering checks.
  Existing material-scroll tests now derive their traversal limit from catalogue
  size so newly inserted materials do not make later items unreachable to the test.
- Browser verification passed at 390x844/portrait, 844x390/landscape, and
  1440x900/square: all 20 inner pages, chapter jumps, copy edits, baseline/edition
  switching, empty photo slots, and persisted catalogue favorites. Desktop also
  passed new-seal favorite ordering, enlargement, and return with edited copy.
- Results and screenshots are in
  `output/template-preview/vow-keepsake-20/browser/`. The aggregate `report.json`
  combines the successful per-width reports. Tooling was corrected for duplicated
  hovered tooltip labels and cells temporarily unmounting after favorite reorder;
  no application navigation changes were needed. No browser JS/HTTP failures or
  backend-generation API requests were observed in the successful runs.
- Sale remains disabled; browser review is not physical-device or print approval.

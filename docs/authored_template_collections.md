# Archived SnapFit Authored Collections

Retired from all new-creation and studio selection menus on 2026-09-07.
The active free baseline is now 빛으로 엮은 우리, 여행의 결, 작은 날의 기록,
with IDs -9301 through -9303. See [the current policy](free_template_baseline.md).
The remainder of this document records the earlier implementation. Sources and
shared assets remain only for regression and saved-document compatibility.

These are newly authored editable designs, not live AI-generated documents and
not rearrangements of legacy template JSON. Fifteen new sample photographs are
generated with built-in ImageGen and used as replaceable image layers. Layouts,
typography, chapter progression and stationery placement are manually authored.
No runtime template-generation API request, purchase, remote catalog write or
deployment is involved. The stationery update includes four new bitmap artworks
created with built-in ImageGen; this does not make the authored layouts live AI output.

## Collection Inventory

| Collection | Direction | Photo treatments | Document size |
| --- | --- | --- | --- |
| 꽃처럼 피어난 날 | Wedding preparation, vows, company, afterglow, letters | Full photos, oval, arch, rounded, torn collage | Cover + 20 inner pages, 39 photo slots |
| 낯선 곳의 조각들 | Departure, wandering, local tables, keepsakes, return | Full photos, torn edge, scalloped stamp, oval | Cover + 20 inner pages, 36 photo slots |
| 좋아하는 순간들 | Morning, favourites, outside, small records, together | Full photos, die-cut sticker, circle, rounded, arch | Cover + 20 inner pages, 39 photo slots |

Each collection has five four-page chapters and ten facing-page spreads. The
rhythm alternates large photographs, photo sequences, multi-photo grids, notes,
letters and collage compositions. It is not a repeated layout with new headings.
The source metadata records chapter ranges, page names, roles, spread indices and
left/right positions. These are design-review metadata, not new editor controls.

Each collection includes portrait (14.5 x 19.4), square (20 x 20), and landscape
(19.4 x 14.5) variants using the existing physical album sizes. This is **three
collections**, not nine independent designs. Cover compositions reflow in the
landscape variant; circle dimensions remain circular in every format.

## App Integration

- Source: `lib/core/templates/authored_collections.dart` and its
  `authored_petal.dart`, `authored_wander.dart`, `authored_good.dart` parts.
- Registration: `lib/features/album/data/bundled_creation_templates.dart`.
- Available in **Album creation > free templates**, before the remote catalog
  finishes loading. Remote refresh and offline errors do not remove originals.
- IDs -9201 through -9203 identify local free creation templates, not products
  in the server store. Do not send these IDs to billing or server like APIs.
- The regular public store catalog and AI generation pipeline are unchanged.
- Selection carries all three variants into the existing creation flow, clears
  sample photos, and preserves masks, geometry, text and decorative layers.
- Native editor/reader, template preview, and frame picker use the same
  normalized `StudioMaterial` paths. Legacy frame styles remain unchanged.
- Six frame keys: `studioOval`, `studioRounded`, `studioArch`, `studioTorn`,
  `studioSticker`, `studioScallop`. The oval becomes a true circle with equal
  physical width and height. Die-cut is a shaped photo, not AI background removal.
- Unframed photographs use the existing `none` key. Not every photograph receives
  an ornamental mask; full-image layouts provide visual rest between collages.
- Tape, petal, seal and sparkle decorations are editable separate layers.
- Material keys persist through the existing `imageBackground` export field.

## Stationery Update

The collections now also use the new 13-item stationery pack. 꽃처럼 피어난 날 uses
pressed cosmos, a cotton ribbon, letter paper and a botanical stamp. 낯선 곳의 조각들
uses torn cotton stock, printed washi and a keepsake ticket. 좋아하는 순간들 uses an
original risograph-style citrus illustration. Materials are intentionally selective,
not placed on every page. See `docs/studio_stationery.md` for the catalog, artwork
provenance, shared rendering and verification contract.

## Preview and Verification

The existing `tool/template_studio/preview_app.dart` now starts with 꽃처럼 피어난 날.
The palette menu contains all three originals plus the previous review specimens.
The standalone preview does not save albums; the app creation flow does.

```sh
flutter test test/design/authored_collections_test.dart --dart-define=EXPORT_AUTHORED_COLLECTIONS=true
flutter test test/widget/bundled_creation_templates_test.dart
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --target tool/template_studio/preview_app.dart --output build/template-preview
node tool/template_studio/verify_preview.cjs
node tool/template_studio/verify_collections.cjs
```

Generated contact sheets and review JSON are under
`output/template-preview/collections/`. Browser screenshots and the structured
report are under `output/template-preview/collection-browser/`.
Tests cover all 189 variant pages (63 compositions in three physical formats),
text fitting, distinct photo geometry, photo decoding, saved shape keys, photo
replacement, native/catalog pixel parity, offline selection and rotation.
The 52 focused tests passed after the update. Browser checks additionally inspect
all 27 collection/format/viewport combinations, navigation to page 20, selecting
the final thumbnail and opening/closing its enlarged preview. Individual spread
PNGs are exported under `collections/<collection>_<aspect>/spread-1.png` etc.
Automated geometry checks and screen inspection do not certify print production
or replace a final art-direction review on physical proof copies.

## Photo Provenance and Release Gate

This revision replaces the old stock sample imagery in these three collections
with 15 fictional editorial photographs under
`assets/templates/original_editorial/images/`. Exact prompts, generation mode and
original source paths are recorded in the adjacent `provenance.json`. The PNGs
were copied unchanged from built-in ImageGen output. They are not real user
photos, verified travel destinations, flattened template pages or runtime AI
template results. Existing assets and saved albums were not overwritten.

No competitor layouts, reference screenshots or newly scraped images are bundled.
Output rights, font rights and physical print quality still require normal release
review. Sample photos are removed when selecting a design for a personal album.

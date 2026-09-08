# SnapFit Stationery Collection

## Design Standard

New artwork must not be an emoji, platform glyph, enlarged Material icon or glossy
plastic substitute. This pack uses tactile matte artwork, subtle paper fibers,
controlled edge irregularity and proportional die-cut silhouettes. Small collage
details support the photograph; they should not obscure faces or captions.

| Category | New materials |
| --- | --- |
| Paper (5) | Scanned-style cotton rag, cotton deckle, blush fiber paper, ruled archive note, translucent vellum |
| Illustrated stickers (3) | Pressed cosmos, sage grosgrain ribbon, citrus print |
| Keepsakes (2) | Memory ticket, botanical postage stamp |
| Washi (3) | Sage pinstripe, rose check, indigo ink dots |

The 4 raster artworks were generated with the **built-in ImageGen tool**, then
copied without pixel modification into `assets/sticker/studio/`. Full prompts and
source identifiers are in `assets/sticker/studio/provenance.json`. No external API
key or template-generation service was called. These are newly authored preset
templates containing generated artwork, not a claim of live user-prompt AI generation.

The other materials are deterministic code-native stationery paths, print marks
and fine fiber strokes. They remain crisp at different sizes. The stamp includes
the same generated cosmos; it is not another unique generated illustration.
Vellum and washi retain transparency; shadows are small matte contact shadows.

## Integration

- Catalog and sizing: `lib/core/templates/studio_decoration_catalog.dart`.
- Shared artwork: `lib/shared/widgets/studio_decoration.dart`.
- Editor decoration picker opens on **새 컬렉션**, then 종이 / 스티커 / 테이프.
- Legacy decorations remain in **기존 장식**. Previously saved albums are not
  rewritten or made dependent on the new catalog.
- New raster insertions use `LayerType.sticker`, not replaceable photo slots.
- Materials use `LayerType.decoration` and stable `imageBackground` keys.
- Insertion maintains each asset's aspect ratio, fits within the canvas and uses
  the existing editor undo/redo history. Oversized scale is bounded proportionally.
- The template renderer contains raster stickers, while photo frames retain cover
  cropping. Image clearing during template selection preserves all sticker artwork.
- New asset styles render identically in native LayerBuilder and catalog previews.
- Bundled asset directory is registered explicitly in `pubspec.yaml`.

## Preview

The existing preview at `http://127.0.0.1:4323/` contains the updated three collections.
Its **종이·스티커** toolbar button opens the actual picker with a larger artwork
inspector and white / sage / ink background swatches. The inspector is a local
development preview, not album persistence. App insertions use the real editor.

```sh
flutter test test/widget/studio_decorations_test.dart
flutter test test/design/authored_collections_test.dart test/widget/bundled_creation_templates_test.dart
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --target tool/template_studio/preview_app.dart --output build/template-preview
node tool/template_studio/verify_materials.cjs
node tool/template_studio/verify_collections.cjs
```

Tests check insertion in all three album proportions, undo/redo, export/import,
photo clearing, actual alpha in PNG assets, native/catalog pixel parity, and
picker category actions at 320, 390 and 844 pixel widths in light/dark themes.
Browser QA verifies actual canvas pixels and saves large material inspections.

This is a local bundled addition, not a deployment or public store publication.
Physical print sampling and native-device gesture QA remain release checks;
existing sample-photography licensing/release checks are unchanged.

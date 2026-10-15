# Catalog thumbnails

Generated from the native Flutter cover/material renderers, with bundled fonts
and all image providers loaded before capture. Transparent artwork stays transparent.
These are display-only: purchase metadata, editable documents and print assets
remain separate and unchanged.

Regenerate after changing published artwork, frame preview photographs or fonts:

```sh
flutter test --dart-define=EXPORT_CATALOG=true test/tool/catalog_thumbnail_export_test.dart
```

Commit the PNG files and `lib/core/templates/catalog_preview_assets.g.dart` together.
The exporter checks image loads and layout exceptions. The catalog coverage test
requires a preview for each published item. New/remote items without a preview
fall back to native rendering. Cover previews are only used for the canonical
bundled document builder, not remote overrides that happen to share its ID.

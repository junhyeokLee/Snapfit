# Catalog Favorites

## Behavior

- Device-local persistent favorites, available without login or AI/API credits.
- New favorites move to the front. Favorite order is save order, not usage order.
- Removing a favorite restores the original catalog ordering. Removing and saving again makes it newest.
- Only entries in the current published catalog are displayed. Retired templates are never resurrected from saved IDs.
- Template IDs are shared across the store, detail, creation flow and editor.
- Frames, studio/legacy stickers, paper, tape, editable phrases, fonts, page layouts and text-decoration color variants use independent stable IDs.
- A 44-pixel star target is separate from apply/open. Saving a favorite does not edit the document or enter undo history.
- Favorites-only filters have an empty state and an action to return to the full catalog. Category/search filters can narrow saved items.
- Store favorites are accessible at the top, with the featured carousel hidden in favorites-only mode.
- Grouped text decorations show recently saved variants before the regular sections. Color variants can be saved separately.

## Persistence

`catalog_favorites_v1` stores a versioned JSON object in SharedPreferences. Ordered IDs avoid dependence on device clock or timestamps. A serialized mutation queue prevents rapid taps on different items from losing updates. Failed writes roll back and show a retry message. Corrupt JSON can recover; a newer schema is not overwritten.

Existing local template hearts are imported once per guest/user scope, after current favorites. Migration markers persist so refresh does not re-add a removed favorite.

This is not account/cloud sync. Clearing app data or removing the application can remove favorites; a different device has a separate list. Favorites do not confer access to a paid asset. Aspect ratio, color sliders and other utility controls are not catalog assets.

## Verification

Focused unit and widget suite covers save ordering, rapid taps, reload, before-load mutations, write/read failure, migration, stable cross-screen keys, independent hit targets, empty filters and 320/390/844px picker layouts.

```sh
flutter test --no-pub test/unit/catalog_favorites_test.dart test/widget/catalog_favorites_test.dart
flutter test --no-pub test/widget/studio_atelier_test.dart test/widget/studio_photo_frames_test.dart test/widget/studio_decorations_test.dart test/unit/published_template_catalog_test.dart test/widget/published_store_catalog_test.dart
```

The existing template workbench uses the same favorite service and controls in the store, frame browser, materials and atelier views. No credentials, paid API calls or catalog publishing are required.

Validation on 2026-09-08: 34 focused tests and 77 catalog/material regression tests passed. Targeted Dart analysis and `git diff --check` were clean. Browser checks at 390x844, 844x390 and 1440x900 verify independent star targets, unchanged album artwork, save ordering, filtering, reload, empty-state recovery and cross-screen frame identity. Browser artifacts are in `output/template-preview/favorites` and can be regenerated with `node tool/template_studio/verify_favorites.cjs`.

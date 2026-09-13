import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/catalog_favorites.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_sticker_tab.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import '../widget/ai_album_start_step_test.dart' show wrapCreation;

void main() {
  testWidgets(
    'material chooser creates previews only for visible grid children',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      CatalogFavorites.instance = CatalogFavorites();
      await CatalogFavorites.instance.load();
      addTearDown(CatalogFavorites.instance.dispose);
      DecorateStickerTab.debugPreviewBuildCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pointShopCatalogProvider.overrideWith((ref) async => []),
            ownedPointShopKeysProvider.overrideWith((ref) async => {}),
          ],
          child: wrapCreation(
            const SizedBox(
              height: 500,
              child: DecorateStickerTab(surfaceColor: Colors.white),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(DecorateStickerTab.debugPreviewBuildCount, greaterThan(0));
      expect(DecorateStickerTab.debugPreviewBuildCount, lessThan(40));
      expect(
        DecorateStickerTab.debugPreviewBuildCount,
        lessThan(studioDecorations.length),
      );
      final before = DecorateStickerTab.debugPreviewBuildCount;
      debugPrint('BUDGET material_initial_previews=$before eager_baseline=376');
      await tester.drag(find.byType(GridView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(DecorateStickerTab.debugPreviewBuildCount, greaterThan(before));
      debugPrint(
        'BUDGET material_after_scroll_previews=${DecorateStickerTab.debugPreviewBuildCount}',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

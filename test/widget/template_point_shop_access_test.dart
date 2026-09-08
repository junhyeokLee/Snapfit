import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

void main() {
  setUpAll(loadCreationFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets(
    'preview never buys; denied selection stays open and granted retry uses the same authored key',
    (tester) async {
      var granted = false;
      final keys = <String>[];
      AlbumCreationTemplate? selected;
      await tester.pumpWidget(
        wrapCreation(
          Builder(
            builder: (context) => TextButton(
              child: const Text('템플릿 보기'),
              onPressed: () async {
                selected = await Navigator.push<AlbumCreationTemplate>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TemplateDetailScreen(
                      template: bundledCreationTemplates.first,
                      selectForCreation: true,
                    ),
                  ),
                );
              },
            ),
          ),
          shopProducts: const [
            PointShopProduct(
              productKey: 'template:lightbound',
              kind: 'template',
              assetId: 'lightbound',
              title: '빛의 기록',
              pointPrice: 650,
              isActive: true,
            ),
          ],
          pointShopGate:
              (context, ref, {required productKey, required title}) async {
                keys.add(productKey);
                return granted;
              },
        ),
      );
      await tester.tap(find.text('템플릿 보기'));
      await tester.pumpAndSettle();
      expect(find.text('650P'), findsOneWidget);
      expect(keys, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, '이 디자인 선택'));
      await tester.pumpAndSettle();
      expect(keys, ['template:lightbound']);
      expect(selected, isNull);
      expect(find.byType(TemplateDetailScreen), findsOneWidget);
      granted = true;
      await tester.tap(find.widgetWithText(FilledButton, '이 디자인 선택'));
      await tester.pumpAndSettle();
      expect(keys, ['template:lightbound', 'template:lightbound']);
      expect(selected, isNotNull);
      expect(selected!.pages, isNotEmpty);
      expect(find.byType(TemplateDetailScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

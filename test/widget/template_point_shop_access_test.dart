import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_document_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_edition_sheet.dart';
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

  for (final count in [24, 32]) {
    testWidgets(
      'paid wedding delivers selected $count pages and the same purchase key',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AlbumCreationTemplate? selected;
        final keys = <String>[];
        await tester.pumpWidget(
          wrapCreation(
            Builder(
              builder: (context) => TextButton(
                child: const Text('유료 템플릿 보기'),
                onPressed: () async {
                  selected = await Navigator.push<AlbumCreationTemplate>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TemplateDetailScreen(
                        template: publishedPremiumTemplates.first,
                        selectForCreation: true,
                      ),
                    ),
                  );
                },
              ),
            ),
            pointShopGate:
                (context, ref, {required productKey, required title}) async {
                  keys.add(productKey);
                  return true;
                },
          ),
        );
        await tester.tap(find.text('유료 템플릿 보기'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            await precacheImage((element.widget as Image).image, element);
          }
        });
        await tester.pumpAndSettle();
        expect(keys, isEmpty);
        await tester.tap(find.widgetWithText(FilledButton, '이 디자인 선택'));
        // Previewing an edition never performs a purchase or confirms selection.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(keys, isEmpty);
        final option = find.byKey(ValueKey('template-edition-$count'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pump(const Duration(milliseconds: 300));
        final preview = tester.widget<CreationDocumentPreview>(
          find.descendant(
            of: find.byType(TemplateEditionSheet),
            matching: find.byType(CreationDocumentPreview),
          ),
        );
        expect(preview.pages, hasLength(count + 1));
        expect(keys, isEmpty);
        expect(selected, isNull);
        await tester.tap(
          find.byKey(const ValueKey('template-edition-continue')),
        );
        await tester.pumpAndSettle();
        expect(keys, ['template:vow-keepsake']);
        expect(selected!.isPremium, true);
        expect(selected!.preserveTypography, true);
        expect(selected!.pages, hasLength(count + 1));
        expect(selected!.variants, isNotEmpty);
        for (final pages in selected!.variants.values) {
          expect(pages, hasLength(count + 1));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/premium_template_list.dart';
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

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      'store $size: current covers, search, free detail and local favorites',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              templateRepositoryProvider.overrideWith(
                (ref) => throw StateError(
                  'The retired catalog must never be queried',
                ),
              ),
            ],
            child: wrapCreation(const StoreScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scope = ProviderScope.containerOf(
          tester.element(find.byType(StoreScreen)),
        );
        expect(
          scope.read(templateListProvider).requireValue.map((t) => t.id),
          bundledCreationTemplates.map((t) => t.id),
        );
        final search = find.byType(TextField);
        final scroll = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(search, 280, scrollable: scroll);
        await tester.pumpAndSettle();
        for (final category in [
          '웨딩',
          '여행',
          '일상',
          '성장·육아',
          '가족·친구',
          '커플·기념일',
          '반려동물',
        ]) {
          final chip = find.descendant(
            of: find.byKey(const ValueKey('store-topic-filters')),
            matching: find.text(category),
          );
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(
            find.text(
              '$category 분위기에 어울리는 ${category == '여행' || category == '커플·기념일' ? 6 : 5}개',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        final allTopics = find.descendant(
          of: find.byKey(const ValueKey('store-topic-filters')),
          matching: find.text('전체'),
        );
        await tester.ensureVisible(allTopics);
        await tester.pumpAndSettle();
        await tester.tap(allTopics);
        await tester.pumpAndSettle();
        for (final template in bundledCreationTemplates) {
          await tester.scrollUntilVisible(search, -280, scrollable: scroll);
          await tester.enterText(search, template.title);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(ValueKey('store-template-${template.id}')),
            240,
            scrollable: scroll,
          );
          final covers = tester
              .widgetList<CreationCatalogCover>(
                find.byType(CreationCatalogCover),
              )
              .where(
                (cover) => find
                    .ancestor(
                      of: find.byWidget(cover),
                      matching: find.byType(PremiumTemplateList),
                    )
                    .evaluate()
                    .isEmpty,
              );
          expect(covers.map((cover) => cover.template.id), [template.id]);
        }
        await tester.scrollUntilVisible(search, -280, scrollable: scroll);
        await tester.enterText(search, '제주의 기록');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('store-template--9302')),
          findsNothing,
        );
        await tester.enterText(search, '여행의 결');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('store-template--9302')),
          240,
          scrollable: scroll,
        );
        final cover = find
            .byWidgetPredicate(
              (widget) =>
                  widget is CreationCatalogCover && widget.template.id == -9302,
            )
            .last;
        await tester.ensureVisible(cover);
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getCenter(cover));
        await tester.pumpAndSettle();
        expect(find.byType(TemplateDetailScreen), findsOneWidget);
        expect(
          tester
              .widget<TemplateDetailScreen>(find.byType(TemplateDetailScreen))
              .template
              .id,
          -9302,
        );
        expect(publishedTemplatePhotoCount(bundledCreationTemplates[1]), 25);
        final like = find
            .byKey(ValueKey('favorite-${CatalogFavoriteKeys.template(-9302)}'))
            .last;
        await tester.ensureVisible(like);
        await tester.tap(like);
        await tester.pumpAndSettle();
        expect(
          CatalogFavorites.instance.contains(
            CatalogFavoriteKeys.template(-9302),
          ),
          true,
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(PreferencesFavoritesStorage.key),
          contains(CatalogFavoriteKeys.template(-9302)),
        );
        Navigator.of(tester.element(find.byType(TemplateDetailScreen))).pop();
        await tester.pumpAndSettle();
        expect(
          CatalogFavorites.instance.contains(
            CatalogFavoriteKeys.template(-9302),
          ),
          true,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('$size: thirty-six-item carousel has bounded pagination', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateListProvider.overrideWith(
              (ref) async => bundledCreationTemplates,
            ),
          ],
          child: wrapCreation(
            const SingleChildScrollView(child: PremiumTemplateList()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 37'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('다음 컬렉션'));
      for (var i = 2; i <= 37; i++) {
        await tester.tap(find.byTooltip('다음 컬렉션'));
        await tester.pumpAndSettle();
        expect(find.text('$i / 37'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '다음 컬렉션',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('이전 컬렉션'));
      await tester.pumpAndSettle();
      expect(find.text('36 / 37'), findsOneWidget);
    });
  }
}

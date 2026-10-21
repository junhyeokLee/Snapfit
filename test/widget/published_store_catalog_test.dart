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
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
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
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              templateRepositoryProvider.overrideWith(
                (ref) => throw StateError(
                  'The retired catalog must never be queried',
                ),
              ),
            ],
            child: wrapCreation(
              MediaQuery(
                data: MediaQueryData(size: size, disableAnimations: true),
                child: const StoreHubScreen(),
              ),
              showShell: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('store-departments')), findsOneWidget);
        expect(find.byTooltip('스토어 검색'), findsOneWidget);
        expect(find.text('완성 템플릿'), findsNothing);
        final scope = ProviderScope.containerOf(
          tester.element(find.byType(StoreScreen)),
        );
        expect(
          scope.read(templateListProvider).requireValue.map((t) => t.id),
          publishedCreationTemplates.map((t) => t.id),
        );
        final scroll = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('store-topic-filters')),
          280,
          scrollable: scroll,
        );
        Future<void> selectTopic(String category) async {
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('store-topic-filters')),
            280,
            scrollable: scroll,
          );
          final chip = find.byKey(ValueKey('store-topic-$category'));
          // Move the whole tap target into both viewports, then let layout
          // settle before reading its position for the actual pointer event.
          await Scrollable.ensureVisible(
            tester.element(chip),
            alignment: .25,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          );
          await tester.pumpAndSettle();
          expect(chip.hitTestable(), findsOneWidget, reason: category);
          await tester.tap(chip.hitTestable());
          await tester.pumpAndSettle();
        }

        for (final category in [
          '웨딩',
          '여행',
          '일상',
          '성장·육아',
          '가족·친구',
          '커플·기념일',
          '반려동물',
        ]) {
          await selectTopic(category);
          final resultLabel = find.text(
            '$category · ${publishedCreationTemplates.where((t) => t.category == category).length}종',
          );
          // Subject changes retain the controls and current result count;
          // there is no second trip past the collection hero.
          expect(resultLabel, findsOneWidget);
          expect(resultLabel.hitTestable(), findsOneWidget);
          expect(
            find.byKey(ValueKey('store-topic-$category')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        await selectTopic('전체');
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.byTooltip('스토어 검색'));
        await tester.pumpAndSettle();
        final searchScreen = find.byWidgetPredicate(
          (widget) => widget is StoreScreen && widget.searchMode,
        );
        expect(searchScreen, findsOneWidget);
        expect(find.text('템플릿 검색'), findsOneWidget);
        final search = find.byType(TextField);
        expect(search, findsOneWidget);
        Future<void> showSearch() async {
          tester
              .widget<CustomScrollView>(find.byType(CustomScrollView))
              .controller!
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(search, 240, scrollable: scroll);
        }

        for (final template in publishedCreationTemplates) {
          await showSearch();
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
        await showSearch();
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
    testWidgets('$size: free-catalog carousel has bounded pagination', (
      tester,
    ) async {
      final count = bundledCreationTemplates.length;
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
      expect(find.text('1 / $count'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('다음 컬렉션'));
      for (var i = 2; i <= count; i++) {
        await tester.tap(find.byTooltip('다음 컬렉션'));
        await tester.pumpAndSettle();
        expect(find.text('$i / $count'), findsOneWidget);
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
      expect(find.text('${count - 1} / $count'), findsOneWidget);
    });
  }
}

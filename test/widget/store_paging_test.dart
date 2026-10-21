import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_floating_cover.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

void main() {
  setUpAll(loadCreationFonts);
  testWidgets(
    'catalog grows 12 at a time; filters reset and documents stay lazy',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      CatalogFavorites.instance = CatalogFavorites();
      await CatalogFavorites.instance.load();
      addTearDown(() => CatalogFavorites.instance.dispose());
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final built = <int>{};
      final items = List.generate(
        30,
        (i) => PremiumTemplate(
          id: i + 1,
          title: 'Template $i',
          coverImageUrl: '',
          previewImages: const [],
          pageCount: 24,
          isPremium: i % 3 == 2,
          userCount: 0,
          category: '여행',
          documentBuilder: () {
            built.add(i);
            return '{"pages":[]}';
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [templateListProvider.overrideWith((ref) async => items)],
          child: wrapCreation(
            const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: StoreScreen(searchMode: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      int count() =>
          (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
                  as SliverChildBuilderDelegate)
              .childCount!;
      expect(count(), 12);
      expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .cacheExtent,
        inInclusiveRange(200, 400),
      );
      expect(built.length, lessThan(12));
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(count(), 24);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(count(), 30);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Template 29');
      await tester.pumpAndSettle();
      expect(count(), 1);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(count(), 12);
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text('유료'),
        ),
      );
      await tester.pumpAndSettle();
      expect(count(), 10);
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text('무료'),
        ),
      );
      await tester.pumpAndSettle();
      expect(count(), 12);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('visible cover floats without rebuilding artwork', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              SizedBox(
                height: 180,
                child: StoreFloatingCover(
                  scrollController: scroll,
                  seed: 1,
                  child: const ColoredBox(color: Colors.red),
                ),
              ),
              const SizedBox(height: 1800),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final transform = find.descendant(
      of: find.byType(StoreFloatingCover),
      matching: find.byType(Transform),
    );
    final before = tester.widget<Transform>(transform).transform.clone();
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.widget<Transform>(transform).transform, isNot(before));
    final gesture = await tester.startGesture(const Offset(100, 100));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    final paused = tester.widget<Transform>(transform).transform.clone();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<Transform>(transform).transform, paused);
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

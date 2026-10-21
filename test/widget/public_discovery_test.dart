import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/store/presentation/views/public_discovery_screen.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/features/auth/presentation/providers/public_template_return_intent.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('guest catalog searches published artwork without an account', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicPointShopCatalogProvider.overrideWith((_) async => []),
        ],
        child: MaterialApp(
          theme: SnapFitWebTheme.from(ThemeData()),
          home: const PublicDiscoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('사진과 이야기가 한 권의 책으로'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('discovery-search')),
      '없는디자인검색어',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('검색 결과가 없어요. 다른 이름이나 주제로 찾아보세요.'),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('public-discovery-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('검색 결과가 없어요. 다른 이름이나 주제로 찾아보세요.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('discovery-search')),
      publishedCreationTemplates.first.title,
    );
    await tester.pumpAndSettle();
    final result = find.byKey(
      ValueKey('discovery-template-${publishedCreationTemplates.first.id}'),
    );
    await tester.scrollUntilVisible(
      result,
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('public-discovery-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(result, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native discovery returns to the existing login before creation',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicPointShopCatalogProvider.overrideWith((_) async => []),
          ],
          child: MaterialApp(
            theme: SnapFitWebTheme.from(ThemeData()),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PublicDiscoveryScreen(),
                    ),
                  ),
                  child: const Text('로그인 화면에서 둘러보기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('로그인 화면에서 둘러보기'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PublicDiscoveryScreen)),
      );
      container
          .read(publicTemplateReturnIntentProvider.notifier)
          .remember(publishedCreationTemplates.first.id);
      await tester.tap(find.byKey(const ValueKey('discovery-login')));
      await tester.pumpAndSettle();
      expect(container.read(publicTemplateReturnIntentProvider), isNull);
      expect(find.byType(PublicDiscoveryScreen), findsNothing);
      expect(find.text('로그인 화면에서 둘러보기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
  ]) {
    testWidgets(
      'large public search keeps filters and dismisses the keyboard at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height < 400 ? 100 : 200,
        );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              publicPointShopCatalogProvider.overrideWith((_) async => []),
              pointShopRepositoryProvider.overrideWith(
                (_) => throw StateError(
                  'public search must not request an account',
                ),
              ),
            ],
            child: MaterialApp(
              theme: SnapFitWebTheme.from(ThemeData()),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.8)),
                child: child!,
              ),
              home: const PublicDiscoveryScreen(catalogOnly: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final template = publishedCreationTemplates.first;
        final search = find.byKey(const ValueKey('discovery-search'));
        await tester.ensureVisible(search);
        await tester.enterText(search, template.title);
        await tester.pumpAndSettle();
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        final category = find.widgetWithText(ChoiceChip, template.category!);
        await tester.ensureVisible(category);
        await tester.tap(category);
        await tester.pumpAndSettle();
        final result = find.byKey(
          ValueKey('discovery-template-${template.id}'),
        );
        await tester.scrollUntilVisible(
          result,
          100,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('public-discovery-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(result, findsOneWidget);
        expect(tester.takeException(), isNull);
        final clear = find.byKey(const ValueKey('discovery-search-clear'));
        tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey('public-discovery-scroll')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(clear.hitTestable(), findsOneWidget);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(search).controller!.text, isEmpty);
        expect(tester.widget<ChoiceChip>(category).selected, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final size in [const Size(320, 568), const Size(648, 320)]) {
    testWidgets('empty search recovers actual subjects at large text $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicPointShopCatalogProvider.overrideWith((_) async => []),
            pointShopRepositoryProvider.overrideWith(
              (_) => throw StateError('Recovery must not request an account'),
            ),
          ],
          child: MaterialApp(
            theme: SnapFitWebTheme.from(ThemeData(brightness: Brightness.dark)),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: const PublicDiscoveryScreen(catalogOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('discovery-search'));
      final existingCategory = publishedCreationTemplates.first.category!;
      final chip = find.widgetWithText(ChoiceChip, existingCategory);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      await tester.enterText(search, '존재하지않는디자인');
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('public-discovery-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final reset = find.byKey(const ValueKey('discovery-reset-filters'));
      await tester.scrollUntilVisible(reset, 120, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(reset.hitTestable(), findsOneWidget);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(search, -120, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '전체'))
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('discovery-search-empty')),
        findsNothing,
      );

      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      await tester.enterText(search, '다시존재하지않는디자인');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('discovery-search-empty')),
        120,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      final suggestions = find.byType(ActionChip);
      expect(suggestions, findsNWidgets(3));
      final suggestion = tester.widget<ActionChip>(suggestions.first);
      final category = (suggestion.label as Text).data!;
      expect(
        publishedCreationTemplates.any(
          (template) => template.category == category,
        ),
        isTrue,
      );
      final target = find.byKey(ValueKey('discovery-suggestion-$category'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      expect(target.hitTestable(), findsOneWidget);
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(search, -120, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, category))
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('discovery-search-empty')),
        findsNothing,
      );
      final result = publishedCreationTemplates.firstWhere(
        (template) => template.category == category,
      );
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('discovery-template-${result.id}')),
        160,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('public-discovery-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

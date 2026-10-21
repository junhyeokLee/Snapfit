import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/template_catalog_categories.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/store/domain/public_discovery_ordering.dart';
import 'package:snap_fit/features/store/presentation/views/public_discovery_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/shared/web/web_design.dart';

Widget _host() => ProviderScope(
  overrides: [
    publicPointShopCatalogProvider.overrideWith((_) async => []),
    pointShopRepositoryProvider.overrideWith(
      (_) => throw StateError(
        'Public discovery must not request private account data',
      ),
    ),
    ownedPointShopKeysProvider.overrideWith(
      (_) => throw StateError('Public discovery must not request ownership'),
    ),
  ],
  child: MaterialApp(
    theme: SnapFitWebTheme.from(ThemeData()),
    home: const PublicDiscoveryScreen(catalogOnly: true),
  ),
);

Finder _scroll() => find
    .descendant(
      of: find.byKey(const ValueKey('public-discovery-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

List<int> _displayedIds(WidgetTester tester) {
  final gridFinder = find.byType(SliverGrid);
  final grid = tester.widget<SliverGrid>(gridFinder);
  final delegate = grid.delegate as SliverChildBuilderDelegate;
  final context = tester.element(gridFinder);
  return [
    for (var index = 0; index < delegate.estimatedChildCount!; index++)
      int.parse(
        (((delegate.builder(context, index) as Material).child as InkWell).key
                as ValueKey<String>)
            .value
            .substring('discovery-template-'.length),
      ),
  ];
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _search(WidgetTester tester, String query) async {
  tester.state<ScrollableState>(_scroll()).position.jumpTo(0);
  await tester.pumpAndSettle();
  final search = find.byKey(const ValueKey('discovery-search'));
  await tester.ensureVisible(search);
  await tester.enterText(search, query);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'mobile public discovery exposes varied subjects and retains comparison through search and topic changes',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final ordered = orderPublicDiscoveryTemplates(publishedCreationTemplates);
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      final first = _displayedIds(tester);
      expect(first, ordered.take(12).map((item) => item.id));
      final shown = publishedCreationTemplates.where(
        (item) => first.contains(item.id),
      );
      expect(
        shown.map((item) => item.category).toSet(),
        templateTopicOrder.toSet(),
      );
      expect(shown.where((item) => item.isPremium), hasLength(4));

      final selected = ordered.first;
      final compare = find.byKey(ValueKey('discovery-compare-${selected.id}'));
      await tester.scrollUntilVisible(compare, 180, scrollable: _scroll());
      await tester.ensureVisible(compare);
      await tester.pumpAndSettle();
      await tester.tap(compare);
      await tester.pumpAndSettle();
      final selectedChip = find.byKey(
        ValueKey('comparison-selected-${selected.id}'),
      );
      expect(selectedChip, findsOneWidget);

      final searched = publishedPremiumTemplates.first;
      await _search(tester, searched.title);
      final expectedSearch = ordered
          .where(
            (item) =>
                '${item.title} ${item.description ?? ''} ${item.tags?.join(' ') ?? ''}'
                    .toLowerCase()
                    .contains(searched.title.toLowerCase()),
          )
          .take(12)
          .map((item) => item.id);
      expect(_displayedIds(tester), expectedSearch);
      expect(_displayedIds(tester), contains(searched.id));
      expect(selectedChip, findsOneWidget);

      await _search(tester, '');
      expect(_displayedIds(tester), first);
      final travel = find.widgetWithText(ChoiceChip, '여행');
      await tester.ensureVisible(travel);
      await tester.tap(travel);
      await tester.pumpAndSettle();
      expect(
        _displayedIds(tester),
        ordered
            .where((item) => item.category == '여행')
            .take(12)
            .map((item) => item.id),
      );
      expect(
        selectedChip,
        findsOneWidget,
        reason: 'A different visible subject cannot discard selected IDs',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'public load more appends the next stable twelve without repeated IDs',
    (tester) async {
      _viewport(tester, const Size(1280, 1000));
      final ordered = orderPublicDiscoveryTemplates(publishedCreationTemplates);
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      final first = _displayedIds(tester);
      expect(first, hasLength(12));
      final more = find.widgetWithText(OutlinedButton, '디자인 더 보기');
      await tester.scrollUntilVisible(more, 300, scrollable: _scroll());
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      final next = _displayedIds(tester);
      expect(next, ordered.take(24).map((item) => item.id));
      expect(next.take(12), first);
      expect(next.toSet(), hasLength(24));
      await _search(tester, ordered.first.title);
      await _search(tester, '');
      expect(
        _displayedIds(tester),
        first,
        reason: 'Search changes retain the existing twelve-item page reset',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

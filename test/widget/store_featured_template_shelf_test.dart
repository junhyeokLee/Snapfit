import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/fonts/document_font_gate.dart';
import 'package:snap_fit/core/templates/catalog_preview_assets.g.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_image.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_featured_template_shelf.dart';
import 'package:snap_fit/shared/widgets/catalog_preview_builder.dart';

PremiumTemplate _book(
  int id, {
  bool premium = false,
  String Function()? documentBuilder,
}) => PremiumTemplate(
  id: id,
  title: '오래 남길 이야기 $id',
  category: '여행',
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 24,
  userCount: 99999,
  weeklyScore: 99999,
  isBest: true,
  isPremium: premium,
  documentBuilder:
      documentBuilder ??
      () => throw StateError('Featured shelves must not read documents'),
);

StoreCuration _curation(
  List<PremiumTemplate> books, {
  String title = '운영자가 고른 이야기',
  bool enabled = true,
}) => StoreCuration(
  placement: 'templates',
  title: title,
  subtitle: '사진과 문장으로 엮는 한 권',
  enabled: enabled,
  productKeys: books.map(pointShopTemplateKey).toList(),
);

Widget _host({
  required List<PremiumTemplate> templates,
  required StoreCuration? selection,
  Map<String, StoreProductDiscovery> discovery = const {},
  ValueChanged<PremiumTemplate>? onOpen,
  Map<int, int> prices = const {},
  bool dark = false,
  double scale = 1,
  double keyboard = 0,
  String? topic,
}) => ProviderScope(
  overrides: [
    storeDiscoveryProvider.overrideWith((_) async => discovery),
    storeDiscoveryClockProvider.overrideWithValue(DateTime.utc(2026, 11, 4)),
    pointShopCatalogProvider.overrideWith(
      (_) async => [
        for (final template in templates)
          PointShopProduct(
            productKey: pointShopTemplateKey(template),
            kind: 'template',
            assetId: '${template.id}',
            title: template.title,
            pointPrice: prices[template.id] ?? (template.isPremium ? 1800 : 0),
            isActive: true,
          ),
      ],
    ),
    ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
  ],
  child: MaterialApp(
    theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboard),
        disableAnimations: true,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: StoreFeaturedTemplateShelf(
            templates: templates,
            selection: selection,
            discovery: discovery,
            topic: topic,
            onOpen: onOpen ?? (_) {},
          ),
        ),
      ),
    ),
  ),
);

void _viewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _heading(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.key == const ValueKey('store-featured-title') &&
      (widget.semanticsLabel ?? widget.data) == label,
);

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _expectPrice(int id, String label) {
  expect(
    find.descendant(
      of: find.byKey(ValueKey('store-featured-template-price-$id')),
      matching: find.text(label),
    ),
    findsOneWidget,
  );
}

void _expectSelected(
  WidgetTester tester,
  PremiumTemplate selected, {
  Iterable<PremiumTemplate> others = const [],
}) {
  expect(
    find.byKey(ValueKey('store-featured-template-${selected.id}')),
    findsOneWidget,
  );
  final title = find.byKey(
    ValueKey('store-featured-template-title-${selected.id}'),
  );
  expect(title, findsOneWidget);
  final titleText = tester.widget<Text>(title);
  expect(titleText.semanticsLabel ?? titleText.data, selected.title);
  expect(
    find.byKey(ValueKey('store-featured-open-${selected.id}')),
    findsOneWidget,
  );
  for (final other in others) {
    expect(
      find.byKey(ValueKey('store-featured-template-${other.id}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('store-featured-template-price-${other.id}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('store-featured-open-${other.id}')),
      findsNothing,
    );
  }
}

List<int> _position(WidgetTester tester) => RegExp(r'\d+')
    .allMatches(
      tester
          .widget<Text>(find.byKey(const ValueKey('store-featured-position')))
          .data!,
    )
    .map((match) => int.parse(match.group(0)!))
    .toList();

bool _controlEnabled(WidgetTester tester, String direction) =>
    tester
        .widget<IconButton>(find.byKey(ValueKey('store-featured-$direction')))
        .onPressed !=
    null;

void main() {
  group('featured metadata selection', () {
    test(
      'topic scope preserves verified ranks and configured product order',
      () {
        final books = [_book(1).copyWith(category: '일상'), _book(2), _book(3)];
        final ranks = {
          pointShopTemplateKey(books[0]): const StoreProductDiscovery(
            bestRank: 1,
          ),
          pointShopTemplateKey(books[2]): const StoreProductDiscovery(
            bestRank: 4,
          ),
        };
        final groups = selectStoreFeaturedTemplates(
          templates: books,
          selection: _curation(books.reversed.toList()),
          discovery: ranks,
          topic: '여행',
        );
        expect(groups.best.map((book) => book.id), [3]);
        expect(ranks[pointShopTemplateKey(books[2])]!.bestRank, 4);
        expect(groups.curated.map((book) => book.id), [3, 2]);
        expect(groups.isTopicRecommendation, isFalse);
      },
    );

    test('only an explicit topic can offer non-popularity suggestions', () {
      final books = [for (var id = 1; id <= 8; id++) _book(id)];
      StoreFeaturedTemplateGroups choose({
        String? topic,
        StoreCuration? pick,
      }) => selectStoreFeaturedTemplates(
        templates: books,
        selection: pick,
        discovery: const {},
        topic: topic,
      );
      final topic = choose(topic: '여행');
      expect(topic.best, isEmpty);
      expect(topic.curated.map((book) => book.id), [1, 2, 3, 4, 5, 6]);
      expect(topic.isTopicRecommendation, isTrue);
      expect(choose().curated, isEmpty);
      expect(choose(topic: '웨딩').curated, isEmpty);
      expect(
        choose(topic: '여행', pick: _curation(books, enabled: false)).curated,
        isEmpty,
      );
    });

    test(
      'BEST only uses verified ranks, remains bounded and ignores legacy signals',
      () {
        final books = [for (var id = 100; id < 108; id++) _book(id)];
        final discovery = {
          for (var i = 0; i < 6; i++)
            pointShopTemplateKey(books[i]): StoreProductDiscovery(
              bestRank: i < 5 ? 5 - i : 1,
            ),
          pointShopTemplateKey(books[6]): const StoreProductDiscovery(
            bestRank: 6,
          ),
          pointShopTemplateKey(books[7]): const StoreProductDiscovery(
            bestRank: 0,
          ),
        };
        final result = selectStoreFeaturedTemplates(
          templates: [...books, books.first],
          selection: null,
          discovery: discovery,
        );
        expect(result.best.map((item) => item.id), [104, 105, 103, 102, 101]);
        expect(result.curated, isEmpty);
        expect(books.map((item) => item.id), [
          100,
          101,
          102,
          103,
          104,
          105,
          106,
          107,
        ]);
        expect(
          selectStoreFeaturedTemplates(
            templates: books,
            selection: null,
            discovery: const {},
          ).best,
          isEmpty,
        );
      },
    );

    test(
      'manual selection preserves configured order, deduplicates and stops at six',
      () {
        final books = [for (var id = 100; id < 108; id++) _book(id)];
        final order = [books[7], books[2], books[2], ...books.reversed];
        final selection = StoreCuration(
          placement: 'templates',
          title: '선정 목록',
          subtitle: '',
          productKeys: ['template:missing', ...order.map(pointShopTemplateKey)],
        );
        final result = selectStoreFeaturedTemplates(
          templates: books,
          selection: selection,
          discovery: const {},
        );
        expect(result.best, isEmpty);
        expect(result.curated.map((item) => item.id), [
          107,
          102,
          106,
          105,
          104,
          103,
        ]);
        expect(() => result.curated.clear(), throwsUnsupportedError);
      },
    );

    test(
      'missing, disabled and empty settings do not invent curated fallback items',
      () {
        final books = [_book(100)];
        for (final selection in [
          null,
          _curation(books, enabled: false),
          _curation(const []),
        ]) {
          final result = selectStoreFeaturedTemplates(
            templates: books,
            selection: selection,
            discovery: const {},
          );
          expect(result.best, isEmpty);
          expect(result.curated, isEmpty);
        }
      },
    );
  });

  testWidgets('topic suggestions are labelled and navigation stays neutral', (
    tester,
  ) async {
    _viewport(tester, 390);
    final books = [_book(1), _book(2), _book(3)];
    await tester.pumpWidget(
      _host(templates: books, selection: null, topic: '여행'),
    );
    await tester.pumpAndSettle();
    expect(_heading('여행 추천 디자인'), findsOneWidget);
    expect(find.text('주제에서 골라보기'), findsOneWidget);
    expect(find.text('최근 30일 포인트 소장 기준'), findsNothing);
    await _tap(tester, 'store-featured-next');
    _expectSelected(tester, books[1], others: [books.first, books.last]);
    List<Color?> backgrounds(String direction) => tester
        .widgetList<Material>(
          find.descendant(
            of: find.byKey(ValueKey('store-featured-$direction')),
            matching: find.byType(Material),
          ),
        )
        .map((material) => material.color)
        .toList();
    expect(backgrounds('next'), backgrounds('previous'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one selected design keeps its title, price, cover and open action together',
    (tester) async {
      _viewport(tester, 390);
      final books = [_book(100), _book(101, premium: true), _book(102)];
      final opened = <int>[];
      await tester.pumpWidget(
        _host(
          templates: books,
          selection: _curation([
            books[1],
            books[0],
            books[2],
          ], title: '주말에 펼치는 책'),
          onOpen: (template) => opened.add(template.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(_heading('주말에 펼치는 책'), findsOneWidget);
      expect(_heading('요즘 많이 소장한 디자인'), findsNothing);
      expect(find.text('BEST'), findsNothing);
      _expectSelected(tester, books[1], others: [books[0], books[2]]);
      _expectPrice(101, '1800P');
      expect(_position(tester), [1, 3]);
      expect(_controlEnabled(tester, 'previous'), isFalse);
      await _tap(tester, 'store-featured-open-101');
      await _tap(tester, 'store-featured-template-101');
      expect(opened, [101, 101]);
      await tester.pump(const Duration(seconds: 30));
      _expectSelected(tester, books[1], others: [books[0], books[2]]);

      await _tap(tester, 'store-featured-next');
      _expectSelected(tester, books[0], others: [books[1], books[2]]);
      _expectPrice(100, '무료');
      expect(_position(tester), [2, 3]);
      await _tap(tester, 'store-featured-open-100');
      expect(opened.last, 100);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'previous and next cover the entire configured six without wrapping',
    (tester) async {
      _viewport(tester, 390);
      final books = [for (var id = 100; id < 106; id++) _book(id)];
      await tester.pumpWidget(
        _host(templates: books, selection: _curation(books)),
      );
      await tester.pumpAndSettle();
      expect(_controlEnabled(tester, 'previous'), isFalse);
      for (var i = 0; i < books.length; i++) {
        _expectSelected(
          tester,
          books[i],
          others: books.where((book) => book.id != books[i].id),
        );
        expect(_position(tester), [i + 1, 6]);
        expect(_controlEnabled(tester, 'next'), i < books.length - 1);
        if (i < books.length - 1) await _tap(tester, 'store-featured-next');
      }
      await _tap(tester, 'store-featured-previous');
      _expectSelected(tester, books[4], others: [books.last]);
      expect(_position(tester), [5, 6]);

      final next = find.byKey(const ValueKey('store-featured-next'));
      final icon = find.descendant(of: next, matching: find.byType(Icon)).first;
      final focus = Focus.of(tester.element(icon));
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      _expectSelected(tester, books[3], others: [books[4]]);
      expect(_position(tester), [4, 6]);

      final card = find.byKey(const ValueKey('store-featured-template-103'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final swipe = await tester.startGesture(tester.getCenter(card));
      for (var step = 0; step < 6; step++) {
        await swipe.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 250));
      }
      await swipe.up();
      await tester.pumpAndSettle();
      _expectSelected(tester, books[4], others: [books[3]]);
      expect(_position(tester), [5, 6]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'verified popularity leads, editorial switching works and lost ranks cannot stay BEST',
    (tester) async {
      _viewport(tester, 390);
      final books = [_book(100), _book(101), _book(102)];
      final selection = _curation([books[2]], title: '다른 운영 추천');
      final discovery = {
        pointShopTemplateKey(books[1]): const StoreProductDiscovery(
          bestRank: 1,
        ),
      };
      await tester.pumpWidget(
        _host(templates: books, selection: selection, discovery: discovery),
      );
      await tester.pumpAndSettle();
      expect(_heading('요즘 많이 소장한 디자인'), findsOneWidget);
      _expectSelected(tester, books[1], others: [books[0], books[2]]);
      await _tap(tester, 'store-featured-mode-curated');
      expect(_heading('다른 운영 추천'), findsOneWidget);
      _expectSelected(tester, books[2], others: [books[0], books[1]]);
      await _tap(tester, 'store-featured-mode-best');
      _expectSelected(tester, books[1], others: [books[2]]);
      await tester.pumpWidget(_host(templates: books, selection: selection));
      await tester.pumpAndSettle();
      expect(_heading('요즘 많이 소장한 디자인'), findsNothing);
      expect(find.text('BEST'), findsNothing);
      expect(_heading('다른 운영 추천'), findsOneWidget);
      _expectSelected(tester, books[2], others: [books[1]]);
      expect(
        find.byKey(const ValueKey('store-featured-mode-best')),
        findsNothing,
      );
      await tester.pumpWidget(
        _host(templates: books, selection: _curation(books, enabled: false)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('store-featured-templates')),
        findsNothing,
      );
      expect(tester.getSize(find.byType(StoreFeaturedTemplateShelf)).height, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual browsing survives late popularity and each mode keeps its chosen design',
    (tester) async {
      _viewport(tester, 390);
      final books = [_book(100), _book(101), _book(102)];
      final selection = _curation(books);
      await tester.pumpWidget(_host(templates: books, selection: selection));
      await tester.pumpAndSettle();
      await _tap(tester, 'store-featured-next');
      _expectSelected(tester, books[1], others: [books[0], books[2]]);
      await tester.pumpWidget(
        _host(
          templates: books,
          selection: selection,
          discovery: {
            pointShopTemplateKey(books[0]): const StoreProductDiscovery(
              bestRank: 1,
            ),
            pointShopTemplateKey(books[2]): const StoreProductDiscovery(
              bestRank: 2,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(_heading(selection.title), findsOneWidget);
      _expectSelected(tester, books[1], others: [books[0], books[2]]);
      await _tap(tester, 'store-featured-mode-best');
      _expectSelected(tester, books[0], others: [books[1], books[2]]);
      await _tap(tester, 'store-featured-next');
      _expectSelected(tester, books[2], others: [books[0], books[1]]);
      await _tap(tester, 'store-featured-mode-curated');
      _expectSelected(tester, books[1], others: [books[0], books[2]]);
      await _tap(tester, 'store-featured-mode-best');
      _expectSelected(tester, books[2], others: [books[0], books[1]]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canonical covers and server fallbacks stay bitmap-only and reject a forged canonical identity',
    (tester) async {
      _viewport(tester, 390);
      var documentReads = 0;
      String forbiddenDocument() {
        documentReads++;
        throw StateError('Unseen document work is forbidden');
      }

      final canonical = publishedCreationTemplates.firstWhere(
        (template) =>
            catalogPreviewAssets.containsKey('template:${template.id}'),
      );
      final custom = _book(100, documentBuilder: forbiddenDocument);
      final books = [canonical, custom];
      await tester.pumpWidget(
        _host(templates: books, selection: _curation(books)),
      );
      await tester.pumpAndSettle();
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images, isNotEmpty);
      final paths = <String>[];
      for (final image in images) {
        final provider = image.image is ResizeImage
            ? (image.image as ResizeImage).imageProvider
            : image.image;
        expect(provider, isA<AssetImage>());
        paths.add((provider as AssetImage).assetName);
      }
      expect(paths, contains(catalogPreviewAssets['template:${canonical.id}']));
      expect(find.byType(CreationTemplateImage), findsNothing);
      await _tap(tester, 'store-featured-next');
      _expectSelected(tester, custom, others: [canonical]);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(CreationTemplateImage), findsOneWidget);

      final forged = _book(canonical.id, documentBuilder: forbiddenDocument);
      await tester.pumpWidget(
        _host(templates: [forged], selection: _curation([forged])),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.byType(CreationTemplateImage), findsOneWidget);
      expect(find.byType(CatalogPreviewBuilder), findsNothing);
      expect(find.byType(DocumentFontGate), findsNothing);
      expect(documentReads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'price refresh preserves the selected identity and removal returns to the first design',
    (tester) async {
      _viewport(tester, 390);
      final books = [
        for (var id = 100; id < 103; id++) _book(id, premium: true),
      ];
      final selection = _curation(books);
      final opened = <int>[];
      final livePrices = <int, int>{101: 1800};
      await tester.pumpWidget(
        _host(
          templates: books,
          selection: selection,
          prices: livePrices,
          onOpen: (book) => opened.add(book.id),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'store-featured-next');
      _expectSelected(tester, books[1], others: [books[0], books[2]]);
      _expectPrice(101, '1800P');

      livePrices[101] = 2500;
      await tester.pumpWidget(
        _host(
          templates: [...books],
          selection: selection,
          prices: livePrices,
          onOpen: (book) => opened.add(book.id),
        ),
      );
      ProviderScope.containerOf(
        tester.element(find.byType(StoreFeaturedTemplateShelf)),
      ).invalidate(pointShopCatalogProvider);
      await tester.pumpAndSettle();
      _expectSelected(tester, books[1], others: [books[0], books[2]]);
      expect(_position(tester), [2, 3]);
      _expectPrice(101, '2500P');
      await _tap(tester, 'store-featured-open-101');
      expect(opened.last, 101);

      await tester.pumpWidget(
        _host(
          templates: [books[0], books[2]],
          selection: selection,
          onOpen: (book) => opened.add(book.id),
        ),
      );
      await tester.pumpAndSettle();
      _expectSelected(tester, books.first, others: [books[1], books[2]]);
      expect(_position(tester), [1, 2]);
      await _tap(tester, 'store-featured-open-100');
      expect(opened.last, 100);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'NEW keeps its existing priority over BEST inside the popular hero',
    (tester) async {
      _viewport(tester, 390);
      final books = [_book(100)];
      final key = pointShopTemplateKey(books.single);
      await tester.pumpWidget(
        _host(
          templates: books,
          selection: null,
          discovery: {
            key: StoreProductDiscovery(
              bestRank: 1,
              firstPublishedAt: DateTime.utc(2026, 11, 3),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(_heading('요즘 많이 소장한 디자인'), findsOneWidget);
      expect(find.byKey(ValueKey('store-badge-$key-NEW')), findsOneWidget);
      expect(find.byKey(ValueKey('store-badge-$key-BEST')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (dark, keyboard) in [(false, 0.0), (true, 260.0)]) {
    testWidgets(
      'large hero grows with narrow text and remains usable dark=$dark keyboard=$keyboard',
      (tester) async {
        _viewport(tester, 320);
        final books = [_book(100, premium: true), _book(101), _book(102)];
        final discovery = {
          for (var i = 0; i < books.length; i++)
            pointShopTemplateKey(books[i]): StoreProductDiscovery(
              bestRank: i + 1,
            ),
        };
        await tester.pumpWidget(
          _host(
            templates: books,
            selection: _curation(books),
            discovery: discovery,
            dark: dark,
            scale: 2,
            keyboard: keyboard,
          ),
        );
        await tester.pumpAndSettle();
        for (final key in [
          'store-featured-mode-best',
          'store-featured-mode-curated',
        ]) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.width, greaterThanOrEqualTo(44));
          expect(size.height, greaterThanOrEqualTo(44));
        }
        await _tap(tester, 'store-featured-next');
        _expectSelected(tester, books[1], others: [books[0], books[2]]);
        final open = find.byKey(const ValueKey('store-featured-open-101'));
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        expect(open.hitTestable(), findsOneWidget);
        final size = tester.getSize(open);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

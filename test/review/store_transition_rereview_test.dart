import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/providers/design_template_catalog_provider.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/data/repositories/supabase_template_repository.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/entities/template_summary_page.dart';
import 'package:snap_fit/features/store/domain/repositories/template_repository.dart';
import 'package:snap_fit/features/store/domain/store_template_recommendations.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

class _Tokens extends TokenStorage {
  @override
  Future<String?> getResolvedUserId() async => null;
}

class _ObservedRemoteRepository extends SupabaseTemplateRepository {
  _ObservedRemoteRepository(super.client, {required super.tokenStorage});
  int started = 0;
  int completed = 0;
  @override
  Future<TemplateSummaryPage> getTemplateSummaries({
    int page = 0,
    int size = 20,
    String? category,
    String? query,
    bool? isPaid,
  }) {
    started++;
    return super
        .getTemplateSummaries(
          page: page,
          size: size,
          category: category,
          query: query,
          isPaid: isPaid,
        )
        .whenComplete(() => completed++);
  }
}

class _Repository implements TemplateRepository {
  final calls = <(int, int, String?, String?)>[];
  final pending = <Completer<TemplateSummaryPage>>[];
  bool defer = false;
  int fullLoads = 0;

  @override
  Future<TemplateSummaryPage> getTemplateSummaries({
    int page = 0,
    int size = 20,
    String? category,
    String? query,
    bool? isPaid,
  }) {
    calls.add((page, size, category, query));
    final request = Completer<TemplateSummaryPage>();
    pending.add(request);
    if (!defer) request.complete(_page(page));
    return request.future;
  }

  static TemplateSummaryPage _page(
    int page, {
    List<PremiumTemplate> content = const [],
  }) => TemplateSummaryPage(
    content: content,
    page: page,
    size: 20,
    totalPages: 1,
    totalElements: content.length,
    hasNext: false,
  );

  void complete(int index, {List<PremiumTemplate> content = const []}) {
    if (!pending[index].isCompleted)
      pending[index].complete(_page(0, content: content));
  }

  @override
  Future<List<PremiumTemplate>> getTemplates() {
    fullLoads++;
    throw StateError('Browsing must not load full documents');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class _Fixture {
  final repository = _Repository();
  int localLoads = 0;
  late final templates = [
    for (final (topic, category) in storeTemplateTopicOrder.indexed)
      for (var i = 0; i < 8; i++)
        PremiumTemplate(
          id: 80000 + topic * 8 + i,
          title: 'Look ${topic * 8 + i}',
          category: category,
          isPremium: i.isOdd,
          coverImageUrl: '',
          previewImages: const [],
          pageCount: 8,
          userCount: 0,
        ),
  ];

  Widget host({
    bool remote = false,
    bool animations = false,
    TemplateRepository? repositoryOverride,
  }) => ProviderScope(
    overrides: [
      if (!remote)
        mockTemplateList(() {
          localLoads++;
          return templates;
        }),
      templateRepositoryProvider.overrideWithValue(
        repositoryOverride ?? repository,
      ),
      tokenStorageProvider.overrideWithValue(_Tokens()),
      pointShopCatalogProvider.overrideWith(
        (_) async => [
          for (final t in remote ? publishedCreationTemplates : templates)
            PointShopProduct(
              productKey: pointShopTemplateKey(t),
              kind: 'template',
              assetId: '${t.id}',
              title: t.title,
              pointPrice: t.isPremium ? 1800 : 0,
              isActive: true,
            ),
        ],
      ),
      ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
      storeCurationsProvider.overrideWith(
        (_) async => <String, StoreCuration>{},
      ),
      pointShopRepositoryProvider.overrideWith(
        (_) => throw StateError('No live commerce'),
      ),
    ],
    child: MaterialApp(
      theme: SnapFitTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: !animations),
        child: child!,
      ),
      home: const StoreHubScreen(),
    ),
  );
}

final _store = find.byType(StoreScreen);
final _search = find.byWidgetPredicate(
  (w) => w is StoreScreen && w.searchMode,
  skipOffstage: false,
);

ScrollController _vertical(WidgetTester tester) => tester
    .widget<CustomScrollView>(
      find
          .descendant(of: _store, matching: find.byType(CustomScrollView))
          .first,
    )
    .controller!;
ScrollController _horizontal(WidgetTester tester) => tester
    .widget<SingleChildScrollView>(
      find.byKey(const ValueKey('store-topic-filters')),
    )
    .controller!;
VoidCallback _open(WidgetTester tester) => tester
    .widget<IconButton>(
      find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '스토어 검색'),
    )
    .onPressed!;

Future<void> _topic(WidgetTester tester, String value) async {
  final chip = find.byKey(ValueKey('store-topic-$value'));
  if (chip.evaluate().isEmpty) {
    _vertical(tester).jumpTo(0);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byTooltip('뒤로가기'));
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

Future<void> _native(WidgetTester tester, bool Function() done) async {
  for (var attempt = 0; attempt < 100 && !done(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'Native HTTP JSON decoding did not finish');
}

void main() {
  test(
    'review: current cover title matches editor layers and all printable store variants',
    () {
      final collection = authoredCollections.singleWhere(
        (c) => c.id == 'our-walking-promise',
      );
      final store = publishedCreationTemplateById(collection.bundledId)!;
      final editor = publishedDesignTemplates.singleWhere(
        (t) => t.id == collection.id,
      );
      final document = jsonDecode(store.templateJson!) as Map<String, dynamic>;
      expect(store.title, collection.catalogTitle);
      expect(editor.name, store.title);
      expect(
        collection.title,
        '산책이라는 약속',
        reason: 'Original authored metadata must not be rewritten',
      );
      for (final aspect in CollectionAspect.printable) {
        final variant = (document['variants'] as Map)[aspect.name] as Map;
        expect(variant['title'], store.title);
        final text = editor
            .buildLayers(aspect.canvas)
            .map((l) => l.text ?? '')
            .join(' ')
            .replaceAll(RegExp(r'\s+'), '');
        expect(text, contains('너랑걷는오후'), reason: aspect.name);
        expect(text, isNot(contains('산책이라는약속')), reason: aspect.name);
      }
    },
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets(
    'review: every browse scope retains rows and vertical position across search visits',
    (tester) async {
      final fixture = _Fixture();
      await _show(tester, fixture.host());
      final parent = ProviderScope.containerOf(tester.element(_store));
      final rootState = tester.state(_store);
      final vertical = _vertical(tester);
      for (final category in ['추천', '전체', '여행', '동아리', '전체']) {
        await _topic(tester, category);
        vertical.jumpTo(
          (vertical.offset + 80).clamp(0, vertical.position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
        final offset = vertical.offset;
        final rows = parent.read(storeTemplateFeedProvider).items;
        _open(tester)();
        await tester.pumpAndSettle();
        final scoped = ProviderScope.containerOf(tester.element(_store));
        final searchScroll = _vertical(tester);
        await tester.enterText(find.byType(TextField), 'Look 0');
        await tester.pumpAndSettle();
        await _close(tester);
        expect(tester.state(_store), same(rootState));
        expect(parent.read(storeTemplateFeedProvider).items, same(rows));
        expect(
          parent.read(storeTemplateFeedProvider).filterCategory,
          ['전체', '추천'].contains(category) ? '' : category,
        );
        expect(vertical.offset, closeTo(offset, .5));
        expect(searchScroll.hasClients, isFalse);
        expect(() => scoped.read(storeTemplateFeedProvider), throwsStateError);
      }
      expect(fixture.localLoads, 1);
      expect(fixture.repository.fullLoads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(vertical.hasClients, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review: manually browsed category strip must keep its offset after search',
    (tester) async {
      final fixture = _Fixture();
      await _show(tester, fixture.host());
      await tester.ensureVisible(
        find.byKey(const ValueKey('store-topic-filters')),
      );
      await tester.pumpAndSettle();
      final vertical = _vertical(tester);
      final horizontal = _horizontal(tester);
      horizontal.jumpTo(horizontal.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final before = horizontal.offset;
      final verticalBefore = vertical.offset;
      expect(before, greaterThan(0));
      _open(tester)();
      await tester.pumpAndSettle();
      await _close(tester);
      final after = horizontal.offset;
      expect(vertical.offset, closeTo(verticalBefore, .5));
      debugPrint('review category strip before=$before after=$after');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(horizontal.hasClients, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      expect(
        after,
        closeTo(before, .5),
        reason: 'Opening search must not discard manual horizontal browsing',
      );
    },
  );

  testWidgets(
    'review: pending identical HTTP reads must be shared across search scopes',
    (tester) async {
      final fixture = _Fixture();
      final requests = <http.Request>[];
      final pending = <Completer<http.Response>>[];
      final client = SupabaseClient(
        'https://fixture.invalid',
        'public-test-key',
        httpClient: MockClient((request) {
          requests.add(request);
          final response = Completer<http.Response>();
          pending.add(response);
          return response.future;
        }),
      );
      var clientDisposed = false;
      Future<void> disposeClient() async {
        if (clientDisposed) return;
        clientDisposed = true;
        var done = false;
        client.dispose().then((_) => done = true);
        await _native(tester, () => done);
      }

      addTearDown(disposeClient);
      final repository = _ObservedRemoteRepository(
        client,
        tokenStorage: _Tokens(),
      );
      await _show(
        tester,
        fixture.host(remote: true, repositoryOverride: repository),
      );
      final parent = ProviderScope.containerOf(tester.element(_store));
      expect(requests, hasLength(1));
      for (var visit = 0; visit < 3; visit++) {
        _open(tester)();
        await tester.pumpAndSettle();
        await _close(tester);
      }
      final calls = requests
          .map((request) => (request.method, request.url.toString()))
          .toList();
      final concurrent = pending.where((c) => !c.isCompleted).length;
      void complete(int index, List<Map<String, Object>> rows) =>
          pending[index].complete(
            http.Response(
              jsonEncode(rows),
              200,
              request: requests[index],
              headers: {'content-type': 'application/json'},
            ),
          );
      complete(0, []);
      await _native(
        tester,
        () =>
            repository.completed >= 1 &&
            !parent.read(storeTemplateFeedProvider).isInitialLoading,
      );
      final rows = parent.read(storeTemplateFeedProvider).items;
      for (var i = 1; i < pending.length; i++) {
        complete(i, [
          {
            'id': 990000 + i,
            'title': 'Late closed scope $i',
            'cover_image_url': '',
            'preview_images': <String>[],
            'page_count': 1,
            'user_count': 0,
          },
        ]);
      }
      await _native(tester, () => repository.completed == repository.started);
      expect(repository.started, 4);
      expect(repository.completed, 4);
      expect(parent.read(storeTemplateFeedProvider).items, same(rows));
      expect(calls.toSet(), hasLength(1));
      expect(
        requests.every(
          (r) => r.method == 'GET' && r.url.queryParameters['limit'] == '20',
        ),
        isTrue,
      );
      debugPrint(
        'review identical HTTP requests=${calls.length} concurrent=$concurrent; late closed responses ignored',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
      await disposeClient();
      expect(
        calls,
        hasLength(1),
        reason:
            'The parent request is still in flight with the identical scope',
      );
    },
  );

  testWidgets(
    'review: animated rapid search open close releases scopes and preserves the parent',
    (tester) async {
      final fixture = _Fixture();
      await _show(tester, fixture.host(animations: true));
      final parent = ProviderScope.containerOf(tester.element(_store));
      final rows = parent.read(storeTemplateFeedProvider).items;
      final rootState = tester.state(_store);
      final open = _open(tester);
      final scopes = <ProviderContainer>[];
      for (var visit = 0; visit < 6; visit++) {
        open();
        open();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));
        expect(_search, findsOneWidget);
        final element = tester.element(_search);
        scopes.add(ProviderScope.containerOf(element));
        Navigator.of(element).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));
      }
      await tester.pumpAndSettle();
      expect(_search, findsNothing);
      expect(tester.state(_store), same(rootState));
      expect(parent.read(storeTemplateFeedProvider).items, same(rows));
      for (final scoped in scopes) {
        expect(() => scoped.read(storeTemplateFeedProvider), throwsStateError);
      }
      expect(fixture.localLoads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

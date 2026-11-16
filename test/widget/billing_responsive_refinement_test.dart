import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/profile/presentation/views/billing_management_screen.dart';
import '../support/point_ledger_history_fakes.dart';
import '../support/point_purchase_fakes.dart';

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

final _products = [
  product,
  ProductDetails(
    id: 'snapfit_points_8000',
    title: '8,000P',
    description: '',
    price: '₩5,900',
    rawPrice: 5900,
    currencyCode: 'KRW',
  ),
  ProductDetails(
    id: 'snapfit_points_18000',
    title: '18,000P',
    description: '',
    price: '₩11,900',
    rawPrice: 11900,
    currencyCode: 'KRW',
  ),
];
final _entries = [
  PointLedgerEntry(
    id: 5,
    createdAt: DateTime.utc(2026, 10, 14, 6),
    amountDelta: -450,
    reason: 'DIGITAL_ITEM_PURCHASE',
  ),
  PointLedgerEntry(
    id: 4,
    createdAt: DateTime.utc(2026, 10, 14, 5),
    amountDelta: 2500,
    reason: 'POINT_PURCHASE',
  ),
  PointLedgerEntry(
    id: 3,
    createdAt: DateTime.utc(2026, 10, 13, 6),
    amountDelta: -700,
    reason: 'AI_ALBUM_DRAFT_CHARGE',
  ),
  PointLedgerEntry(
    id: 2,
    createdAt: DateTime.utc(2026, 10, 12, 6),
    amountDelta: -2500,
    reason: 'POINT_PURCHASE_REFUND',
  ),
  PointLedgerEntry(
    id: 1,
    createdAt: DateTime.utc(2026, 10, 11, 6),
    amountDelta: 0,
    reason: 'AI_ALBUM_DRAFT_FREE',
  ),
];

class _Store extends FakeStore {
  List<ProductDetails> catalog = List.of(_products);
  bool available = true;
  bool failQuery = false;
  Completer<ProductDetailsResponse>? pending;
  int queries = 0;
  int buys = 0;
  ProductDetails? bought;

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) async {
    queries++;
    requestedIds = ids;
    if (failQuery) throw StateError('fixture_product_query_failed');
    if (pending != null) return pending!.future;
    return ProductDetailsResponse(productDetails: catalog, notFoundIDs: []);
  }

  @override
  Future<bool> buy(ProductDetails product, String accountId) async {
    buys++;
    bought = product;
    return super.buy(product, accountId);
  }
}

void main() {
  _PaintBinding();
  final captureKey = GlobalKey();
  late _Store store;
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  setUp(() {
    store = _Store();
    addTearDown(store.controller.close);
  });

  void metrics(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = size.width > size.height
        ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
        : const FakeViewPadding(top: 24, bottom: 34);
  }

  void resetMetrics(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
  }

  Future<void> mount(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1.3,
    bool ai = false,
    int initialPointsTabIndex = 0,
    PointPurchaseService? purchases,
    Future<int> Function()? balance,
    Future<List<PointLedgerEntry>> Function()? ledger,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pointPurchaseServiceProvider.overrideWith((ref) {
            final service = purchases ?? fakePointPurchaseService(store: store);
            ref.onDispose(service.dispose);
            return service;
          }),
          myPointBalanceProvider.overrideWith(
            (_) => balance?.call() ?? Future.value(12450),
          ),
          pointLedgerHistoryProvider.overrideWith2(
            (filter) => FixturePointLedgerHistoryController(
              filter,
              () => ledger?.call() ?? Future.value(_entries),
            ),
          ),
        ],
        child: MaterialApp(
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: captureKey, child: child!),
          ),
          home: BillingManagementScreen(
            returnToAiDraftFlow: ai,
            initialPointsTabIndex: initialPointsTabIndex,
          ),
        ),
      ),
    );
    if (store.pending == null)
      await tester.pumpAndSettle();
    else
      await tester.pump(const Duration(milliseconds: 100));
  }

  Finder activeScroll() => find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  Future<void> visible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      tester.state<ScrollableState>(activeScroll()).position.jumpTo(0);
      await tester.pumpAndSettle();
    }
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 100, scrollable: activeScroll());
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await visible(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> history(WidgetTester tester) => tap(tester, find.text('이용 내역'));
  Finder action() => find.byKey(const ValueKey('points-charge-action'));
  Finder option(String sku) => find.byKey(ValueKey('points-product-$sku'));

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark,
  ) async {
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('POINTS_RESPONSIVE_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('output/all-screens-qa')
        ..createSync(recursive: true);
      File(
        '${dir.path}/$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'delayed native payment keeps charge disabled and exposes recovery',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await tap(tester, option(sku));
      await tap(tester, action());
      expect(store.buys, 1);
      await tester.pump(const Duration(minutes: 2, seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      expect(find.text('결제 확인이 지연되고 있어요'), findsOneWidget);
      expect(find.byKey(const ValueKey('points-payment-help')), findsOneWidget);
      final recover = find.byKey(const ValueKey('points-purchase-recover'));
      expect(tester.widget<TextButton>(recover).onPressed, isNotNull);
      await tap(tester, recover);
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      expect(store.buys, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed refreshed catalog disables charging and stale callbacks',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await tap(tester, option(sku));
      final oldCharge = tester.widget<FilledButton>(action()).onPressed!;
      store.failQuery = true;
      await tester.tap(find.byTooltip('포인트 새로고침'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      expect(find.text('충전 상품 확인 필요'), findsWidgets);
      oldCharge();
      await tester.pumpAndSettle();
      expect(store.buys, 0);
      final retry = find.byKey(const ValueKey('points-catalog-retry'));
      store.failQuery = false;
      await tap(tester, retry);
      expect(tester.widget<FilledButton>(action()).onPressed, isNotNull);
      expect(
        find.byKey(const ValueKey('points-purchase-status')),
        findsNothing,
      );
      expect(store.buys, 0);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'points selection and history render safely at $size dark=$dark',
        (tester) async {
          resetMetrics(tester);
          metrics(tester, size);
          await mount(tester, dark: dark);
          await capture(tester, 'points-charge', size, dark);
          expect(find.byKey(const ValueKey('attendance-entry')), findsNothing);
          expect(find.byKey(const ValueKey('referral-entry')), findsNothing);
          expect(tester.widget<FilledButton>(action()).onPressed, isNull);
          await tap(tester, option(sku));
          expect(store.buys, 0);
          expect(tester.widget<FilledButton>(action()).onPressed, isNotNull);
          expect(find.text('₩2,200 · 2,500 P 충전하기'), findsOneWidget);
          expect(
            tester.getBottomRight(action()).dy,
            lessThanOrEqualTo(
              size.height - (size.width > size.height ? 24 : 34),
            ),
          );
          await capture(tester, 'points-charge-selected', size, dark);
          await history(tester);
          expect(action(), findsNothing);
          await capture(tester, 'points-history', size, dark);
          await tap(tester, find.text('차감'));
          expect(find.byKey(const ValueKey('points-ledger-4')), findsNothing);
          expect(find.byKey(const ValueKey('points-ledger-1')), findsNothing);
          await capture(tester, 'points-history-spent', size, dark);
          await tester.pumpWidget(const SizedBox());
          await mount(tester, dark: dark, ai: true);
          final back = find.byKey(const ValueKey('points-ai-return-action'));
          await visible(tester, back);
          expect(tester.widget<OutlinedButton>(back).onPressed, isNotNull);
          await capture(tester, 'points-ai-return', size, dark);
          expect(store.buys, 0);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'checkout separates point amount from store price before payment',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await tap(tester, option(sku));
      expect(find.text('충전 포인트'), findsOneWidget);
      expect(find.text('₩2,200 · 2,500 P 충전하기'), findsOneWidget);
      expect(tester.widget<FilledButton>(action()).onPressed, isNotNull);
      expect(find.text('2,500 P'), findsWidgets);
      expect(find.text('₩2,200'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('₩2,200')).semanticsLabel,
        '결제 금액 ₩2,200',
      );
      expect(store.buys, 0);
      await capture(
        tester,
        'points-checkout-summary',
        const Size(390, 844),
        false,
      );
    },
  );

  for (final dark in [false, true]) {
    testWidgets('points redesign at regular text size dark=$dark', (
      tester,
    ) async {
      const size = Size(390, 844);
      resetMetrics(tester);
      metrics(tester, size);
      await mount(tester, dark: dark, scale: 1);
      expect(find.text('12,450 P'), findsWidgets);
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      await capture(tester, 'points-redesign', size, dark);
      await tap(tester, option(sku));
      expect(find.text('₩2,200 · 2,500 P 충전하기'), findsOneWidget);
      expect(store.buys, 0);
      await capture(tester, 'points-redesign-selected', size, dark);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'verification waiting and failure never announce a successful grant',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      final verified = Completer<StorePointPurchaseResult>();
      var started = false;
      final purchases = PointPurchaseService(
        store: store,
        storage: MemoryReceipts(),
        currentUserId: () => 'owner',
        ensureServerAvailable: () async {},
        verify: (_) {
          started = true;
          return verified.future;
        },
        onBalanceChanged: () {},
      );
      await mount(tester, purchases: purchases);
      await tap(tester, option(sku));
      await tester.tap(action());
      await tester.pumpAndSettle();
      store.controller.add([purchase(nativeOwner: 'owner')]);
      for (var i = 0; i < 20 && !started; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(started, true);
      expect(purchases.busy, true);
      await visible(
        tester,
        find.byKey(const ValueKey('points-purchase-status')),
      );
      expect(find.text('결제·지급 확인 중'), findsWidgets);
      expect(find.textContaining('지급 완료'), findsNothing);
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(BillingManagementScreen)),
        ).read(myPointBalanceProvider).requireValue,
        12450,
      );
      await capture(
        tester,
        'points-verification-waiting',
        const Size(390, 844),
        false,
      );
      verified.completeError(StateError('fixture verification unavailable'));
      await tester.pumpAndSettle();
      expect(purchases.message, isNotNull);
      expect(find.text('결제 확인이 지연되고 있어요'), findsOneWidget);
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      // 예상 잔액 카드 아래의 복구 액션은 스크롤로 접근한다.
      await visible(
        tester,
        find.byKey(const ValueKey('points-purchase-recover')),
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('points-purchase-recover')),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.textContaining('지급 완료'), findsNothing);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(BillingManagementScreen)),
        ).read(myPointBalanceProvider).requireValue,
        12450,
      );
      await capture(
        tester,
        'points-verification-retry',
        const Size(390, 844),
        false,
      );
      expect(store.buys, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'My point history shortcut starts in history and can return to charge',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester, initialPointsTabIndex: 1);
      expect(find.byKey(const ValueKey('points-ledger-5')), findsOneWidget);
      expect(action(), findsNothing);
      expect(find.byKey(const ValueKey('attendance-entry')), findsNothing);
      expect(find.byKey(const ValueKey('referral-entry')), findsNothing);
      await tap(tester, find.text('충전'));
      expect(action(), findsOneWidget);
      expect(store.buys, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selection and history filter survive rotations without starting a purchase',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await tap(tester, option('snapfit_points_8000'));
      metrics(tester, const Size(648, 320));
      await tester.pumpAndSettle();
      expect(find.text('₩5,900 · 8,000 P 충전하기'), findsOneWidget);
      await history(tester);
      await tap(tester, find.text('차감'));
      metrics(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(action(), findsNothing);
      expect(find.byKey(const ValueKey('points-ledger-4')), findsNothing);
      await tap(tester, find.text('충전'));
      expect(find.text('₩5,900 · 8,000 P 충전하기'), findsOneWidget);
      expect(store.buys, 0);
      expect(store.queries, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only explicit charge starts one purchase and busy remains locked after rotation',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(844, 390));
      await mount(tester, ai: true);
      await tap(tester, option(sku));
      expect(store.buys, 0);
      await tester.tap(action());
      await tester.pumpAndSettle();
      expect(store.buys, 1);
      expect(store.bought, same(product));
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      await visible(
        tester,
        find.byKey(const ValueKey('points-purchase-recover')),
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('points-purchase-recover')),
            )
            .onPressed,
        isNull,
      );
      metrics(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      await tester.tap(action());
      await tester.pumpAndSettle();
      expect(store.buys, 1);
      final back = find.byKey(const ValueKey('points-ai-return-action'));
      await visible(tester, back);
      expect(tester.widget<OutlinedButton>(back).onPressed, isNull);
      expect(find.text('12,450 P'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets(
      'points controls respect large text and system insets at $size',
      (tester) async {
        resetMetrics(tester);
        metrics(tester, size);
        await mount(tester, dark: true, scale: 1.8, ai: true);
        await tap(tester, option('snapfit_points_18000'));
        expect(
          tester.getBottomRight(action()).dy,
          lessThanOrEqualTo(size.height - (size.width > size.height ? 24 : 34)),
        );
        await history(tester);
        await tap(tester, find.text('적립'));
        expect(find.byKey(const ValueKey('points-ledger-5')), findsNothing);
        await visible(tester, find.byKey(const ValueKey('points-ledger-4')));
        expect(find.text('+2500P'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(store.buys, 0);
      },
    );
  }

  testWidgets(
    'catalog refresh uses the latest price and cannot charge a removed product',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await tap(tester, option(sku));
      final updated = ProductDetails(
        id: sku,
        title: '2,500P',
        description: '',
        price: '₩2,500',
        rawPrice: 2500,
        currencyCode: 'KRW',
      );
      store.catalog = [updated];
      await tester.tap(find.byTooltip('포인트 새로고침'));
      await tester.pumpAndSettle();
      expect(find.text('₩2,500 · 2,500 P 충전하기'), findsOneWidget);
      store.catalog = [];
      await tester.tap(find.byTooltip('포인트 새로고침'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      expect(store.buys, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('history scroll stays lazy and preserves the provider order', (
    tester,
  ) async {
    resetMetrics(tester);
    metrics(tester, const Size(390, 844));
    final entries = List.generate(
      80,
      (index) => PointLedgerEntry(
        id: 1000 - index,
        createdAt: DateTime.utc(
          2026,
          10,
          14,
        ).subtract(Duration(minutes: index)),
        amountDelta: -index,
        reason: 'DIGITAL_ITEM_PURCHASE',
      ),
    );
    await mount(tester, ledger: () async => entries);
    await history(tester);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('points-ledger-1000'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('points-ledger-999'))).dy,
      ),
    );
    expect(find.byKey(const ValueKey('points-ledger-921')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('points-ledger-950')),
      250,
      scrollable: activeScroll(),
    );
    expect(find.byKey(const ValueKey('points-ledger-950')), findsOneWidget);
    expect(find.byKey(const ValueKey('points-ledger-921')), findsNothing);
    expect(store.buys, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading and query failures never enable charging and both balances can retry',
    (tester) async {
      resetMetrics(tester);
      const size = Size(844, 390);
      metrics(tester, size);
      store.pending = Completer<ProductDetailsResponse>();
      final balance = Completer<int>();
      var balanceRequests = 0;
      await mount(
        tester,
        dark: true,
        balance: () =>
            balanceRequests++ == 0 ? balance.future : Future.value(-600),
      );
      await capture(tester, 'points-loading', size, true);
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      store.pending!.complete(
        ProductDetailsResponse(productDetails: [], notFoundIDs: []),
      );
      balance.completeError(StateError('fixture_balance_failed'));
      await tester.pumpAndSettle();
      await capture(tester, 'points-error', size, true);
      expect(find.text('잔액 다시 확인'), findsOneWidget);
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      expect(store.buys, 0);
      await tap(tester, find.text('잔액 다시 확인'));
      expect(find.text('-600 P'), findsOneWidget);
      expect(find.textContaining('먼저 정산돼요'), findsOneWidget);
      await capture(tester, 'points-negative-balance', size, true);
      await tester.pumpWidget(const SizedBox());
      store.pending = null;
      var fail = true;
      await mount(
        tester,
        ledger: () async {
          if (fail) throw StateError('fixture_ledger_failed');
          return _entries;
        },
      );
      await history(tester);
      expect(find.text('이용 내역 다시 확인'), findsOneWidget);
      fail = false;
      await tap(tester, find.text('이용 내역 다시 확인'));
      expect(find.text('이용 내역 다시 확인'), findsNothing);
      expect(find.text('-450P'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'queued charge cannot bypass catalog refresh, disappearance or store unavailability',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await tap(tester, option(sku));
      final oldCharge = tester.widget<FilledButton>(action()).onPressed!;
      store.pending = Completer<ProductDetailsResponse>();
      await tester.tap(find.byTooltip('포인트 새로고침'));
      await tester.pump(const Duration(milliseconds: 100));
      oldCharge();
      expect(store.buys, 0);
      store.pending!.complete(
        ProductDetailsResponse(productDetails: [], notFoundIDs: []),
      );
      await tester.pumpAndSettle();
      oldCharge();
      expect(store.buys, 0);
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      store.pending = null;
      store.catalog = List.of(_products);
      await tester.tap(find.byTooltip('포인트 새로고침'));
      await tester.pumpAndSettle();
      store.available = false;
      await tester.tap(find.byTooltip('포인트 새로고침'));
      await tester.pumpAndSettle();
      oldCharge();
      expect(store.buys, 0);
      expect(tester.widget<FilledButton>(action()).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'explicit charge reads the refreshed native product rather than the old price object',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await tap(tester, option(sku));
      final oldCharge = tester.widget<FilledButton>(action()).onPressed!;
      final updated = ProductDetails(
        id: sku,
        title: '2,500P',
        description: '',
        price: '₩2,500',
        rawPrice: 2500,
        currencyCode: 'KRW',
      );
      store.catalog = [updated];
      await tester.tap(find.byTooltip('포인트 새로고침'));
      await tester.pumpAndSettle();
      oldCharge();
      await tester.pumpAndSettle();
      expect(store.bought, same(updated));
      expect(store.buys, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('empty history and empty filters do not fabricate transactions', (
    tester,
  ) async {
    resetMetrics(tester);
    metrics(tester, const Size(648, 320));
    await mount(tester, ledger: () async => []);
    await history(tester);
    expect(find.text('아직 포인트 내역이 없어요.'), findsOneWidget);
    await tap(tester, find.text('적립'));
    expect(find.text('해당 포인트 내역이 없어요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('points-ledger-4')), findsNothing);
    expect(store.buys, 0);
    expect(tester.takeException(), isNull);
  });
}

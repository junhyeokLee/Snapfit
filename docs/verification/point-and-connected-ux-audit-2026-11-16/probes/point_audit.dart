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

import 'file:///Users/devsheep/SnapFit/SnapFit/test/support/point_ledger_history_fakes.dart';
import 'file:///Users/devsheep/SnapFit/SnapFit/test/support/point_purchase_fakes.dart';

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
    contextTitle: '여행의 결',
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
    contextTitle: '우리가 함께한 가을',
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
    double scale = 1,
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
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
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
    void repaint(RenderObject object) {
      object.visitChildren(repaint);
      if (object.attached) {
        object.markNeedsLayout();
        object.markNeedsCompositingBitsUpdate();
        object.markNeedsPaint();
      }
    }

    for (final view in tester.binding.renderViews) {
      repaint(view);
    }
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.takeException(), isNull, reason: name);
    await tester.runAsync(() async {
      final image =
          await (captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory(Platform.environment['NEXT_AUDIT_DIR']!)
        ..createSync(recursive: true);
      File(
        '${dir.path}/$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> top(WidgetTester tester) async {
    tester.state<ScrollableState>(activeScroll()).position.jumpTo(0);
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  const phone = Size(390, 844);

  testWidgets('audit points 01 ordinary charge entry', (tester) async {
    resetMetrics(tester);
    metrics(tester, phone);
    await mount(tester);
    expect(tester.widget<FilledButton>(action()).onPressed, isNull);
    await capture(tester, '01-point-charge-entry', phone, false);
    await finish(tester);
  });

  testWidgets('audit points 02 selected pack and lower guidance', (
    tester,
  ) async {
    resetMetrics(tester);
    metrics(tester, phone);
    await mount(tester);
    await tap(tester, option(sku));
    expect(store.buys, 0);
    expect(tester.widget<FilledButton>(action()).onPressed, isNotNull);
    await top(tester);
    await capture(tester, '02-point-pack-selected', phone, false);
    await visible(tester, find.text('포인트가 반영되지 않았다면 구매 복원으로 확인하세요.'));
    await capture(tester, '03-point-charge-lower-guidance', phone, false);
    await finish(tester);
  });

  testWidgets('audit points 03 ledger purpose and refund row', (tester) async {
    resetMetrics(tester);
    metrics(tester, phone);
    await mount(tester, initialPointsTabIndex: 1);
    await capture(tester, '04-point-ledger-overview', phone, false);
    await visible(tester, find.byKey(const ValueKey('points-ledger-2')));
    await capture(tester, '05-point-ledger-refund', phone, false);
    await finish(tester);
  });

  testWidgets(
    'audit points 04 negative balance before and after selecting a pack',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, phone);
      await mount(tester, balance: () async => -2500);
      await tap(tester, option(sku));
      expect(store.buys, 0);
      await top(tester);
      await capture(tester, '06-point-negative-balance-selected', phone, false);
      await visible(tester, find.text('포인트가 반영되지 않았다면 구매 복원으로 확인하세요.'));
      await capture(tester, '07-point-negative-charge-action', phone, false);
      await finish(tester);
    },
  );

  testWidgets('audit points 05 real fake-store verified successful charge', (
    tester,
  ) async {
    resetMetrics(tester);
    metrics(tester, phone);
    var balance = 12450;
    ProviderContainer? container;
    final purchases = PointPurchaseService(
      store: store,
      storage: MemoryReceipts(),
      currentUserId: () => 'owner',
      ensureServerAvailable: () async {},
      verify: (record) async {
        balance = 14950;
        return StorePointPurchaseResult(
          productId: record.productId,
          grantedPoints: 2500,
          remainingBalance: balance,
        );
      },
      onBalanceChanged: () => container?.invalidate(myPointBalanceProvider),
    );
    await mount(tester, purchases: purchases, balance: () async => balance);
    container = ProviderScope.containerOf(
      tester.element(find.byType(BillingManagementScreen)),
      listen: false,
    );
    await tap(tester, option(sku));
    await tap(tester, action());
    expect(store.buys, 1);
    store.controller.add([purchase(nativeOwner: 'owner')]);
    await tester.pumpAndSettle();
    expect(purchases.message, contains('충전되었습니다'));
    expect(purchases.busy, isFalse);
    expect(purchases.canStartPurchase, isTrue);
    expect(tester.widget<FilledButton>(action()).onPressed, isNotNull);
    await top(tester);
    await capture(tester, '08-point-charge-success-balance', phone, false);
    await visible(tester, find.byKey(const ValueKey('points-purchase-status')));
    await capture(tester, '09-point-charge-success-status', phone, false);
    await finish(tester);
  });

  testWidgets('audit points 06 native balance fetch failure and retry', (
    tester,
  ) async {
    resetMetrics(tester);
    metrics(tester, phone);
    await mount(
      tester,
      balance: () async => throw StateError('fixture_balance_unavailable'),
    );
    expect(find.text('확인 실패'), findsOneWidget);
    expect(find.text('잔액 다시 확인'), findsOneWidget);
    await capture(tester, '10-point-native-balance-error', phone, false);
    await finish(tester);
  });

  testWidgets('audit points 07 small dark charge selected at large text', (
    tester,
  ) async {
    const size = Size(320, 568);
    resetMetrics(tester);
    metrics(tester, size);
    await mount(tester, dark: true, scale: 1.8);
    await tap(tester, option(sku));
    await top(tester);
    await capture(tester, '11-point-small-dark-selected', size, true);
    await finish(tester);
  });

  testWidgets('audit points 08 small dark ledger with purpose names', (
    tester,
  ) async {
    const size = Size(320, 568);
    resetMetrics(tester);
    metrics(tester, size);
    await mount(tester, dark: true, scale: 1.8, initialPointsTabIndex: 1);
    await visible(tester, find.byKey(const ValueKey('points-ledger-3')));
    await capture(tester, '12-point-small-dark-ledger', size, true);
    await finish(tester);
  });
}

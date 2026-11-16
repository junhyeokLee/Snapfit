// 검증용 계정과 FakeStore를 사용해 현재 위젯을 그대로 캡처한다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/billing/domain/point_top_up_context.dart';
import 'package:snap_fit/features/profile/presentation/views/billing_management_screen.dart';

import 'file:///Users/devsheep/SnapFit/SnapFit/test/support/point_ledger_history_fakes.dart';
import 'file:///Users/devsheep/SnapFit/SnapFit/test/support/point_purchase_fakes.dart';
import 'file:///tmp/snapfit-point-improvements-20261116/audit_support.dart';

const _purpose = PointTopUpContext(
  ownerId: 'owner',
  productKey: 'sticker:studioCottonRag',
  title: '수제지 조각',
  requiredPoints: 100,
);

final _entries = [
  PointLedgerEntry.fromJson({
    'id': 5,
    'created_at': '2026-11-16T08:30:00Z',
    'amount_delta': -100,
    'reason': 'DIGITAL_ITEM_PURCHASE',
    'metadata': {'title': '수제지 조각'},
  }),
  PointLedgerEntry.fromJson({
    'id': 4,
    'created_at': '2026-11-16T08:00:00Z',
    'amount_delta': 2500,
    'reason': 'POINT_PURCHASE',
  }),
  PointLedgerEntry.fromJson({
    'id': 3,
    'created_at': '2026-11-15T08:00:00Z',
    'amount_delta': -700,
    'reason': 'AI_ALBUM_DRAFT_CHARGE',
    'metadata': {'title': '우리가 함께한 가을'},
  }),
  PointLedgerEntry.fromJson({
    'id': 2,
    'created_at': '2026-11-14T08:00:00Z',
    'amount_delta': -2500,
    'reason': 'POINT_PURCHASE_REFUND',
  }),
];

class _Store extends FakeStore {
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) async {
    requestedIds = ids;
    return ProductDetailsResponse(
      productDetails: [
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
      ],
      notFoundIDs: [],
    );
  }
}

class _WalletFixture {
  _WalletFixture({this.balance = 12450});
  int balance;
  final store = _Store();
  ProviderContainer? container;
  late final service = PointPurchaseService(
    store: store,
    storage: MemoryReceipts(),
    currentUserId: () => 'owner',
    ensureServerAvailable: () async {},
    verify: (record) async {
      balance += 2500;
      return StorePointPurchaseResult(
        productId: record.productId,
        grantedPoints: 2500,
        remainingBalance: balance,
      );
    },
    onBalanceChanged: () => container?.invalidate(myPointBalanceProvider),
  );
}

Future<void> _mount(
  WidgetTester tester,
  _WalletFixture fixture, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
  PointTopUpContext? purpose,
  bool push = false,
  int initialTab = 0,
}) async {
  auditViewport(tester, size: size);
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 34);
  addTearDown(tester.view.resetPadding);
  addTearDown(fixture.store.controller.close);
  Widget screen() => BillingManagementScreen(
    purchaseContext: purpose,
    initialPointsTabIndex: initialTab,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pointPurchaseServiceProvider.overrideWith((ref) {
          ref.onDispose(fixture.service.dispose);
          return fixture.service;
        }),
        myPointBalanceProvider.overrideWith((_) async => fixture.balance),
        pointLedgerHistoryProvider.overrideWith2(
          (filter) =>
              FixturePointLedgerHistoryController(filter, () async => _entries),
        ),
      ],
      child: MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: auditFrame(child!),
        ),
        home: push
            ? Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      key: const ValueKey('capture-open-wallet'),
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (_) => screen()),
                      ),
                      child: const Text('상품에서 포인트 충전하기'),
                    ),
                  ),
                ),
              )
            : screen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (push) {
    await tester.tap(find.byKey(const ValueKey('capture-open-wallet')));
    await tester.pumpAndSettle();
  }
  fixture.container = ProviderScope.containerOf(
    tester.element(find.byType(BillingManagementScreen)),
    listen: false,
  );
}

Finder _scroll() => find
    .descendant(
      of: find.byType(CustomScrollView).first,
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _show(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 100, scrollable: _scroll());
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _top(WidgetTester tester) async {
  tester.state<ScrollableState>(_scroll()).position.jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester) async {
  final option = find.byKey(
    const ValueKey('points-product-snapfit_points_2500'),
  );
  await _show(tester, option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

Future<void> _verifiedPurchase(
  WidgetTester tester,
  _WalletFixture fixture,
  String token,
) async {
  await _select(tester);
  final pay = find.byKey(const ValueKey('points-charge-action'));
  await tester.tap(pay);
  expect(fixture.store.buyCalls, 1);
  fixture.store.controller.add([purchase(token: token, nativeOwner: 'owner')]);
  await tester.pumpAndSettle();
  expect(fixture.service.busy, isFalse);
  expect(fixture.store.finished, isNotEmpty);
  expect(find.byKey(const ValueKey('points-charge-action')), findsNothing);
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(auditFonts);

  testWidgets('capture improved points 01 purchase purpose and shortfall', (
    tester,
  ) async {
    final fixture = _WalletFixture(balance: 20);
    await _mount(tester, fixture, purpose: _purpose, push: true);
    expect(
      find.byKey(const ValueKey('points-purchase-context')),
      findsOneWidget,
    );
    expect(find.text('80 P 더 필요해요.'), findsOneWidget);
    await auditCapture(tester, '01-point-purpose-shortfall-390-light');
    await _finish(tester);
  });

  testWidgets('capture improved points 02 selected pack projected balance', (
    tester,
  ) async {
    final fixture = _WalletFixture(balance: 20);
    await _mount(tester, fixture, purpose: _purpose, push: true);
    await _select(tester);
    final projected = find.byKey(const ValueKey('points-expected-balance'));
    await _show(tester, projected);
    expect(
      find.descendant(of: projected, matching: find.text('2,520 P')),
      findsOneWidget,
    );
    await auditCapture(tester, '02-point-projected-balance-390-light');
    await _finish(tester);
  });

  testWidgets(
    'capture improved points 03 negative settlement and usable projected balance',
    (tester) async {
      final fixture = _WalletFixture(balance: -2500);
      await _mount(tester, fixture);
      await _select(tester);
      await _top(tester);
      await auditCapture(tester, '03-point-negative-wallet-390-light');
      final projected = find.byKey(const ValueKey('points-expected-balance'));
      await _show(tester, projected);
      expect(
        find.descendant(of: projected, matching: find.text('0 P')),
        findsOneWidget,
      );
      await auditCapture(tester, '04-point-negative-settlement-390-light');
      await _finish(tester);
    },
  );

  testWidgets(
    'capture improved points 04 verified completion returns to purchase purpose',
    (tester) async {
      final fixture = _WalletFixture();
      await _mount(tester, fixture, purpose: _purpose, push: true);
      await _verifiedPurchase(tester, fixture, 'capture-context-completion');
      expect(fixture.balance, 14950);
      expect(
        find.byKey(const ValueKey('points-completion-return')),
        findsOneWidget,
      );
      await _show(tester, find.byKey(const ValueKey('points-completion')));
      await auditCapture(tester, '05-point-completed-purpose-390-light');
      await _finish(tester);
    },
  );

  testWidgets(
    'capture improved points 05 verified ordinary completion offers history',
    (tester) async {
      final fixture = _WalletFixture();
      await _mount(tester, fixture);
      await _verifiedPurchase(tester, fixture, 'capture-ordinary-completion');
      expect(
        find.byKey(const ValueKey('points-completion-history')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('points-charge-more')), findsOneWidget);
      await _show(tester, find.byKey(const ValueKey('points-completion')));
      await auditCapture(tester, '06-point-completed-history-390-light');
      await _finish(tester);
    },
  );

  testWidgets('capture improved points 06 ledger and nearby refund help', (
    tester,
  ) async {
    final fixture = _WalletFixture();
    await _mount(tester, fixture, initialTab: 1);
    await auditCapture(tester, '07-point-ledger-390-light');
    await _show(tester, find.byKey(const ValueKey('points-support-help')));
    expect(find.byKey(const ValueKey('points-policy-help')), findsOneWidget);
    await auditCapture(tester, '08-point-ledger-refund-help-390-light');
    await _finish(tester);
  });

  testWidgets(
    'capture improved points 07 small dark single-line balance and charge CTA',
    (tester) async {
      final fixture = _WalletFixture();
      await _mount(
        tester,
        fixture,
        size: const Size(320, 568),
        dark: true,
        scale: 1.8,
      );
      await _select(tester);
      await _top(tester);
      await auditCapture(tester, '09-point-small-dark-balance-320-text180');
      await _show(
        tester,
        find.byKey(const ValueKey('points-expected-balance')),
      );
      await auditCapture(tester, '10-point-small-dark-projected-320-text180');
      await _finish(tester);
    },
  );

  testWidgets('capture improved points 08 dark landscape at large text', (
    tester,
  ) async {
    final fixture = _WalletFixture(balance: 20);
    await _mount(
      tester,
      fixture,
      size: const Size(844, 390),
      dark: true,
      scale: 1.8,
      purpose: _purpose,
      push: true,
    );
    await _select(tester);
    await _top(tester);
    await auditCapture(tester, '11-point-landscape-dark-844-text180');
    await _finish(tester);
  });

  for (final size in [const Size(648, 320), const Size(844, 390)]) {
    testWidgets('capture improved points 09 verified completion landscape $size', (
      tester,
    ) async {
      final fixture = _WalletFixture();
      await _mount(
        tester,
        fixture,
        size: size,
        dark: true,
        scale: 1.8,
        purpose: _purpose,
        push: true,
      );
      await _verifiedPurchase(
        tester,
        fixture,
        'capture-landscape-completion-${size.width.toInt()}',
      );
      expect(fixture.balance, 14950);
      expect(fixture.service.verificationDelayed, isFalse);

      final primary = find.byKey(const ValueKey('points-completion-return'));
      final additional = find.byKey(const ValueKey('points-charge-more'));
      final safeFrame = Rect.fromLTRB(32, 0, size.width - 48, size.height - 24);
      void expectSafe(Finder target) {
        expect(target.hitTestable(), findsOneWidget);
        final rect = tester.getRect(target);
        expect(rect.left, greaterThanOrEqualTo(safeFrame.left));
        expect(rect.right, lessThanOrEqualTo(safeFrame.right));
        expect(rect.top, greaterThanOrEqualTo(safeFrame.top));
        expect(rect.bottom, lessThanOrEqualTo(safeFrame.bottom));
      }

      expectSafe(primary);
      expectSafe(find.text('포인트'));

      // 짧은 화면에서도 고정 버튼이 읽을 본문 공간을 잠식하면 안 된다.
      final body = tester.getRect(_scroll());
      expect(body.height, greaterThanOrEqualTo(120));
      expect(body.bottom, lessThanOrEqualTo(tester.getRect(primary).top));
      final state = tester.state<ScrollableState>(_scroll());
      expect(state.position.maxScrollExtent, greaterThan(0));
      await _top(tester);
      final receiptHeading = find.text('포인트가 충전됐어요');
      expect(receiptHeading.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(receiptHeading).top,
        greaterThanOrEqualTo(body.top),
      );
      expect(
        tester.getRect(receiptHeading).bottom,
        lessThanOrEqualTo(body.bottom),
      );
      expectSafe(primary);
      expect(tester.takeException(), isNull);
      final headingNumber = size.width == 648 ? '14' : '15';
      await auditCapture(
        tester,
        '$headingNumber-point-completion-${size.width.toInt()}-dark-text180',
      );

      await _show(tester, find.text('충전 후 확인 잔액'));
      expectSafe(find.text('충전 후 확인 잔액'));
      expect(
        tester.getRect(find.text('충전 후 확인 잔액')).bottom,
        lessThanOrEqualTo(tester.getRect(primary).top),
      );
      expectSafe(primary);
      await _show(tester, additional);
      expectSafe(additional);
      expect(tester.getRect(additional).bottom, lessThanOrEqualTo(body.bottom));
      expect(
        tester.getRect(primary).overlaps(tester.getRect(additional)),
        isFalse,
      );
      expectSafe(primary);
      expect(tester.takeException(), isNull);
      final detailsNumber = size.width == 648 ? '16' : '17';
      await auditCapture(
        tester,
        '$detailsNumber-point-completion-more-${size.width.toInt()}-dark-text180',
      );
      debugPrint(
        'POINT_COMPLETION_LAYOUT $size: bodyHeight=${body.height}, '
        'maxScroll=${state.position.maxScrollExtent}, '
        'primary=${tester.getRect(primary)}, additional=${tester.getRect(additional)}',
      );
      await _finish(tester);
    });
  }
}

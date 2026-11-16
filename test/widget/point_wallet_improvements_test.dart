import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/billing/domain/point_top_up_context.dart';
import 'package:snap_fit/features/profile/presentation/views/billing_management_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/terms_policy_screen.dart';
import '../support/point_ledger_history_fakes.dart';
import '../support/point_purchase_fakes.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _WalletFixture {
  _WalletFixture({this.balance = 12450});
  int balance;
  String? owner = 'owner';
  bool balanceFailure = false;
  final store = FakeStore();
  ProviderContainer? container;
  late final service = PointPurchaseService(
    store: store,
    storage: MemoryReceipts(),
    currentUserId: () => owner,
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
  PointTopUpContext? purchaseContext,
  Widget? home,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(fixture.store.controller.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pointPurchaseServiceProvider.overrideWith((ref) {
          ref.onDispose(fixture.service.dispose);
          return fixture.service;
        }),
        myPointBalanceProvider.overrideWith((_) async {
          if (fixture.balanceFailure) throw StateError('fixture_balance_error');
          return fixture.balance;
        }),
        pointLedgerHistoryProvider.overrideWith2(
          (filter) =>
              FixturePointLedgerHistoryController(filter, () async => []),
        ),
      ],
      child: MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home ?? BillingManagementScreen(purchaseContext: purchaseContext),
      ),
    ),
  );
  fixture.container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
  await tester.pumpAndSettle();
}

Finder _scroll() => find
    .descendant(
      of: find.byType(CustomScrollView).first,
      matching: find.byType(Scrollable),
    )
    .first;
Future<void> _show(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 120, scrollable: _scroll());
  }
  await tester.ensureVisible(target);
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

void main() {
  setUpAll(loadCreationFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'wallet: verified charge replaces the buy action with completion and history',
    (tester) async {
      final fixture = _WalletFixture();
      await _mount(tester, fixture);
      await _select(tester);
      final pay = find.byKey(const ValueKey('points-charge-action'));
      await tester.tap(pay);
      fixture.store.controller.add([purchase(nativeOwner: 'owner')]);
      await tester.pumpAndSettle();
      expect(fixture.balance, 14950);
      final completed = find.byKey(const ValueKey('points-completion'));
      await _show(tester, completed);
      expect(completed, findsOneWidget);
      expect(find.byKey(const ValueKey('points-charge-action')), findsNothing);
      expect(
        find.descendant(
          of: completed,
          matching: find.textContaining('2,500 P'),
        ),
        findsOneWidget,
      );
      final history = find.byKey(const ValueKey('points-completion-history'));
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(find.text('아직 포인트 내역이 없어요.'), findsOneWidget);
      expect(fixture.store.buyCalls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'wallet: negative balance names settlement and explains the selected pack result',
    (tester) async {
      final fixture = _WalletFixture(balance: -2500);
      await _mount(tester, fixture);
      expect(find.text('포인트 잔액'), findsOneWidget);
      await _select(tester);
      final projection = find.byKey(const ValueKey('points-expected-balance'));
      await _show(tester, projection);
      expect(
        find.descendant(of: projection, matching: find.text('0 P')),
        findsOneWidget,
      );
      expect(fixture.balance, -2500);
      expect(fixture.store.buyCalls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'wallet: normal charging exposes the existing refund policy without a transaction',
    (tester) async {
      final fixture = _WalletFixture();
      await _mount(tester, fixture);
      final policy = find.byKey(const ValueKey('points-policy-help'));
      await _show(tester, policy);
      await tester.tap(policy);
      await tester.pumpAndSettle();
      expect(find.byType(TermsPolicyScreen), findsOneWidget);
      expect(fixture.store.buyCalls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'wallet: large accessible balance keeps the amount and unit on one line',
    (tester) async {
      final fixture = _WalletFixture();
      await _mount(
        tester,
        fixture,
        size: const Size(320, 568),
        scale: 1.8,
        dark: true,
      );
      final value = find.text('12,450 P');
      final paragraph = tester.renderObject<RenderParagraph>(value);
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 8),
      );
      expect(boxes.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('wallet: purchase purpose is visible only to its own account', (
    tester,
  ) async {
    final fixture = _WalletFixture(balance: 20);
    await _mount(
      tester,
      fixture,
      purchaseContext: const PointTopUpContext(
        ownerId: 'owner',
        productKey: 'sticker:studioCottonRag',
        title: '수제지 조각',
        requiredPoints: 100,
      ),
    );
    expect(find.text('수제지 조각'), findsOneWidget);
    expect(find.text('80 P 더 필요해요.'), findsOneWidget);
    fixture.owner = 'another-owner';
    fixture.container!.invalidate(myPointBalanceProvider);
    await tester.pumpAndSettle();
    expect(find.text('수제지 조각'), findsNothing);
    expect(find.byKey(const ValueKey('points-purchase-context')), findsNothing);
    expect(fixture.store.buyCalls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'wallet: unavailable balance never becomes a projected zero balance',
    (tester) async {
      final fixture = _WalletFixture()..balanceFailure = true;
      await _mount(tester, fixture);
      await _select(tester);
      tester.state<ScrollableState>(_scroll()).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('확인 실패'), findsOneWidget);
      expect(find.text('0 P'), findsNothing);
      expect(
        find.byKey(const ValueKey('points-expected-balance')),
        findsNothing,
      );
      expect(fixture.store.buyCalls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'wallet: choosing another charge clears the previous success and requires a new selection',
    (tester) async {
      final fixture = _WalletFixture();
      await _mount(tester, fixture);
      await _select(tester);
      await tester.tap(find.byKey(const ValueKey('points-charge-action')));
      fixture.store.controller.add([purchase(nativeOwner: 'owner')]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('points-charge-more')));
      await tester.pumpAndSettle();
      expect(fixture.service.completion, isNull);
      expect(find.textContaining('충전되었습니다'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('points-charge-action')),
            )
            .onPressed,
        isNull,
      );
      expect(fixture.store.buyCalls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'wallet: completed recharge can return to the original purchase without buying it',
    (tester) async {
      final fixture = _WalletFixture(balance: 20);
      bool? returned;
      const purpose = PointTopUpContext(
        ownerId: 'owner',
        productKey: 'sticker:studioCottonRag',
        title: '수제지 조각',
        requiredPoints: 100,
      );
      await _mount(
        tester,
        fixture,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                returned = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const BillingManagementScreen(purchaseContext: purpose),
                  ),
                );
              },
              child: const Text('상품에서 충전 열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('상품에서 충전 열기'));
      await tester.pumpAndSettle();
      await _select(tester);
      await tester.tap(find.byKey(const ValueKey('points-charge-action')));
      fixture.store.controller.add([purchase(nativeOwner: 'owner')]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('points-completion-return')));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(find.text('상품에서 충전 열기'), findsOneWidget);
      await tester.tap(find.text('상품에서 충전 열기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('points-completion')), findsNothing);
      expect(find.textContaining('충전되었습니다'), findsNothing);
      expect(fixture.store.buyCalls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [const Size(648, 320), const Size(844, 390)]) {
    testWidgets('wallet: completion keeps readable space in landscape $size', (
      tester,
    ) async {
      final fixture = _WalletFixture();
      await _mount(tester, fixture, size: size, dark: true, scale: 1.8);
      await _select(tester);
      await tester.tap(find.byKey(const ValueKey('points-charge-action')));
      fixture.store.controller.add([purchase(nativeOwner: 'owner')]);
      await tester.pumpAndSettle();
      final primary = find.byKey(const ValueKey('points-completion-history'));
      expect(primary.hitTestable(), findsOneWidget);
      // 완료 내용을 한 줄씩만 읽게 만드는 과도한 고정 영역을 방지한다.
      expect(tester.getSize(_scroll()).height, greaterThanOrEqualTo(120));
      await _show(tester, find.text('충전 후 확인 잔액'));
      expect(find.text('충전 후 확인 잔액').hitTestable(), findsOneWidget);
      final more = find.byKey(const ValueKey('points-charge-more'));
      await _show(tester, more);
      expect(more.hitTestable(), findsOneWidget);
      expect(tester.getRect(primary).overlaps(tester.getRect(more)), isFalse);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(fixture.service.completion, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('points-charge-action')),
            )
            .onPressed,
        isNull,
      );
      expect(fixture.store.buyCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'wallet: another account cannot see the previous successful amount or message',
    (tester) async {
      final fixture = _WalletFixture();
      await _mount(tester, fixture);
      await _select(tester);
      await tester.tap(find.byKey(const ValueKey('points-charge-action')));
      fixture.store.controller.add([purchase(nativeOwner: 'owner')]);
      await tester.pumpAndSettle();
      expect(fixture.service.completion, isNotNull);
      fixture.owner = 'another-owner';
      fixture.balance = 700;
      fixture.container!.invalidate(myPointBalanceProvider);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('points-completion')), findsNothing);
      expect(find.textContaining('충전되었습니다'), findsNothing);
      expect(find.textContaining('14950'), findsNothing);
      expect(find.textContaining('14,950'), findsNothing);
      expect(find.text('700 P'), findsWidgets);
      expect(fixture.store.buyCalls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

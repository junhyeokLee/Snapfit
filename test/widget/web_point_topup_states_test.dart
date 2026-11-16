import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/config/env.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/web_point_topup_repository.dart';
import 'package:snap_fit/features/billing/domain/web_point_topup.dart';
import 'package:snap_fit/features/billing/presentation/widgets/web_point_topup_panel.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _payment = 'SFPTT_22222222-2222-4222-8222-222222222222';
const _secondPayment = 'SFPTT_33333333-3333-4333-8333-333333333333';

Map<String, dynamic> _sdkRow(String id, String status) => {
  'paymentId': id,
  'ownerId': _owner,
  'productId': 'snapfit_points_2500',
  'title': '2,500P',
  'points': 2500,
  'totalAmount': 2200,
  'currency': 'KRW',
  'status': status,
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
  'sdkStartedAt': status == 'PENDING'
      ? DateTime.now().toUtc().toIso8601String()
      : null,
  'verifiedAt': null,
  'refundedAt': null,
  'serverVerified': false,
  'environment': 'test',
  'isTest': true,
  'productionApproved': false,
  'realPointsGranted': 0,
  'storeId': webPointTestStoreId,
  'channelKey': webPointTestChannelKey,
  'canLaunch': status == 'PREPARED',
  'sdkLaunchAuthorized': status == 'PENDING',
};

class _PaymentClient implements WebPointPaymentClient {
  final launches = <String, Completer<void>>{};
  @override
  bool get hasUnresolvedWindow => false;
  @override
  void confirmTerminal(WebPointTopup row) {}
  @override
  void ensureSupported() {}
  @override
  Future<void> prepare() async {}
  @override
  Future<void> launch(WebPointSdkRequest request) {
    final pending = Completer<void>();
    launches[request.topup.paymentId] = pending;
    return pending.future;
  }
}

class _PhysicalWindowClient extends _PaymentClient {
  final pendingWindows = <String>{};
  final confirmed = <String>[];
  @override
  bool get hasUnresolvedWindow => pendingWindows.isNotEmpty;
  @override
  void confirmTerminal(WebPointTopup row) => confirmed.add(row.paymentId);
  @override
  Future<void> launch(WebPointSdkRequest request) {
    pendingWindows.add(request.topup.paymentId);
    return super
        .launch(request)
        .whenComplete(() => pendingWindows.remove(request.topup.paymentId));
  }
}

class _Auth extends Mock implements GoTrueClient {}

class _Topup extends Mock implements WebPointTopup {}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth)
    : super(
        'https://topup.invalid',
        'fixture',
        httpClient: MockClient(
          (_) async => throw StateError('Unexpected HTTP'),
        ),
        accessToken: () async => 'fixture',
      );
  final GoTrueClient fixtureAuth;
  @override
  GoTrueClient get auth => fixtureAuth;
}

class _Repository extends WebPointTopupRepository {
  _Repository(super.client);
  List<WebPointTopup> rows = [];
  int confirms = 0, prepares = 0, historyReads = 0;
  Completer<WebPointTopup>? confirmation;
  Completer<List<WebPointTopup>>? historyGate;
  @override
  Future<WebPointCatalog> catalog(String owner) async => const WebPointCatalog(
    testAvailable: true,
    liveAvailable: false,
    environment: 'test',
    products: [
      WebPointProduct(
        id: 'snapfit_points_2500',
        title: '2,500P',
        points: 2500,
        amount: 2200,
      ),
    ],
  );
  @override
  Future<List<WebPointTopup>> history(String owner) async {
    historyReads++;
    return historyGate?.future ?? Future.value(List.of(rows));
  }

  @override
  Future<WebPointTopup> prepare(
    String owner,
    String requestId,
    WebPointProduct product, {
    String environment = 'test',
  }) async {
    prepares++;
    final row = WebPointTopup.fromJson(
      _sdkRow(prepares == 1 ? _payment : _secondPayment, 'PREPARED'),
    );
    rows = [row, ...rows.where((item) => item.paymentId != row.paymentId)];
    return row;
  }

  @override
  Future<WebPointSdkRequest> authorizeLaunch(
    String owner,
    WebPointTopup session,
  ) async {
    final request = WebPointSdkRequest.fromAuthorized(
      _sdkRow(session.paymentId, 'PENDING'),
    );
    rows = [
      request.topup,
      ...rows.where((item) => item.paymentId != session.paymentId),
    ];
    return request;
  }

  @override
  Future<WebPointTopup> confirm(String owner, String paymentId) async {
    expect(owner, _owner);
    expect(paymentId, _payment);
    confirms++;
    return confirmation?.future ?? Future.value(rows.first);
  }
}

WebPointTopup _row({String status = 'PENDING', bool test = true}) {
  final row = _Topup();
  when(() => row.paymentId).thenReturn(_payment);
  when(() => row.ownerId).thenReturn(_owner);
  when(() => row.environment).thenReturn(test ? 'test' : 'live');
  when(() => row.isTest).thenReturn(test);
  when(() => row.status).thenReturn(status);
  when(() => row.pending).thenReturn(status == 'PENDING' || status == 'REVIEW');
  when(
    () => row.needsRecovery,
  ).thenReturn(status == 'PENDING' || status == 'REVIEW');
  when(() => row.canLaunch).thenReturn(false);
  when(() => row.points).thenReturn(2500);
  when(() => row.amount).thenReturn(2200);
  when(() => row.serverVerified).thenReturn(status != 'PENDING');
  when(
    () => row.verifiedAt,
  ).thenReturn(status == 'PENDING' ? null : DateTime.utc(2026, 10, 29));
  when(
    () => row.refundedAt,
  ).thenReturn(status == 'REFUNDED' ? DateTime.utc(2026, 10, 30) : null);
  when(() => row.statusLabel).thenReturn(switch (status) {
    'PENDING' => 'TEST 결제 확인 중',
    'VERIFIED_TEST' => 'TEST 승인 확인 · 실잔액 미반영',
    'CREDITED' => '결제 확인 · 포인트 지급 완료',
    'REVIEW' => '취소·결제 상태 확인 필요',
    _ => '환불 확인 · 지급 포인트 회수',
  });
  return row;
}

void main() {
  late _Client client;
  late _Repository repository;
  var balanceReads = 0, ledgerReads = 0;
  setUp(() {
    final auth = _Auth();
    when(() => auth.currentUser).thenReturn(
      User(
        id: _owner,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-29',
      ),
    );
    client = _Client(auth);
    repository = _Repository(client);
    balanceReads = ledgerReads = 0;
  });
  tearDown(() async => client.dispose());

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    WebPointPaymentClient? paymentClient,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visibleOrderOwnerProvider.overrideWithValue(_owner),
          webPointTopupRepositoryProvider.overrideWithValue(repository),
          myPointBalanceProvider.overrideWith((_) async {
            balanceReads++;
            return 12450;
          }),
          myPointLedgerProvider.overrideWith((_) async {
            ledgerReads++;
            return [];
          }),
        ],
        child: MaterialApp(
          theme: SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Consumer(
                  builder: (context, ref, _) {
                    ref.watch(myPointBalanceProvider);
                    ref.watch(myPointLedgerProvider);
                    return paymentClient == null
                        ? const WebPointTopupPanel(ownerId: _owner)
                        : WebPointTopupPanel(
                            ownerId: _owner,
                            paymentClient: paymentClient,
                          );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('closed production gate stays closed without a test flag', (
    tester,
  ) async {
    await mount(tester);
    expect(webPointTopupLiveCheckoutReleased, false);
    expect(find.text('포인트 충전 준비 중'), findsOneWidget);
    expect(find.byKey(const ValueKey('web-topup-charge-action')), findsNothing);
    expect(repository.confirms, 0);
    await tester.pumpWidget(const SizedBox());
  }, skip: Env.webPointTopupTestEnabled);

  testWidgets(
    'pending invoice exposes only same-invoice confirmation and never a new charge',
    (tester) async {
      repository.rows = [_row()];
      await mount(tester, size: const Size(320, 568), scale: 1.8);
      expect(find.byKey(const ValueKey('web-topup-pending')), findsOneWidget);
      final pendingCard = find.byKey(const ValueKey('web-topup-pending'));
      expect(
        find.descendant(of: pendingCard, matching: find.text('충전 포인트')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pendingCard, matching: find.text('2,500 P')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pendingCard, matching: find.text('결제 금액')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pendingCard, matching: find.text('2,200원')),
        findsOneWidget,
      );
      final action = find.byKey(const ValueKey('web-topup-check-existing'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      repository.confirmation = Completer<WebPointTopup>();
      await tester.tap(action);
      await tester.pump();
      expect(repository.confirms, 2);
      expect(tester.widget<OutlinedButton>(action).onPressed, isNull);
      expect(
        find.byKey(const ValueKey('web-topup-charge-action')),
        findsNothing,
      );
      repository.confirmation!.complete(_row(status: 'VERIFIED_TEST'));
      await tester.pumpAndSettle();
      expect(find.text('서버 확인 결과: TEST 승인 확인 · 실잔액 미반영'), findsOneWidget);
      expect(balanceReads, 1);
      expect(ledgerReads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !Env.webPointTopupTestEnabled,
  );

  testWidgets(
    'terminal recovery retires a hung SDK and its late error cannot change a newer checkout',
    (tester) async {
      final sdk = _PaymentClient();
      await mount(tester, paymentClient: sdk);
      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tapVisible(
        find.byKey(const ValueKey('web-topup-product-snapfit_points_2500')),
      );
      await tapVisible(find.byType(CheckboxListTile));
      await tapVisible(find.byKey(const ValueKey('web-topup-charge-action')));
      expect(sdk.launches.keys, [_payment]);
      expect(repository.prepares, 1);
      final terminal = _row(status: 'VERIFIED_TEST');
      repository.confirmation = Completer<WebPointTopup>()..complete(terminal);
      repository.rows = [terminal];
      await tapVisible(find.byKey(const ValueKey('web-topup-check-existing')));
      expect(
        find.byKey(const ValueKey('web-topup-check-existing')),
        findsNothing,
      );
      expect(find.text('서버 확인 결과: TEST 승인 확인 · 실잔액 미반영'), findsOneWidget);
      await tapVisible(find.byType(CheckboxListTile));
      final charge = find.byKey(const ValueKey('web-topup-charge-action'));
      expect(tester.widget<FilledButton>(charge).onPressed, isNotNull);
      await tapVisible(charge);
      expect(repository.prepares, 2);
      expect(sdk.launches.keys, [_payment, _secondPayment]);
      final confirmations = repository.confirms;
      final histories = repository.historyReads;
      sdk.launches[_payment]!.completeError(StateError('late old SDK error'));
      await tester.pumpAndSettle();
      expect(repository.confirms, confirmations);
      expect(repository.historyReads, histories);
      expect(find.byKey(const ValueKey('web-topup-pending')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('web-topup-charge-action')),
        findsNothing,
      );
      expect(find.textContaining('연결 상태를 확인해주세요.'), findsNothing);
      expect(repository.rows.first.paymentId, _secondPayment);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      sdk.launches[_secondPayment]!.complete();
      await tester.pump();
    },
    skip: !Env.webPointTopupTestEnabled,
  );

  testWidgets(
    'confirmed invoice preserves history but requires a hung physical SDK to close before a new prepare',
    (tester) async {
      final sdk = _PhysicalWindowClient();
      await mount(tester, paymentClient: sdk);
      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tapVisible(
        find.byKey(const ValueKey('web-topup-product-snapfit_points_2500')),
      );
      await tapVisible(find.byType(CheckboxListTile));
      final charge = find.byKey(const ValueKey('web-topup-charge-action'));
      await tapVisible(charge);
      expect(repository.prepares, 1);
      final terminal = _row(status: 'VERIFIED_TEST');
      repository.confirmation = Completer<WebPointTopup>()..complete(terminal);
      repository.rows = [terminal];
      await tapVisible(find.byKey(const ValueKey('web-topup-check-existing')));
      expect(sdk.confirmed, [_payment]);
      expect(find.text('서버 확인 결과: TEST 승인 확인 · 실잔액 미반영'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('web-topup-previous-window-unresolved')),
        findsOneWidget,
      );
      await tapVisible(find.byType(CheckboxListTile));
      expect(tester.widget<FilledButton>(charge).onPressed, isNull);
      expect(repository.prepares, 1);
      sdk.launches[_payment]!.completeError(StateError('late old SDK error'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('web-topup-previous-window-unresolved')),
        findsNothing,
      );
      expect(find.textContaining('연결 상태를 확인해주세요.'), findsNothing);
      expect(tester.widget<FilledButton>(charge).onPressed, isNotNull);
      expect(repository.prepares, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !Env.webPointTopupTestEnabled,
  );

  testWidgets(
    'late pending history cannot regress a manual authoritative grant or invalidate wallet twice',
    (tester) async {
      repository.rows = [_row()];
      await mount(tester);
      expect(repository.confirms, 1);
      final pendingSnapshot = [_row()];
      repository.historyGate = Completer<List<WebPointTopup>>();
      final refresh = find.widgetWithText(OutlinedButton, '상태 새로고침');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(repository.historyReads, 2);
      final terminal = _row(status: 'CREDITED', test: false);
      repository.confirmation = Completer<WebPointTopup>()..complete(terminal);
      final check = find.byKey(const ValueKey('web-topup-check-existing'));
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(balanceReads, 2);
      expect(ledgerReads, 2);
      repository.historyGate!.complete(pendingSnapshot);
      repository.historyGate = null;
      repository.rows = [terminal];
      await tester.pumpAndSettle();
      expect(repository.confirms, 2);
      expect(find.byKey(const ValueKey('web-topup-pending')), findsNothing);
      expect(find.text('결제 확인 · 포인트 지급 완료'), findsOneWidget);
      expect(balanceReads, 2);
      expect(ledgerReads, 2);
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(balanceReads, 2);
      expect(ledgerReads, 2);
      expect(repository.confirms, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !Env.webPointTopupTestEnabled,
  );

  testWidgets(
    'a later server cancellation review replaces a previously paid status',
    (tester) async {
      repository.rows = [_row(status: 'VERIFIED_TEST')];
      await mount(tester);
      final review = _row(status: 'REVIEW');
      repository.rows = [review];
      final refresh = find.widgetWithText(OutlinedButton, '상태 새로고침');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-topup-pending')), findsOneWidget);
      expect(find.text('취소·결제 상태 확인 필요'), findsWidgets);
      expect(
        find.byKey(const ValueKey('web-topup-charge-action')),
        findsNothing,
      );
      expect(balanceReads, 1);
      expect(ledgerReads, 1);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !Env.webPointTopupTestEnabled,
  );

  testWidgets(
    'history-only authoritative grant and refund refresh wallet exactly once per change',
    (tester) async {
      repository.rows = [_row(status: 'CREDITED', test: false)];
      await mount(tester);
      expect(balanceReads, 2);
      expect(ledgerReads, 2);
      Future<void> refresh() async {
        final action = find.widgetWithText(OutlinedButton, '상태 새로고침');
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
      }

      await refresh();
      expect(balanceReads, 2);
      expect(ledgerReads, 2);
      repository.rows = [_row(status: 'REFUNDED', test: false)];
      await refresh();
      expect(balanceReads, 3);
      expect(ledgerReads, 3);
      expect(webPointTopupLiveCheckoutReleased, false);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !Env.webPointTopupTestEnabled,
  );
}

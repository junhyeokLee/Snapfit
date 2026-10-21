import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_checkout_screen.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_preview_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/domain/account_deletion_request.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/domain/entities/storage_quota.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/portone_payment_launcher.dart';
import 'package:snap_fit/features/profile/data/print_dev_checkout.dart';
import 'package:snap_fit/features/profile/data/print_payment_service.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/features/profile/presentation/views/account_settings_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/admin_point_shop_management_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/order_history_screen.dart';
import 'package:snap_fit/shared/web/web_design.dart';

const _owner = 'local-web-owner';
const _user = UserInfo(
  id: _owner,
  name: '테스트 고객',
  email: 'local.owner@example.com',
  provider: 'EMAIL',
);

class _Auth extends AuthViewModel {
  int logoutCalls = 0, deleteCalls = 0, resetCalls = 0;
  @override
  FutureOr<UserInfo?> build() => _user;
  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<AccountDeletionRequest> requestAccountDeletion() async {
    deleteCalls++;
    return const AccountDeletionRequest(
      reference: 'DEL-1',
      alreadyRequested: false,
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resetCalls++;
  }

  void changeOwner() => state = const AsyncData(
    UserInfo(id: 'different-local-owner', name: '다른 계정', provider: 'EMAIL'),
  );
}

class _Session extends OrderSessionOwner {
  @override
  ObservedOrderSession build() =>
      const ObservedOrderSession(observed: true, ownerId: _owner);
}

class _Home extends HomeViewModel {
  @override
  FutureOr<List<Album>> build() => const [
    Album(id: 7, title: '우리의 여행', userId: _owner, ratio: '1', totalPages: 20),
  ];
}

class _Orders extends Mock implements OrderRepository {}

const _summary = OrderSummaryResult(
  paymentPending: 0,
  paymentCompleted: 0,
  inProduction: 0,
  shipping: 1,
  delivered: 0,
  canceled: 0,
  latestUpdatedAt: null,
);

OrderHistoryItem _shippingOrder() => OrderHistoryItem(
  orderId: 'local-shipping-order',
  title: '우리의 여행',
  amount: 49900,
  pageCount: 20,
  status: 'SHIPPING',
  statusLabel: '배송 중',
  progress: .8,
  orderedAt: DateTime(2026, 10, 18),
  recipientName: '테스트 수령인',
  courier: 'CJ대한통운',
  trackingNumber: '1234567890',
  printProductSnapshot: const {
    'id': 'REDP_200_SOFT',
    'trimWidthMm': 200,
    'trimHeightMm': 200,
  },
);

OrderQuoteResult _quote({
  int amount = 49900,
  String version = 'local-design-only',
  String? retailPriceStatus,
}) => OrderQuoteResult.fromJson({
  'amount': amount,
  'pageCount': 20,
  'basePages': 20,
  'basePrice': amount,
  'sourcePageCount': 1,
  'addedBlankPageCount': 19,
  'productCode': 'REDP_200_SOFT',
  'supplierCostVerified': true,
  'shippingCostVerified': true,
  'packagingCostVerified': true,
  'shippingIncluded': true,
  'pricePolicyVersion': version,
  if (retailPriceStatus != null) 'retailPriceStatus': retailPriceStatus,
  if (retailPriceStatus == 'PLANNED') 'priceIsEstimate': true,
  'specMissing': true,
});
Map<String, dynamic> _snapshot() => {
  'album': {
    'id': 7,
    'title': '우리의 여행',
    'ratio': '1',
    'cover_theme': 'classic',
    'cover_layers_json': jsonEncode({
      'pages': [
        {'index': 0, 'isCover': true, 'layers': []},
        {'index': 1, 'isCover': false, 'layers': []},
      ],
    }),
  },
  'pages': <dynamic>[],
};

Future<void> _mount(
  WidgetTester tester,
  Widget screen, {
  required _Orders orders,
  required _Auth auth,
  Size size = const Size(1440, 900),
  double textScale = 1,
  bool dark = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(() => auth),
        orderSessionOwnerProvider.overrideWith(_Session.new),
        homeViewModelProvider.overrideWith(_Home.new),
        orderRepositoryProvider.overrideWithValue(orders),
        myOrderSummaryProvider.overrideWith((_) async => _summary),
        myPointBalanceProvider.overrideWith((_) async => 12000),
        myStorageQuotaProvider.overrideWith(
          (_) async => const StorageQuotaStatus(
            userId: _owner,
            planCode: 'FREE',
            usedBytes: 10485760,
            softLimitBytes: 1073741824,
            hardLimitBytes: 1073741824,
            softExceeded: false,
            hardExceeded: false,
            usagePercent: 1,
          ),
        ),
        ownedPointShopKeysProvider.overrideWith(
          (_) async => {'template:local-design'},
        ),
        pointShopAdminAccessProvider.overrideWithValue(false),
        printDevAdminAccessProvider.overrideWithValue(false),
        // These fail loudly if a design interaction tries to prepare or launch payment.
        printPaymentServiceProvider.overrideWith(
          (_) => throw StateError('payment forbidden in local design test'),
        ),
        portOnePaymentLauncherProvider.overrideWith(
          (_) => throw StateError(
            'payment launcher forbidden in local design test',
          ),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: SnapFitWebTheme.from(
            dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

// Chrome's test reporter can omit the useful exception text; keep the original
// error handler and failure while emitting a plain diagnostic for the run log.
void _routeTest(
  String name,
  WidgetTesterCallback callback, {
  bool skip = false,
}) {
  testWidgets(name, (tester) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrintSynchronously(
        '[web-route-framework] $name: ${details.exceptionAsString()}',
      );
      if (details.stack != null)
        debugPrintSynchronously(details.stack.toString());
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    try {
      await callback(tester);
    } catch (error, stack) {
      debugPrintSynchronously('[web-route-failure] $name: $error');
      debugPrintSynchronously(stack.toString());
      rethrow;
    }
  }, skip: skip);
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  bool requireHit = true,
}) async {
  // A ListView creates its distant children only as the user scrolls. Prefer
  // the current dialog's vertical list when a modal is open; otherwise use
  // the route's innermost visible vertical list.
  if (target.evaluate().isEmpty) {
    final vertical = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.down ||
              widget.axisDirection == AxisDirection.up),
    );
    final modal = find.byType(Dialog);
    final candidates = modal.evaluate().isEmpty
        ? vertical
        : find.descendant(of: modal.last, matching: vertical);
    expect(
      candidates,
      findsWidgets,
      reason: 'A user-scrollable route must expose the lazy target: $target',
    );
    await tester.scrollUntilVisible(
      target,
      140,
      scrollable: candidates.last,
      maxScrolls: 50,
    );
    await tester.pumpAndSettle();
  }
  expect(
    target,
    findsOneWidget,
    reason: 'The actual route must build its target after scrolling.',
  );
  // Every reveal must finish layout before the next geometry-dependent action.
  // Centering exposes the actual checkbox, rather than the center of a tall,
  // wrapping CheckboxListTile.
  await Scrollable.ensureVisible(
    tester.element(target),
    alignment: .5,
    duration: Duration.zero,
    alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
  );
  await tester.pumpAndSettle();
  final rect = tester.getRect(target);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  debugPrintSynchronously(
    '[web-route-target] $target rect=$rect viewport=$size',
  );
  expect(
    rect.center.dy,
    inInclusiveRange(0, size.height),
    reason:
        'Target center must be inside the actual browser viewport: $target $rect',
  );
  if (requireHit)
    expect(
      target.hitTestable(),
      findsOneWidget,
      reason:
          'The actual interaction target must receive pointer events: $target $rect',
    );
}

void _noRouteException(WidgetTester tester, String stage) {
  final error = tester.takeException();
  if (error != null)
    debugPrintSynchronously('[web-route-takeException] $stage: $error');
  expect(error, isNull, reason: stage);
}

void main() {
  late _Orders orders;
  late _Auth auth;
  var readDetails = 0;
  setUp(() {
    orders = _Orders();
    auth = _Auth();
    readDetails = 0;
    when(
      () => orders.fetchMyOrdersPage(
        statuses: any(named: 'statuses'),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer(
      (_) async => OrderPageResult(
        items: [_shippingOrder()],
        page: 0,
        size: 20,
        totalPages: 1,
        totalElements: 1,
        hasNext: false,
      ),
    );
    when(() => orders.fetchMyPrintOrder('local-shipping-order')).thenAnswer((
      _,
    ) async {
      readDetails++;
      return _shippingOrder();
    });
    when(
      () => orders.fetchMyPrintOrderProgress('local-shipping-order'),
    ).thenAnswer(
      (_) async => const PrintOrderProgress(
        orderId: 'local-shipping-order',
        customerStage: 'SHIPPING',
        preflightPassed: true,
        requiresAction: false,
      ),
    );
    when(
      () => orders.fetchPrintPreviewSnapshot(albumId: 7),
    ).thenAnswer((_) async => _snapshot());
    when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
      (_) async => PrintCheckoutReadiness(
        canPay: false,
        status: 'PREPARING',
        reasonCode: 'print_sales_not_ready',
        message: '정식 주문 서비스를 준비하고 있어요.',
        quote: _quote(),
      ),
    );
  });

  for (final size in const [Size(1024, 500), Size(320, 500)]) {
    _routeTest('actual web account settings retains safe actions at $size', (
      tester,
    ) async {
      var photoChanges = 0;
      await _mount(
        tester,
        AccountSettingsScreen(
          onChangePhoto: (_, __, ___) async {
            photoChanges++;
          },
        ),
        orders: orders,
        auth: auth,
        size: size,
        textScale: size.width == 320 ? 1.3 : 1,
      );
      expect(find.text('프로필과 보안'), findsOneWidget);
      expect(find.text('local.owner@example.com'), findsOneWidget);
      await tester.ensureVisible(find.text('프로필 사진 변경'));
      await tester.tap(find.text('프로필 사진 변경'));
      await tester.pumpAndSettle();
      expect(photoChanges, 1);
      await tester.ensureVisible(find.text('로그아웃'));
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      expect(find.text('로그아웃할까요?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account-sheet-cancel')));
      await tester.pumpAndSettle();
      expect(auth.logoutCalls, 0);
      await tester.ensureVisible(find.text('회원 탈퇴'));
      expect(find.text('회원 탈퇴').hitTestable(), findsOneWidget);
      expect(auth.deleteCalls, 0);
      expect(auth.resetCalls, 0);
      _noRouteException(tester, 'completed route assertions');
      await _dispose(tester);
    }, skip: !kIsWeb);
  }

  _routeTest('actual account route hides a stale profile on session change', (
    tester,
  ) async {
    await _mount(
      tester,
      const AccountSettingsScreen(),
      orders: orders,
      auth: auth,
      size: const Size(390, 500),
    );
    expect(find.text('local.owner@example.com'), findsOneWidget);
    auth.changeOwner();
    await tester.pumpAndSettle();
    expect(find.text('local.owner@example.com'), findsNothing);
    expect(find.text('로그인 계정을 확인하고 계정 설정을 다시 열어주세요.'), findsOneWidget);
    expect(auth.logoutCalls + auth.deleteCalls + auth.resetCalls, 0);
    _noRouteException(tester, 'completed route assertions');
    await _dispose(tester);
  }, skip: !kIsWeb);

  for (final size in const [Size(1440, 900), Size(390, 500)]) {
    _routeTest(
      'actual account overview reaches settings and grouped tools at $size',
      (tester) async {
        await _mount(
          tester,
          const MyPageScreen(),
          orders: orders,
          auth: auth,
          size: size,
          dark: size.width == 390,
        );
        expect(find.text('테스트 고객님'), findsOneWidget);
        expect(find.text('디자인 보관함'), findsOneWidget);
        await tester.ensureVisible(find.text('내 저장 공간'));
        expect(find.text('내 저장 공간').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text('프로필 및 로그인 정보'));
        await tester.tap(find.text('프로필 및 로그인 정보'));
        await tester.pumpAndSettle();
        expect(find.byType(AccountSettingsScreen), findsOneWidget);
        expect(find.text('프로필과 보안'), findsOneWidget);
        expect(auth.logoutCalls + auth.deleteCalls + auth.resetCalls, 0);
        _noRouteException(tester, 'completed route assertions');
        await _dispose(tester);
      },
      skip: !kIsWeb,
    );
  }

  _routeTest(
    'actual short order history opens owned detail and shipment facts',
    (tester) async {
      await _mount(
        tester,
        const OrderHistoryScreen(),
        orders: orders,
        auth: auth,
        size: const Size(390, 500),
      );
      final row = find.byKey(
        const ValueKey('personal-order-local-shipping-order'),
      );
      await _reveal(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(readDetails, 1);
      expect(find.text('주문 상세'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      final support = find.text('주문 문의 · 취소 · 환불 요청');
      await _reveal(tester, support);
      expect(support.hitTestable(), findsOneWidget);
      expect(find.text('1234567890'), findsWidgets);
      expect(find.text('결제 완료'), findsNothing);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      auth.changeOwner();
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      expect(find.textContaining('주문 내역을 볼 수 있어요.'), findsOneWidget);
      _noRouteException(tester, 'completed route assertions');
      await _dispose(tester);
    },
    skip: !kIsWeb,
  );

  for (final size in const [Size(1024, 500), Size(390, 500)]) {
    _routeTest(
      'actual web checkout preserves delivery and keeps payment closed at $size',
      (tester) async {
        var forbiddenPayCalls = 0;
        await _mount(
          tester,
          PrintOrderCheckoutScreen(
            albumId: 7,
            albumTitle: '우리의 여행',
            initialQuote: _quote(),
            reviewedRevision: printCheckoutRevision(_snapshot()),
            onPay: (_) async {
              forbiddenPayCalls++;
              return null;
            },
          ),
          orders: orders,
          auth: auth,
          size: size,
          dark: size.width == 390,
        );
        Future<void> enter(String key, String value) async {
          final field = find.byKey(ValueKey(key));
          await _reveal(tester, field);
          await tester.enterText(field, value);
          await tester.pump();
        }

        await enter('print-recipient-name', '테스트 수령인');
        await enter('print-recipient-phone', '01000000000');
        await enter('print-zip-code', '12345');
        await enter('print-address-line1', '서울 테스트도로 1');
        await enter('print-address-line2', '테스트 동 호수');
        await _reveal(tester, find.text('주문 내용 확인하기'));
        await tester.tap(find.text('주문 내용 확인하기'));
        await tester.pumpAndSettle();
        final payment = find.byKey(const ValueKey('print-checkout-payment'));
        await _reveal(tester, payment, requireHit: false);
        expect(tester.widget<FilledButton>(payment).onPressed, isNull);
        expect(find.text('정식 주문 서비스를 준비하고 있어요.'), findsOneWidget);
        final agreement = find.byKey(
          const ValueKey('print-checkout-agreement'),
        );
        final checkbox = find.descendant(
          of: agreement,
          matching: find.byType(Checkbox),
        );
        await _reveal(tester, checkbox);
        expect(tester.widget<Checkbox>(checkbox).value, isFalse);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(checkbox).value, isTrue);
        await _reveal(tester, payment, requireHit: false);
        expect(tester.widget<FilledButton>(payment).onPressed, isNull);
        await _reveal(tester, find.text('배송지 수정'));
        await tester.tap(find.text('배송지 수정'));
        await tester.pumpAndSettle();
        final nameField = find.byKey(const ValueKey('print-recipient-name'));
        await _reveal(tester, nameField);
        final input = tester.widget<TextFormField>(nameField);
        expect(input.controller!.text, '테스트 수령인');
        expect(forbiddenPayCalls, 0);
        expect(find.byType(PrintOrderCheckoutScreen), findsOneWidget);
        _noRouteException(tester, 'completed route assertions');
        await _dispose(tester);
      },
      skip: !kIsWeb,
    );
  }

  _routeTest(
    'actual short web checkout reveals its first validation error without losing input',
    (tester) async {
      var forbiddenPayCalls = 0;
      await _mount(
        tester,
        PrintOrderCheckoutScreen(
          albumId: 7,
          albumTitle: '우리의 여행',
          initialQuote: _quote(),
          reviewedRevision: printCheckoutRevision(_snapshot()),
          onPay: (_) async {
            forbiddenPayCalls++;
            return null;
          },
        ),
        orders: orders,
        auth: auth,
        size: const Size(1024, 600),
      );
      final zip = find.byKey(const ValueKey('print-zip-code'));
      final address = find.byKey(const ValueKey('print-address-line1'));
      await _reveal(tester, zip);
      await tester.enterText(zip, '12345');
      await _reveal(tester, address);
      await tester.enterText(address, '서울 테스트도로 1');
      final next = find.text('주문 내용 확인하기');
      await _reveal(tester, next);
      final name = find.byKey(const ValueKey('print-recipient-name'));
      expect(
        name.hitTestable(),
        findsNothing,
        reason:
            'The user is at the bottom of a form with missing upper fields.',
      );
      await tester.tap(next);
      await tester.pumpAndSettle();
      // Deliberately do not reveal this target in the test: the route must
      // bring the first invalid field and its message into view itself.
      expect(name.hitTestable(), findsOneWidget);
      expect(find.text('받는 분 이름을 입력해주세요.').hitTestable(), findsOneWidget);
      expect(find.text('010으로 시작하는 휴대폰 번호 11자리를 입력해주세요.'), findsOneWidget);
      final nameRect = tester.getRect(name);
      expect(nameRect.center.dy, inInclusiveRange(0, 600));
      expect(tester.widget<TextFormField>(zip).controller!.text, '12345');
      expect(
        tester.widget<TextFormField>(address).controller!.text,
        '서울 테스트도로 1',
      );
      expect(
        find.byKey(const ValueKey('print-checkout-payment')),
        findsNothing,
      );
      expect(forbiddenPayCalls, 0);
      verify(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).called(1);
      _noRouteException(tester, 'web first validation error is visible');
      await _dispose(tester);
    },
    skip: !kIsWeb,
  );

  for (final state in ['FINAL', 'PLANNED', 'PENDING_SUPPLIER_QUOTE']) {
    for (final preview in [true, false]) {
      _routeTest(
        'web ${preview ? 'preview' : 'checkout'} labels $state independently of closed sales',
        (tester) async {
          final amount = state == 'FINAL'
              ? 57900
              : state == 'PLANNED'
              ? 58900
              : 87900;
          final notice = state == 'PENDING_SUPPLIER_QUOTE'
              ? '이 사양의 제작비 확인이 필요하여 아직 판매가를 정하지 않았습니다.'
              : state == 'PLANNED'
              ? '업체 제작비를 반영한 예정 판매가이며 현재 결제는 열리지 않습니다.'
              : '기본 배송비를 포함한 판매가입니다. 현재 실제 결제는 열리지 않습니다.';
          final quote = OrderQuoteResult.fromJson({
            'pageCount': 20,
            'amount': amount,
            'basePages': 20,
            'basePrice': amount,
            'sourcePageCount': 1, 'addedBlankPageCount': 19,
            'productCode': 'REDP_200_SOFT', 'retailPriceStatus': state,
            // Contradictory positive/verified pending data must remain hidden.
            'supplierCostVerified': true, 'shippingCostVerified': true,
            'packagingCostVerified': true, 'shippingIncluded': true,
            'priceIsEstimate': state != 'FINAL',
            'pricePolicyVersion': 'local-price-$state',
            'priceNotice': notice, 'specMissing': true,
          });
          when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
            (_) async => PrintCheckoutReadiness(
              canPay: false,
              status: 'PREPARING',
              reasonCode: 'print_sales_not_ready',
              message: '정식 주문 서비스를 준비하고 있어요.',
              quote: quote,
            ),
          );
          var forbiddenPayCalls = 0;
          await _mount(
            tester,
            preview
                ? const PrintOrderPreviewScreen(
                    albumId: 7,
                    albumTitle: '우리의 여행',
                  )
                : PrintOrderCheckoutScreen(
                    albumId: 7,
                    albumTitle: '우리의 여행',
                    initialQuote: quote,
                    reviewedRevision: printCheckoutRevision(_snapshot()),
                    onPay: (_) async {
                      forbiddenPayCalls++;
                      return null;
                    },
                  ),
            orders: orders,
            auth: auth,
            size: const Size(1024, 600),
          );
          if (!preview && state == 'FINAL') {
            for (final field in {
              'print-recipient-name': '테스트 수령인',
              'print-recipient-phone': '01000000000',
              'print-zip-code': '12345',
              'print-address-line1': '서울 테스트도로 1',
            }.entries) {
              final input = find.byKey(ValueKey(field.key));
              await _reveal(tester, input);
              await tester.enterText(input, field.value);
              await tester.pump();
            }
            await _reveal(tester, find.text('주문 내용 확인하기'));
            await tester.tap(find.text('주문 내용 확인하기'));
            await tester.pumpAndSettle();
            final payment = find.byKey(
              const ValueKey('print-checkout-payment'),
            );
            await _reveal(tester, payment, requireHit: false);
            expect(tester.widget<FilledButton>(payment).onPressed, isNull);
          }
          final value = state == 'PENDING_SUPPLIER_QUOTE'
              ? '가격 확인 필요'
              : state == 'FINAL'
              ? '57,900원'
              : '58,900원';
          await _reveal(tester, find.text(value), requireHit: false);
          expect(
            find.text(state == 'PLANNED' ? '예정 판매가' : '판매가'),
            findsOneWidget,
          );
          expect(find.text(notice), findsOneWidget);
          expect(find.text('견적 확인 중'), findsNothing);
          expect(find.text('87,900원'), findsNothing);
          expect(find.text('57,900원 예정'), findsNothing);
          expect(
            find.byKey(const ValueKey('print-checkout-payment')),
            !preview && state == 'FINAL' ? findsOneWidget : findsNothing,
          );
          expect(forbiddenPayCalls, 0);
          _noRouteException(tester, '$state price display with sales closed');
          await _dispose(tester);
        },
        skip: !kIsWeb,
      );
    }
  }

  _routeTest(
    'web preview refreshes the displayed price on focus without reloading artwork',
    (tester) async {
      var quote = _quote(retailPriceStatus: 'PLANNED', version: 'planned-v1');
      when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
        (_) async => PrintCheckoutReadiness(
          canPay: false,
          status: 'PREPARING',
          reasonCode: 'print_sales_not_ready',
          message: '정식 주문 서비스를 준비하고 있어요.',
          quote: quote,
          reviewedRevision: printCheckoutRevision(_snapshot()),
          reviewedSpecRevision: printSpecRevision(quote.printSpec),
        ),
      );
      await _mount(
        tester,
        const PrintOrderPreviewScreen(albumId: 7, albumTitle: '우리의 여행'),
        orders: orders,
        auth: auth,
      );
      await _reveal(tester, find.text('49,900원'), requireHit: false);
      quote = _quote(
        amount: 59900,
        version: 'planned-v2',
        retailPriceStatus: 'PLANNED',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('59,900원'), requireHit: false);
      expect(find.text('49,900원'), findsNothing);
      expect(find.text('예정 판매가'), findsOneWidget);
      expect(find.textContaining('판매가 안내가 갱신되었습니다'), findsOneWidget);
      verify(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).called(2);
      verify(() => orders.fetchPrintPreviewSnapshot(albumId: 7)).called(1);
      _noRouteException(tester, 'focus updates price without fetching artwork');
      await _dispose(tester);
    },
    skip: !kIsWeb,
  );

  _routeTest('web preview hides a stale price if focus refresh fails', (
    tester,
  ) async {
    await _mount(
      tester,
      const PrintOrderPreviewScreen(albumId: 7, albumTitle: '우리의 여행'),
      orders: orders,
      auth: auth,
    );
    when(
      () => orders.fetchPrintCheckoutReadiness(albumId: 7),
    ).thenThrow(StateError('offline'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    final failure = find.byKey(
      const ValueKey('print-preview-price-refresh-error'),
    );
    await _reveal(tester, failure, requireHit: false);
    expect(find.textContaining('최신 판매가를 확인하지 못했어요'), findsOneWidget);
    expect(find.text('49,900원'), findsNothing);
    expect(find.text('가격 확인 필요'), findsOneWidget);
    verify(() => orders.fetchPrintPreviewSnapshot(albumId: 7)).called(1);
    _noRouteException(tester, 'failed price refresh is handled and closed');
    await _dispose(tester);
  }, skip: !kIsWeb);

  for (final priceChange in [true, false]) {
    _routeTest(
      'web checkout focus refresh resets consent after ${priceChange ? 'price' : 'version only'} change and preserves delivery',
      (tester) async {
        var quote = _quote(retailPriceStatus: 'PLANNED', version: 'planned-v1');
        when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
          (_) async => PrintCheckoutReadiness(
            canPay: false,
            status: 'PREPARING',
            reasonCode: 'print_sales_not_ready',
            message: '정식 주문 서비스를 준비하고 있어요.',
            quote: quote,
            reviewedRevision: printCheckoutRevision(_snapshot()),
            reviewedSpecRevision: printSpecRevision(quote.printSpec),
          ),
        );
        var forbiddenPayCalls = 0;
        await _mount(
          tester,
          PrintOrderCheckoutScreen(
            albumId: 7,
            albumTitle: '우리의 여행',
            initialQuote: quote,
            reviewedRevision: printCheckoutRevision(_snapshot()),
            onPay: (_) async {
              forbiddenPayCalls++;
              return null;
            },
          ),
          orders: orders,
          auth: auth,
        );
        for (final field in {
          'print-recipient-name': '테스트 수령인',
          'print-recipient-phone': '01000000000',
          'print-zip-code': '12345',
          'print-address-line1': '서울 테스트도로 1',
        }.entries) {
          final input = find.byKey(ValueKey(field.key));
          await _reveal(tester, input);
          await tester.enterText(input, field.value);
          await tester.pump();
        }
        await _reveal(tester, find.text('주문 내용 확인하기'));
        await tester.tap(find.text('주문 내용 확인하기'));
        await tester.pumpAndSettle();
        final agreement = find.byKey(
          const ValueKey('print-checkout-agreement'),
        );
        await _reveal(tester, agreement);
        await tester.tap(agreement);
        await tester.pump();
        expect(tester.widget<CheckboxListTile>(agreement).value, isTrue);
        quote = _quote(
          amount: priceChange ? 59900 : 49900,
          version: 'planned-v2',
          retailPriceStatus: 'PLANNED',
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(agreement).value, isFalse);
        await _reveal(
          tester,
          find.text(priceChange ? '59,900원' : '49,900원'),
          requireHit: false,
        );
        expect(find.textContaining('제작 금액이 갱신되었습니다'), findsOneWidget);
        expect(find.textContaining('테스트 수령인'), findsOneWidget);
        expect(find.textContaining('서울 테스트도로 1'), findsOneWidget);
        final payment = find.byKey(const ValueKey('print-checkout-payment'));
        await _reveal(tester, payment, requireHit: false);
        expect(tester.widget<FilledButton>(payment).onPressed, isNull);
        expect(forbiddenPayCalls, 0);
        verify(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).called(3);
        // Initial and explicit review read the artwork; focus uses the
        // server's revision without reloading it a third time.
        verify(() => orders.fetchPrintPreviewSnapshot(albumId: 7)).called(2);
        _noRouteException(
          tester,
          'updated catalog requires fresh review consent',
        );
        await _dispose(tester);
      },
      skip: !kIsWeb,
    );
  }

  _routeTest(
    'actual narrow preview keeps page navigation and final actions reachable',
    (tester) async {
      await _mount(
        tester,
        const PrintOrderPreviewScreen(albumId: 7, albumTitle: '우리의 여행'),
        orders: orders,
        auth: auth,
        size: const Size(390, 500),
      );
      expect(find.text('인쇄 미리보기'), findsWidgets);
      final next = find.byTooltip('다음 페이지');
      await _reveal(tester, next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.textContaining('내지 1 / 20'), findsOneWidget);
      expect(find.byKey(const ValueKey('print-preview-page')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('print-continue-to-delivery')),
        findsNothing,
      );
      final edit = find.text('앨범 계속 편집하기');
      await _reveal(tester, edit);
      expect(edit.hitTestable(), findsOneWidget);
      expect(find.byType(PrintOrderCheckoutScreen), findsNothing);
      _noRouteException(tester, 'completed route assertions');
      await _dispose(tester);
    },
    skip: !kIsWeb,
  );
}

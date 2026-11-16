import 'file:///tmp/snapfit-checkout-design-20261116/audit_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_checkout_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/print_payment_service.dart';
import 'package:snap_fit/features/profile/data/print_prepayment_package_service.dart';
import 'package:snap_fit/features/profile/data/print_order_request_repository.dart';
import 'package:snap_fit/features/profile/data/portone_payment_launcher.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';

class _Orders extends Mock implements OrderRepository {}

class _Auth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async => const UserInfo(
    id: 'fixture-owner',
    name: '고객',
    email: 'owner@example.com',
    provider: 'EMAIL',
  );
}

OrderQuoteResult _quote({int amount = 49900}) => OrderQuoteResult.fromJson({
  'amount': amount,
  'pageCount': 20,
  'basePages': 20,
  'basePrice': amount,
  'sourcePageCount': 20,
  'addedBlankPageCount': 0,
  'productCode': 'REDP_200X150_SOFT',
  'supplierCostVerified': true,
  'shippingCostVerified': true,
  'packagingCostVerified': true,
  'shippingIncluded': true,
  'pricePolicyVersion': 'confirmed-test-v1',
});

// Valid normalized cover layers use an existing bundled photo; no network source.
Map<String, dynamic> _snapshot() => {
  'album': {
    'id': 7,
    'title': '우리가 함께한 가을',
    'ratio': '4:3',
    'cover_theme': 'classic',
    'cover_layers_json': {
      'pages': [
        {
          'index': 0,
          'isCover': true,
          'backgroundColor': '#FFF7F4EC',
          'layers': [
            {
              'id': 'qa-cover-photo',
              'type': 'IMAGE',
              'zIndex': 0,
              'x': 0.0, 'y': 0.0, 'width': 1.0, 'height': 0.78,
              'scale': 1.0, 'rotation': 0.0, 'opacity': 1.0,
              'payload': {
                'imageUrl': 'asset:assets/templates/original_editorial/images/couple_walk.png',
                'previewUrl': 'asset:assets/templates/original_editorial/images/couple_walk.png',
                'imageBackground': 'none',
                'imageTemplate': 'none',
              },
            },
            {
              'id': 'qa-cover-title',
              'type': 'TEXT',
              'zIndex': 1,
              'x': 0.055, 'y': 0.835, 'width': 0.9, 'height': 0.125,
              'scale': 1.0, 'rotation': 0.0, 'opacity': 1.0,
              'payload': {
                'text': '우리가 함께한 가을',
                'textAlign': 'center',
                'textStyle': {
                  'fontFamily': 'NotoSans',
                  'fontSizeRatio': 0.058,
                  'fontWeight': 6,
                  'color': '#FF3D433D',
                },
              },
            },
          ],
        },
      ],
    },
  },
  'pages': [],
};

PrintCheckoutReadiness _readiness({bool canPay = true, int amount = 49900}) =>
    PrintCheckoutReadiness(
      canPay: canPay,
      status: canPay ? 'READY' : 'PREPARING',
      reasonCode: canPay ? '' : 'print_sales_not_ready',
      message: canPay ? '' : '정식 주문 서비스를 준비하고 있어요.',
      quote: _quote(amount: amount),
      environment: canPay ? 'production' : 'unavailable',
    );

void main() {
 setUpAll(auditFonts);
  late _Orders orders;
  setUpAll(
    () => registerFallbackValue(
      const PrintCheckoutRequest(
        albumId: 7,
        reviewedRevision: '',
        amount: 49900,
        recipientName: '',
        recipientPhone: '',
        zipCode: '',
        addressLine1: '',
        addressLine2: '',
      ),
    ),
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orders = _Orders();
    when(() => orders.fetchMyPrintOrderProgress('paid-order')).thenAnswer(
      (_) async => const PrintOrderProgress(
        orderId: 'paid-order',
        customerStage: 'PAID',
        preflightPassed: false,
        requiresAction: false,
      ),
    );
    when(
      () => orders.printPaymentOwnerId(),
    ).thenAnswer((_) async => 'fixture-owner');
    when(
      () => orders.fetchPrintPreviewSnapshot(albumId: 7),
    ).thenAnswer((_) async => _snapshot());
    when(
      () => orders.fetchPrintCheckoutReadiness(albumId: 7),
    ).thenAnswer((_) async => _readiness());
  });

  Future<void> pump(
    WidgetTester tester, {
    Future<PrintPaidReceipt?> Function(PrintCheckoutRequest request)? onPay,
    PortOnePaymentLauncher? launch,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool dark = false,
    PrintPrepaymentPackageService? packages,
    PrintOrderRequestRepository? orderRequests,
    String Function()? requestId,
    Widget? home,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Warm the exact resized image before any widget starts it in fake time.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    Object? photoError;
    await tester.runAsync(() => precacheImage(
      ResizeImage.resizeIfNeeded(128, null,
        const AssetImage('assets/templates/original_editorial/images/couple_walk.png')),
      tester.element(find.byType(SizedBox).first),
      onError: (error, _) => photoError = error,
    ));
    expect(photoError, isNull);
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orders),
          authViewModelProvider.overrideWith(_Auth.new),
          if (orderRequests != null)
            printOrderRequestRepositoryProvider.overrideWithValue(
              orderRequests,
            ),
          if (launch != null)
            portOnePaymentLauncherProvider.overrideWithValue(launch),
          printPaymentServiceProvider.overrideWith(
            (ref) => PrintPaymentService(
              repository: orders,
              requestId:
                  requestId ?? () => '00000000-0000-4000-8000-000000000000',
              prepaymentPackages: packages,
              orderRequests: orderRequests,
            ),
          ),
        ],
        child: MaterialApp(
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: auditFrame(child!),
          ),
          home:
              home ??
              PrintOrderCheckoutScreen(
                albumId: 7,
                albumTitle: '우리가 함께한 가을',
                initialQuote: _quote(),
                reviewedRevision: printCheckoutRevision(_snapshot()),
                onPay: onPay ?? (_) async => null,
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

  }

  Future<void> field(WidgetTester tester, String key, String value) async {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        120,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump();
  }

  Future<void> validDelivery(WidgetTester tester) async {
    await field(tester, 'print-recipient-name', '테스트 수령인');
    await field(tester, 'print-recipient-phone', '01000000000');
    await field(tester, 'print-zip-code', '12345');
    await field(tester, 'print-address-line1', '서울 테스트도로 1');
    await field(tester, 'print-address-line2', '테스트 동 호수');
  }

  Future<void> review(WidgetTester tester) async {
    await tester.ensureVisible(find.text('주문 내용 확인하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('주문 내용 확인하기'));
    await tester.pumpAndSettle();
  }

  Future<void> agree(WidgetTester tester) async {
    for (final key in [
      'print-checkout-agreement',
      'print-checkout-policy-agreement',
      'print-checkout-custom-production-agreement',
    ]) {
      final checkbox = find.byKey(ValueKey(key));
      if (checkbox.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          checkbox,
          120,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      await tester.ensureVisible(checkbox);
      await tester.pump();
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
    }
  }

  Future<void> top(WidgetTester tester) async {
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 150,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  testWidgets('capture checkout delivery light phone 390x844', (tester) async {
    await pump(tester);
    await auditCapture(tester, '01-checkout-delivery-390-light');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('capture checkout review top light phone 390x844', (tester) async {
    await pump(tester);
    await validDelivery(tester);
    await review(tester);
    await top(tester);
    await auditCapture(tester, '02-checkout-review-top-390-light');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('capture checkout consents light phone 390x844', (tester) async {
    await pump(tester);
    await validDelivery(tester);
    await review(tester);
    await show(tester, 'print-checkout-consents');
    await auditCapture(tester, '03-checkout-three-consents-390-light');
    await show(tester, 'print-checkout-custom-production-details');
    await tester.tap(find.byKey(const ValueKey('print-checkout-custom-production-details')));
    await tester.pumpAndSettle();
    await show(tester, 'print-checkout-custom-production-details');
    await auditCapture(tester, '04-checkout-custom-consent-expanded-390-light');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('capture checkout small dark phone 320x568 scale 1.6', (tester) async {
    await pump(tester, size: const Size(320, 568), dark: true, textScale: 1.6);
    await validDelivery(tester);
    await review(tester);
    await top(tester);
    await auditCapture(tester, '05-checkout-review-320-dark-text160');
    await show(tester, 'print-checkout-agreement');
    await auditCapture(tester, '06-checkout-consents-320-dark-text160');
    await show(tester, 'print-checkout-custom-production-agreement');
    await auditCapture(tester, '07-checkout-consents-bottom-320-dark-text160');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('capture checkout landscape 844x390 scale 1.8', (tester) async {
    await pump(tester, size: const Size(844, 390), textScale: 1.8);
    await validDelivery(tester);
    await review(tester);
    await top(tester);
    await auditCapture(tester, '08-checkout-summary-844-landscape-text180');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

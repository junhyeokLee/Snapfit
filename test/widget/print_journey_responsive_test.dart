import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_checkout_screen.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_complete_screen.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';

class _Orders extends Mock implements OrderRepository {}

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

final _quote = OrderQuoteResult.fromJson({
  'amount': 49900,
  'pageCount': 24,
  'basePages': 24,
  'basePrice': 49900,
  'sourcePageCount': 24,
  'addedBlankPageCount': 0,
  'productCode': 'REDP_200X150_SOFT',
  'supplierCostVerified': true,
  'shippingCostVerified': true,
  'packagingCostVerified': true,
  'shippingIncluded': true,
  'pricePolicyVersion': 'responsive-fixture-v1',
});
final _snapshot = <String, dynamic>{
  'album': {'id': 7, 'title': '여름을 오래 간직하는 방법'},
  'pages': [],
};
final _receipt = PrintPaidReceipt.fromOrder(
  OrderHistoryItem(
    orderId: 'SNAPFIT-REVIEW-20261014',
    albumId: 7,
    title: '여름을 오래 간직하는 방법',
    amount: 49900,
    status: 'PAYMENT_COMPLETED',
    statusLabel: '결제완료',
    progress: .25,
    orderedAt: DateTime.utc(2026, 10, 14),
    paymentConfirmedAt: DateTime.utc(2026, 10, 14, 1),
  ),
);

void main() {
  _PaintBinding();
  const exportImages = bool.fromEnvironment('PRINT_JOURNEY_QA');
  final boundary = GlobalKey();
  late _Orders orders;
  var paymentAttempts = 0;

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
    SharedPreferences.setMockInitialValues({});
    paymentAttempts = 0;
    orders = _Orders();
    when(
      () => orders.fetchPrintPreviewSnapshot(albumId: 7),
    ).thenAnswer((_) async => _snapshot);
    when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
      (_) async => PrintCheckoutReadiness(
        canPay: true,
        status: 'READY',
        reasonCode: '',
        message: '',
        quote: _quote,
        environment: 'production',
      ),
    );
    when(
      () => orders.searchAddress(keyword: any(named: 'keyword')),
    ).thenThrow(StateError('fixture_search_unavailable'));
  });

  void metrics(WidgetTester tester, Size size, {double keyboard = 0}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = size.width > size.height
        ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
        : const FakeViewPadding(top: 24, bottom: 34);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  void resetMetrics(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
  }

  Widget checkout() => PrintOrderCheckoutScreen(
    albumId: 7,
    albumTitle: '여름을 오래 간직하는 방법',
    initialQuote: _quote,
    reviewedRevision: printCheckoutRevision(_snapshot),
    onPay: (_) async {
      paymentAttempts++;
      return null;
    },
  );

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    bool dark = false,
    double scale = 1.3,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orders),
          visibleOrderOwnerProvider.overrideWithValue('responsive-owner'),
        ],
        child: MaterialApp(
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder checkoutScroll() => find
      .descendant(
        of: find.byKey(const PageStorageKey('print-checkout-content')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> visible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        100,
        scrollable: checkoutScroll(),
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    for (final entry in {
      'print-recipient-name': '김하늘',
      'print-recipient-phone': '01000000000',
      'print-zip-code': '12345',
      'print-address-line1': '서울특별시 테스트도로 14',
      'print-address-line2': '101동 202호',
    }.entries) {
      final field = find.byKey(ValueKey(entry.key));
      await visible(tester, field);
      await tester.enterText(field, entry.value);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> review(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, '주문 내용 확인하기');
    await visible(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('주문 내용 확인'), findsOneWidget);
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark,
  ) async {
    expect(tester.takeException(), isNull, reason: name);
    if (!exportImages) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
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

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('print journey renders safe at $size dark=$dark', (
        tester,
      ) async {
        resetMetrics(tester);
        metrics(tester, size);
        await mount(tester, checkout(), dark: dark);
        await capture(tester, 'checkout-delivery', size, dark);
        await fill(tester);
        await review(tester);
        await capture(tester, 'checkout-review', size, dark);
        final payment = find.byKey(const ValueKey('print-checkout-payment'));
        expect(
          tester.getBottomRight(payment).dy,
          lessThanOrEqualTo(size.height - (size.width > size.height ? 24 : 34)),
        );
        await visible(tester, payment);
        expect(tester.widget<FilledButton>(payment).onPressed, isNull);
        final agreement = find.byKey(
          const ValueKey('print-checkout-agreement'),
        );
        await visible(tester, agreement);
        await tester.tap(agreement);
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(payment).onPressed, isNotNull);
        expect(paymentAttempts, 0);

        await tester.pumpWidget(const SizedBox());
        when(
          () => orders.fetchMyPrintOrderProgress(_receipt.orderId),
        ).thenAnswer(
          (_) async => PrintOrderProgress(
            orderId: _receipt.orderId,
            customerStage: 'PAID',
            preflightPassed: false,
            requiresAction: false,
          ),
        );
        await mount(
          tester,
          PrintOrderCompleteScreen(receipt: _receipt),
          dark: dark,
        );
        await capture(tester, 'print-paid-progress', size, dark);
        await tester.pumpWidget(const SizedBox());
        when(
          () => orders.fetchMyPrintOrderProgress(_receipt.orderId),
        ).thenAnswer(
          (_) async => PrintOrderProgress(
            orderId: _receipt.orderId,
            customerStage: 'SHIPPING',
            preflightPassed: true,
            requiresAction: false,
            filesReadyAt: DateTime.utc(2026, 10, 14, 2),
            vendorAcceptedAt: DateTime.utc(2026, 10, 14, 3),
            fileCheckedAt: DateTime.utc(2026, 10, 14, 4),
            productionStartedAt: DateTime.utc(2026, 10, 14, 5),
            shippedAt: DateTime.utc(2026, 10, 14, 6),
            courier: '검토용 택배',
            trackingNumber: '000000000000',
          ),
        );
        await mount(
          tester,
          PrintOrderCompleteScreen(receipt: _receipt),
          dark: dark,
        );
        await capture(tester, 'print-shipping-progress', size, dark);
        await tester.ensureVisible(
          find.byKey(const ValueKey('print-progress-배송 완료')),
        );
        await tester.pumpAndSettle();
        await capture(tester, 'print-shipping-detail', size, dark);
        expect(find.text('검토용 택배 · 000000000000'), findsOneWidget);
        if (size.width > size.height) {
          final action = find.widgetWithText(FilledButton, '주문 내역 확인하기');
          expect(
            tester.getBottomRight(action).dy,
            lessThanOrEqualTo(size.height - 24),
          );
          expect(tester.getTopLeft(action).dx, greaterThanOrEqualTo(32));
        }
        await tester.pumpWidget(const SizedBox());
      });

      for (final size in [
        const Size(320, 568),
        const Size(648, 320),
        const Size(844, 390),
      ]) {
        testWidgets(
          'large accessible text keeps checkout and progress usable at $size',
          (tester) async {
            resetMetrics(tester);
            metrics(tester, size);
            await mount(tester, checkout(), dark: true, scale: 1.8);
            await fill(tester);
            await review(tester);
            final agreement = find.byKey(
              const ValueKey('print-checkout-agreement'),
            );
            await visible(tester, agreement);
            await tester.tap(agreement);
            await tester.pumpAndSettle();
            final payment = find.byKey(
              const ValueKey('print-checkout-payment'),
            );
            expect(tester.widget<FilledButton>(payment).onPressed, isNotNull);
            expect(
              tester.getBottomRight(payment).dy,
              lessThanOrEqualTo(
                size.height - (size.width > size.height ? 24 : 34),
              ),
            );
            expect(paymentAttempts, 0);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            when(
              () => orders.fetchMyPrintOrderProgress(_receipt.orderId),
            ).thenAnswer(
              (_) async => PrintOrderProgress(
                orderId: _receipt.orderId,
                customerStage: 'PAID',
                preflightPassed: false,
                requiresAction: false,
              ),
            );
            await mount(
              tester,
              PrintOrderCompleteScreen(receipt: _receipt),
              dark: true,
              scale: 1.8,
            );
            final stage = find.byKey(
              const ValueKey('print-progress-제작사 주문 접수'),
            );
            await tester.ensureVisible(stage);
            await tester.pumpAndSettle();
            expect(
              find.descendant(of: stage, matching: find.text('대기')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }

  testWidgets(
    'delivery draft, active field and final agreement survive rotations',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester, checkout(), scale: 1.5);
      await fill(tester);
      final field = find.byKey(const ValueKey('print-address-line2'));
      await visible(tester, field);
      await tester.tap(field);
      await tester.pump();
      final editable = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      final focus = tester.widget<EditableText>(editable).focusNode;
      expect(focus.hasFocus, isTrue);
      metrics(tester, const Size(648, 320), keyboard: 140);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text, '101동 202호');
      expect(tester.widget<EditableText>(editable).focusNode, same(focus));
      expect(focus.hasFocus, isTrue);
      await visible(tester, field);
      expect(tester.getBottomRight(field).dy, lessThanOrEqualTo(180));
      FocusManager.instance.primaryFocus?.unfocus();
      metrics(tester, const Size(648, 320));
      await tester.pumpAndSettle();
      await review(tester);
      final agreement = find.byKey(const ValueKey('print-checkout-agreement'));
      await visible(tester, agreement);
      await tester.tap(agreement);
      await tester.pumpAndSettle();
      metrics(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      await visible(tester, agreement);
      expect(tester.widget<CheckboxListTile>(agreement).value, isTrue);
      expect(find.text('주문 내용 확인'), findsOneWidget);
      expect(find.textContaining('김하늘'), findsOneWidget);
      expect(paymentAttempts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    testWidgets(
      'address search failure scrolls safely with keyboard at $size',
      (tester) async {
        resetMetrics(tester);
        metrics(tester, size);
        await mount(tester, checkout(), dark: true, scale: 1.5);
        final search = find.widgetWithText(OutlinedButton, '주소 검색');
        await visible(tester, search);
        await tester.tap(search);
        await tester.pumpAndSettle();
        final keyword = find.byKey(
          const ValueKey('print-address-search-keyword'),
        );
        await tester.enterText(keyword, '테스트도로');
        metrics(tester, size, keyboard: 140);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '검색'));
        await tester.pumpAndSettle();
        expect(find.textContaining('배송지 화면에서 직접 입력해주세요'), findsOneWidget);
        await capture(tester, 'checkout-address-keyboard', size, true);
        expect(
          tester.getBottomRight(keyword).dy,
          lessThanOrEqualTo(size.height - 140),
        );
        await tester.tap(find.byTooltip('닫기'));
        metrics(tester, size);
        await tester.pumpAndSettle();
        await fill(tester);
        await review(tester);
        expect(paymentAttempts, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'address search selection survives rotation and preserves recipient',
    (tester) async {
      resetMetrics(tester);
      metrics(tester, const Size(390, 844));
      when(() => orders.searchAddress(keyword: '테스트도로')).thenAnswer(
        (_) async => const AddressSearchResult(
          page: 1,
          totalCount: 1,
          items: [
            AddressSearchItem(
              zipCode: '54321',
              roadAddress: '서울특별시 테스트도로 99',
              roadAddressPart1: '서울특별시 테스트도로 99',
              roadAddressPart2: '',
              jibunAddress: '',
            ),
          ],
        ),
      );
      await mount(tester, checkout());
      await fill(tester);
      final search = find.widgetWithText(OutlinedButton, '주소 검색');
      await visible(tester, search);
      await tester.tap(search);
      await tester.pumpAndSettle();
      final keyword = find.byKey(
        const ValueKey('print-address-search-keyword'),
      );
      await tester.enterText(keyword, '테스트도로');
      metrics(tester, const Size(740, 360));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(keyword).controller!.text, '테스트도로');
      await tester.tap(find.widgetWithText(FilledButton, '검색'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('서울특별시 테스트도로 99'));
      await tester.pumpAndSettle();
      final zip = find.byKey(const ValueKey('print-zip-code'));
      final address = find.byKey(const ValueKey('print-address-line1'));
      expect(tester.widget<TextFormField>(zip).controller!.text, '54321');
      expect(
        tester.widget<TextFormField>(address).controller!.text,
        '서울특별시 테스트도로 99',
      );
      await review(tester);
      expect(find.textContaining('김하늘'), findsOneWidget);
      expect(find.textContaining('[54321] 서울특별시 테스트도로 99'), findsOneWidget);
      expect(paymentAttempts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('paid progress does not restart or invent stages when rotating', (
    tester,
  ) async {
    resetMetrics(tester);
    metrics(tester, const Size(390, 844));
    when(() => orders.fetchMyPrintOrderProgress(_receipt.orderId)).thenAnswer(
      (_) async => PrintOrderProgress(
        orderId: _receipt.orderId,
        customerStage: 'FILE_CHECKING',
        preflightPassed: true,
        requiresAction: false,
        filesReadyAt: DateTime.utc(2026, 10, 14, 2),
        vendorAcceptedAt: DateTime.utc(2026, 10, 14, 3),
      ),
    );
    await mount(
      tester,
      PrintOrderCompleteScreen(receipt: _receipt),
      dark: true,
      scale: 1.5,
    );
    metrics(tester, const Size(844, 390));
    await tester.pumpAndSettle();
    final stage = find.byKey(const ValueKey('print-progress-책 제작'));
    await tester.ensureVisible(stage);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: stage, matching: find.text('대기')),
      findsOneWidget,
    );
    expect(find.text('제작사 파일 확인 중'), findsOneWidget);
    metrics(tester, const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.text('제작사 파일 확인 중'), findsOneWidget);
    verify(() => orders.fetchMyPrintOrderProgress(_receipt.orderId)).called(1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

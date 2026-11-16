import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_checkout_screen.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';

import 'audit_support.dart';

class _CheckoutOrders extends Mock implements OrderRepository {}

void main() {
  for (final scenario in [
    (id: 'normal', prefix: '', size: const Size(390, 844), textScale: 1.0),
    (
      id: 'compact',
      prefix: 'compact/',
      size: const Size(320, 568),
      textScale: 1.0,
    ),
    (id: 'large', prefix: 'large/', size: const Size(390, 844), textScale: 1.6),
  ]) {
    testWidgets('audit native checkout missing name visibility ${scenario.id}', (
      tester,
    ) async {
      auditViewport(tester, size: scenario.size);
      final orders = _CheckoutOrders();
      var paymentAttempts = 0;
      final snapshot = <String, dynamic>{
        'album': {'id': 7, 'title': '여름을 오래 간직하는 방법'},
        'pages': [],
      };
      final quote = OrderQuoteResult.fromJson({
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
        'pricePolicyVersion': 'checkout-audit-fixture-v1',
      });
      when(
        () => orders.fetchPrintPreviewSnapshot(albumId: 7),
      ).thenAnswer((_) async => snapshot);
      when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
        (_) async => PrintCheckoutReadiness(
          canPay: true,
          status: 'READY',
          reasonCode: '',
          message: '',
          quote: quote,
          environment: 'production',
        ),
      );

      // 실제 주문 서비스 대신 호출 횟수만 세는 콜백으로 결제 경로를 막는다.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(orders),
            visibleOrderOwnerProvider.overrideWithValue('checkout-audit-owner'),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SnapFitTheme.light().copyWith(
              splashFactory: NoSplash.splashFactory,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.textScale)),
              child: auditFrame(child!),
            ),
            home: PrintOrderCheckoutScreen(
              albumId: 7,
              albumTitle: '여름을 오래 간직하는 방법',
              initialQuote: quote,
              reviewedRevision: printCheckoutRevision(snapshot),
              onPay: (_) async {
                paymentAttempts++;
                return null;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('print-checkout-content')),
            matching: find.byType(Scrollable),
          )
          .first;
      final name = find.byKey(const ValueKey('print-recipient-name'));
      final button = find.widgetWithText(FilledButton, '주문 내용 확인하기');

      Future<void> reveal(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(finder, 100, scrollable: scroll);
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }

      for (final entry in {
        'print-recipient-phone': '01000000000',
        'print-zip-code': '12345',
        'print-address-line1': '서울특별시 테스트도로 14',
        'print-address-line2': '101동 202호',
      }.entries) {
        final field = find.byKey(ValueKey(entry.key));
        await reveal(field);
        await tester.enterText(field, entry.value);
        await tester.pump();
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await reveal(name);
      expect(tester.widget<TextFormField>(name).controller!.text, isEmpty);
      await auditCapture(
        tester,
        '${scenario.prefix}04-checkout-filled-name-empty',
      );

      await reveal(button);
      final beforeOffset = tester
          .state<ScrollableState>(scroll)
          .position
          .pixels;
      final beforeViewport = tester.getRect(scroll);
      final beforeButton = tester.getRect(button);
      expect(beforeViewport.contains(beforeButton.center), isTrue);
      await auditCapture(
        tester,
        '${scenario.prefix}05-checkout-before-continue',
      );

      await tester.tap(button);
      await tester.pumpAndSettle();
      final error = find.text('받는 분 이름을 입력해주세요.');
      expect(error, findsOneWidget);
      expect(find.text('주문 내용 확인'), findsNothing);
      expect(paymentAttempts, 0);
      for (final key in [
        'print-recipient-phone',
        'print-zip-code',
        'print-address-line1',
      ]) {
        final state = tester.state<FormFieldState<String>>(
          find.byKey(ValueKey(key)),
        );
        expect(state.errorText, isNull, reason: '$key는 유효한 합성 입력이다.');
      }

      final errorRect = tester.getRect(error);
      final viewportRect = tester.getRect(scroll);
      final afterOffset = tester.state<ScrollableState>(scroll).position.pixels;
      final editableName = tester.widget<EditableText>(
        find.descendant(of: name, matching: find.byType(EditableText)),
      );
      List<double> rectValues(Rect value) => [
        value.left,
        value.top,
        value.right,
        value.bottom,
      ];
      final errorCenterVisible = viewportRect.contains(errorRect.center);
      final errorIntersectsViewport = viewportRect.overlaps(errorRect);

      // 후보를 단정하는 assert 대신 실제 위치를 기록해 자동 이동도 그대로 드러낸다.
      debugPrint(
        'CHECKOUT_AUDIT ${jsonEncode({'scenario': scenario.id, 'width': scenario.size.width, 'height': scenario.size.height, 'textScale': scenario.textScale, 'beforeScrollOffset': beforeOffset, 'afterScrollOffset': afterOffset, 'viewportRect': rectValues(viewportRect), 'beforeButtonRect': rectValues(beforeButton), 'nameErrorRect': rectValues(errorRect), 'nameErrorCenterVisible': errorCenterVisible, 'nameErrorIntersectsViewport': errorIntersectsViewport, 'nameHasFocus': editableName.focusNode.hasFocus, 'candidateReproduced': !errorIntersectsViewport, 'paymentAttempts': paymentAttempts})}',
      );
      await auditCapture(
        tester,
        '${scenario.prefix}06-checkout-after-continue',
      );

      // 사용자가 위로 돌아가 오류를 찾는 상태까지 같은 실제 화면에서 확인한다.
      await reveal(error);
      final revealedViewport = tester.getRect(scroll);
      final revealedError = tester.getRect(error);
      expect(revealedViewport.contains(revealedError.center), isTrue);
      await auditCapture(
        tester,
        '${scenario.prefix}07-checkout-name-error-revealed',
      );
      debugPrint(
        'CHECKOUT_AUDIT_REVEALED ${jsonEncode({'scenario': scenario.id, 'width': scenario.size.width, 'height': scenario.size.height, 'textScale': scenario.textScale, 'scrollOffset': tester.state<ScrollableState>(scroll).position.pixels, 'viewportRect': rectValues(revealedViewport), 'nameErrorRect': rectValues(revealedError), 'nameErrorCenterVisible': true, 'paymentAttempts': paymentAttempts})}',
      );
      expect(paymentAttempts, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}

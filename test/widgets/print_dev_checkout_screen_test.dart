import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/presentation/views/print_dev_checkout_screen.dart';
import 'package:snap_fit/features/profile/data/portone_payment_launcher.dart';
import 'package:snap_fit/features/profile/data/print_dev_checkout.dart';
import 'package:snap_fit/features/profile/domain/portone_payment.dart';

import '../unit/print_dev_checkout_test.dart' as fixture;

class _Service extends Mock implements PrintDevCheckoutService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'SDK success remains TEST pending and never confirms payment from the app',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _Service();
      final prepared = PrintDevCheckoutSession.fromJson(fixture.devResponse());
      final ready = PrintDevCheckoutSession.fromJson(
        fixture.devResponse(packageState: 'READY'),
      );
      final authorized = PrintDevCheckoutSession.fromJson(
        fixture.devResponse(packageState: 'READY', sdk: fixture.devSdk()),
      );
      registerFallbackValue(prepared);
      when(() => service.resume()).thenAnswer((_) async => null);
      when(() => service.sdkStarted()).thenAnswer((_) async => false);
      when(
        () => service.prepare(
          albumId: 69,
          reviewedRevision: fixture.devRevision,
          recipient: any(named: 'recipient'),
        ),
      ).thenAnswer((_) async => prepared);
      when(
        () => service.prepareFiles(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async => ready);
      when(() => service.authorize(any())).thenAnswer((_) async => authorized);
      when(() => service.assertCanLaunch(any())).thenAnswer((_) async {});
      var launched = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            printDevAdminAccessProvider.overrideWithValue(true),
            printDevCheckoutServiceProvider.overrideWithValue(service),
            portOnePaymentLauncherProvider.overrideWithValue((
              context,
              sdk,
            ) async {
              expect(sdk.environment, 'test');
              expect(sdk.paymentId, fixture.devPayment);
              launched++;
              return PortOneSdkResult.fromCallback({
                'paymentId': fixture.devPayment,
              }, sdk);
            }),
          ],
          child: MaterialApp(
            home: PrintDevCheckoutScreen(
              albumId: 69,
              albumTitle: '합성80쪽',
              reviewedRevision: fixture.devRevision,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      for (final entry in [
        '테스트',
        '01000000000',
        '12345',
        '합성 주소',
        '',
        '',
      ].indexed) {
        await tester.enterText(fields.at(entry.$1), entry.$2);
      }
      await tester.tap(find.byKey(const ValueKey('print-dev-prepare')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('print-dev-test-pay')));
      await tester.pumpAndSettle();
      expect(launched, 1);
      expect(find.text('TEST 결제 확인 대기'), findsOneWidget);
      expect(find.textContaining('이제 앱을 닫아도'), findsOneWidget);
      expect(find.text('서버에 저장된 TEST 결제 영수증 확인 완료'), findsNothing);
      verifyNever(() => service.status(any()));
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final safe in [true, false]) {
    testWidgets(
      safe
          ? 'recovery error displays a safe reference code without claiming payment'
          : 'recovery error never echoes unsafe response details',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final service = _Service();
        final code = safe
            ? 'print_validation_busy'
            : 'https://private.example/photo?token=secret';
        when(() => service.resume()).thenThrow(PrintDevCheckoutException(code));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              printDevAdminAccessProvider.overrideWithValue(true),
              printDevCheckoutServiceProvider.overrideWithValue(service),
            ],
            child: MaterialApp(
              home: PrintDevCheckoutScreen(
                albumId: 69,
                albumTitle: '합성80쪽',
                reviewedRevision: fixture.devRevision,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('이전 개발 테스트를 확인하지 못했어요'), findsOneWidget);
        expect(
          find.textContaining('참조 코드:'),
          safe ? findsOneWidget : findsNothing,
        );
        expect(find.textContaining(code), safe ? findsOneWidget : findsNothing);
        verifyNever(() => service.authorize(any()));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

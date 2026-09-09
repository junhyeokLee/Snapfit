import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_unavailable_screen.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';

void main() {
  testWidgets(
    'unavailable print checkout never accesses orders or opens payment',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var repositoryReads = 0;
      Object? routeResult = 'not-returned';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWith((ref) {
              repositoryReads++;
              throw StateError('unavailable checkout must not access orders');
            }),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      routeResult = await Navigator.push<Object?>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrintOrderUnavailableScreen(
                            albumId: 7,
                            albumTitle: '우리의 앨범',
                            pageCount: 20,
                          ),
                        ),
                      );
                    },
                    child: const Text('안내 보기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('안내 보기'));
      await tester.pumpAndSettle();
      expect(find.text('인화 주문 결제 준비 중'), findsOneWidget);
      expect(find.text('우리의 앨범'), findsOneWidget);
      expect(find.text('20페이지'), findsOneWidget);
      expect(find.text('인쇄 미리보기 · PDF 만들기'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('결제 수단'), findsNothing);
      final payment = find.widgetWithText(ElevatedButton, '결제 준비 중');
      expect(tester.widget<ElevatedButton>(payment).onPressed, isNull);
      await tester.tap(payment, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repositoryReads, 0);
      expect(routeResult, 'not-returned');
      expect(find.text('기존 주문 내역 보기'), findsOneWidget);
      await tester.ensureVisible(find.text('제작·배송 참고 안내'));
      expect(find.textContaining('영업일 5~6일'), findsOneWidget);
      expect(find.textContaining('택배 배송 기간 별도'), findsOneWidget);
      expect(find.textContaining('주문번호 스티커'), findsOneWidget);
      expect(repositoryReads, 0);
      await tester.ensureVisible(find.text('앨범으로 돌아가기'));
      await tester.tap(find.text('앨범으로 돌아가기'));
      await tester.pumpAndSettle();
      expect(routeResult, isNull);
      expect(find.text('안내 보기'), findsOneWidget);
      expect(repositoryReads, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

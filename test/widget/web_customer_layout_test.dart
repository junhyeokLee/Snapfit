import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/presentation/widgets/customer_web_page.dart';
import 'package:snap_fit/features/profile/presentation/widgets/web_order_history_row.dart';
import 'package:snap_fit/shared/web/web_design.dart';

const _formKey = ValueKey('customer-form-fixture');
const _summaryKey = ValueKey('customer-summary-fixture');
const _actionKey = ValueKey('customer-summary-action');

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1440, 900),
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: SnapFitWebTheme.from(
          ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            splashFactory: NoSplash.splashFactory,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _longForm(VoidCallback onContinue) => CustomerWebPage(
  title: '배송지 입력',
  description: '책을 받을 분과 배송지 정보를 입력하세요.',
  showNavigation: false,
  scrollBody: true,
  sidebar: CustomerWebNote(
    key: _summaryKey,
    title: '주문 요약',
    message: '제작 구성과 금액을 확인하세요.',
    child: FilledButton(
      key: _actionKey,
      onPressed: onContinue,
      child: const Text('주문 내용 확인하기'),
    ),
  ),
  child: Column(
    key: _formKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final label in ['받는 분', '휴대폰 번호', '도로명 주소', '상세 주소']) ...[
        TextField(decoration: InputDecoration(labelText: label)),
        const SizedBox(height: 48),
      ],
      const Text('입력 내용은 그대로 유지됩니다.'),
    ],
  ),
);

void main() {
  for (final size in const [Size(648, 320), Size(390, 320)]) {
    testWidgets('short web form remains scrollable with keyboard at $size', (
      tester,
    ) async {
      await _mount(
        tester,
        SnapFitWebShell(
          title: '앨범 주문',
          showNavigation: false,
          actions: [
            TextButton(onPressed: () {}, child: const Text('이전')),
            IconButton(
              onPressed: () {},
              tooltip: '최신 주문 정보 확인',
              icon: const Icon(Icons.refresh),
            ),
          ],
          child: ListView(
            key: const ValueKey('short-web-form-scroll'),
            children: const [
              TextField(decoration: InputDecoration(labelText: '받는 분')),
              SizedBox(height: 600),
              TextField(decoration: InputDecoration(labelText: '상세 주소')),
            ],
          ),
        ),
        size: size,
        textScale: 1.5,
      );
      addTearDown(tester.view.resetViewInsets);
      tester.view.viewInsets = const FakeViewPadding(bottom: 140);
      await tester.pumpAndSettle();
      final scrolling = find.descendant(
        of: find.byKey(const ValueKey('short-web-form-scroll')),
        matching: find.byType(Scrollable),
      );
      expect(
        tester
            .state<ScrollableState>(scrolling.first)
            .position
            .viewportDimension,
        greaterThan(40),
      );
      final lastField = find.byType(TextField).last;
      await tester.ensureVisible(lastField);
      await tester.pumpAndSettle();
      expect(lastField.hitTestable(), findsOneWidget);
      await tester.enterText(lastField, '테스트 상세 주소');
      expect(find.text('테스트 상세 주소'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'desktop form precedes the right summary without a second scroll',
    (tester) async {
      await _mount(tester, _longForm(() {}));
      final form = tester.getRect(find.byKey(_formKey));
      final summary = tester.getRect(find.byKey(_summaryKey));
      expect(summary.left, greaterThan(form.right));
      expect(summary.top, lessThanOrEqualTo(form.top));
      expect(form.top - summary.top, lessThanOrEqualTo(64));
      expect(
        find.byKey(const ValueKey('customer-web-page-scroll')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in const [
    Size(1024, 500),
    Size(768, 500),
    Size(390, 500),
    Size(320, 500),
  ]) {
    testWidgets('form actions and summary remain reachable at $size', (
      tester,
    ) async {
      var continued = false;
      await _mount(
        tester,
        _longForm(() => continued = true),
        size: size,
        textScale: size.width == 320 ? 1.6 : 1,
        dark: size.width == 390,
      );
      final pageScroll = find.byKey(const ValueKey('customer-web-page-scroll'));
      await tester.drag(pageScroll, const Offset(0, -1800));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(_actionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_actionKey));
      await tester.pumpAndSettle();
      expect(continued, isTrue);
      expect(find.text('주문 요약'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'narrow bounded history collapses guidance and keeps list usable',
    (tester) async {
      await _mount(
        tester,
        CustomerWebPage(
          title: '포인트',
          showNavigation: false,
          sidebar: const CustomerWebNote(
            title: '사용 가능한 포인트',
            message: '12,000 P',
          ),
          child: ListView(
            children: const [
              Text('이용내역'),
              SizedBox(height: 400),
              Text('마지막 내역'),
            ],
          ),
        ),
        size: const Size(390, 500),
      );
      expect(
        find.byKey(const ValueKey('customer-web-context-toggle')),
        findsOneWidget,
      );
      expect(find.text('12,000 P').hitTestable(), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('customer-web-context-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('12,000 P'), findsOneWidget);
      expect(find.text('이용내역'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  final order = OrderHistoryItem(
    orderId: 'fixture-order-01',
    title: '우리 가족의 기록',
    amount: 49900,
    pageCount: 80,
    status: 'SHIPPING',
    statusLabel: '배송 중',
    progress: .8,
    orderedAt: DateTime(2026, 10, 18),
    courier: 'CJ대한통운',
    trackingNumber: '1234567890',
  );

  for (final width in [1320.0, 884.0, 768.0, 390.0, 320.0]) {
    testWidgets('order row keeps real status and shipment facts at $width', (
      tester,
    ) async {
      var opened = 0;
      await _mount(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: WebOrderHistoryRow(
              order: order,
              amountLabel: '49,900원',
              dateLabel: '2026.10.18',
              artwork: const ColoredBox(color: Colors.teal),
              onTap: () => opened++,
            ),
          ),
        ),
        size: Size(width, 600),
        textScale: width == 320 ? 1.6 : 1,
        dark: width == 390,
      );
      expect(find.text('우리 가족의 기록'), findsOneWidget);
      expect(find.text('배송 중'), findsOneWidget);
      expect(find.text('49,900원'), findsOneWidget);
      expect(find.text('CJ대한통운 · 1234567890'), findsOneWidget);
      expect(
        find.text(order.orderId),
        width >= 820 ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text('우리 가족의 기록'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'actual desktop content width switches to cards for double-sized text',
    (tester) async {
      await _mount(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: WebOrderHistoryRow(
              order: order,
              amountLabel: '49,900원',
              dateLabel: '2026.10.18',
              artwork: const SizedBox(),
              onTap: () {},
            ),
          ),
        ),
        size: const Size(884, 600),
        textScale: 2,
      );
      expect(find.text(order.orderId), findsNothing);
      expect(find.text('배송 중'), findsOneWidget);
      expect(find.text('CJ대한통운 · 1234567890'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('payment waiting is never displayed as completed by the row', (
    tester,
  ) async {
    final waiting = OrderHistoryItem(
      orderId: 'waiting-order',
      title: '아직 결제 전',
      amount: 49900,
      status: 'PAYMENT_PENDING',
      statusLabel: '결제 대기',
      progress: 0,
      orderedAt: DateTime(2026, 10, 18),
    );
    await _mount(
      tester,
      Scaffold(
        body: WebOrderHistoryRow(
          order: waiting,
          amountLabel: '49,900원',
          dateLabel: '2026.10.18',
          artwork: const SizedBox(),
          onTap: () {},
        ),
      ),
    );
    expect(find.text('결제 확인 대기'), findsOneWidget);
    expect(find.text('배송 완료'), findsNothing);
    expect(find.text('결제 완료'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

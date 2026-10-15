import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/presentation/widgets/order_album_artwork.dart';
import 'package:snap_fit/features/profile/presentation/views/order_history_screen.dart';

class _Orders extends Mock implements OrderRepository {}

class _Auth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async => const UserInfo(
    id: 'owner',
    name: '고객',
    email: 'owner@example.com',
    provider: 'EMAIL',
  );
  void switchOwner() => state = const AsyncData(
    UserInfo(
      id: 'another-owner',
      name: '다른 고객',
      email: 'another@example.com',
      provider: 'EMAIL',
    ),
  );
}

class _Home extends HomeViewModel {
  @override
  Future<List<Album>> build() async => [];
}

OrderHistoryItem order(
  String id, {
  String status = 'PAYMENT_COMPLETED',
  String fulfillment = 'READY',
}) => OrderHistoryItem(
  orderId: id,
  title: '여행 앨범 $id',
  amount: 59900,
  pageCount: 24,
  status: status,
  statusLabel: switch (status) {
    'SHIPPING' => '배송중',
    'IN_PRODUCTION' => '제작중',
    'PAYMENT_PENDING' => '결제대기',
    _ => '제작 준비중',
  },
  progress: .25,
  orderedAt: DateTime.utc(2026, 10, 15),
  paymentConfirmedAt: status == 'PAYMENT_PENDING'
      ? null
      : DateTime.utc(2026, 10, 15, 1),
  printFulfillmentStatus: fulfillment,
  recipientName: '테스트 고객',
  addressLine1: '테스트 도로 1',
);

PrintOrderProgress progress(String id, String stage) => PrintOrderProgress(
  orderId: id,
  customerStage: stage,
  preflightPassed: true,
  requiresAction: false,
  filesReadyAt: DateTime.utc(2026, 10, 15, 1),
);
OrderPageResult page(List<OrderHistoryItem> items, {bool more = false}) =>
    OrderPageResult(
      items: items,
      page: 0,
      size: 20,
      totalPages: more ? 2 : 1,
      totalElements: items.length,
      hasNext: more,
    );

void main() {
  late _Orders repository;
  late OrderHistoryItem current;
  late String stage;
  var fail = false;
  var detailReads = 0;

  setUp(() {
    repository = _Orders();
    current = order('saved-order');
    stage = 'FILES_READY';
    fail = false;
    detailReads = 0;
    when(
      () => repository.fetchMyOrdersPage(
        statuses: any(named: 'statuses'),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((_) async => page([current]));
    when(() => repository.fetchMyPrintOrder('saved-order')).thenAnswer((
      _,
    ) async {
      detailReads++;
      if (fail) throw StateError('offline');
      return current;
    });
    when(() => repository.fetchMyPrintOrderProgress('saved-order')).thenAnswer((
      _,
    ) async {
      if (fail) throw StateError('offline');
      return progress('saved-order', stage);
    });
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(repository),
          authViewModelProvider.overrideWith(_Auth.new),
          homeViewModelProvider.overrideWith(_Home.new),
          myOrderSummaryProvider.overrideWith(
            (_) async => const OrderSummaryResult(
              paymentPending: 0,
              paymentCompleted: 0,
              inProduction: 0,
              shipping: 0,
              delivered: 0,
              canceled: 0,
              latestUpdatedAt: null,
            ),
          ),
        ],
        child: MaterialApp(
          theme: SnapFitTheme.light(),
          home: const OrderHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('personal-order-saved-order')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'saved paid order follows automatic submission while detail stays open',
    (tester) async {
      await mount(tester);
      await open(tester);
      expect(find.text('자동 발주 대기'), findsWidgets);
      stage = 'FILE_CHECKING';
      current = order('saved-order', fulfillment: 'ACCEPTED');
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('제작사 파일 확인 중'), findsWidgets);
      expect(detailReads, 2);
      stage = 'PRODUCTION_PENDING';
      await tester.tap(find.byKey(const ValueKey('order-detail-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('책 제작 대기'), findsWidgets);
      expect(find.textContaining('앱을 닫아도'), findsWidgets);
      expect(tester.takeException(), isNull);
      await dispose(tester);
    },
  );

  testWidgets(
    'failed refresh keeps last confirmed state without inventing completion',
    (tester) async {
      await mount(tester);
      await open(tester);
      fail = true;
      await tester.tap(find.byKey(const ValueKey('order-detail-refresh')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('order-detail-refresh-error')),
        findsOneWidget,
      );
      expect(find.text('자동 발주 대기'), findsWidgets);
      expect(find.text('책 제작 대기'), findsNothing);
      fail = false;
      stage = 'FILE_CHECKING';
      await tester.tap(find.byKey(const ValueKey('order-detail-refresh')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('order-detail-refresh-error')),
        findsNothing,
      );
      expect(find.text('제작사 파일 확인 중'), findsWidgets);
      await dispose(tester);
    },
  );

  testWidgets('background pauses polling and resume reads same saved order', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    final reads = detailReads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 31));
    expect(detailReads, reads);
    stage = 'PRODUCTION';
    current = order('saved-order', status: 'IN_PRODUCTION');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(detailReads, reads + 1);
    expect(find.text('제작중'), findsWidgets);
    await dispose(tester);
  });

  testWidgets('refresh button does not create concurrent detail requests', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    final pending = Completer<OrderHistoryItem>();
    when(() => repository.fetchMyPrintOrder('saved-order')).thenAnswer((_) {
      detailReads++;
      return pending.future;
    });
    await tester.tap(find.byKey(const ValueKey('order-detail-refresh')));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('order-detail-refresh')),
          )
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 15));
    expect(detailReads, 2);
    pending.complete(current);
    await tester.pumpAndSettle();
    await dispose(tester);
  });

  testWidgets('automatic list refresh preserves scroll position', (
    tester,
  ) async {
    when(
      () => repository.fetchMyOrdersPage(
        statuses: any(named: 'statuses'),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer(
      (_) async => page([for (var i = 0; i < 20; i++) order('row-$i')]),
    );
    await mount(tester);
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -650));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)).first,
    );
    final before = scroll.position.pixels;
    expect(before, greaterThan(0));
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, before);
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });
  testWidgets('account change hides the previous customer order immediately', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    expect(find.text('여행 앨범 saved-order'), findsWidgets);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OrderHistoryScreen)),
    );
    (container.read(authViewModelProvider.notifier) as _Auth).switchOwner();
    await tester.pumpAndSettle();
    expect(find.text('여행 앨범 saved-order'), findsNothing);
    expect(find.textContaining('로그인 계정이 변경'), findsWidgets);
    final reads = detailReads;
    await tester.pump(const Duration(seconds: 30));
    expect(detailReads, reads);
    await dispose(tester);
  });
  testWidgets(
    'SDK session switch hides shipping data before cached profile refreshes',
    (tester) async {
      await mount(tester);
      await open(tester);
      await tester.scrollUntilVisible(
        find.text('테스트 도로 1'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(OrderDetailWorkspace),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      expect(find.text('테스트 도로 1'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OrderHistoryScreen)),
      );
      expect(container.read(authViewModelProvider).asData?.value?.id, 'owner');
      container
          .read(orderSessionOwnerProvider.notifier)
          .observe('another-owner');
      await tester.pumpAndSettle();
      expect(container.read(authViewModelProvider).asData?.value?.id, 'owner');
      expect(find.text('테스트 도로 1'), findsNothing);
      expect(find.text('테스트 고객'), findsNothing);
      expect(find.text('여행 앨범 saved-order'), findsNothing);
      final reads = detailReads;
      await tester.pump(const Duration(seconds: 30));
      expect(detailReads, reads);
      await dispose(tester);
    },
  );
}

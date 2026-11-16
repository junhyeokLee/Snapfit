// 실제 주문 화면의 읽기 전용 상태를 로컬 데이터로 재현한다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/print_dev_checkout.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/features/profile/presentation/views/order_history_screen.dart';
import 'package:snap_fit/features/profile/presentation/widgets/order_album_artwork.dart';

import 'capture_support.dart';

class _Orders extends Mock implements OrderRepository {}

class _Auth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => const UserInfo(
    id: 'audit-order-owner',
    name: '지현',
    email: 'order-audit@example.com',
    provider: 'EMAIL',
  );
}

final _titles = <String>[
  '우리의 여름, 오래 간직할 장면들',
  '제주에서 함께한 다섯 날',
  '민서의 첫 번째 생일',
  '가을 산책의 조각들',
];
final _photos = <String>[
  'ocean_shore',
  'alpine_lake',
  'celebration',
  'forest_trail',
];

Album _album(int index) => Album(
  id: 201 + index,
  userId: 'audit-order-owner',
  title: _titles[index],
  ratio: '1',
  totalPages: 24,
  targetPages: 24,
  createdAt: '2026-11-12T10:00:00',
  coverLayersJson: jsonEncode({
    'pages': [
      {
        'index': 0,
        'isCover': true,
        'backgroundColor': 0xFFF4F3ED,
        'layers': [
          {
            'id': 'order-audit-cover-$index',
            'type': 'image',
            'x': 0.0,
            'y': 0.0,
            'width': 1.0,
            'height': 1.0,
            'rotation': 0.0,
            'payload': {
              'originalUrl': 'asset:assets/frame_preview/${_photos[index]}.jpg',
            },
            'zIndex': 0,
          },
        ],
      },
    ],
  }),
);

class _Home extends HomeViewModel {
  @override
  FutureOr<List<Album>> build() => List.generate(4, _album);
}

OrderHistoryItem _order(int index, String status) => OrderHistoryItem(
  orderId: 'SF-202611${12 - index}-000${index + 1}',
  albumId: 201 + index,
  title: _titles[index],
  amount: [59900, 64900, 59900, 54900][index],
  pageCount: [24, 32, 24, 24][index],
  status: status,
  statusLabel: switch (status) {
    'SHIPPING' => '배송 중',
    'IN_PRODUCTION' => '제작 중',
    'DELIVERED' => '배송 완료',
    _ => '제작 준비 중',
  },
  progress: status == 'DELIVERED' ? 1 : .5,
  orderedAt: DateTime.utc(2026, 11, 12 - index, 3, 10),
  paymentConfirmedAt: DateTime.utc(2026, 11, 12 - index, 3, 12),
  printFulfillmentStatus: switch (status) {
    'SHIPPING' => 'SHIPPED',
    'IN_PRODUCTION' => 'PRODUCTION',
    'DELIVERED' => 'DELIVERED',
    _ => 'READY',
  },
  pricingVersion: 'PRINT_REDP_200_SOFT_V1',
  paymentMethod: '신용카드 · 현대카드',
  recipientName: '김지현',
  recipientPhone: '010-1234-5678',
  zipCode: '04055',
  addressLine1: '서울특별시 마포구 와우산로 94',
  addressLine2: '102동 503호',
  deliveryMemo: '부재 시 문 앞에 놓아 주세요.',
  courier: status == 'SHIPPING' || status == 'DELIVERED' ? 'CJ대한통운' : null,
  trackingNumber: status == 'SHIPPING' || status == 'DELIVERED'
      ? '6890 1234 5678'
      : null,
  printSubmittedAt: DateTime.utc(2026, 11, 12 - index, 3, 20),
  shippedAt: status == 'SHIPPING' || status == 'DELIVERED'
      ? DateTime.utc(2026, 11, 14 - index, 6, 10)
      : null,
  deliveredAt: status == 'DELIVERED'
      ? DateTime.utc(2026, 11, 13, 2, 30)
      : null,
);

final _items = <OrderHistoryItem>[
  _order(0, 'SHIPPING'),
  _order(1, 'IN_PRODUCTION'),
  _order(2, 'PAYMENT_COMPLETED'),
  _order(3, 'DELIVERED'),
];

PrintOrderProgress _progress(OrderHistoryItem order) => PrintOrderProgress(
  orderId: order.orderId,
  customerStage: switch (order.status) {
    'SHIPPING' => 'SHIPPING',
    'IN_PRODUCTION' => 'PRODUCTION',
    'DELIVERED' => 'DELIVERED',
    _ => 'FILES_READY',
  },
  preflightPassed: true,
  requiresAction: false,
  filesReadyAt: order.orderedAt.add(const Duration(minutes: 5)),
  vendorAcceptedAt: order.status == 'PAYMENT_COMPLETED'
      ? null
      : order.orderedAt.add(const Duration(minutes: 10)),
  fileCheckedAt: order.status == 'PAYMENT_COMPLETED'
      ? null
      : order.orderedAt.add(const Duration(hours: 2)),
  productionStartedAt: order.status == 'PAYMENT_COMPLETED'
      ? null
      : order.orderedAt.add(const Duration(hours: 4)),
  shippedAt: order.shippedAt,
  courier: order.courier,
  trackingNumber: order.trackingNumber,
);

void main() {
  late _Orders repository;

  setUpAll(() async {
    await auditFonts();
    // 로컬 이미지 데이터만 미리 읽어 네트워크와 분리한다.
    for (final photo in _photos) {
      await rootBundle.load('assets/frame_preview/$photo.jpg');
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _Orders();
    when(
      () => repository.fetchMyOrdersPage(
        statuses: any(named: 'statuses'),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((invocation) async {
      final statuses = invocation.namedArguments[#statuses] as List<String>;
      final items = statuses.isEmpty
          ? _items
          : _items.where((order) => statuses.contains(order.status)).toList();
      return OrderPageResult(
        items: items,
        page: 0,
        size: 20,
        totalPages: 1,
        totalElements: items.length,
        hasNext: false,
      );
    });
    for (final order in _items) {
      when(() => repository.fetchMyPrintOrder(order.orderId))
          .thenAnswer((_) async => order);
      when(() => repository.fetchMyPrintOrderProgress(order.orderId))
          .thenAnswer((_) async => _progress(order));
    }
  });

  Future<void> mount(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          authViewModelProvider.overrideWith(_Auth.new),
          homeViewModelProvider.overrideWith(_Home.new),
          orderRepositoryProvider.overrideWithValue(repository),
          printDevAdminAccessProvider.overrideWithValue(false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: auditFrame(child!),
            ),
            home: const OrderHistoryScreen(),
          ),
        ),
      ),
    );
    // 표지 큐는 위젯 테스트의 프레임 안에서 만든다.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  Finder detailScroll() => find.descendant(
    of: find.byType(OrderDetailWorkspace),
    matching: find.byType(Scrollable),
  ).last;

  Future<void> open(WidgetTester tester, int index) async {
    final finder = find.byKey(ValueKey('personal-order-${_items[index].orderId}'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('orders shipping list and actual detail', (tester) async {
    auditViewport(tester);
    try {
      await mount(tester);
      await auditCapture(tester, 'orders-01-mixed-list-390');
      await open(tester, 0);
      await auditCapture(tester, 'orders-02-shipping-detail-top-390');
      await tester.drag(detailScroll(), const Offset(0, -300));
      await tester.pumpAndSettle();
      await auditCapture(tester, 'orders-03-shipping-detail-status-390');
      // 조회 버튼은 시각적으로 확인하며 외부 배송 사이트는 열지 않는다.
      await tester.scrollUntilVisible(
        find.text('배송 조회'),
        320,
        scrollable: detailScroll(),
      );
      await auditCapture(tester, 'orders-04-shipping-detail-actions-390');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('orders production detail information', (tester) async {
    auditViewport(tester);
    try {
      await mount(tester);
      await open(tester, 1);
      await tester.drag(detailScroll(), const Offset(0, -300));
      await tester.pumpAndSettle();
      await auditCapture(tester, 'orders-05-production-detail-status-390');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('orders compact large dark list and detail', (tester) async {
    auditViewport(tester, size: const Size(320, 844));
    try {
      await mount(tester, dark: true, scale: 1.6);
      await auditCapture(tester, 'orders-06-mixed-list-320-large-dark');
      await open(tester, 0);
      await auditCapture(tester, 'orders-07-shipping-detail-top-320-large-dark');
      await tester.drag(detailScroll(), const Offset(0, -300));
      await tester.pumpAndSettle();
      await auditCapture(tester, 'orders-08-shipping-detail-status-320-large-dark');
    } finally {
      await unmount(tester);
    }
  });
}

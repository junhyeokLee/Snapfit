import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Tokens extends Mock implements TokenStorage {}

OrderHistoryItem _order({
  String status = 'PAYMENT_COMPLETED',
  String? fulfillment,
  bool paid = true,
}) => OrderHistoryItem(
  orderId: 'customer-order',
  title: '우리 여행',
  amount: 59900,
  pageCount: 24,
  status: status,
  statusLabel: status == 'SHIPPING' ? '배송중' : '결제완료',
  progress: .25,
  orderedAt: DateTime.utc(2026, 10, 15),
  paymentConfirmedAt: paid ? DateTime.utc(2026, 10, 15, 1) : null,
  printFulfillmentStatus: fulfillment,
);

void main() {
  test(
    'legacy UTC dates and explicit UTC dates represent the same instant',
    () {
      OrderHistoryItem parse(String timestamp) => OrderHistoryItem.fromJson({
        'orderId': 'customer-order',
        'orderedAt': timestamp,
        'paymentConfirmedAt': timestamp,
      });
      final explicit = parse('2026-10-15T01:00:00Z');
      final legacy = parse('2026-10-15T01:00:00');
      expect(legacy.orderedAt.isAtSameMomentAs(explicit.orderedAt), isTrue);
      expect(
        legacy.paymentConfirmedAt!.isAtSameMomentAs(
          explicit.paymentConfirmedAt!,
        ),
        isTrue,
      );
    },
  );

  test('unpaid order never displays automatic acceptance or file success', () {
    for (final fulfillment in ['READY', 'ACCEPTED', 'FILE_CHECKED']) {
      final order = _order(
        status: 'PAYMENT_PENDING',
        fulfillment: fulfillment,
        paid: false,
      );
      expect(order.customerStatusLabel, '결제 확인 대기');
      expect(order.customerStatusDescription, contains('아직 결제 완료가 확인되지'));
    }
    expect(
      _order(fulfillment: 'ACCEPTED', paid: false).customerStatusLabel,
      '결제 상태 확인 중',
    );
  });

  test('paid stages distinguish automatic submission from file acceptance', () {
    expect(_order(fulfillment: 'READY').customerStatusLabel, '자동 발주 대기');
    expect(_order(fulfillment: 'SUBMITTED').customerStatusLabel, '제작사 접수 확인 중');
    expect(_order(fulfillment: 'ACCEPTED').customerStatusLabel, '인쇄 파일 확인 중');
    expect(_order(fulfillment: 'FILE_CHECKED').customerStatusLabel, '책 제작 대기');
    expect(_order(fulfillment: 'FILE_ERROR').customerStatusLabel, '주문 확인 중');
    expect(
      _order(fulfillment: 'FILE_ERROR').customerStatusDescription,
      contains('결제한 주문은 보관'),
    );
    expect(
      _order(status: 'SHIPPING', fulfillment: 'FILE_ERROR').customerStatusLabel,
      '배송중',
    );
    expect(_order(status: 'DELIVERED').isFinal, isTrue);
    expect(_order(status: 'PREPARATION_CANCELED', paid: false).isFinal, isTrue);
  });

  group('customer order query isolation', () {
    late HttpServer server;
    late SupabaseClient client;
    late OrderRepository repository;
    late _Tokens tokens;
    late dynamic response;
    late List<Uri> requests;

    setUp(() async {
      requests = [];
      response = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requests.add(request.uri);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      client = SupabaseClient('http://127.0.0.1:${server.port}', 'fixture-key');
      tokens = _Tokens();
      when(() => tokens.getResolvedUserId()).thenAnswer((_) async => 'owner');
      repository = OrderRepository(tokenStorage: tokens, supabase: client);
    });

    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    test(
      'list and summary exclude TEST while retaining legacy null environment',
      () async {
        await repository.fetchMyOrders();
        await repository.fetchMyOrderSummary();
        for (final uri in requests) {
          expect(uri.queryParameters['user_id'], 'eq.owner');
          expect(
            uri.queryParameters['or'],
            '(payment_environment.is.null,payment_environment.neq.test)',
          );
        }
      },
    );

    test(
      'pending/canceled filters cannot overwrite the TEST exclusion',
      () async {
        await repository.fetchMyOrdersPage(
          statuses: [
            'PAYMENT_PENDING',
            'PAYMENT_COMPLETED',
            'PREPARATION_CANCELED',
          ],
        );
        final uri = requests.single;
        expect(uri.queryParameters['user_id'], 'eq.owner');
        final filter = uri.queryParameters['or']!;
        expect(filter, startsWith('(and(or(payment_environment.is.null,'));
        expect(filter, contains('payment_environment.neq.test'));
        expect(filter, contains('status.eq.PAYMENT_PENDING'));
        expect(filter, contains('print_preparation_aborted_at.not.is.null'));
        expect(filter, contains('PAYMENT_COMPLETED'));
      },
    );

    test(
      'another device can query only the saved invoice by order identity',
      () async {
        response = {};
        await expectLater(
          repository.fetchPrintPaymentStatus(orderId: 'ordp_saved-order'),
          throwsFormatException,
        );
        expect(requests.single.path, '/functions/v1/print-order-checkout');
        await expectLater(
          () => repository.fetchPrintPaymentStatus(
            orderId: 'saved-order',
            paymentId: 'other',
          ),
          throwsFormatException,
        );
        expect(requests.length, 1);
      },
    );

    test('direct saved order lookup also refuses a TEST row', () async {
      response = {
        'order_id': 'customer-order',
        'user_id': 'owner',
        'payment_environment': 'test',
        'amount': 59900,
        'status': 'PAYMENT_COMPLETED',
      };
      await expectLater(
        repository.fetchMyPrintOrder('customer-order'),
        throwsFormatException,
      );
    });

    test(
      'account switch cannot publish the previous account order list',
      () async {
        var reads = 0;
        when(
          () => tokens.getResolvedUserId(),
        ).thenAnswer((_) async => reads++ == 0 ? 'owner' : 'different-owner');
        await expectLater(repository.fetchMyOrders(), throwsStateError);
      },
    );
  });
}

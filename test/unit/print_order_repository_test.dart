import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TokenStorage extends Mock implements TokenStorage {}

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late OrderRepository repository;
  late List<
    ({
      String path,
      String method,
      Map<String, String> query,
      Map<String, dynamic> body,
    })
  >
  requests;
  late Object responseBody;
  late int responseStatus;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = [];
    responseStatus = 200;
    responseBody = <String, dynamic>{};
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
      requests.add((
        path: request.uri.path,
        method: request.method,
        query: request.uri.queryParameters,
        body: Map<String, dynamic>.from(body),
      ));
      request.response.statusCode = responseStatus;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(responseBody));
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
    final tokens = _TokenStorage();
    when(() => tokens.getResolvedUserId()).thenAnswer((_) async => 'owner');
    repository = OrderRepository(tokenStorage: tokens, supabase: client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'uses server quote and actual page count instead of local pricing',
    () async {
      responseBody = {
        'pageCount': 20,
        'amount': 44500,
        'basePages': 12,
        'basePrice': 34900,
        'extraPageCount': 8,
        'extraPagePrice': 1200,
      };
      final quote = await repository.fetchOrderQuote(albumId: 1, pageCount: 12);
      expect(quote.pageCount, 20);
      expect(quote.amount, 44500);
      expect(requests.single.path, '/rest/v1/rpc/get_print_order_quote');
    },
  );

  test(
    'order history keeps an unpaid order pending and only reads the current user',
    () async {
      responseBody = [
        {
          'order_id': 'order-a',
          'user_id': 'owner',
          'amount': 39700,
          'page_count': 16,
          'status': 'PAYMENT_PENDING',
          'ordered_at': '2026-09-08T10:00:00Z',
        },
      ];
      final orders = await repository.fetchMyOrders();
      expect(orders.single.orderId, 'order-a');
      expect(orders.single.status, 'PAYMENT_PENDING');
      expect(orders.single.progress, 0);
      expect(orders.single.paymentConfirmedAt, isNull);
      expect(requests.single.path, '/rest/v1/orders');
      expect(requests.single.method, 'GET');
      expect(requests.single.query['user_id'], 'eq.owner');
      expect(requests.single.body, isEmpty);
    },
  );

  test('a failed history request never returns a manufactured order', () async {
    responseStatus = 500;
    responseBody = {'message': 'test server unavailable'};
    await expectLater(
      repository.fetchMyOrders(),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests.single.method, 'GET');
  });
  test(
    'trusted preparation cancellation is separate from unpaid and actual paid history',
    () async {
      Map<String, dynamic> row(
        String id, {
        String status = 'PAYMENT_PENDING',
        Object? abortedAt,
        String? paidAt,
      }) => {
        'order_id': id,
        'user_id': 'owner',
        'amount': 49900,
        'status': status,
        'ordered_at': '2026-10-15T00:00:00Z',
        if (abortedAt != null) 'print_preparation_aborted_at': abortedAt,
        if (paidAt != null) 'payment_confirmed_at': paidAt,
      };
      responseBody = [
        row('aborted', abortedAt: '2026-10-15T00:10:00Z'),
        row(
          'paid',
          status: 'PAYMENT_COMPLETED',
          abortedAt: '2026-10-15T00:10:00Z',
          paidAt: '2026-10-15T00:20:00Z',
        ),
        row(
          'payment-evidence',
          abortedAt: '2026-10-15T00:10:00Z',
          paidAt: '2026-10-15T00:20:00Z',
        ),
        row('invalid-proof', abortedAt: 'not-a-timestamp'),
        row('pending'),
      ];
      final orders = await repository.fetchMyOrders();
      expect(orders[0].status, 'PREPARATION_CANCELED');
      expect(orders[0].statusLabel, '준비 취소');
      expect(orders[0].preparationAbortedAt?.hour, 9);
      expect(orders[0].preparationAbortedAt?.minute, 10);
      expect(orders[0].paymentConfirmedAt, isNull);
      expect(orders[1].status, 'PAYMENT_COMPLETED');
      expect(orders[1].paymentConfirmedAt, isNotNull);
      expect(
        orders.skip(2).map((order) => order.status),
        everyElement('PAYMENT_PENDING'),
      );
      final summary = await repository.fetchMyOrderSummary();
      expect(summary.paymentPending, 3);
      expect(summary.paymentCompleted, 1);
      expect(summary.canceled, 1);
    },
  );

  test(
    'completed history selects aborted preparations by server evidence without inventing a database status',
    () async {
      responseBody = [];
      await repository.fetchMyOrdersPage(
        statuses: ['DELIVERED', 'CANCELED', 'PREPARATION_CANCELED'],
      );
      final query = requests.single.query;
      expect(query['user_id'], 'eq.owner');
      expect(query['or'], contains('status.in.("DELIVERED","CANCELED")'));
      expect(
        query['or'],
        contains(
          'and(status.eq.PAYMENT_PENDING,print_preparation_aborted_at.not.is.null,payment_confirmed_at.is.null)',
        ),
      );
      expect(query['or'], isNot(contains('PREPARATION_CANCELED')));
      expect(query['status'], isNull);
      expect(requests.single.method, 'GET');
    },
  );

  test(
    'payment-pending history excludes aborted preparations while preserving rows with payment evidence',
    () async {
      responseBody = [];
      await repository.fetchMyOrdersPage(
        statuses: ['PAYMENT_PENDING', 'PAYMENT_COMPLETED'],
      );
      final query = requests.single.query;
      expect(query['user_id'], 'eq.owner');
      expect(
        query['or'],
        contains(
          'and(status.eq.PAYMENT_PENDING,or(print_preparation_aborted_at.is.null,payment_confirmed_at.not.is.null))',
        ),
      );
      expect(query['or'], contains('status.in.("PAYMENT_COMPLETED")'));
      expect(requests.single.method, 'GET');
    },
  );
  test('quote retains server product dimensions and estimate status', () async {
    responseBody = {
      'pageCount': 20,
      'amount': 79900,
      'productCode': 'REDP_300_SOFT',
      'productName': '30×30cm 소프트커버 포토북',
      'priceIsEstimate': true,
      'printProduct': {
        'id': 'REDP_300_SOFT',
        'trimWidthMm': 300,
        'trimHeightMm': 300,
      },
      'spec': {
        'id': 'REDP_300_SOFT',
        'interior': {'trimWidthMm': 300, 'trimHeightMm': 300},
      },
    };
    final quote = await repository.fetchOrderQuote(albumId: 1);
    expect(quote.productCode, 'REDP_300_SOFT');
    expect(quote.printProduct['trimWidthMm'], 300);
    expect(quote.priceIsEstimate, isTrue);
    expect(requests.single.body, {'p_album_id': 1, 'p_page_count': null});
  });

  test(
    'planned retail retains confirmed production and uncertain delivery separately',
    () async {
      responseBody = {
        'pageCount': 80,
        'amount': 159900,
        'basePages': 80,
        'basePrice': 159900,
        'extraPageCount': 0,
        'supplierCostVerified': true,
        'shippingCostVerified': false,
        'packagingCostVerified': false,
        'shippingIncluded': true,
        'priceIsEstimate': true,
        'pricePolicyVersion': 'PRINT_REDP_VERIFIED_COMBO_20261013_V1',
        'priceNotice': '배송·포장 비용은 최종 확인 후 확정됩니다.',
      };
      final quote = await repository.fetchOrderQuote(albumId: 1);
      expect(quote.amount, 159900);
      expect(quote.basePages, 80);
      expect(quote.extraPageCount, 0);
      expect(quote.hasPlannedRetailPrice, isTrue);
      expect(quote.shippingIncluded, isTrue);
      expect(quote.shippingCostVerified, isFalse);
      expect(quote.packagingCostVerified, isFalse);
      expect(quote.pricePolicyVersion, 'PRINT_REDP_VERIFIED_COMBO_20261013_V1');
      expect(quote.priceNotice, '배송·포장 비용은 최종 확인 후 확정됩니다.');
    },
  );

  test('unverified and zero quotes never become a customer planned price', () {
    expect(
      OrderQuoteResult.fromJson({'amount': 303900}).hasPlannedRetailPrice,
      isFalse,
    );
    expect(
      OrderQuoteResult.fromJson({
        'amount': 0,
        'supplierCostVerified': true,
      }).hasPlannedRetailPrice,
      isFalse,
    );
  });

  test('mixed paid orders keep the frozen product for admin handoff', () async {
    responseBody = [
      {
        'order_id': 'legacy',
        'pricing_version': 'PRINT_REDP_200_SOFT_V1',
        'print_product_snapshot': {
          'id': 'REDP_300_SOFT',
          'trimWidthMm': 300,
          'trimHeightMm': 300,
        },
      },
      {
        'order_id': 'large',
        'pricing_version': 'PRINT_REDP_MULTISIZE_V2',
        'print_product_snapshot': {
          'id': 'REDP_250X200_SOFT',
          'trimWidthMm': 250,
          'trimHeightMm': 200,
        },
      },
      {'order_id': 'unknown'},
    ];
    final orders = await repository.fetchMyOrders();
    expect(orders[0].printProductLabel, '200×200mm 소프트커버');
    expect(orders[1].printProductLabel, '250×200mm 소프트커버');
    expect(orders[1].printProduct!.id, 'REDP_250X200_SOFT');
    expect(orders[2].printProductLabel, '제작 크기 확인 필요');
  });
  test('hardcover quote without template retains preparation state', () async {
    responseBody = {
      'pageCount': 20,
      'amount': 89900,
      'productCode': 'REDP_250X200_HARD',
      'specMissing': true,
      'spec': null,
      'printProduct': {
        'id': 'REDP_250X200_HARD',
        'trimWidthMm': 250,
        'trimHeightMm': 200,
      },
    };
    final quote = await repository.fetchOrderQuote(albumId: 1);
    expect(quote.specMissing, true);
    expect(quote.printSpec, isEmpty);
    expect(quote.productCode, 'REDP_250X200_HARD');
  });

  test(
    'frozen hard and soft choices remain distinct for admin handoff',
    () async {
      responseBody = [
        {
          'order_id': 'hard',
          'pricing_version': 'PRINT_REDP_COVERTYPE_V3',
          'print_product_snapshot': {
            'id': 'REDP_250_HARD',
            'trimWidthMm': 250,
            'trimHeightMm': 250,
          },
        },
        {
          'order_id': 'soft',
          'pricing_version': 'PRINT_REDP_COVERTYPE_V3',
          'print_product_snapshot': {
            'id': 'REDP_250_SOFT',
            'trimWidthMm': 250,
            'trimHeightMm': 250,
          },
        },
        {
          'order_id': 'bad-legacy',
          'pricing_version': 'PRINT_REDP_MULTISIZE_V2',
          'print_product_snapshot': {
            'id': 'REDP_250_HARD',
            'trimWidthMm': 250,
            'trimHeightMm': 250,
          },
        },
      ];
      final orders = await repository.fetchMyOrders();
      expect(orders[0].printProductLabel, '250×250mm 하드커버');
      expect(orders[1].printProductLabel, '250×250mm 소프트커버');
      expect(orders[2].printProduct, isNull);
    },
  );
}

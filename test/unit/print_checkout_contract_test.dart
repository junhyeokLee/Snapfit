import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/features/profile/domain/print_checkout_consent.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Tokens extends Mock implements TokenStorage {}

Map<String, dynamic> _snapshot({
  String theme = 'classic',
  String caption = '우리 여행',
}) => {
  'album': {
    'id': 9,
    'title': '여행 기록',
    'ratio': '4:3',
    'cover_theme': theme,
    'updated_at': '2026-10-14T00:00:00Z',
    'cover_layers_json': jsonEncode({
      'pages': [
        {
          'index': 0,
          'layers': [
            {'text': caption, 'imageUrl': 'asset://photo'},
          ],
        },
      ],
    }),
  },
  'pages': const [],
};

Map<String, dynamic> _quote({bool estimate = true, bool verified = false}) => {
  'pageCount': 20,
  'amount': 49900,
  'productCode': 'REDP_200X150_SOFT',
  'priceIsEstimate': estimate,
  'supplierCostVerified': true,
  'shippingCostVerified': true,
  'packagingCostVerified': true,
  'pricePolicyVersion': 'verified-combo',
  'spec': {'verified': verified},
};

void main() {
  test(
    'IEEE754 revision matches shared JavaScript fixture and integer doubles',
    () {
      Map<String, dynamic> snapshot(num x) => {
        'album': {
          'id': 9,
          'title': '여행 기록',
          'cover_layers_json': {
            'pages': [
              {
                'index': 0,
                'layers': [
                  {
                    'x': x,
                    'y': 0.125,
                    'rotation': 0,
                    'text': '숫자 · emoji 🖼',
                    'nested': {'z': 3.141592653589793, 'a': 1},
                  },
                ],
              },
            ],
          },
        },
        'pages': [],
      };
      expect(
        printCheckoutRevision(snapshot(1)),
        printCheckoutRevision(snapshot(1.0)),
      );
      expect(
        printCheckoutRevision(snapshot(1)),
        '5e92bae5e676a7bae1356194370ced6b69aa5d74780b30544e8d94761781419e',
      );
      expect(
        printCheckoutRevision(snapshot(1.0000000000000002)),
        isNot(printCheckoutRevision(snapshot(1))),
      );
    },
  );
  test('review revision ignores metadata and JSON key formatting', () {
    final first = _snapshot();
    final second = _snapshot();
    (second['album'] as Map)['updated_at'] = '2026-10-14T00:01:00Z';
    (second['album'] as Map)['cover_layers_json'] = {
      'pages': [
        {
          'layers': [
            {'imageUrl': 'asset://photo', 'text': '우리 여행'},
          ],
          'index': 0,
        },
      ],
    };
    expect(printCheckoutRevision(first), printCheckoutRevision(second));
  });

  test('review revision detects cover theme and artwork changes', () {
    final revision = printCheckoutRevision(_snapshot());
    expect(printCheckoutRevision(_snapshot(theme: 'plain')), isNot(revision));
    expect(printCheckoutRevision(_snapshot(caption: '다른 문구')), isNot(revision));
  });

  test('legacy page image changes cannot reuse review consent', () {
    final first = {
      'album': {
        'id': 9,
        'ratio': '4:3',
        'cover_layers_json': {'layers': []},
      },
      'pages': [
        {'page_index': 0, 'layers_json': '{"imageUrl":"first"}'},
      ],
    };
    final second = {
      ...first,
      'pages': [
        {'page_index': 0, 'layers_json': '{"imageUrl":"second"}'},
      ],
    };
    expect(printCheckoutRevision(first), isNot(printCheckoutRevision(second)));
  });

  test('planned price and even a ready flag cannot open unverified sales', () {
    for (final environment in ['unavailable', 'test', 'production']) {
      final result = PrintCheckoutReadiness.fromJson({
        'canPay': true,
        'status': 'READY',
        'environment': environment,
        'paymentProvider': 'PORTONE',
        'quote': _quote(),
      });
      expect(result.canPay, isFalse);
    }
  });

  test(
    'only an explicit production, exact-cost, verified contract allows payment',
    () {
      final response = {
        'canPay': true,
        'status': 'READY',
        'environment': 'production',
        'paymentProvider': 'PORTONE',
        'quote': _quote(estimate: false, verified: true),
        'reviewedRevision': printCheckoutRevision(_snapshot()),
        'reviewedSpecRevision': printSpecRevision(
          Map<String, dynamic>.from(
            _quote(estimate: false, verified: true)['spec'] as Map,
          ),
        ),
      };
      expect(PrintCheckoutReadiness.fromJson(response).canPay, isTrue);
      expect(
        PrintCheckoutReadiness.fromJson({
          ...response,
          'paymentProvider': 'UNKNOWN',
        }).canPay,
        isFalse,
      );
      expect(
        PrintCheckoutReadiness.fromJson({...response, 'canPay': false}).canPay,
        isFalse,
      );
    },
  );

  test(
    'a pending, canceled or timestamp-less order cannot create a receipt',
    () {
      Map<String, dynamic> order(String status, {String? paidAt}) => {
        'orderId': 'print-order',
        'albumId': 9,
        'title': '여행 기록',
        'amount': 49900,
        'status': status,
        'orderedAt': '2026-10-14T00:00:00Z',
        if (paidAt != null) 'paymentConfirmedAt': paidAt,
      };
      for (final status in ['PAYMENT_PENDING', 'CANCELED', 'UNKNOWN']) {
        expect(
          () => PrintPaidReceipt.fromOrder(
            OrderHistoryItem.fromJson(
              order(status, paidAt: '2026-10-14T00:01:00Z'),
            ),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => PrintPaidReceipt.fromOrder(
          OrderHistoryItem.fromJson(order('PAYMENT_COMPLETED')),
        ),
        throwsFormatException,
      );
      final receipt = PrintPaidReceipt.fromOrder(
        OrderHistoryItem.fromJson(
          order('PAYMENT_COMPLETED', paidAt: '2026-10-14T00:01:00Z'),
        ),
      );
      expect(receipt.orderId, 'print-order');
      expect(receipt.amount, 49900);
    },
  );

  group('authenticated repository contract', () {
    late HttpServer server;
    late SupabaseClient client;
    late OrderRepository repository;
    late Map<String, dynamic> response;
    late List<
      ({String path, String method, Map<String, String> query, String body})
    >
    calls;

    setUp(() async {
      calls = [];
      response = {};
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        calls.add((
          path: request.uri.path,
          method: request.method,
          query: request.uri.queryParameters,
          body: body,
        ));
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      client = SupabaseClient('http://127.0.0.1:${server.port}', 'fixture-key');
      final tokens = _Tokens();
      when(() => tokens.getResolvedUserId()).thenAnswer((_) async => 'owner');
      repository = OrderRepository(tokenStorage: tokens, supabase: client);
    });

    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    test(
      'readiness sends only album identity and shows real server quote',
      () async {
        response = {'canPay': false, 'status': 'PREPARING', 'quote': _quote()};
        final result = await repository.fetchPrintCheckoutReadiness(
          albumId: 9,
          pageCount: 20,
        );
        expect(result.canPay, isFalse);
        expect(result.quote.amount, 49900);
        expect(calls.single.path, '/functions/v1/print-order-checkout');
        expect(jsonDecode(calls.single.body), {
          'action': 'readiness',
          'albumId': 9,
          'pageCount': 20,
        });
      },
    );

    test(
      'checkout sends versioned separate consent beside the frozen order conditions',
      () async {
        const consent = PrintCheckoutConsent(
          orderReviewed: true,
          policyAccepted: true,
          customProductionAccepted: true,
        );
        const requestId = '00000000-0000-4000-8000-000000000000';
        final review = printCheckoutRevision(_snapshot());
        final spec = printSpecRevision({});
        response = {
          'environment': 'production',
          'status': 'PREPARED',
          'orderId': 'ordp_$requestId',
          'paymentId': 'SFP_$requestId',
          'requestId': requestId,
          'albumId': 9,
          'totalAmount': 49900,
          'reviewedSpecRevision': spec,
        };
        await repository.preparePrintPayment(
          requestId: requestId,
          request: PrintCheckoutRequest(
            albumId: 9,
            reviewedRevision: review,
            reviewedSpecRevision: spec,
            amount: 49900,
            recipientName: '수령인',
            recipientPhone: '01000000000',
            zipCode: '12345',
            addressLine1: '테스트 도로',
            addressLine2: '테스트 호수',
            consent: consent,
          ),
        );
        final sent = jsonDecode(calls.single.body) as Map;
        expect(sent['consent'], consent.toJson());
        expect(sent['reviewedRevision'], review);
        expect(sent['reviewedSpecRevision'], spec);
        expect(sent['expectedAmount'], 49900);
        expect((sent['consent'] as Map).containsKey('acceptedAt'), isFalse);
      },
    );

    test(
      'receipt lookup is owner scoped and refuses a wrong amount or owner',
      () async {
        response = {
          'order_id': 'print-order',
          'user_id': 'owner',
          'album_id': 9,
          'amount': 49900,
          'status': 'PAYMENT_COMPLETED',
          'ordered_at': '2026-10-14T00:00:00Z',
          'payment_confirmed_at': '2026-10-14T00:01:00Z',
        };
        final result = await repository.fetchPrintPaidReceipt(
          orderId: 'print-order',
          albumId: 9,
          expectedAmount: 49900,
        );
        expect(result.orderId, 'print-order');
        expect(calls.single.method, 'GET');
        expect(calls.single.query['user_id'], 'eq.owner');
        expect(calls.single.query['order_id'], 'eq.print-order');
        await expectLater(
          repository.fetchPrintPaidReceipt(
            orderId: 'print-order',
            albumId: 9,
            expectedAmount: 100,
          ),
          throwsFormatException,
        );
        response['user_id'] = 'other-user';
        await expectLater(
          repository.fetchPrintPaidReceipt(
            orderId: 'print-order',
            albumId: 9,
            expectedAmount: 49900,
          ),
          throwsFormatException,
        );
      },
    );
    test(
      'production receipt requires live matching payment identity, not a test paid row',
      () async {
        response = {
          'order_id': 'print-order',
          'user_id': 'owner',
          'album_id': 9,
          'amount': 49900,
          'status': 'PAYMENT_COMPLETED',
          'ordered_at': '2026-10-14T00:00:00Z',
          'payment_confirmed_at': '2026-10-14T00:01:00Z',
          'checkout_flow': 'PORTONE_V2_V1',
          'payment_environment': 'live',
          'verified_payment_provider': 'PORTONE',
          'verified_payment_id': 'SFP_fixture',
          'payment_currency': 'KRW',
        };
        Future<PrintPaidReceipt> read() => repository.fetchPrintPaidReceipt(
          orderId: 'print-order',
          albumId: 9,
          expectedAmount: 49900,
          expectedPaymentId: 'SFP_fixture',
        );
        expect((await read()).orderId, 'print-order');
        for (final patch in [
          {'payment_environment': 'test'},
          {'verified_payment_id': 'other'},
          {'verified_payment_provider': 'UNKNOWN'},
          {'payment_currency': 'USD'},
          {'checkout_flow': null},
        ]) {
          final original = Map<String, dynamic>.from(response);
          response.addAll(patch);
          await expectLater(read(), throwsFormatException);
          response = original;
        }
        response['album_id'] = null;
        response['print_content_snapshot'] = {
          'album': {'id': 9},
        };
        expect((await read()).albumId, 9);
        response['print_content_snapshot'] = {
          'album': {'id': 10},
        };
        await expectLater(read(), throwsFormatException);
      },
    );
    test(
      'customer progress sends only owned order identity and keeps milestones separate',
      () async {
        response = {
          'orderId': 'print-order',
          'customerStage': 'FILE_CHECKING',
          'preflightPassed': true,
          'vendorAcceptedAt': '2026-10-14T00:02:00Z',
          'fileCheckedAt': null,
          'productionStartedAt': null,
        };
        final progress = await repository.fetchMyPrintOrderProgress(
          'print-order',
        );
        expect(calls.single.path, '/rest/v1/rpc/fetch_my_print_order_progress');
        expect(jsonDecode(calls.single.body), {'p_order_id': 'print-order'});
        expect(progress.vendorAcceptedAt, isNotNull);
        expect(progress.fileCheckedAt, isNull);
        expect(progress.productionStartedAt, isNull);
        response['orderId'] = 'other-order';
        await expectLater(
          repository.fetchMyPrintOrderProgress('print-order'),
          throwsFormatException,
        );
      },
    );
  });
}

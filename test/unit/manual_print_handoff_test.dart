import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/data/admin_ops_repository.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'ready files remain production preparation until actual vendor acceptance',
    () {
      OrderHistoryItem order(String stage, String status) =>
          OrderHistoryItem.fromJson({
            'orderId': 'o1',
            'status': status,
            'statusLabel': status == 'IN_PRODUCTION' ? '제작중' : '결제완료',
            'printFulfillmentStatus': stage,
            'printCoverPdfPath': 'private/cover.pdf',
            'printInteriorPdfPath': 'private/interior.pdf',
          });
      expect(order('READY', 'PAYMENT_COMPLETED').customerStatusLabel, '제작 준비중');
      expect(
        order('SUBMITTED', 'PAYMENT_COMPLETED').customerStatusLabel,
        '제작 접수 확인중',
      );
      expect(order('ACCEPTED', 'IN_PRODUCTION').customerStatusLabel, '제작중');
      expect(
        order('REVIEW_REQUIRED', 'PAYMENT_COMPLETED').hasPrintFiles,
        isTrue,
      );
      expect(
        order('READY', 'PAYMENT_COMPLETED').fulfillmentConfirmation,
        isEmpty,
      );
    },
  );

  group('private admin handoff', () {
    late HttpServer server;
    late SupabaseClient client;
    late AdminOpsRepository repo;
    late List<
      ({String path, String method, List<int> bytes, String? contentType})
    >
    requests;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      requests = [];
      server.listen((request) async {
        final bytes = await request.fold<List<int>>(
          [],
          (previous, element) => previous..addAll(element),
        );
        requests.add((
          path: request.uri.path,
          method: request.method,
          bytes: bytes,
          contentType: request.headers.contentType?.mimeType,
        ));
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            request.uri.path.contains('/storage/')
                ? {'Key': 'print-packages/object.pdf'}
                : {
                    'orderId': 'o1',
                    'status': 'PAYMENT_COMPLETED',
                    'printFulfillmentStatus': 'READY',
                  },
          ),
        );
        await request.response.close();
      });
      client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
      repo = AdminOpsRepository(supabase: client);
    });
    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    test(
      'uploads two PDFs with signed binary upload and never creates public URLs',
      () async {
        final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7\nfixture'));
        await repo.uploadPrintPdfs(
          upload: {
            'bucket': 'print-packages',
            'cover': {'path': 'o1/cover.pdf', 'token': 'cover-token'},
            'interior': {'path': 'o1/interior.pdf', 'token': 'interior-token'},
          },
          coverPdf: pdf,
          interiorPdf: pdf,
        );
        expect(requests.map((request) => request.method), ['PUT', 'PUT']);
        expect(requests.map((request) => request.path), [
          '/storage/v1/object/upload/sign/print-packages/o1/cover.pdf',
          '/storage/v1/object/upload/sign/print-packages/o1/interior.pdf',
        ]);
        expect(
          requests.every(
            (request) =>
                request.contentType == 'multipart/form-data' &&
                utf8
                    .decode(request.bytes)
                    .contains('content-type: application/pdf'),
          ),
          isTrue,
        );
        expect(
          requests.every(
            (request) =>
                utf8.decode(request.bytes).contains('%PDF-1.7\nfixture'),
          ),
          isTrue,
        );
      },
    );

    test(
      'rejects unexpected storage buckets before sending customer files',
      () async {
        await expectLater(
          repo.uploadPrintPdfs(
            upload: {'bucket': 'public-images'},
            coverPdf: Uint8List(2),
            interiorPdf: Uint8List(2),
          ),
          throwsStateError,
        );
        expect(requests, isEmpty);
      },
    );

    test(
      'package finalization and real vendor submission are separate actions',
      () async {
        final ready = await repo.finalizePrintPackage(
          adminKey: 'admin',
          orderId: 'o1',
          uploadId: 'up1',
          manifest: {'sourceFingerprint': 'frozen', 'pageCount': 20},
        );
        expect(ready.status, 'PAYMENT_COMPLETED');
        var body = jsonDecode(utf8.decode(requests.single.bytes)) as Map;
        expect(body['action'], 'finalizePrintPackage');
        expect(body.containsKey('vendorOrderId'), isFalse);
        await repo.submitPrintVendor(
          adminKey: 'admin',
          orderId: 'o1',
          vendorOrderId: 'actual-vendor-order',
          actualPrintCost: 22000,
          actualShippingCost: 7000,
          actualPackagingCost: 1000,
          fulfillmentMethod: 'REPACK',
          senderLabelConfirmed: false,
          priceSlipOmittedConfirmed: false,
          promotionalMaterialsOmittedConfirmed: false,
          vendorSpecConfirmed: true,
          confirmationNote: '2026-09-08 official template checked',
        );
        body = jsonDecode(utf8.decode(requests.last.bytes)) as Map;
        expect(body['action'], 'submitPrintVendor');
        expect(body['vendorOrderId'], 'actual-vendor-order');
        expect(body['senderLabelConfirmed'], isFalse);
        expect(body['fulfillmentMethod'], 'REPACK');
        expect(body.containsKey('status'), isFalse);
      },
    );
    test(
      'hardcover template geometry is sent intact and soft overrides stay compatible',
      () async {
        final geometry = {
          'construction': 'casewrap',
          'widthMm': 461.10,
          'heightMm': 196,
          'bleedMm': 20,
          'front': {'xMm': 235.10, 'yMm': 20, 'widthMm': 206, 'heightMm': 156},
          'back': {'xMm': 20, 'yMm': 20, 'widthMm': 206, 'heightMm': 156},
          'trim': {'xMm': 20, 'yMm': 20, 'widthMm': 421.10, 'heightMm': 156},
        };
        await repo.configurePrintSpec(
          adminKey: 'admin',
          orderId: 'o1',
          spineMm: 9.10,
          evidence: 'Official hard200x150 20p guide',
          coverGeometry: geometry,
        );
        var body = jsonDecode(utf8.decode(requests.last.bytes)) as Map;
        expect(body['action'], 'configurePrintSpec');
        expect(body['coverGeometry'], geometry);
        await repo.configurePrintSpec(
          adminKey: 'admin',
          orderId: 'o1',
          spineMm: 7.22,
          evidence: 'Official soft200x150 20p guide',
        );
        body = jsonDecode(utf8.decode(requests.last.bytes)) as Map;
        expect(body.containsKey('coverGeometry'), isFalse);
      },
    );
  });
}

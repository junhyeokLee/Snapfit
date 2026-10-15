import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/print_prepayment_package_service.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';

class _Orders extends Mock implements OrderRepository {}

class _Exporter extends AlbumPrintExporter {
  int calls = 0;
  int interiorBytes = 10;
  int coverBytes = 4;
  Map<String, dynamic>? generatedSnapshot;
  Map<String, String>? generatedUrls;

  @override
  Future<AlbumPrintExport> generate({
    required Map<String, dynamic> snapshot,
    required PrintVendorSpec spec,
    Map<String, String> sourceUrls = const {},
    void Function(int, int)? onProgress,
  }) async {
    calls++;
    generatedSnapshot = snapshot;
    generatedUrls = sourceUrls;
    onProgress?.call(1, 21);
    return AlbumPrintExport(
      coverPdf: coverBytes == 4
          ? Uint8List.fromList([37, 80, 68, 70])
          : Uint8List(coverBytes),
      interiorPdf: Uint8List(interiorBytes),
      interiorPageCount: 20,
      report: {
        'renderer': 'flutter-layer-builder-raster-v1',
        'specVersion': spec.specVersion,
        'pageCount': 20,
        'dpi': 300,
        'missingAssets': <String>[],
        'colorSpace': 'sRGB',
        'iccProfileEmbedded': true,
      },
    );
  }
}

const _rid = '00000000-0000-4000-8000-000000000000';
const _pid = 'SFP_00000000-0000-4000-8000-000000000000';
const _fp = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
final _snapshot = <String, dynamic>{
  'album': {
    'id': 7,
    'title': '확정 앨범',
    'ratio': '1',
    'cover_theme': 'classic',
    'cover_layers_json': {
      'pages': [
        {'index': 0, 'isCover': true, 'layers': []},
        {'index': 1, 'isCover': false, 'layers': []},
      ],
    },
  },
  'pages': <dynamic>[],
};
final _spec = <String, dynamic>{
  'id': 'REDP_200_SOFT',
  'specVersion': 'test-approved-v1',
  'pageCount': 20,
  'verified': true,
  'interior': {'trimWidthMm': 200, 'trimHeightMm': 200, 'bleedMm': 5},
  'cover': {
    'widthMm': 417.22,
    'heightMm': 210,
    'front': {'xMm': 212.22, 'yMm': 5, 'widthMm': 200, 'heightMm': 200},
    'back': {'xMm': 5, 'yMm': 5, 'widthMm': 200, 'heightMm': 200},
  },
};
final _request = PrintCheckoutRequest(
  albumId: 7,
  reviewedRevision: printCheckoutRevision(_snapshot),
  reviewedSpecRevision: printSpecRevision(_spec),
  amount: 49900,
  recipientName: '테스트',
  recipientPhone: '01000000000',
  zipCode: '12345',
  addressLine1: '합성 주소',
  addressLine2: '',
  deliveryMemo: '',
);

PrintPaymentInvoice _invoice({bool ready = false}) =>
    PrintPaymentInvoice.fromJson({
      'environment': 'production',
      'orderId': 'owned-order',
      'paymentId': _pid,
      'requestId': _rid,
      'albumId': 7,
      'totalAmount': 49900,
      'status': 'PREPARED',
      'printPackageReady': ready,
      'reviewedRevision': _request.reviewedRevision,
      'reviewedSpecRevision': _request.reviewedSpecRevision,
    });

Map<String, dynamic> _identity() => {
  'orderId': 'owned-order',
  'paymentId': _pid,
  'requestId': _rid,
  'albumId': 7,
  'reviewedRevision': _request.reviewedRevision,
  'reviewedSpecRevision': _request.reviewedSpecRevision,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Orders orders;
  late _Exporter exporter;
  late PrintPrepaymentPackageService service;
  late List<String> events;
  late String owner;
  late String packageState;
  late String finalizedState;
  late int maximumBytes;
  late int maximumCoverBytes;
  late bool multipartUploads;
  late bool partVerified;
  late Map<String, dynamic> frozenSnapshot;
  Map<String, dynamic>? fileRecovery;
  setUpAll(() {
    registerFallbackValue(_request);
    registerFallbackValue(_invoice());
    registerFallbackValue(Uint8List(0));
  });
  setUp(() {
    orders = _Orders();
    exporter = _Exporter();
    service = PrintPrepaymentPackageService(
      repository: orders,
      exporter: exporter,
    );
    events = [];
    owner = 'owner';
    packageState = 'NONE';
    finalizedState = 'READY';
    maximumBytes = 500000000;
    maximumCoverBytes = 150000000;
    multipartUploads = false;
    partVerified = true;
    fileRecovery = null;
    frozenSnapshot = {
      ..._snapshot,
      'printProduct': {
        'id': 'REDP_200_SOFT',
        'trimWidthMm': 200,
        'trimHeightMm': 200,
      },
    };
    when(() => orders.printPaymentOwnerId()).thenAnswer((_) async => owner);
    when(
      () => orders.invokePrintPrepaymentPackage(
        invoice: any(named: 'invoice'),
        action: 'snapshot',
      ),
    ).thenAnswer((_) async {
      events.add('snapshot');
      return {
        ..._identity(),
        'snapshot': frozenSnapshot,
        'spec': _spec,
        'sourceUrls': {'photo-source': 'https://example.com/signed-original'},
        'sourceFingerprint': _fp,
        'maxFileBytes': maximumBytes,
        'maxCoverFileBytes': maximumCoverBytes,
        'packageState': packageState,
        if (fileRecovery != null) ...{
          'packageId': '00000000-0000-4000-8000-000000000007',
          'fileRecovery': fileRecovery,
        },
      };
    });
    when(
      () => orders.invokePrintPrepaymentPackage(
        invoice: any(named: 'invoice'),
        action: 'uploads',
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((invocation) async {
      events.add('uploads');
      final payload = invocation.namedArguments[#payload] as Map;
      return {
        ..._identity(),
        'sourceFingerprint': _fp,
        'maxFileBytes': maximumBytes,
        'maxCoverFileBytes': maximumCoverBytes,
        'packageId': 'package-id',
        'bucket': 'print-files',
        'cover': {'path': 'owned/cover.pdf', 'token': 'cover-token'},
        'interior': multipartUploads
            ? {
                'parts': [
                  for (
                    var index = 0;
                    index < (payload['interior']['parts'] as List).length;
                    index++
                  )
                    {
                      'index': index,
                      'path': 'owned/interior/part-$index',
                      'token': 'interior-part-$index-token',
                      'byteLength':
                          payload['interior']['parts'][index]['bytes'],
                      'sha256': payload['interior']['parts'][index]['sha256'],
                    },
                ],
              }
            : {'path': 'owned/interior.pdf', 'token': 'interior-token'},
      };
    });
    when(
      () => orders.uploadPrintPrepaymentFile(
        bucket: any(named: 'bucket'),
        path: any(named: 'path'),
        token: any(named: 'token'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((invocation) async {
      events.add('upload:${invocation.namedArguments[#path]}');
    });
    when(
      () => orders.invokePrintPrepaymentPackage(
        invoice: any(named: 'invoice'),
        action: 'finalize',
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((invocation) async {
      final body = invocation.namedArguments[#payload] as Map;
      final partIndex = body['partIndex'];
      events.add(
        partIndex == null
            ? 'finalize:${body['kind']}'
            : 'finalize:${body['kind']}:$partIndex',
      );
      return {
        ..._identity(),
        if (partIndex != null) ...{
          'partVerified': partVerified,
          'partIndex': partIndex,
          'kind': body['kind'],
        },
        'packageState': body['kind'] == 'cover' ? 'UPLOADING' : finalizedState,
      };
    });
    when(
      () => orders.preparePrintPayment(
        requestId: _rid,
        request: any(named: 'request'),
      ),
    ).thenAnswer((_) async {
      events.add('ready-invoice');
      return _invoice(ready: true);
    });
  });

  test(
    'renders frozen artwork once, uploads both hashes and verifies each before SDK issuance',
    () async {
      final progress = <String>[];
      final result = await service.prepare(
        invoice: _invoice(),
        request: _request,
        onProgress: progress.add,
      );
      expect(result.printPackageReady, isTrue);
      expect(exporter.calls, 1);
      expect(exporter.generatedSnapshot, frozenSnapshot);
      expect(exporter.generatedSnapshot?['printProduct'], isNotNull);
      expect(
        exporter.generatedUrls?['photo-source'],
        'https://example.com/signed-original',
      );
      expect(events, [
        'snapshot',
        'uploads',
        'upload:owned/cover.pdf',
        'finalize:cover',
        'upload:owned/interior.pdf',
        'finalize:interior',
        'ready-invoice',
      ]);
      final payload =
          verify(
                () => orders.invokePrintPrepaymentPackage(
                  invoice: any(named: 'invoice'),
                  action: 'uploads',
                  payload: captureAny(named: 'payload'),
                ),
              ).captured.single
              as Map;
      expect(payload['cover'], {
        'bytes': 4,
        'sha256': sha256.convert([37, 80, 68, 70]).toString(),
      });
      expect((payload['manifest'] as Map)['sourceFingerprint'], _fp);
      expect((payload['manifest'] as Map).containsKey('cover'), isFalse);
      expect(progress.last, '파일 검수 완료 · 결제 준비 중');
    },
  );

  test(
    'partial cover recovery observes its immutable duplicate through actual finalize',
    () async {
      when(
        () => orders.uploadPrintPrepaymentFile(
          bucket: any(named: 'bucket'),
          path: any(named: 'path'),
          token: any(named: 'token'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer((invocation) async {
        final path = invocation.namedArguments[#path] as String;
        events.add('upload:$path');
        if (path.endsWith('cover.pdf')) {
          throw const StorageException(
            'Already exists',
            statusCode: '409',
            error: 'Duplicate',
          );
        }
      });
      final ready = await service.prepare(
        invoice: _invoice(),
        request: _request,
      );
      expect(ready.printPackageReady, isTrue);
      expect(events, [
        'snapshot',
        'uploads',
        'upload:owned/cover.pdf',
        'finalize:cover',
        'upload:owned/interior.pdf',
        'finalize:interior',
        'ready-invoice',
      ]);
    },
  );

  test(
    'lost inner upload response can complete only through server-verified READY',
    () async {
      when(
        () => orders.uploadPrintPrepaymentFile(
          bucket: any(named: 'bucket'),
          path: any(named: 'path'),
          token: any(named: 'token'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer((invocation) async {
        final path = invocation.namedArguments[#path] as String;
        events.add('upload:$path');
        if (path.endsWith('interior.pdf'))
          throw StateError('upload_response_lost');
      });
      final ready = await service.prepare(
        invoice: _invoice(),
        request: _request,
      );
      expect(ready.printPackageReady, isTrue);
      expect(events.sublist(events.length - 2), [
        'finalize:interior',
        'ready-invoice',
      ]);
    },
  );

  test(
    'uncertain upload plus unconfirmed stored file cannot issue an SDK invoice',
    () async {
      when(
        () => orders.uploadPrintPrepaymentFile(
          bucket: any(named: 'bucket'),
          path: any(named: 'path'),
          token: any(named: 'token'),
          bytes: any(named: 'bytes'),
        ),
      ).thenThrow(StateError('upload_response_lost'));
      when(
        () => orders.invokePrintPrepaymentPackage(
          invoice: any(named: 'invoice'),
          action: 'finalize',
          payload: any(named: 'payload'),
        ),
      ).thenThrow(
        const PrintCheckoutApiException('print_upload_hash_mismatch', 409),
      );
      await expectLater(
        service.prepare(invoice: _invoice(), request: _request),
        throwsA(
          isA<PrintCheckoutApiException>().having(
            (e) => e.reasonCode,
            'safe reason',
            'print_upload_not_confirmed',
          ),
        ),
      );
      expect(events, ['snapshot', 'uploads']);
      verifyNever(
        () => orders.preparePrintPayment(
          requestId: _rid,
          request: any(named: 'request'),
        ),
      );
    },
  );

  test(
    'READY package recovery never regenerates or reuploads immutable PDFs',
    () async {
      packageState = 'READY';
      final result = await service.prepare(
        invoice: _invoice(),
        request: _request,
      );
      expect(result.printPackageReady, isTrue);
      expect(exporter.calls, 0);
      expect(events, ['snapshot', 'ready-invoice']);
    },
  );

  for (final state in ['UPLOADING', 'FILES_VERIFIED']) {
    test(
      '$state recovers the original verified upload without rendering new bytes',
      () async {
        packageState = state;
        final originalManifest = {
          'renderer': 'flutter-layer-builder-raster-v1',
          'specVersion': 'test-approved-v1',
          'pageCount': 20,
          'dpi': 300,
          'missingAssets': <String>[],
          'sourceFingerprint': _fp,
          'colorSpace': 'sRGB',
          'iccProfileEmbedded': true,
        };
        fileRecovery = {
          'packageId': '00000000-0000-4000-8000-000000000007',
          'manifest': originalManifest,
        };
        final result = await service.prepare(
          invoice: _invoice(),
          request: _request,
        );
        expect(result.printPackageReady, isTrue);
        expect(exporter.calls, 0);
        expect(events, [
          'snapshot',
          'finalize:cover',
          'finalize:interior',
          'ready-invoice',
        ]);
        final calls = verify(
          () => orders.invokePrintPrepaymentPackage(
            invoice: any(named: 'invoice'),
            action: 'finalize',
            payload: captureAny(named: 'payload'),
          ),
        ).captured.cast<Map>();
        expect(calls, hasLength(2));
        for (final payload in calls) {
          expect(payload['packageId'], '00000000-0000-4000-8000-000000000007');
          expect(payload['manifest'], originalManifest);
        }
      },
    );
  }

  test(
    'an incomplete immutable upload never regenerates or overwrites PDFs',
    () async {
      packageState = 'UPLOADING';
      await expectLater(
        service.prepare(invoice: _invoice(), request: _request),
        throwsA(
          isA<PrintCheckoutApiException>().having(
            (e) => e.reasonCode,
            'safe reason',
            'print_package_partial_upload',
          ),
        ),
      );
      expect(exporter.calls, 0);
      expect(events, ['snapshot']);
    },
  );

  test(
    'a recovery report from another source cannot be finalized or replaced',
    () async {
      packageState = 'UPLOADING';
      fileRecovery = {
        'packageId': '00000000-0000-4000-8000-000000000007',
        'manifest': {'sourceFingerprint': 'wrong-source'},
      };
      await expectLater(
        service.prepare(invoice: _invoice(), request: _request),
        throwsFormatException,
      );
      expect(exporter.calls, 0);
      expect(events, ['snapshot']);
    },
  );

  test(
    'negotiated byte limit stops before storage or payment; quality remains unchanged',
    () async {
      maximumBytes = 9;
      await expectLater(
        service.prepare(invoice: _invoice(), request: _request),
        throwsA(
          isA<PrintPreflightException>().having(
            (e) => e.code,
            'code',
            'print_checkout_pdf_too_large',
          ),
        ),
      );
      expect(exporter.calls, 1);
      expect(events, ['snapshot']);
    },
  );

  test('server cannot silently raise the vendor file limit', () async {
    maximumBytes = 500000001;
    await expectLater(
      service.prepare(invoice: _invoice(), request: _request),
      throwsFormatException,
    );
    expect(exporter.calls, 0);
    expect(events, ['snapshot']);
  });

  test('server cannot silently raise the separate cover limit', () async {
    maximumCoverBytes = 150000001;
    await expectLater(
      service.prepare(invoice: _invoice(), request: _request),
      throwsFormatException,
    );
    expect(exporter.calls, 0);
    expect(events, ['snapshot']);
  });

  test(
    'a package completed during uploads is reused without expecting new write tokens',
    () async {
      when(
        () => orders.invokePrintPrepaymentPackage(
          invoice: any(named: 'invoice'),
          action: 'uploads',
          payload: any(named: 'payload'),
        ),
      ).thenAnswer(
        (_) async => {
          ..._identity(),
          'packageState': 'READY',
          'sourceFingerprint': _fp,
          'maxFileBytes': maximumBytes,
          'maxCoverFileBytes': maximumCoverBytes,
        },
      );
      final ready = await service.prepare(
        invoice: _invoice(),
        request: _request,
      );
      expect(ready.printPackageReady, isTrue);
      expect(exporter.calls, 1);
      expect(events, ['snapshot', 'ready-invoice']);
      verifyNever(
        () => orders.uploadPrintPrepaymentFile(
          bucket: any(named: 'bucket'),
          path: any(named: 'path'),
          token: any(named: 'token'),
          bytes: any(named: 'bytes'),
        ),
      );
    },
  );

  test('incomplete inner inspection never issues SDK invoice', () async {
    finalizedState = 'UPLOADING';
    await expectLater(
      service.prepare(invoice: _invoice(), request: _request),
      throwsStateError,
    );
    expect(events.last, 'finalize:interior');
    expect(events, isNot(contains('ready-invoice')));
  });

  test(
    'a large PDF is uploaded as unchanged views and every part precedes full inspection',
    () async {
      exporter.interiorBytes = 60200362;
      multipartUploads = true;
      final uploaded = <Uint8List>[];
      when(
        () => orders.uploadPrintPrepaymentFile(
          bucket: any(named: 'bucket'),
          path: any(named: 'path'),
          token: any(named: 'token'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer((invocation) async {
        final path = invocation.namedArguments[#path] as String;
        events.add('upload:$path');
        if (path.contains('interior/')) {
          uploaded.add(invocation.namedArguments[#bytes] as Uint8List);
        }
      });
      final ready = await service.prepare(
        invoice: _invoice(),
        request: _request,
      );
      expect(ready.printPackageReady, isTrue);
      expect(uploaded.map((p) => p.length), [
        16000000,
        16000000,
        16000000,
        12200362,
      ]);
      expect(uploaded.map((p) => p.offsetInBytes), [
        0,
        16000000,
        32000000,
        48000000,
      ]);
      final originalStorage = uploaded.first.buffer.asUint8List();
      originalStorage[uploaded[1].offsetInBytes] = 29;
      expect(uploaded[1].first, 29);
      originalStorage[uploaded[1].offsetInBytes] = 0;
      expect(events, [
        'snapshot',
        'uploads',
        'upload:owned/cover.pdf',
        'finalize:cover',
        for (var index = 0; index < 4; index++) ...[
          'upload:owned/interior/part-$index',
          'finalize:interior:$index',
        ],
        'finalize:interior',
        'ready-invoice',
      ]);
      final payload =
          verify(
                () => orders.invokePrintPrepaymentPackage(
                  invoice: any(named: 'invoice'),
                  action: 'uploads',
                  payload: captureAny(named: 'payload'),
                ),
              ).captured.single
              as Map;
      expect(payload['interior']['bytes'], 60200362);
      final declaredParts = payload['interior']['parts'] as List;
      for (var index = 0; index < uploaded.length; index++) {
        expect(
          declaredParts[index]['sha256'],
          sha256.convert(uploaded[index]).toString(),
        );
      }
      expect(exporter.calls, 1);
    },
  );

  test(
    'unverified part stops before another upload, full PDF or SDK',
    () async {
      exporter.interiorBytes = 50000001;
      multipartUploads = true;
      partVerified = false;
      await expectLater(
        service.prepare(invoice: _invoice(), request: _request),
        throwsStateError,
      );
      expect(events.last, 'finalize:interior:0');
      expect(events, isNot(contains('upload:owned/interior/part-1')));
      expect(events, isNot(contains('finalize:interior')));
      expect(events, isNot(contains('ready-invoice')));
    },
  );

  test(
    'a lost part upload response recovers only after its exact server proof',
    () async {
      exporter.interiorBytes = 50000001;
      multipartUploads = true;
      when(
        () => orders.uploadPrintPrepaymentFile(
          bucket: any(named: 'bucket'),
          path: any(named: 'path'),
          token: any(named: 'token'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer((invocation) async {
        final path = invocation.namedArguments[#path] as String;
        events.add('upload:$path');
        if (path.endsWith('part-1')) throw StateError('upload_response_lost');
      });
      final ready = await service.prepare(
        invoice: _invoice(),
        request: _request,
      );
      expect(ready.printPackageReady, isTrue);
      expect(events, contains('finalize:interior:1'));
      expect(events.sublist(events.length - 2), [
        'finalize:interior',
        'ready-invoice',
      ]);
    },
  );

  test(
    'all verified parts still require complete PDF verification before SDK',
    () async {
      exporter.interiorBytes = 50000001;
      multipartUploads = true;
      finalizedState = 'UPLOADING';
      await expectLater(
        service.prepare(invoice: _invoice(), request: _request),
        throwsStateError,
      );
      expect(events, contains('finalize:interior:3'));
      expect(events.last, 'finalize:interior');
      expect(events, isNot(contains('ready-invoice')));
    },
  );

  test('a separate negotiated cover cap applies before any upload', () async {
    maximumCoverBytes = 3;
    await expectLater(
      service.prepare(invoice: _invoice(), request: _request),
      throwsA(isA<PrintPreflightException>()),
    );
    expect(events, ['snapshot']);
  });

  test(
    'changed owner during cover upload stops before finalize or payment',
    () async {
      when(
        () => orders.uploadPrintPrepaymentFile(
          bucket: any(named: 'bucket'),
          path: any(named: 'path'),
          token: any(named: 'token'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer((_) async {
        owner = 'another-owner';
      });
      await expectLater(
        service.prepare(invoice: _invoice(), request: _request),
        throwsStateError,
      );
      expect(events, ['snapshot', 'uploads']);
    },
  );

  test('a package for another order stops before rendering', () async {
    when(
      () => orders.invokePrintPrepaymentPackage(
        invoice: any(named: 'invoice'),
        action: 'snapshot',
      ),
    ).thenAnswer((_) async => {..._identity(), 'orderId': 'another-order'});
    await expectLater(
      service.prepare(invoice: _invoice(), request: _request),
      throwsFormatException,
    );
    expect(exporter.calls, 0);
  });

  test(
    'normalizing the frozen product never hides changed album artwork',
    () async {
      frozenSnapshot = {
        ...frozenSnapshot,
        'album': {...(_snapshot['album'] as Map), 'title': '변경된 앨범'},
      };
      await expectLater(
        service.prepare(invoice: _invoice(), request: _request),
        throwsFormatException,
      );
      expect(exporter.calls, 0);
    },
  );

  test('frozen physical product must still match the approved spec', () async {
    frozenSnapshot = {
      ...frozenSnapshot,
      'printProduct': {
        'id': 'REDP_250_SOFT',
        'trimWidthMm': 250,
        'trimHeightMm': 250,
      },
    };
    await expectLater(
      service.prepare(invoice: _invoice(), request: _request),
      throwsFormatException,
    );
    expect(exporter.calls, 0);
  });

  test('SDK-bearing invoice without package proof remains blocked', () async {
    packageState = 'READY';
    when(
      () => orders.preparePrintPayment(
        requestId: _rid,
        request: any(named: 'request'),
      ),
    ).thenAnswer((_) async => _invoice());
    await expectLater(
      service.prepare(invoice: _invoice(), request: _request),
      throwsFormatException,
    );
    expect(exporter.calls, 0);
  });
}

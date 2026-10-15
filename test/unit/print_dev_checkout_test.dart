import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/profile/data/print_dev_checkout.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';

class DevRepository extends Mock implements PrintDevCheckoutRepository {}

class DevStore extends PrintDevCheckoutStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String owner) async => values[owner];
  @override
  Future<void> write(String owner, Map<String, dynamic> value) async =>
      values[owner] = Map.from(value);
}

class DevExporter extends AlbumPrintExporter {
  int calls = 0;
  int length = 12;
  @override
  Future<AlbumPrintExport> generate({
    required Map<String, dynamic> snapshot,
    required PrintVendorSpec spec,
    Map<String, String> sourceUrls = const {},
    void Function(int, int)? onProgress,
  }) async {
    calls++;
    return AlbumPrintExport(
      coverPdf: Uint8List.fromList([37, 80, 68, 70]),
      interiorPdf: Uint8List(length),
      interiorPageCount: 80,
      report: {
        'renderer': 'flutter-layer-builder-raster-v1',
        'specVersion': spec.specVersion,
        'pageCount': 80,
        'dpi': 300,
        'missingAssets': <String>[],
        'colorSpace': 'sRGB',
        'iccProfileEmbedded': true,
      },
    );
  }
}

const devRun = '11111111-1111-4111-8111-111111111111';
const devRequest = '22222222-2222-4222-8222-222222222222';
const devPayment = 'SFPGT_33333333-3333-4333-8333-333333333333';
final devProduct = PrintProduct.forId('REDP_300_HARD')!.toJson();
final devSnapshot = <String, dynamic>{
  'album': {
    'id': 69,
    'title': 'TEST owned80',
    'ratio': '1',
    'cover_theme': 'classic',
    'cover_layers_json': {
      'printProduct': devProduct,
      'pages': [
        for (var i = 0; i <= 80; i++)
          {'index': i, 'isCover': i == 0, 'layers': []},
      ],
    },
  },
  'pages': [],
};
final devRevision = printCheckoutRevision(devSnapshot);
final devSpec = <String, dynamic>{
  'id': 'REDP_300_HARD',
  'specVersion': 'TEST_ONLY_HARD_80',
  'geometrySource': 'Synthetic test geometry; not production approval',
  'verified': false,
  'pageCount': 80,
  'dpi': 300,
  'interior': {'trimWidthMm': 300, 'trimHeightMm': 300, 'bleedMm': 5},
  'cover': {
    'construction': 'casewrap',
    'bleedMm': 20,
    'widthMm': 681.2,
    'heightMm': 346,
    'back': {'xMm': 20, 'yMm': 20, 'widthMm': 306, 'heightMm': 306},
    'front': {'xMm': 355.2, 'yMm': 20, 'widthMm': 306, 'heightMm': 306},
    'trim': {'xMm': 20, 'yMm': 20, 'widthMm': 641.2, 'heightMm': 306},
  },
};
Map<String, dynamic> devResponse({
  String packageState = 'NONE',
  Map<String, dynamic>? sdk,
  bool verified = false,
}) => {
  'environment': 'test',
  'isTest': true,
  'productionApproved': false,
  'runId': devRun,
  'orderId': 'ordp_$devRun',
  'paymentId': devPayment,
  'requestId': devRequest,
  'albumId': 69,
  'totalAmount': 159900,
  'reviewedRevision': devRevision,
  'reviewedSpecRevision': printSpecRevision(devSpec),
  'status': verified ? 'VERIFIED_TEST' : 'PREPARED',
  'stage': 'PREPARED',
  'packageState': packageState,
  if (sdk != null) 'sdkRequest': sdk,
};
Map<String, dynamic> devSdk() => {
  'status': 'PREPARED',
  'environment': 'test',
  'currency': 'KRW',
  'storeId': PrintDevCheckoutSession.testStoreId,
  'channelKey': PrintDevCheckoutSession.testChannelKey,
  'paymentId': devPayment,
  'orderName': '스냅핏 개발 TEST 80쪽',
  'totalAmount': 159900,
};
Map<String, dynamic> devRecoveryManifest() => {
  'renderer': 'flutter-layer-builder-raster-v1',
  'specVersion': devSpec['specVersion'],
  'sourceFingerprint': 'a' * 64,
  'productId': 'REDP_300_HARD',
  'coverType': 'HARD',
  'pageCount': 80,
  'dpi': 300,
  'colorSpace': 'sRGB',
  'iccProfileEmbedded': true,
  'pdfStandard': 'PDF-1.4',
  'fit': 'contain',
  'missingAssets': <String>[],
  'warnings': <String>[],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'empty and non-error sentinel responses never become reference codes',
    () {
      for (final value in [null, '', 'null', 'undefined', 'unknown', 546]) {
        expect(printDevErrorReference(value), isNull);
      }
      expect(
        printDevErrorReference('print_validation_busy'),
        'print_validation_busy',
      );
    },
  );
  late DevRepository repo;
  late DevStore store;
  late DevExporter exporter;
  late PrintDevCheckoutService service;
  late String owner;
  late List<String> events;
  late bool partVerified;
  setUpAll(() => registerFallbackValue(Uint8List(0)));
  setUp(() {
    repo = DevRepository();
    store = DevStore();
    exporter = DevExporter();
    owner = 'admin-owner';
    events = [];
    partVerified = true;
    service = PrintDevCheckoutService(
      repository: repo,
      store: store,
      exporter: exporter,
      requestId: () => devRequest,
    );
    when(() => repo.ownerId()).thenAnswer((_) async => owner);
    when(() => repo.upload(any(), any(), any(), any())).thenAnswer((
      call,
    ) async {
      events.add('upload:${call.positionalArguments[1]}');
    });
    when(() => repo.invoke(any(), any())).thenAnswer((call) async {
      final action = call.positionalArguments[0] as String;
      final body = call.positionalArguments[1] as Map;
      events.add(
        'api:$action${body['partIndex'] == null ? '' : ':${body['partIndex']}'}',
      );
      if (action == 'prepare' || action == 'snapshot')
        return {
          ...devResponse(),
          'snapshot': {...devSnapshot, 'printProduct': devProduct},
          'spec': devSpec,
          'sourceFingerprint': 'a' * 64,
          'sourceUrls': {},
          'maxFileBytes': 500000000,
          'maxCoverFileBytes': 150000000,
        };
      if (action == 'uploads') {
        Map<String, dynamic> target(String kind) {
          final parts = body[kind]['parts'];
          return parts is List
              ? {
                  'parts': [
                    for (var i = 0; i < parts.length; i++)
                      {
                        'index': i,
                        'path': '$kind/part-$i',
                        'token': 'test-token',
                        'byteLength': parts[i]['bytes'],
                        'sha256': parts[i]['sha256'],
                      },
                  ],
                }
              : {'path': '$kind.pdf', 'token': 'test-token'};
        }

        return {
          ...devResponse(packageState: 'UPLOADING'),
          'packageId': devRun,
          'bucket': 'print-files',
          'cover': target('cover'),
          'interior': target('interior'),
        };
      }
      if (action == 'finalize')
        return {
          ...devResponse(
            packageState:
                body['kind'] == 'interior' && body['partIndex'] == null
                ? 'READY'
                : 'UPLOADING',
          ),
          if (body['partIndex'] != null) ...{
            'partVerified': partVerified,
            'partIndex': body['partIndex'],
            'kind': body['kind'],
          },
        };
      if (action == 'authorize')
        return devResponse(packageState: 'READY', sdk: devSdk());
      return devResponse(packageState: 'READY');
    });
  });
  Future<PrintDevCheckoutSession> prepare() => service.prepare(
    albumId: 69,
    reviewedRevision: devRevision,
    recipient: {
      'name': '테스트',
      'phone': '01000000000',
      'zipCode': '12345',
      'addressLine1': '합성 주소',
      'addressLine2': '',
      'deliveryMemo': '',
    },
  );
  test(
    'TEST session rejects production environment, wrong channel and fake verified receipt',
    () {
      expect(
        () => PrintDevCheckoutSession.fromJson({
          ...devResponse(),
          'environment': 'production',
        }),
        throwsFormatException,
      );
      expect(
        () => PrintDevCheckoutSession.fromJson(
          devResponse(
            packageState: 'READY',
            sdk: {...devSdk(), 'channelKey': 'channel-key-other-live-route'},
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => PrintDevCheckoutSession.fromJson(devResponse(verified: true)),
        throwsFormatException,
      );
    },
  );
  test(
    'actual original-size part plan finishes both PDF inspections before TEST SDK and never verifies payment',
    () async {
      exporter.length = 50000001;
      final prepared = await prepare();
      final ready = await service.prepareFiles(prepared);
      expect(ready.filesReady, isTrue);
      expect(exporter.calls, 1);
      final authorized = await service.authorize(ready);
      await service.assertCanLaunch(authorized);
      expect(authorized.sdkRequest?.environment, 'test');
      expect(await service.sdkStarted(), isTrue);
      expect(
        events.indexOf('api:authorize'),
        greaterThan(events.lastIndexOf('api:finalize')),
      );
      expect(events.where((e) => e.startsWith('upload:interior/')).length, 4);
      final before = events.length;
      await service.status(authorized);
      expect(events.sublist(before), ['api:status']);
      expect(
        events.any(
          (e) =>
              e.contains('verify') ||
              e.contains('confirm') ||
              e.contains('submit'),
        ),
        isFalse,
      );
      expect(
        store.values['admin-owner']!.keys,
        unorderedEquals([
          'runId',
          'requestId',
          'orderId',
          'paymentId',
          'albumId',
          'reviewedRevision',
          'sdkStarted',
        ]),
      );
    },
  );
  test('an unverified part never reaches full PDF authorization', () async {
    exporter.length = 50000001;
    partVerified = false;
    final prepared = await prepare();
    await expectLater(service.prepareFiles(prepared), throwsFormatException);
    expect(events.last, 'api:finalize:0');
    expect(events, isNot(contains('api:authorize')));
    expect(await service.sdkStarted(), isFalse);
  });
  test('owner change during upload blocks finalize and SDK', () async {
    final prepared = await prepare();
    when(() => repo.upload(any(), any(), any(), any())).thenAnswer((_) async {
      owner = 'other-admin';
    });
    await expectLater(
      service.prepareFiles(prepared),
      throwsA(isA<PrintDevCheckoutException>()),
    );
    expect(events, isNot(contains('api:finalize')));
    expect(events, isNot(contains('api:authorize')));
  });
  test(
    'SDK issued attempt keeps the original refs on resume and cannot launch twice',
    () async {
      final ready = await service.prepareFiles(await prepare());
      final authorized = await service.authorize(ready);
      final recovered = await service.resume();
      expect(recovered?.refs, authorized.refs);
      await expectLater(
        service.authorize(ready),
        throwsA(isA<PrintDevCheckoutException>()),
      );
      expect(events.where((e) => e == 'api:authorize').length, 1);
    },
  );
  Map<String, dynamic> recoverySnapshot({
    bool includeRecovery = true,
    Map<String, dynamic>? manifest,
  }) => {
    ...devResponse(packageState: 'UPLOADING'),
    'packageId': devRun,
    'snapshot': {...devSnapshot, 'printProduct': devProduct},
    'spec': devSpec,
    'sourceFingerprint': 'a' * 64,
    'sourceUrls': {},
    'maxFileBytes': 500000000,
    'maxCoverFileBytes': 150000000,
    if (includeRecovery)
      'fileRecovery': {
        'packageId': devRun,
        'manifest': manifest ?? devRecoveryManifest(),
      },
  };
  test(
    'a retry inspects the same uploaded package without rendering or uploading and waits for READY before SDK',
    () async {
      final prepared = await prepare();
      final manifest = devRecoveryManifest();
      when(
        () => repo.invoke('snapshot', any()),
      ).thenAnswer((_) async => recoverySnapshot(manifest: manifest));
      var interiorAttempts = 0;
      final finalizeBodies = <Map<String, dynamic>>[];
      when(() => repo.invoke('finalize', any())).thenAnswer((call) async {
        final body = Map<String, dynamic>.from(call.positionalArguments[1]);
        finalizeBodies.add(body);
        if (body['kind'] == 'interior' && ++interiorAttempts == 1) {
          throw const PrintDevCheckoutException('print_validation_busy');
        }
        return {
          ...devResponse(
            packageState: body['kind'] == 'interior' ? 'READY' : 'UPLOADING',
          ),
          'packageId': devRun,
        };
      });
      await expectLater(
        service.prepareFiles(prepared),
        throwsA(isA<PrintDevCheckoutException>()),
      );
      verifyNever(() => repo.invoke('authorize', any()));
      final ready = await service.prepareFiles(prepared);
      expect(ready.filesReady, isTrue);
      expect(exporter.calls, 0);
      verifyNever(() => repo.upload(any(), any(), any(), any()));
      verifyNever(() => repo.invoke('uploads', any()));
      expect(finalizeBodies.map((body) => body['kind']), [
        'cover',
        'interior',
        'cover',
        'interior',
      ]);
      for (final body in finalizeBodies) {
        expect(body['packageId'], devRun);
        expect(body['manifest'], manifest);
        expect(body.containsKey('partIndex'), isFalse);
        for (final entry in prepared.refs.entries) {
          expect(body[entry.key], entry.value);
        }
      }
      await service.authorize(ready);
      verify(() => repo.invoke('authorize', any())).called(1);
    },
  );
  test(
    'existing uploads without complete server recovery proof are preserved without a new render or SDK',
    () async {
      final prepared = await prepare();
      when(
        () => repo.invoke('snapshot', any()),
      ).thenAnswer((_) async => recoverySnapshot(includeRecovery: false));
      await expectLater(
        service.prepareFiles(prepared),
        throwsA(
          isA<PrintDevCheckoutException>().having(
            (error) => error.code,
            'code',
            'print_dev_uploaded_files_need_recovery',
          ),
        ),
      );
      expect(exporter.calls, 0);
      verifyNever(() => repo.upload(any(), any(), any(), any()));
      verifyNever(() => repo.invoke('finalize', any()));
      verifyNever(() => repo.invoke('authorize', any()));
      expect(await service.sdkStarted(), isFalse);
    },
  );
  test(
    'a changed recovery source fingerprint blocks inspection and SDK',
    () async {
      final prepared = await prepare();
      when(() => repo.invoke('snapshot', any())).thenAnswer(
        (_) async => recoverySnapshot(
          manifest: {...devRecoveryManifest(), 'sourceFingerprint': 'b' * 64},
        ),
      );
      await expectLater(service.prepareFiles(prepared), throwsFormatException);
      expect(exporter.calls, 0);
      verifyNever(() => repo.invoke('finalize', any()));
      verifyNever(() => repo.invoke('authorize', any()));
    },
  );
  test(
    'owner change during recovery stops before the next file inspection',
    () async {
      final prepared = await prepare();
      when(
        () => repo.invoke('snapshot', any()),
      ).thenAnswer((_) async => recoverySnapshot());
      when(() => repo.invoke('finalize', any())).thenAnswer((_) async {
        owner = 'different-admin';
        return {...devResponse(packageState: 'UPLOADING'), 'packageId': devRun};
      });
      await expectLater(
        service.prepareFiles(prepared),
        throwsA(isA<PrintDevCheckoutException>()),
      );
      expect(exporter.calls, 0);
      verify(() => repo.invoke('finalize', any())).called(1);
      verifyNever(() => repo.invoke('authorize', any()));
    },
  );
}

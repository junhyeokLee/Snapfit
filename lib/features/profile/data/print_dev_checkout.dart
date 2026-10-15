import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../album/printing/album_print_exporter.dart';
import '../../album/printing/print_album_document.dart';
import '../domain/portone_payment.dart';
import '../domain/print_checkout.dart';
import 'print_pdf_upload_plan.dart';

/// Visibility only. The TEST endpoint independently verifies the current user.
final printDevAdminAccessProvider = Provider<bool>((ref) {
  try {
    ref.watch(authViewModelProvider);
    return ref
            .watch(supabaseClientProvider)
            .auth
            .currentUser
            ?.appMetadata['role'] ==
        'admin';
  } catch (_) {
    return false;
  }
});
final printDevCheckoutServiceProvider = Provider<PrintDevCheckoutService>(
  (ref) => PrintDevCheckoutService(
    repository: PrintDevCheckoutRepository(ref.watch(supabaseClientProvider)),
  ),
);

class PrintDevCheckoutException implements Exception {
  const PrintDevCheckoutException(this.code);
  final String code;
}

String? printDevErrorReference(Object? value) {
  if (value is! String ||
      !RegExp(r'^[a-z0-9_]{1,80}$').hasMatch(value) ||
      const {'null', 'undefined', 'unknown'}.contains(value)) {
    return null;
  }
  return value;
}

/// TEST evidence never becomes a production invoice or paid-order receipt.
class PrintDevCheckoutSession {
  PrintDevCheckoutSession._(this.data, this.sdkRequest);
  static const testStoreId = 'store-33df409e-0ad9-4953-8194-70db7e32efae';
  static const testChannelKey =
      'channel-key-34782ac7-e644-4234-ad27-2767b6904f88';
  final Map<String, dynamic> data;
  final PortOnePaymentRequest? sdkRequest;
  String get runId => data['runId'] as String;
  String get orderId => data['orderId'] as String;
  String get paymentId => data['paymentId'] as String;
  String get requestId => data['requestId'] as String;
  int get albumId => data['albumId'] as int;
  int get totalAmount => data['totalAmount'] as int;
  String get reviewedRevision => data['reviewedRevision'] as String;
  String get reviewedSpecRevision => data['reviewedSpecRevision'] as String;
  bool get filesReady => data['packageState'] == 'READY';
  bool get verifiedTest => data['status'] == 'VERIFIED_TEST';
  String get stage => '${data['stage'] ?? 'PREPARED'}';
  String? get devOrderNum =>
      data['devOrderNum'] is String ? data['devOrderNum'] as String : null;
  Map<String, dynamic> get refs => {
    'runId': runId,
    'requestId': requestId,
    'orderId': orderId,
    'paymentId': paymentId,
    'albumId': albumId,
  };

  factory PrintDevCheckoutSession.fromJson(Map<String, dynamic> json) {
    final uuid = RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
    );
    final hash = RegExp(r'^[a-f0-9]{64}$');
    final id = '${json['runId'] ?? ''}';
    final payment = '${json['paymentId'] ?? ''}';
    if (json['environment'] != 'test' ||
        json['isTest'] != true ||
        json['productionApproved'] != false ||
        !uuid.hasMatch(id) ||
        json['orderId'] != 'ordp_$id' ||
        !uuid.hasMatch('${json['requestId']}') ||
        !payment.startsWith('SFPGT_') ||
        !uuid.hasMatch(payment.substring(6)) ||
        json['albumId'] is! int ||
        (json['albumId'] as int) <= 0 ||
        json['totalAmount'] != 159900 ||
        !hash.hasMatch('${json['reviewedRevision']}') ||
        !hash.hasMatch('${json['reviewedSpecRevision']}') ||
        !['PREPARED', 'VERIFIED_TEST'].contains(json['status'])) {
      throw const FormatException('print_dev_session_invalid');
    }
    PortOnePaymentRequest? sdk;
    if (json['sdkRequest'] is Map) {
      sdk = PortOnePaymentRequest.fromPrepared(
        Map<String, dynamic>.from(json['sdkRequest'] as Map),
      );
      if (sdk.paymentId != payment ||
          sdk.totalAmount != 159900 ||
          sdk.storeId != testStoreId ||
          sdk.channelKey != testChannelKey ||
          json['packageState'] != 'READY') {
        throw const FormatException('print_dev_sdk_invalid');
      }
    }
    if (json['status'] == 'VERIFIED_TEST') {
      final receipt = json['receipt'];
      if (receipt is! Map ||
          receipt['provider'] != 'PORTONE' ||
          receipt['version'] != 'V2' ||
          receipt['status'] != 'PAID' ||
          receipt['environment'] != 'test' ||
          receipt['isTest'] != true ||
          receipt['paymentId'] != payment ||
          receipt['amount'] != 159900 ||
          receipt['currency'] != 'KRW' ||
          receipt['storeId'] != testStoreId ||
          receipt['channelKey'] != testChannelKey ||
          receipt['transactionId'] is! String ||
          (receipt['transactionId'] as String).isEmpty ||
          DateTime.tryParse('${receipt['paidAt']}') == null) {
        throw const FormatException('print_dev_receipt_unverified');
      }
    } else if (json['receipt'] != null) {
      throw const FormatException('print_dev_receipt_unverified');
    }
    return PrintDevCheckoutSession._(Map.unmodifiable(json), sdk);
  }

  void match(PrintDevCheckoutSession original) {
    for (final key in [
      ...refs.keys,
      'reviewedRevision',
      'reviewedSpecRevision',
      'totalAmount',
    ]) {
      if (data[key] != original.data[key])
        throw const FormatException('print_dev_identity_changed');
    }
  }
}

class PrintDevCheckoutRepository {
  PrintDevCheckoutRepository(this.client);
  final SupabaseClient client;
  Future<String> ownerId() async {
    final user = client.auth.currentUser;
    if (user == null || user.appMetadata['role'] != 'admin') {
      throw const PrintDevCheckoutException('admin_required');
    }
    return user.id;
  }

  Future<Map<String, dynamic>> invoke(
    String action,
    Map<String, dynamic> fields,
  ) async {
    final owner = await ownerId();
    try {
      final result = await client.functions.invoke(
        'print-dev-checkout',
        body: {...fields, 'action': action},
      );
      if (await ownerId() != owner)
        throw const PrintDevCheckoutException('owner_changed');
      if (result.status != 200 ||
          result.data is! Map ||
          (result.data as Map)['error'] != null) {
        final code = printDevErrorReference(
          result.data is Map ? (result.data as Map)['error'] : null,
        );
        throw PrintDevCheckoutException(code ?? 'dev_checkout_unavailable');
      }
      return Map<String, dynamic>.from(result.data as Map);
    } on FunctionException catch (error) {
      final details = error.details;
      final code = printDevErrorReference(
        details is Map ? details['error'] : null,
      );
      throw PrintDevCheckoutException(code ?? 'dev_checkout_unavailable');
    }
  }

  Future<void> upload(
    String bucket,
    String path,
    String token,
    Uint8List bytes,
  ) async {
    final owner = await ownerId();
    try {
      await client.storage
          .from(bucket)
          .uploadBinaryToSignedUrl(
            path,
            token,
            bytes,
            const FileOptions(contentType: 'application/pdf', upsert: false),
          );
    } on StorageException catch (error) {
      if (error.statusCode != '409' &&
          !(error.statusCode == '400' && error.error == 'Duplicate'))
        rethrow;
    }
    if (await ownerId() != owner)
      throw const PrintDevCheckoutException('owner_changed');
  }
}

class PrintDevCheckoutStore {
  String _key(String owner) => 'snapfit_print_dev_pending_v1_$owner';
  Future<Map<String, dynamic>?> read(String owner) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(owner));
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> write(String owner, Map<String, dynamic> value) async {
    if (!(await (await SharedPreferences.getInstance()).setString(
      _key(owner),
      jsonEncode(value),
    ))) {
      throw const PrintDevCheckoutException('dev_recovery_not_saved');
    }
  }
}

class PrintDevCheckoutService {
  PrintDevCheckoutService({
    required this.repository,
    AlbumPrintExporter? exporter,
    PrintDevCheckoutStore? store,
    String Function()? requestId,
  }) : exporter = exporter ?? AlbumPrintExporter(),
       store = store ?? PrintDevCheckoutStore(),
       requestId = requestId ?? const Uuid().v4;
  final PrintDevCheckoutRepository repository;
  final AlbumPrintExporter exporter;
  final PrintDevCheckoutStore store;
  final String Function() requestId;
  Future<void> _same(String owner) async {
    if (await repository.ownerId() != owner)
      throw const PrintDevCheckoutException('owner_changed');
  }

  Future<PrintDevCheckoutSession?> resume() async {
    final owner = await repository.ownerId();
    final saved = await store.read(owner);
    await _same(owner);
    if (saved == null || saved['runId'] == null) return null;
    final raw = await repository.invoke('status', _refs(saved));
    await _same(owner);
    final result = PrintDevCheckoutSession.fromJson(raw);
    for (final key in _refs(saved).keys) {
      if (raw[key] != saved[key])
        throw const FormatException('print_dev_identity_changed');
    }
    return result;
  }

  Future<PrintDevCheckoutSession> prepare({
    required int albumId,
    required String reviewedRevision,
    required Map<String, String> recipient,
  }) async {
    final owner = await repository.ownerId();
    final saved = await store.read(owner);
    await _same(owner);
    if (saved != null &&
        (saved['albumId'] != albumId ||
            saved['reviewedRevision'] != reviewedRevision)) {
      throw const PrintDevCheckoutException('existing_dev_test_pending');
    }
    final id = saved?['requestId'] as String? ?? requestId();
    await store.write(owner, {
      ...?saved,
      'requestId': id,
      'albumId': albumId,
      'reviewedRevision': reviewedRevision,
    });
    await _same(owner);
    final result = PrintDevCheckoutSession.fromJson(
      await repository.invoke('prepare', {
        'requestId': id,
        'albumId': albumId,
        'reviewedRevision': reviewedRevision,
        'recipient': recipient,
      }),
    );
    await _same(owner);
    if (result.albumId != albumId ||
        result.requestId != id ||
        result.reviewedRevision != reviewedRevision) {
      throw const FormatException('print_dev_identity_changed');
    }
    await store.write(owner, {
      ...result.refs,
      'reviewedRevision': reviewedRevision,
      'sdkStarted': saved?['sdkStarted'] == true,
    });
    await _same(owner);
    return result;
  }

  Future<PrintDevCheckoutSession> status(
    PrintDevCheckoutSession current,
  ) async {
    final owner = await repository.ownerId();
    final result = PrintDevCheckoutSession.fromJson(
      await repository.invoke('status', current.refs),
    );
    await _same(owner);
    result.match(current);
    return result;
  }

  Future<bool> sdkStarted() async {
    final owner = await repository.ownerId();
    final value = await store.read(owner);
    await _same(owner);
    return value?['sdkStarted'] == true;
  }

  Future<PrintDevCheckoutSession> prepareFiles(
    PrintDevCheckoutSession current, {
    void Function(String)? onProgress,
  }) async {
    final owner = await repository.ownerId();
    final raw = await repository.invoke('snapshot', current.refs);
    await _same(owner);
    var session = PrintDevCheckoutSession.fromJson(raw)..match(current);
    if (session.filesReady) return session;
    if (raw['snapshot'] is! Map ||
        raw['spec'] is! Map ||
        raw['maxFileBytes'] != 500000000 ||
        raw['maxCoverFileBytes'] != 150000000 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch('${raw['sourceFingerprint']}')) {
      throw const FormatException('print_dev_snapshot_invalid');
    }
    final snapshot = Map<String, dynamic>.from(raw['snapshot'] as Map);
    final specMap = Map<String, dynamic>.from(raw['spec'] as Map);
    final spec = PrintVendorSpec.fromJson(specMap);
    final doc = PrintAlbumDocument.fromSnapshot(snapshot);
    doc.validateSpec(spec);
    if (spec.id != 'REDP_300_HARD' ||
        spec.pageCount != 80 ||
        spec.dpi != 300 ||
        doc.interiors.length != 80 ||
        printCheckoutRevision({...snapshot, 'printProduct': null}) !=
            session.reviewedRevision ||
        printSpecRevision(specMap) != session.reviewedSpecRevision) {
      throw const FormatException('print_dev_review_changed');
    }
    if (raw['packageId'] != null || raw['fileRecovery'] != null) {
      // An existing immutable package must never be regenerated. Its PDF hash
      // may depend on render-time metadata, even for the same frozen artwork.
      return _resumeFileInspection(
        owner: owner,
        current: session,
        snapshot: raw,
        spec: spec,
        onProgress: onProgress,
      );
    }
    onProgress?.call('앱에서 원본 화질 PDF 만드는 중');
    final output = await exporter.generate(
      snapshot: snapshot,
      spec: spec,
      sourceUrls: raw['sourceUrls'] is Map
          ? Map<String, String>.from(raw['sourceUrls'] as Map)
          : const {},
      onProgress: (done, total) =>
          onProgress?.call('인쇄 PDF 만드는 중 $done / $total'),
    );
    await _same(owner);
    if (output.interiorPageCount != 80 ||
        output.coverPdf.isEmpty ||
        output.interiorPdf.isEmpty ||
        output.coverPdf.length > 150000000 ||
        output.interiorPdf.length > 500000000 ||
        output.report['missingAssets'] is! List ||
        (output.report['missingAssets'] as List).isNotEmpty) {
      throw const FormatException('print_dev_export_invalid');
    }
    final plans = {
      'cover': PrintPdfUploadPlan(output.coverPdf),
      'interior': PrintPdfUploadPlan(output.interiorPdf),
    };
    final manifest = {
      ...output.report,
      'sourceFingerprint': raw['sourceFingerprint'],
    };
    final uploads = await repository.invoke('uploads', {
      ...current.refs,
      'manifest': manifest,
      'cover': plans['cover']!.declaration,
      'interior': plans['interior']!.declaration,
    });
    await _same(owner);
    session = PrintDevCheckoutSession.fromJson(uploads)..match(current);
    if (session.filesReady) return session;
    final packageId = uploads['packageId'];
    final bucket = uploads['bucket'];
    if (packageId is! String || bucket is! String)
      throw const FormatException('print_dev_upload_invalid');
    for (final kind in plans.keys) {
      final plan = plans[kind]!;
      final target = uploads[kind];
      if (target is! Map)
        throw const FormatException('print_dev_upload_invalid');
      final parts = target['parts'];
      final declarations = plan.declaration['parts'];
      if (plan.isMultipart &&
          (parts is! List || parts.length != plan.parts.length)) {
        throw const FormatException('print_dev_upload_invalid');
      }
      final count = plan.isMultipart ? plan.parts.length : 1;
      for (var index = 0; index < count; index++) {
        final item = plan.isMultipart ? parts[index] : target;
        if (item is! Map ||
            item['path'] is! String ||
            item['token'] is! String ||
            plan.isMultipart &&
                (item['index'] != index ||
                    item['byteLength'] != declarations[index]['bytes'] ||
                    item['sha256'] != declarations[index]['sha256'])) {
          throw const FormatException('print_dev_upload_invalid');
        }
        await _same(owner);
        onProgress?.call(
          '${kind == 'cover' ? '표지' : '내지'} 업로드·검수 중 ${index + 1} / $count',
        );
        try {
          await repository.upload(
            bucket,
            item['path'] as String,
            item['token'] as String,
            plan.isMultipart ? plan.parts[index] : plan.bytes,
          );
        } catch (_) {
          // Only the server's actual immutable-file inspection resolves a lost
          // upload response. Nothing is replaced and no SDK runs on uncertainty.
        }
        await _same(owner);
        final checked = await repository.invoke('finalize', {
          ...current.refs,
          'packageId': packageId,
          'kind': kind,
          'manifest': manifest,
          if (plan.isMultipart) 'partIndex': index,
        });
        await _same(owner);
        session = PrintDevCheckoutSession.fromJson(checked)..match(current);
        if (plan.isMultipart &&
            (checked['partVerified'] != true ||
                checked['partIndex'] != index ||
                checked['kind'] != kind)) {
          throw const FormatException('print_dev_part_unverified');
        }
      }
      if (plan.isMultipart) {
        onProgress?.call('${kind == 'cover' ? '표지' : '내지'} 전체 PDF 검수 중');
        final checked = await repository.invoke('finalize', {
          ...current.refs,
          'packageId': packageId,
          'kind': kind,
          'manifest': manifest,
        });
        await _same(owner);
        session = PrintDevCheckoutSession.fromJson(checked)..match(current);
      }
    }
    if (!session.filesReady)
      throw const FormatException('print_dev_files_not_ready');
    return session;
  }

  Future<PrintDevCheckoutSession> _resumeFileInspection({
    required String owner,
    required PrintDevCheckoutSession current,
    required Map<String, dynamic> snapshot,
    required PrintVendorSpec spec,
    void Function(String)? onProgress,
  }) async {
    final packageId = snapshot['packageId'];
    final recovery = snapshot['fileRecovery'];
    if (snapshot['packageState'] != 'UPLOADING' ||
        packageId is! String ||
        !RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(packageId) ||
        recovery is! Map ||
        recovery['packageId'] != packageId ||
        recovery['manifest'] is! Map) {
      throw const PrintDevCheckoutException(
        'print_dev_uploaded_files_need_recovery',
      );
    }
    final manifest = Map<String, dynamic>.from(recovery['manifest'] as Map);
    if (manifest['sourceFingerprint'] != snapshot['sourceFingerprint'] ||
        manifest['renderer'] != 'flutter-layer-builder-raster-v1' ||
        manifest['specVersion'] != spec.specVersion ||
        manifest['productId'] != 'REDP_300_HARD' ||
        manifest['coverType'] != 'HARD' ||
        manifest['pageCount'] != 80 ||
        manifest['dpi'] != 300 ||
        manifest['colorSpace'] != 'sRGB' ||
        manifest['iccProfileEmbedded'] != true ||
        manifest['pdfStandard'] != 'PDF-1.4' ||
        manifest['fit'] != 'contain' ||
        manifest['missingAssets'] is! List ||
        (manifest['missingAssets'] as List).isNotEmpty ||
        manifest['warnings'] is! List ||
        manifest.containsKey('declaredFiles') ||
        manifest.containsKey('fileTransport')) {
      throw const FormatException('print_dev_recovery_manifest_invalid');
    }
    var session = current;
    for (final kind in ['cover', 'interior']) {
      await _same(owner);
      onProgress?.call(
        '이미 업로드한 ${kind == 'cover' ? '표지' : '내지'} PDF 전체 검수 이어가는 중',
      );
      final checked = await repository.invoke('finalize', {
        ...current.refs,
        'packageId': packageId,
        'kind': kind,
        'manifest': manifest,
      });
      await _same(owner);
      session = PrintDevCheckoutSession.fromJson(checked)..match(current);
      if (checked['packageId'] != packageId) {
        throw const FormatException('print_dev_identity_changed');
      }
    }
    if (!session.filesReady) {
      throw const PrintDevCheckoutException('print_dev_files_not_ready');
    }
    return session;
  }

  Future<PrintDevCheckoutSession> authorize(
    PrintDevCheckoutSession current,
  ) async {
    final owner = await repository.ownerId();
    final saved = await store.read(owner);
    await _same(owner);
    if (saved == null ||
        _refs(
          saved,
        ).entries.any((entry) => current.refs[entry.key] != entry.value)) {
      throw const FormatException('print_dev_identity_changed');
    }
    if (saved['sdkStarted'] == true)
      throw const PrintDevCheckoutException('test_payment_already_opened');
    if (!current.filesReady)
      throw const FormatException('print_dev_files_not_ready');
    final result = PrintDevCheckoutSession.fromJson(
      await repository.invoke('authorize', current.refs),
    )..match(current);
    await _same(owner);
    if (!result.filesReady || result.sdkRequest == null || result.verifiedTest)
      throw const FormatException('print_dev_sdk_invalid');
    await store.write(owner, {
      ...result.refs,
      'reviewedRevision': result.reviewedRevision,
      'sdkStarted': true,
    });
    await _same(owner);
    return result;
  }

  Future<void> assertCanLaunch(PrintDevCheckoutSession current) async {
    final owner = await repository.ownerId();
    final saved = await store.read(owner);
    await _same(owner);
    if (saved == null ||
        saved['sdkStarted'] != true ||
        _refs(
          saved,
        ).entries.any((entry) => current.refs[entry.key] != entry.value)) {
      throw const FormatException('print_dev_identity_changed');
    }
  }

  Map<String, dynamic> _refs(Map<String, dynamic> saved) => {
    for (final key in ['runId', 'requestId', 'orderId', 'paymentId', 'albumId'])
      key: saved[key],
  };
}

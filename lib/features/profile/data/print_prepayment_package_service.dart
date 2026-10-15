import 'dart:typed_data';

import '../../album/printing/album_print_exporter.dart';
import '../../album/printing/print_album_document.dart';
import '../domain/print_checkout.dart';
import 'order_repository.dart';
import 'print_pdf_upload_plan.dart';

typedef PrintPreparationProgress = void Function(String message);

/// Renders only the owned, frozen checkout artwork. The authenticated server
/// inspects the uploaded bytes before it may issue a payment SDK request.
class PrintPrepaymentPackageService {
  PrintPrepaymentPackageService({
    required this.repository,
    AlbumPrintExporter? exporter,
  }) : exporter = exporter ?? AlbumPrintExporter();

  final OrderRepository repository;
  final AlbumPrintExporter exporter;

  Future<PrintPaymentInvoice> prepare({
    required PrintPaymentInvoice invoice,
    required PrintCheckoutRequest request,
    PrintPreparationProgress? onProgress,
  }) async {
    if (invoice.customerRequestHold || invoice.status != 'PREPARED') {
      throw StateError('print_package_not_prepareable');
    }
    final owner = await repository.printPaymentOwnerId();
    onProgress?.call('확정한 앨범을 불러오는 중');
    final input = await repository.invokePrintPrepaymentPackage(
      invoice: invoice,
      action: 'snapshot',
    );
    await _sameOwner(owner);
    _match(input, invoice, request);
    if (input['packageState'] == 'READY') {
      return _readyInvoice(owner, invoice, request);
    }
    final rawSnapshot = input['snapshot'];
    final rawSpec = input['spec'];
    final limit = input['maxFileBytes'];
    final coverLimit = input['maxCoverFileBytes'];
    final fingerprint = input['sourceFingerprint'];
    if (rawSnapshot is! Map ||
        rawSpec is! Map ||
        limit is! int ||
        limit <= 0 ||
        limit > PrintPdfUploadPlan.maximumInteriorBytes ||
        coverLimit is! int ||
        coverLimit <= 0 ||
        coverLimit > PrintPdfUploadPlan.maximumCoverBytes ||
        fingerprint is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) {
      throw const FormatException('print_package_snapshot_invalid');
    }
    final snapshot = Map<String, dynamic>.from(rawSnapshot);
    final specMap = Map<String, dynamic>.from(rawSpec);
    // The order freeze adds the selected physical product at top level. The
    // reviewed album revision predates that addition; product/spec validation
    // below still uses the complete, unchanged frozen render input.
    if (printCheckoutRevision({...snapshot, 'printProduct': null}) !=
            request.reviewedRevision ||
        printSpecRevision(specMap) != request.reviewedSpecRevision) {
      throw const FormatException('print_package_review_changed');
    }
    final spec = PrintVendorSpec.fromJson(specMap);
    final document = PrintAlbumDocument.fromSnapshot(snapshot);
    document.validateSpec(spec);
    // Recreating the same artwork may still change PDF metadata or bytes. An
    // existing immutable upload must instead finish using its original report.
    if ({'UPLOADING', 'FILES_VERIFIED'}.contains(input['packageState'])) {
      final recovery = input['fileRecovery'];
      if (recovery == null) {
        throw const PrintCheckoutApiException(
          'print_package_partial_upload',
          409,
        );
      }
      if (recovery is! Map ||
          recovery['packageId'] is! String ||
          recovery['packageId'] != input['packageId'] ||
          !RegExp(
            r'^[a-fA-F0-9-]{36}$',
          ).hasMatch(recovery['packageId'] as String) ||
          recovery['manifest'] is! Map) {
        throw const FormatException('print_package_recovery_invalid');
      }
      final manifest = Map<String, dynamic>.from(recovery['manifest'] as Map);
      if (manifest['sourceFingerprint'] != fingerprint ||
          manifest['renderer'] != 'flutter-layer-builder-raster-v1' ||
          manifest['specVersion'] != spec.specVersion ||
          manifest['pageCount'] != spec.pageCount ||
          manifest['missingAssets'] is! List ||
          (manifest['missingAssets'] as List).isNotEmpty ||
          manifest.containsKey('declaredFiles') ||
          manifest.containsKey('fileTransport')) {
        throw const FormatException('print_package_recovery_invalid');
      }
      onProgress?.call('업로드한 원본 인쇄 파일을 다시 검수하는 중');
      for (final kind in ['cover', 'interior']) {
        final checked = await _finalize(
          owner: owner,
          invoice: invoice,
          request: request,
          packageId: recovery['packageId'] as String,
          kind: kind,
          manifest: manifest,
        );
        if (kind == 'interior' && checked['packageState'] != 'READY') {
          throw StateError('print_package_not_ready');
        }
      }
      onProgress?.call('파일 검수 완료 · 결제 준비 중');
      return _readyInvoice(owner, invoice, request);
    }
    if (input['packageState'] != 'NONE') {
      throw const PrintCheckoutApiException('print_package_state_changed', 409);
    }
    final urls = input['sourceUrls'];
    final sourceUrls = urls is Map
        ? Map<String, String>.from(urls)
        : const <String, String>{};
    final output = await exporter.generate(
      snapshot: snapshot,
      spec: spec,
      sourceUrls: sourceUrls,
      onProgress: (done, total) =>
          onProgress?.call('인쇄 PDF 만드는 중 $done / $total'),
    );
    await _sameOwner(owner);
    for (final (bytes, maximum) in [
      (output.coverPdf, coverLimit),
      (output.interiorPdf, limit),
    ]) {
      if (bytes.isEmpty || bytes.length > maximum) {
        throw const PrintPreflightException('print_checkout_pdf_too_large', []);
      }
    }
    if (output.interiorPageCount != spec.pageCount ||
        output.report['missingAssets'] is! List ||
        (output.report['missingAssets'] as List).isNotEmpty) {
      throw const FormatException('print_package_export_invalid');
    }
    final manifest = {...output.report, 'sourceFingerprint': fingerprint};
    final coverPlan = PrintPdfUploadPlan(output.coverPdf);
    final interiorPlan = PrintPdfUploadPlan(output.interiorPdf);
    onProgress?.call('인쇄 파일을 업로드하는 중');
    final uploads = await repository.invokePrintPrepaymentPackage(
      invoice: invoice,
      action: 'uploads',
      payload: {
        'manifest': manifest,
        'cover': coverPlan.declaration,
        'interior': interiorPlan.declaration,
      },
    );
    await _sameOwner(owner);
    _match(uploads, invoice, request);
    if (uploads['packageState'] == 'READY' &&
        uploads['sourceFingerprint'] == fingerprint &&
        uploads['maxFileBytes'] == limit &&
        uploads['maxCoverFileBytes'] == coverLimit) {
      // Another recovery may finish between snapshot and uploads. The server
      // compares the complete declared manifest; reuse that package safely.
      return _readyInvoice(owner, invoice, request);
    }
    if (uploads['sourceFingerprint'] != fingerprint ||
        uploads['maxFileBytes'] != limit ||
        uploads['maxCoverFileBytes'] != coverLimit ||
        uploads['packageId'] is! String ||
        uploads['bucket'] is! String ||
        uploads['cover'] is! Map ||
        uploads['interior'] is! Map) {
      throw const FormatException('print_package_upload_invalid');
    }
    final packageId = uploads['packageId'] as String;
    final bucket = uploads['bucket'] as String;
    // Large PDFs remain byte-identical, held as bounded immutable storage parts.
    // Verify each part before the server inspects the complete logical PDF.
    // Payment is unavailable until both complete PDFs are sealed as READY.
    for (final entry in [('cover', coverPlan), ('interior', interiorPlan)]) {
      await _sameOwner(owner);
      final target = Map<String, dynamic>.from(uploads[entry.$1] as Map);
      final plan = entry.$2;
      late Map<String, dynamic> checked;
      if (plan.isMultipart) {
        final targets = _partTargets(target, plan);
        for (var index = 0; index < plan.parts.length; index++) {
          onProgress?.call(
            '${entry.$1 == 'cover' ? '표지' : '내지'} 파일 업로드 중 ${index + 1} / ${plan.parts.length}',
          );
          final partResult = await _uploadAndFinalize(
            owner: owner,
            invoice: invoice,
            request: request,
            packageId: packageId,
            manifest: manifest,
            kind: entry.$1,
            bucket: bucket,
            target: targets[index],
            bytes: plan.parts[index],
            partIndex: index,
          );
          if (partResult['partVerified'] != true ||
              partResult['partIndex'] != index ||
              partResult['kind'] != entry.$1) {
            throw StateError('print_package_part_not_verified');
          }
        }
        onProgress?.call(
          entry.$1 == 'cover' ? '표지 파일을 검수하는 중' : '내지 파일을 검수하는 중',
        );
        checked = await _finalize(
          owner: owner,
          invoice: invoice,
          request: request,
          packageId: packageId,
          kind: entry.$1,
          manifest: manifest,
        );
      } else {
        checked = await _uploadAndFinalize(
          owner: owner,
          invoice: invoice,
          request: request,
          packageId: packageId,
          manifest: manifest,
          kind: entry.$1,
          bucket: bucket,
          target: target,
          bytes: plan.bytes,
        );
      }
      if (entry.$1 == 'interior' && checked['packageState'] != 'READY') {
        throw StateError('print_package_not_ready');
      }
    }
    onProgress?.call('파일 검수 완료 · 결제 준비 중');
    return _readyInvoice(owner, invoice, request);
  }

  List<Map<String, dynamic>> _partTargets(
    Map<String, dynamic> target,
    PrintPdfUploadPlan plan,
  ) {
    final rawParts = target['parts'];
    final declarations = plan.declaration['parts'] as List;
    if (rawParts is! List || rawParts.length != plan.parts.length) {
      throw const FormatException('print_package_upload_invalid');
    }
    return [
      for (var index = 0; index < rawParts.length; index++)
        if (rawParts[index] is Map &&
            rawParts[index]['index'] == index &&
            rawParts[index]['byteLength'] == declarations[index]['bytes'] &&
            rawParts[index]['sha256'] == declarations[index]['sha256'])
          Map<String, dynamic>.from(rawParts[index] as Map)
        else
          throw const FormatException('print_package_upload_invalid'),
    ];
  }

  Future<Map<String, dynamic>> _uploadAndFinalize({
    required String owner,
    required PrintPaymentInvoice invoice,
    required PrintCheckoutRequest request,
    required String packageId,
    required Map<String, dynamic> manifest,
    required String kind,
    required String bucket,
    required Map<String, dynamic> target,
    required Uint8List bytes,
    int? partIndex,
  }) async {
    if (target['path'] is! String ||
        (target['path'] as String).isEmpty ||
        target['token'] is! String ||
        (target['token'] as String).isEmpty) {
      throw const FormatException('print_package_upload_invalid');
    }
    await _sameOwner(owner);
    var uploadUncertain = false;
    try {
      await repository.uploadPrintPrepaymentFile(
        bucket: bucket,
        path: target['path'] as String,
        token: target['token'] as String,
        bytes: bytes,
      );
    } catch (_) {
      // A lost response may leave the exact immutable file present. Only its
      // authenticated server hash inspection may resolve that uncertainty.
      uploadUncertain = true;
    }
    try {
      return await _finalize(
        owner: owner,
        invoice: invoice,
        request: request,
        packageId: packageId,
        kind: kind,
        manifest: manifest,
        partIndex: partIndex,
      );
    } catch (_) {
      if (uploadUncertain) {
        throw const PrintCheckoutApiException(
          'print_upload_not_confirmed',
          503,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _finalize({
    required String owner,
    required PrintPaymentInvoice invoice,
    required PrintCheckoutRequest request,
    required String packageId,
    required String kind,
    required Map<String, dynamic> manifest,
    int? partIndex,
  }) async {
    await _sameOwner(owner);
    final checked = await repository.invokePrintPrepaymentPackage(
      invoice: invoice,
      action: 'finalize',
      payload: {
        'packageId': packageId,
        'kind': kind,
        'manifest': manifest,
        if (partIndex != null) 'partIndex': partIndex,
      },
    );
    await _sameOwner(owner);
    _match(checked, invoice, request);
    return checked;
  }

  Future<PrintPaymentInvoice> _readyInvoice(
    String owner,
    PrintPaymentInvoice original,
    PrintCheckoutRequest request,
  ) async {
    final ready = await repository.preparePrintPayment(
      requestId: original.requestId,
      request: request,
    );
    await _sameOwner(owner);
    if (ready.orderId != original.orderId ||
        ready.paymentId != original.paymentId ||
        ready.requestId != original.requestId ||
        ready.albumId != request.albumId ||
        ready.totalAmount != request.amount ||
        ready.reviewedRevision != request.reviewedRevision ||
        ready.reviewedSpecRevision != request.reviewedSpecRevision ||
        !ready.printPackageReady ||
        ready.customerRequestHold) {
      throw const FormatException('print_package_invoice_mismatch');
    }
    return ready;
  }

  void _match(
    Map<String, dynamic> value,
    PrintPaymentInvoice invoice,
    PrintCheckoutRequest request,
  ) {
    if (value['orderId'] != invoice.orderId ||
        value['paymentId'] != invoice.paymentId ||
        value['requestId'] != invoice.requestId ||
        value['albumId'] != request.albumId ||
        value['reviewedRevision'] != request.reviewedRevision ||
        value['reviewedSpecRevision'] != request.reviewedSpecRevision) {
      throw const FormatException('print_package_identity_mismatch');
    }
  }

  Future<void> _sameOwner(String owner) async {
    if (await repository.printPaymentOwnerId() != owner) {
      throw StateError('print_payment_account_changed');
    }
  }
}

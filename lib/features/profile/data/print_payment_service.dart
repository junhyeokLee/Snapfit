import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/portone_payment.dart';
import '../../album/printing/album_print_exporter.dart';
import '../domain/print_checkout.dart';
import 'order_repository.dart';
import 'print_order_request_repository.dart';
import 'print_prepayment_package_service.dart';

/// Only order references are stored locally. Delivery details and SDK keys are
/// kept on the authenticated server, never in this recovery record.
class PendingPrintPayment {
  const PendingPrintPayment({
    required this.requestId,
    required this.albumId,
    required this.amount,
    this.orderId,
    this.paymentId,
    this.sdkStarted = false,
  });
  final String requestId;
  final int albumId;
  final int amount;
  final String? orderId;
  final String? paymentId;
  final bool sdkStarted;

  PendingPrintPayment invoice(PrintPaymentInvoice value) => PendingPrintPayment(
    requestId: requestId,
    albumId: albumId,
    amount: amount,
    orderId: value.orderId,
    paymentId: value.paymentId,
    sdkStarted: sdkStarted,
  );
  PendingPrintPayment started() => PendingPrintPayment(
    requestId: requestId,
    albumId: albumId,
    amount: amount,
    orderId: orderId,
    paymentId: paymentId,
    sdkStarted: true,
  );
  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'albumId': albumId,
    'amount': amount,
    'orderId': orderId,
    'paymentId': paymentId,
    'sdkStarted': sdkStarted,
  };
  factory PendingPrintPayment.fromJson(Map<String, dynamic> json) {
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch('${json['requestId']}') ||
        json['albumId'] is! int ||
        json['amount'] is! int ||
        (json['albumId'] as int) <= 0 ||
        (json['amount'] as int) <= 0) {
      throw const FormatException('print_payment_recovery_invalid');
    }
    return PendingPrintPayment(
      requestId: json['requestId'] as String,
      albumId: json['albumId'] as int,
      amount: json['amount'] as int,
      orderId: json['orderId'] as String?,
      paymentId: json['paymentId'] as String?,
      sdkStarted: json['sdkStarted'] == true,
    );
  }
}

class PrintPaymentRecoveryStore {
  Future<PendingPrintPayment?> read(String owner) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(owner));
    if (raw == null) return null;
    // Corrupt references must not silently permit a new charge.
    return PendingPrintPayment.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> write(String owner, PendingPrintPayment pending) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key(owner),
      jsonEncode(pending.toJson()),
    );
    if (!saved) throw StateError('print_payment_recovery_not_saved');
  }

  Future<void> clear(String owner) async {
    final removed = await (await SharedPreferences.getInstance()).remove(
      _key(owner),
    );
    if (!removed) throw StateError('print_payment_recovery_not_removed');
  }

  String _key(String owner) => 'snapfit_print_payment_pending_v1_$owner';
}

class PrintPaymentOutcome {
  const PrintPaymentOutcome({
    this.receipt,
    this.pending = false,
    this.noCharge = false,
    this.preparationError,
    this.verificationUnavailable = false,
  });
  final PrintPaidReceipt? receipt;
  final bool pending;
  final bool noCharge;
  final String? preparationError;

  /// The original attempt is retained; this is never evidence of a failed charge.
  final bool verificationUnavailable;
}

typedef PrintSdkLauncher =
    Future<PortOneSdkResult> Function(PortOnePaymentRequest);

/// Coordinates one durable production attempt per signed-in owner. All SDK
/// outcomes are verified against the original invoice before another attempt.
class PrintPaymentService {
  PrintPaymentService({
    required this.repository,
    PrintPaymentRecoveryStore? store,
    String Function()? requestId,
    PrintOrderRequestRepository? orderRequests,
    PrintPrepaymentPackageService? prepaymentPackages,
  }) : store = store ?? PrintPaymentRecoveryStore(),
       _requestId = requestId ?? const Uuid().v4,
       _orderRequests =
           orderRequests ?? PrintOrderRequestRepository(repository),
       _prepaymentPackages =
           prepaymentPackages ??
           PrintPrepaymentPackageService(repository: repository);
  final OrderRepository repository;
  final PrintPaymentRecoveryStore store;
  final String Function() _requestId;
  final PrintOrderRequestRepository _orderRequests;
  final PrintPrepaymentPackageService _prepaymentPackages;
  bool _busy = false;
  bool get busy => _busy;

  Future<PendingPrintPayment?> pending() async =>
      store.read(await repository.printPaymentOwnerId());

  /// A fresh authenticated request resolution, bound to the stored attempt, is
  /// required. Request submission, expiry or SDK cancellation cannot clear it.
  Future<bool> applyConfirmedReplacement(String requestId) async {
    if (_busy) return false;
    _busy = true;
    try {
      final owner = await repository.printPaymentOwnerId();
      final result = await _orderRequests.status(requestId: requestId);
      await _sameOwner(owner);
      if (!result.canReplace) return false;
      final pending = await store.read(owner);
      if (pending == null) return true;
      // This proof means the server never issued a payment window. A local
      // record that already started one remains ambiguous and must be kept.
      if (result.resolution == 'PRE_SDK_ABORTED' && pending.sdkStarted)
        return false;
      if (result.checkoutRequestId != pending.requestId ||
          pending.paymentId != null && result.paymentId != pending.paymentId ||
          pending.orderId != null && result.orderId != pending.orderId)
        return false;
      await store.clear(owner);
      return true;
    } finally {
      _busy = false;
    }
  }

  Future<PrintPaymentInvoice?> pendingInvoice() async {
    final owner = await repository.printPaymentOwnerId();
    final pending = await store.read(owner);
    if (pending == null) return null;
    final invoice = await _query(pending);
    await _sameOwner(owner);
    _match(pending, invoice);
    return invoice;
  }

  Future<PrintPaymentOutcome> pay(
    PrintCheckoutRequest request,
    PrintSdkLauncher launch, {
    PrintPreparationProgress? onProgress,
  }) async {
    if (_busy) return const PrintPaymentOutcome(pending: true);
    _busy = true;
    String? owner;
    var preparingFiles = false;
    try {
      owner = await repository.printPaymentOwnerId();
      var pending = await store.read(owner);
      if (pending != null) {
        PrintPaymentInvoice? existing;
        try {
          existing = await _query(pending);
        } on PrintCheckoutApiException catch (error) {
          // A local placeholder can retry only this SAME UUID on explicit pay.
          // Missing provider status never proves an issued invoice is unpaid.
          if (error.statusCode != 404 ||
              error.reasonCode != 'print_checkout_not_found' ||
              pending.sdkStarted ||
              pending.paymentId != null ||
              pending.orderId != null ||
              pending.albumId != request.albumId ||
              pending.amount != request.amount) {
            rethrow;
          }
        }
        await _sameOwner(owner);
        if (existing != null) {
          final outcome = await _settle(owner, pending, existing);
          if (outcome.receipt != null ||
              outcome.noCharge ||
              existing.customerRequestHold ||
              pending.sdkStarted ||
              pending.albumId != request.albumId ||
              pending.amount != request.amount)
            return outcome;
        }
        // Re-submit the SAME UUID for a server fingerprint check. An edited
        // address, price or reviewed artwork cannot silently reuse an old invoice.
        var resumed = await repository.preparePrintPayment(
          requestId: pending.requestId,
          request: request,
        );
        await _sameOwner(owner);
        _match(pending, resumed);
        pending = pending.invoice(resumed);
        await store.write(owner, pending);
        final settled = await _settle(owner, pending, resumed);
        if (settled.receipt != null || settled.noCharge) return settled;
        if (!resumed.printPackageReady && !resumed.customerRequestHold) {
          preparingFiles = true;
          resumed = await _prepaymentPackages.prepare(
            invoice: resumed,
            request: request,
            onProgress: onProgress,
          );
          await _sameOwner(owner);
          preparingFiles = false;
        }
        return await _launch(
          owner,
          pending,
          resumed,
          launch,
          request.reviewedSpecRevision,
        );
      }
      // Write the idempotency key before prepare: a lost response is recoverable
      // by this same request UUID without creating a second invoice.
      pending = PendingPrintPayment(
        requestId: _requestId(),
        albumId: request.albumId,
        amount: request.amount,
      );
      await store.write(owner, pending);
      var invoice = await repository.preparePrintPayment(
        requestId: pending.requestId,
        request: request,
      );
      await _sameOwner(owner);
      _match(pending, invoice);
      pending = pending.invoice(invoice);
      await store.write(owner, pending);
      final settled = await _settle(owner, pending, invoice);
      if (settled.receipt != null || settled.noCharge) return settled;
      if (!invoice.printPackageReady && !invoice.customerRequestHold) {
        preparingFiles = true;
        invoice = await _prepaymentPackages.prepare(
          invoice: invoice,
          request: request,
          onProgress: onProgress,
        );
        await _sameOwner(owner);
        preparingFiles = false;
      }
      return await _launch(
        owner,
        pending,
        invoice,
        launch,
        request.reviewedSpecRevision,
      );
    } catch (error) {
      return PrintPaymentOutcome(
        pending: true,
        preparationError: !preparingFiles
            ? null
            : error is PrintPreflightException
            ? error.code
            : error is PrintCheckoutApiException
            ? error.reasonCode
            : error.toString().contains('print_pdf_exceeds_vendor_limit') ||
                  error.toString().contains('print_pdf_exceeds_90mb_limit')
            ? 'print_checkout_pdf_too_large'
            : 'print_package_prepare_failed',
      );
    } finally {
      _busy = false;
    }
  }

  /// Recovery never launches a payment window. It checks the stored invoice only.
  Future<PrintPaymentOutcome> recover() async {
    if (_busy) return const PrintPaymentOutcome(pending: true);
    _busy = true;
    try {
      final owner = await repository.printPaymentOwnerId();
      final pending = await store.read(owner);
      if (pending == null) return const PrintPaymentOutcome();
      var invoice = await _query(pending);
      await _sameOwner(owner);
      _match(pending, invoice);
      await store.write(owner, pending.invoice(invoice));
      if (pending.sdkStarted && !invoice.verifiedPaid) {
        invoice = await repository.confirmPrintPayment(invoice.paymentId);
      }
      return await _settle(owner, pending, invoice);
    } catch (_) {
      return const PrintPaymentOutcome(
        pending: true,
        verificationUnavailable: true,
      );
    } finally {
      _busy = false;
    }
  }

  Future<PrintPaymentInvoice> _query(PendingPrintPayment pending) =>
      pending.paymentId == null
      ? repository.fetchPrintPaymentStatus(requestId: pending.requestId)
      : repository.fetchPrintPaymentStatus(paymentId: pending.paymentId);

  Future<PrintPaymentOutcome> _launch(
    String owner,
    PendingPrintPayment pending,
    PrintPaymentInvoice invoice,
    PrintSdkLauncher launch,
    String reviewedSpecRevision,
  ) async {
    _match(pending, invoice);
    final sdk = invoice.sdkRequest;
    if (pending.sdkStarted ||
        invoice.customerRequestHold ||
        !invoice.printPackageReady ||
        invoice.status != 'PREPARED' ||
        sdk == null ||
        sdk.environment != 'production' ||
        sdk.totalAmount != pending.amount ||
        invoice.reviewedSpecRevision != reviewedSpecRevision) {
      return const PrintPaymentOutcome(pending: true);
    }
    await _sameOwner(owner);
    // Persist BEFORE opening SDK; redirects and process death cannot erase it.
    await store.write(owner, pending.started());
    try {
      await launch(sdk);
    } catch (_) {
      /* Server still checks this ID. */
    }
    await _sameOwner(owner);
    final checked = await repository.confirmPrintPayment(invoice.paymentId);
    return await _settle(owner, pending.started(), checked);
  }

  void _match(PendingPrintPayment pending, PrintPaymentInvoice invoice) {
    if (invoice.requestId != pending.requestId ||
        invoice.albumId != pending.albumId ||
        invoice.totalAmount != pending.amount ||
        pending.orderId != null && pending.orderId != invoice.orderId ||
        pending.paymentId != null && pending.paymentId != invoice.paymentId) {
      throw const FormatException('print_payment_invoice_mismatch');
    }
  }

  Future<PrintPaymentOutcome> _settle(
    String owner,
    PendingPrintPayment pending,
    PrintPaymentInvoice invoice,
  ) async {
    await _sameOwner(owner);
    _match(pending, invoice);
    if (invoice.status == 'PAYMENT_COMPLETED' && invoice.verifiedPaid) {
      final receipt = await repository.fetchPrintPaidReceipt(
        orderId: invoice.orderId,
        albumId: pending.albumId,
        expectedAmount: pending.amount,
        expectedPaymentId: invoice.paymentId,
      );
      await _sameOwner(owner);
      await store.clear(owner);
      return PrintPaymentOutcome(receipt: receipt);
    }
    if (invoice.verifiedUnpaid &&
        {
          'FAILED',
          'CANCELED',
          'CANCELLED',
          'EXPIRED',
        }.contains(invoice.status)) {
      await store.clear(owner);
      return const PrintPaymentOutcome(noCharge: true);
    }
    return const PrintPaymentOutcome(pending: true);
  }

  Future<void> _sameOwner(String owner) async {
    if (await repository.printPaymentOwnerId() != owner)
      throw StateError('print_payment_account_changed');
  }
}

final printPaymentServiceProvider = Provider<PrintPaymentService>(
  (ref) => PrintPaymentService(repository: ref.watch(orderRepositoryProvider)),
);

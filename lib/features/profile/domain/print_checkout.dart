import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../data/order_repository.dart';
import 'entities/order_history_item.dart';
import 'portone_payment.dart';
import 'print_checkout_consent.dart';

/// A content comparison for the review flow; it is not payment evidence.
String printCheckoutRevision(Map<String, dynamic> snapshot) {
  dynamic document(dynamic value) {
    if (value is! String) return value;
    try {
      return jsonDecode(value);
    } on FormatException {
      return value;
    }
  }

  final album = (snapshot['album'] as Map?) ?? const {};
  final pages = (snapshot['pages'] as List?) ?? const [];
  final content = {
    'albumId': album['id'],
    'title': album['title'],
    'ratio': album['ratio'],
    'coverTheme': album['cover_theme'],
    'cover': document(album['cover_layers_json']),
    'printProduct': snapshot['printProduct'],
    'pages': [
      for (final raw in pages)
        if (raw is Map)
          {
            'index': raw['page_number'] ?? raw['page_index'],
            'content': document(raw['layers_json']),
          },
    ],
  };
  return _printCanonicalDigest(content);
}

String printSpecRevision(Map<String, dynamic> spec) =>
    _printCanonicalDigest(spec);
String _printCanonicalDigest(dynamic value) =>
    sha256.convert(utf8.encode(jsonEncode(_printCanonical(value)))).toString();
dynamic _printCanonical(dynamic value) {
  if (value is num) {
    if (!value.isFinite) throw const FormatException('revision_number_invalid');
    final bytes = ByteData(8)..setFloat64(0, value.toDouble(), Endian.big);
    return {
      r'$number64': bytes.buffer
          .asUint8List()
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
    };
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _printCanonical(value[key])};
  }
  if (value is List) return value.map(_printCanonical).toList();
  return value;
}

class PrintCheckoutReadiness {
  const PrintCheckoutReadiness({
    required this.canPay,
    required this.status,
    required this.reasonCode,
    required this.message,
    required this.quote,
    this.paymentProvider = 'UNCONFIGURED',
    this.environment = 'unavailable',
    this.reviewedRevision,
    this.reviewedSpecRevision,
  });

  final bool canPay;
  final String status;
  final String reasonCode;
  final String message;
  final OrderQuoteResult quote;
  final String paymentProvider;
  final String environment;
  final String? reviewedRevision;
  final String? reviewedSpecRevision;

  factory PrintCheckoutReadiness.fromJson(Map<String, dynamic> json) {
    final rawQuote = json['quote'];
    if (rawQuote is! Map) {
      throw const FormatException('print_checkout_quote_missing');
    }
    final quote = OrderQuoteResult.fromJson(
      Map<String, dynamic>.from(rawQuote),
    );
    if (quote.pageCount < 20 ||
        quote.pageCount > 80 ||
        quote.pageCount.isOdd ||
        quote.productCode.isEmpty) {
      throw const FormatException('print_checkout_quote_invalid');
    }
    final environment = '${json['environment'] ?? 'unavailable'}';
    final status = '${json['status'] ?? 'PREPARING'}';
    final provider = '${json['paymentProvider'] ?? 'UNCONFIGURED'}';
    return PrintCheckoutReadiness(
      // Price visibility alone does not permit a physical purchase.
      canPay:
          json['canPay'] == true &&
          status == 'READY' &&
          environment == 'production' &&
          provider == 'PORTONE' &&
          RegExp(
            r'^[a-f0-9]{64}$',
          ).hasMatch('${json['reviewedRevision'] ?? ''}') &&
          json['reviewedSpecRevision'] == printSpecRevision(quote.printSpec) &&
          quote.amount > 0 &&
          !quote.priceIsEstimate &&
          quote.supplierCostVerified &&
          quote.shippingCostVerified &&
          quote.packagingCostVerified &&
          quote.printSpec['verified'] == true &&
          !quote.specMissing,
      status: status,
      reasonCode: '${json['reasonCode'] ?? 'print_sales_not_ready'}',
      message: '${json['message'] ?? '인쇄 주문을 준비하고 있어요.'}',
      quote: quote,
      paymentProvider: provider,
      environment: environment,
      reviewedRevision: json['reviewedRevision']?.toString(),
      reviewedSpecRevision: json['reviewedSpecRevision']?.toString(),
    );
  }
}

/// Immutable identity returned by the authenticated checkout service.
/// This envelope alone is not proof of payment.
class PrintPaymentInvoice {
  const PrintPaymentInvoice({
    required this.orderId,
    required this.paymentId,
    required this.requestId,
    required this.status,
    required this.verifiedPaid,
    required this.verifiedUnpaid,
    required this.albumId,
    required this.totalAmount,
    this.sdkRequest,
    this.reviewedRevision,
    this.reviewedSpecRevision,
    this.recipient = const {},
    this.customerRequestHold = false,
    this.printPackageReady = false,
  });
  final String orderId;
  final String paymentId;
  final String requestId;
  final String status;
  final bool verifiedPaid;
  final bool verifiedUnpaid;
  final int albumId;
  final int totalAmount;
  final PortOnePaymentRequest? sdkRequest;
  final String? reviewedRevision;
  final String? reviewedSpecRevision;
  final Map<String, dynamic> recipient;
  final bool customerRequestHold;
  final bool printPackageReady;

  factory PrintPaymentInvoice.fromJson(Map<String, dynamic> json) {
    final orderId = '${json['orderId'] ?? ''}';
    final paymentId = '${json['paymentId'] ?? ''}';
    final requestId = '${json['requestId'] ?? ''}';
    if (json['environment'] != 'production' ||
        orderId.isEmpty ||
        json['albumId'] is! int ||
        (json['albumId'] as int) <= 0 ||
        json['totalAmount'] is! int ||
        (json['totalAmount'] as int) <= 0 ||
        !RegExp(r'^[A-Za-z0-9_-]{16,100}$').hasMatch(paymentId) ||
        paymentId.startsWith('SFPGT_') ||
        !RegExp(
          r'^[a-f0-9]{64}$',
        ).hasMatch('${json['reviewedSpecRevision'] ?? ''}') ||
        !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(requestId) ||
        (json['customerRequestHold'] != null &&
            json['customerRequestHold'] is! bool)) {
      throw const FormatException('print_payment_invoice_invalid');
    }
    final sdk = json['sdkRequest'];
    final sdkRequest = sdk is Map
        ? PortOnePaymentRequest.fromProductionReady(
            Map<String, dynamic>.from(sdk),
          )
        : null;
    if (sdkRequest != null && sdkRequest.paymentId != paymentId) {
      throw const FormatException('print_payment_invoice_mismatch');
    }
    return PrintPaymentInvoice(
      orderId: orderId,
      paymentId: paymentId,
      requestId: requestId,
      status: '${json['status'] ?? 'UNKNOWN'}',
      verifiedPaid: json['verifiedPaid'] == true,
      verifiedUnpaid: json['verifiedUnpaid'] == true,
      albumId: json['albumId'] as int,
      totalAmount: json['totalAmount'] as int,
      sdkRequest: sdkRequest,
      reviewedRevision: json['reviewedRevision']?.toString(),
      reviewedSpecRevision: json['reviewedSpecRevision']?.toString(),
      customerRequestHold: json['customerRequestHold'] == true,
      printPackageReady: json['printPackageReady'] == true,
      recipient: json['recipient'] is Map
          ? Map<String, dynamic>.from(json['recipient'] as Map)
          : const {},
    );
  }
}

class PrintCheckoutApiException implements Exception {
  const PrintCheckoutApiException(this.reasonCode, this.statusCode);
  final String reasonCode;
  final int statusCode;
}

/// Sanitized progress from an authenticated RPC. A vendor receipt, file check,
/// production start and courier handoff each require their own evidence.
class PrintOrderProgress {
  const PrintOrderProgress({
    required this.orderId,
    required this.customerStage,
    required this.preflightPassed,
    required this.requiresAction,
    this.filesReadyAt,
    this.vendorAcceptedAt,
    this.fileCheckedAt,
    this.productionStartedAt,
    this.shippedAt,
    this.courier,
    this.trackingNumber,
  });
  final String orderId;
  final String customerStage;
  final bool preflightPassed;
  final bool requiresAction;
  final DateTime? filesReadyAt;
  final DateTime? vendorAcceptedAt;
  final DateTime? fileCheckedAt;
  final DateTime? productionStartedAt;
  final DateTime? shippedAt;
  final String? courier;
  final String? trackingNumber;
  factory PrintOrderProgress.fromJson(Map<String, dynamic> json) {
    final orderId = '${json['orderId'] ?? ''}';
    if (orderId.isEmpty)
      throw const FormatException('print_order_progress_invalid');
    DateTime? date(String key) => DateTime.tryParse('${json[key] ?? ''}');
    return PrintOrderProgress(
      orderId: orderId,
      customerStage: '${json['customerStage'] ?? 'PAID'}',
      preflightPassed: json['preflightPassed'] == true,
      requiresAction: json['requiresAction'] == true,
      filesReadyAt: date('filesReadyAt'),
      vendorAcceptedAt: date('vendorAcceptedAt'),
      fileCheckedAt: date('fileCheckedAt'),
      productionStartedAt: date('productionStartedAt'),
      shippedAt: date('shippedAt'),
      courier: json['courier']?.toString(),
      trackingNumber: json['trackingNumber']?.toString(),
    );
  }
  String get label => switch (customerStage) {
    'PAYMENT_PENDING' => '결제 확인 대기',
    'QUEUED' || 'PAID' => '주문 접수 대기',
    'RENDERING' => '인쇄 파일 생성 중',
    'FILES_READY' => '자동 발주 대기',
    'SUBMISSION_UNKNOWN' => '제작사 접수 확인 중',
    'VENDOR_ACCEPTED' || 'FILE_CHECKING' => '제작사 파일 확인 중',
    'FILE_CHECKED' || 'PRODUCTION_PENDING' => '책 제작 대기',
    'PRODUCTION' || 'IN_PRODUCTION' => '책 제작 중',
    'SHIPPING' => '배송 중',
    'DELIVERED' => '배송 완료',
    'CANCELED' || 'CANCELLED' => '주문 취소',
    'FILE_ERROR' || 'HOLD' || 'REVIEW_REQUIRED' => '제작 준비 확인 중',
    _ => '제작 진행 상황 확인 중',
  };
}

class PrintCheckoutRequest {
  const PrintCheckoutRequest({
    required this.albumId,
    required this.reviewedRevision,
    required this.amount,
    required this.recipientName,
    required this.recipientPhone,
    required this.zipCode,
    required this.addressLine1,
    required this.addressLine2,
    this.reviewedSpecRevision = '',
    this.deliveryMemo = '',
    this.consent,
  });

  final int albumId;
  final String reviewedRevision;
  final String reviewedSpecRevision;
  final int amount;
  final String recipientName;
  final String recipientPhone;
  final String zipCode;
  final String addressLine1;
  final String addressLine2;
  final String deliveryMemo;
  final PrintCheckoutConsent? consent;
}

/// Constructed only from an order read back through the authenticated repository.
/// A payment-window callback or a client `success=true` cannot create a receipt.
class PrintPaidReceipt {
  const PrintPaidReceipt._({
    required this.orderId,
    required this.albumId,
    required this.title,
    required this.amount,
    required this.paidAt,
    required this.status,
  });

  final String orderId;
  final int albumId;
  final String title;
  final int amount;
  final DateTime paidAt;
  final String status;
  bool get isValid => true;

  factory PrintPaidReceipt.fromOrder(OrderHistoryItem order) {
    const paidStatuses = {
      'PAYMENT_COMPLETED',
      'IN_PRODUCTION',
      'PRINTING',
      'SHIPPING',
      'DELIVERED',
    };
    final albumId = order.albumId;
    final paidAt = order.paymentConfirmedAt;
    if (order.orderId.isEmpty ||
        albumId == null ||
        albumId <= 0 ||
        order.amount <= 0 ||
        paidAt == null ||
        !paidStatuses.contains(order.status.toUpperCase())) {
      throw const FormatException('print_payment_not_confirmed');
    }
    return PrintPaidReceipt._(
      orderId: order.orderId,
      albumId: albumId,
      title: order.title,
      amount: order.amount,
      paidAt: paidAt,
      status: order.status.toUpperCase(),
    );
  }
}

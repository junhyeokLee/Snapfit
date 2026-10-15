import '../../../album/printing/print_vendor_spec.dart';

class OrderHistoryItem {
  final String orderId;
  final String title;
  final int amount;
  final int? pageCount;
  final String status;
  final String statusLabel;
  final double progress;
  final DateTime orderedAt;
  final int? albumId;
  final String? recipientName;
  final String? recipientPhone;
  final String? zipCode;
  final String? addressLine1;
  final String? addressLine2;
  final String? deliveryMemo;
  final String? paymentMethod;
  final String? courier;
  final String? trackingNumber;
  final String? printVendor;
  final String? printVendorOrderId;
  final String? printPackageJsonUrl;
  final String? printFilePdfUrl;
  final String? printFileZipUrl;
  final int? printAssetCount;
  final DateTime? paymentConfirmedAt;
  final DateTime? preparationAbortedAt;
  final DateTime? printPackageGeneratedAt;
  final DateTime? printSubmittedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String? printFulfillmentStatus;
  final String? printCoverPdfPath;
  final String? printInteriorPdfPath;
  final Map<String, dynamic> printManifest;
  final Map<String, dynamic> printCostSnapshot;
  final Map<String, dynamic> printProductSnapshot;
  final String? pricingVersion;

  PrintProduct? get printProduct {
    if (pricingVersion == 'PRINT_REDP_200_SOFT_V1') {
      return PrintProduct.forId('REDP_200_SOFT');
    }
    if (printProductSnapshot.isEmpty) return null;
    try {
      final product = PrintProduct.fromJson(printProductSnapshot);
      if (pricingVersion == 'PRINT_REDP_MULTISIZE_V2' && product.isHardcover)
        return null;
      return product;
    } on FormatException {
      return null;
    }
  }

  String get printProductLabel => printProduct?.label ?? '제작 크기 확인 필요';
  final int? actualPrintCost;
  final int? actualShippingCost;
  final int? actualPackagingCost;
  final int? contributionMargin;
  final DateTime? printAcceptedAt;
  final String? fulfillmentMethod;
  final Map<String, dynamic> fulfillmentConfirmation;

  bool get hasPrintFiles =>
      (printCoverPdfPath?.isNotEmpty ?? false) &&
      (printInteriorPdfPath?.isNotEmpty ?? false);

  String get fulfillmentLabel => switch (printFulfillmentStatus) {
    'AWAITING_RENDER' => '인쇄 파일 준비 대기',
    'RENDERING' => '인쇄 파일 생성중',
    'REVIEW_REQUIRED' => '인쇄 파일 검수 대기',
    'READY' => '발주 준비 완료',
    'SUBMITTED' => '제작사 접수 확인 대기',
    'ACCEPTED' => '제작사 접수 완료',
    'FILE_CHECKED' => '제작사 파일 확인 완료',
    'PRODUCTION' || 'IN_PRODUCTION' => '책 제작 중',
    'SHIPPED' => '택배 출고 완료',
    'DELIVERED' => '배송 완료',
    'FILE_ERROR' => '인쇄 파일 확인 필요',
    'FAILED' || 'RENDER_FAILED' || 'PREFLIGHT_FAILED' => '제작 준비 확인 필요',
    _ => '인쇄 준비 상태 미확인',
  };

  bool get requiresPrintAttention => {
    'FILE_ERROR',
    'FAILED',
    'RENDER_FAILED',
    'PREFLIGHT_FAILED',
    'REVIEW_REQUIRED',
  }.contains(printFulfillmentStatus);

  bool get isFinal => const {
    'DELIVERED',
    'CANCELED',
    'CANCELLED',
    'PREPARATION_CANCELED',
  }.contains(status.toUpperCase());

  String get customerStatusLabel {
    final current = status.toUpperCase();
    if (current == 'PAYMENT_PENDING') return '결제 확인 대기';
    if (current == 'PREPARATION_CANCELED') return '주문 준비 취소';
    if (current != 'PAYMENT_COMPLETED') return statusLabel;
    if (paymentConfirmedAt == null) return '결제 상태 확인 중';
    if (requiresPrintAttention) return '주문 확인 중';
    return switch (printFulfillmentStatus) {
      'READY' => '자동 발주 대기',
      'SUBMITTED' => '제작사 접수 확인 중',
      'ACCEPTED' => '인쇄 파일 확인 중',
      'FILE_CHECKED' => '책 제작 대기',
      _ => '제작 준비 중',
    };
  }

  String get customerStatusDescription {
    switch (status.toUpperCase()) {
      case 'PAYMENT_PENDING':
        return '아직 결제 완료가 확인되지 않았어요. 기존 주문의 결제 결과를 확인하거나 준비를 이어갈 수 있어요.';
      case 'PREPARATION_CANCELED':
        return '결제 전 주문 준비가 취소됐어요. 앨범을 수정해 다시 주문을 준비할 수 있어요.';
      case 'CANCELED':
      case 'CANCELLED':
        return '취소된 주문이에요. 환불이나 처리 내역이 궁금하면 주문 문의에서 확인해주세요.';
      case 'SHIPPING':
        return '택배사에 책을 전달했어요. 송장번호가 등록되면 배송 조회를 이용할 수 있어요.';
      case 'DELIVERED':
        return '배송이 완료됐어요. 인쇄나 배송에 문제가 있다면 주문 문의로 알려주세요.';
      case 'IN_PRODUCTION':
      case 'PRINTING':
        return '책을 제작하고 있어요. 제작이 시작된 주문은 취소가 어려울 수 있어요.';
    }
    if (paymentConfirmedAt == null) {
      return '서버에서 결제 결과를 확인하고 있어요. 결제 완료는 확인된 결과로만 표시돼요.';
    }
    if (requiresPrintAttention) {
      return '결제한 주문은 보관되어 있어요. 제작 준비 상태를 확인하고 있으며, 필요한 안내는 이 주문에서 확인할 수 있어요.';
    }
    return '결제 확인 후 인쇄 파일 검수와 제작사 주문 접수가 자동으로 이어져요. 앱을 닫아도 진행되며 이 화면에서 확인할 수 있어요.';
  }

  const OrderHistoryItem({
    required this.orderId,
    required this.title,
    required this.amount,
    this.pageCount,
    required this.status,
    required this.statusLabel,
    required this.progress,
    required this.orderedAt,
    this.albumId,
    this.recipientName,
    this.recipientPhone,
    this.zipCode,
    this.addressLine1,
    this.addressLine2,
    this.deliveryMemo,
    this.paymentMethod,
    this.courier,
    this.trackingNumber,
    this.printVendor,
    this.printVendorOrderId,
    this.printPackageJsonUrl,
    this.printFilePdfUrl,
    this.printFileZipUrl,
    this.printAssetCount,
    this.paymentConfirmedAt,
    this.preparationAbortedAt,
    this.printPackageGeneratedAt,
    this.printSubmittedAt,
    this.shippedAt,
    this.deliveredAt,
    this.printFulfillmentStatus,
    this.printCoverPdfPath,
    this.printInteriorPdfPath,
    this.printManifest = const {},
    this.printCostSnapshot = const {},
    this.printProductSnapshot = const {},
    this.pricingVersion,
    this.actualPrintCost,
    this.actualShippingCost,
    this.actualPackagingCost,
    this.contributionMargin,
    this.printAcceptedAt,
    this.fulfillmentMethod,
    this.fulfillmentConfirmation = const {},
  });

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseOptionalDate(String key) =>
        _parseServerDateTime(json[key]?.toString());

    return OrderHistoryItem(
      orderId: json['orderId']?.toString() ?? '',
      title: json['title']?.toString() ?? '주문',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      pageCount: (json['pageCount'] as num?)?.toInt(),
      status: json['status']?.toString() ?? 'PAYMENT_PENDING',
      statusLabel: json['statusLabel']?.toString() ?? '결제대기',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      orderedAt:
          _parseServerDateTime(json['orderedAt']?.toString()) ?? DateTime.now(),
      albumId: (json['albumId'] as num?)?.toInt(),
      recipientName: json['recipientName']?.toString(),
      recipientPhone: json['recipientPhone']?.toString(),
      zipCode: json['zipCode']?.toString(),
      addressLine1: json['addressLine1']?.toString(),
      addressLine2: json['addressLine2']?.toString(),
      deliveryMemo: json['deliveryMemo']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      courier: json['courier']?.toString(),
      trackingNumber: json['trackingNumber']?.toString(),
      printVendor: json['printVendor']?.toString(),
      printVendorOrderId: json['printVendorOrderId']?.toString(),
      printPackageJsonUrl: json['printPackageJsonUrl']?.toString(),
      printFilePdfUrl: json['printFilePdfUrl']?.toString(),
      printFileZipUrl: json['printFileZipUrl']?.toString(),
      printAssetCount: (json['printAssetCount'] as num?)?.toInt(),
      paymentConfirmedAt: parseOptionalDate('paymentConfirmedAt'),
      preparationAbortedAt: parseOptionalDate('preparationAbortedAt'),
      printPackageGeneratedAt: parseOptionalDate('printPackageGeneratedAt'),
      printSubmittedAt: parseOptionalDate('printSubmittedAt'),
      shippedAt: parseOptionalDate('shippedAt'),
      deliveredAt: parseOptionalDate('deliveredAt'),
      printFulfillmentStatus: json['printFulfillmentStatus']?.toString(),
      printCoverPdfPath: json['printCoverPdfPath']?.toString(),
      printInteriorPdfPath: json['printInteriorPdfPath']?.toString(),
      printManifest:
          (json['printManifest'] as Map?)?.cast<String, dynamic>() ?? const {},
      printCostSnapshot:
          (json['printCostSnapshot'] as Map?)?.cast<String, dynamic>() ??
          const {},
      printProductSnapshot:
          (json['printProductSnapshot'] as Map?)?.cast<String, dynamic>() ??
          const {},
      pricingVersion: json['pricingVersion']?.toString(),
      actualPrintCost: (json['actualPrintCost'] as num?)?.toInt(),
      actualShippingCost: (json['actualShippingCost'] as num?)?.toInt(),
      actualPackagingCost: (json['actualPackagingCost'] as num?)?.toInt(),
      contributionMargin: (json['contributionMargin'] as num?)?.toInt(),
      printAcceptedAt: parseOptionalDate('printAcceptedAt'),
      fulfillmentMethod: json['fulfillmentMethod']?.toString(),
      fulfillmentConfirmation:
          (json['fulfillmentConfirmation'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
  }

  static DateTime? _parseServerDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;

    // 서버가 LocalDateTime(타임존 없는 문자열)로 내려줄 때는 UTC 기준으로 저장된 값으로 간주하고 KST로 변환한다.
    if (!text.endsWith('Z') && !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(text)) {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      ).toLocal();
    }
    return parsed.toLocal();
  }
}

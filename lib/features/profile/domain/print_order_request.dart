const _requestUuid =
    r'[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}';

bool isPrintOrderRequestOrderId(String value) =>
    RegExp('^ordp_$_requestUuid\$').hasMatch(value);

class PrintOrderRequestTarget {
  const PrintOrderRequestTarget._({
    this.orderId,
    this.paymentId,
    this.checkoutRequestId,
  });
  factory PrintOrderRequestTarget.order(String value) {
    if (!isPrintOrderRequestOrderId(value))
      throw const FormatException('invalid_order_request_target');
    return PrintOrderRequestTarget._(orderId: value);
  }
  factory PrintOrderRequestTarget.payment(String value) {
    if (!RegExp('^SFP_$_requestUuid\$').hasMatch(value))
      throw const FormatException('invalid_order_request_target');
    return PrintOrderRequestTarget._(paymentId: value);
  }
  factory PrintOrderRequestTarget.checkout(String value) {
    if (!RegExp('^$_requestUuid\$').hasMatch(value))
      throw const FormatException('invalid_order_request_target');
    return PrintOrderRequestTarget._(checkoutRequestId: value);
  }
  final String? orderId, paymentId, checkoutRequestId;
  Map<String, dynamic> toJson() => {
    if (orderId != null) 'orderId': orderId,
    if (paymentId != null) 'paymentId': paymentId,
    if (checkoutRequestId != null) 'checkoutRequestId': checkoutRequestId,
  };
  bool matches(PrintOrderRequestResult result) => orderId != null
      ? result.orderId == orderId
      : paymentId != null
      ? result.paymentId == paymentId
      : result.checkoutRequestId == checkoutRequestId;
}

class PrintOrderRequestResult {
  const PrintOrderRequestResult._({
    required this.requestId,
    required this.checkoutRequestId,
    required this.type,
    required this.status,
    required this.resolution,
    required this.replacementAllowed,
    required this.orderId,
    required this.paymentId,
    required this.createdAt,
    required this.updatedAt,
    required this.message,
    required this.preSdkAbortVerified,
  });
  final String requestId,
      checkoutRequestId,
      type,
      status,
      resolution,
      orderId,
      paymentId,
      message;
  final bool replacementAllowed;
  final bool preSdkAbortVerified;
  final DateTime createdAt, updatedAt;
  bool get canReplace =>
      status == 'COMPLETED' &&
      replacementAllowed &&
      (const ['CANCELLED_UNPAID', 'REFUNDED_FULL'].contains(resolution) ||
          resolution == 'PRE_SDK_ABORTED' && preSdkAbortVerified);
  bool get unresolvedFinancial => type != 'GENERAL' && status != 'COMPLETED';
  String get label => switch (status) {
    'WAITING_PROVIDER' => '결제·제작사 상태 확인 중',
    'REVIEW_REQUIRED' => '담당자 확인 필요',
    'COMPLETED' => switch (resolution) {
      'CANCELLED_UNPAID' => '미결제 주문 취소 확인됨',
      'REFUNDED_FULL' => '전액 환불 확인됨',
      'PRE_SDK_ABORTED' =>
        preSdkAbortVerified ? '결제 전 준비 주문 취소됨' : '준비 주문 처리 결과 확인 필요',
      _ => '문의 처리 완료',
    },
    _ => '요청 접수됨',
  };
  factory PrintOrderRequestResult.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty || value.length > 1000)
        throw const FormatException('invalid_order_request_response');
      return value;
    }

    final id = text('requestId'),
        type = text('type'),
        status = text('status'),
        resolution = text('resolution');
    final order = text('orderId'),
        payment = text('paymentId'),
        checkout = text('checkoutRequestId');
    final created = DateTime.tryParse('${json['createdAt'] ?? ''}'),
        updated = DateTime.tryParse('${json['updatedAt'] ?? ''}');
    if (!RegExp('^$_requestUuid\$').hasMatch(id) ||
        !RegExp('^$_requestUuid\$').hasMatch(checkout) ||
        !isPrintOrderRequestOrderId(order) ||
        !RegExp('^SFP_$_requestUuid\$').hasMatch(payment) ||
        !const ['CANCEL', 'REFUND', 'GENERAL'].contains(type) ||
        !const [
          'REQUESTED',
          'WAITING_PROVIDER',
          'REVIEW_REQUIRED',
          'COMPLETED',
        ].contains(status) ||
        !const [
          'NONE',
          'CANCELLED_UNPAID',
          'REFUNDED_FULL',
          'PRE_SDK_ABORTED',
        ].contains(resolution) ||
        json['replacementAllowed'] is! bool ||
        (json['preSdkAbortVerified'] != null &&
            json['preSdkAbortVerified'] is! bool) ||
        created == null ||
        updated == null ||
        updated.isBefore(created) ||
        (status != 'COMPLETED' && resolution != 'NONE') ||
        (type == 'GENERAL' && resolution != 'NONE') ||
        (json['replacementAllowed'] == true &&
            (status != 'COMPLETED' || resolution == 'NONE')) ||
        (json['preSdkAbortVerified'] == true &&
            (status != 'COMPLETED' ||
                resolution != 'PRE_SDK_ABORTED' ||
                type == 'GENERAL' ||
                json['replacementAllowed'] != true)) ||
        (resolution == 'PRE_SDK_ABORTED' &&
            json['replacementAllowed'] == true &&
            json['preSdkAbortVerified'] != true)) {
      throw const FormatException('invalid_order_request_response');
    }
    return PrintOrderRequestResult._(
      requestId: id,
      checkoutRequestId: checkout,
      type: type,
      status: status,
      resolution: resolution,
      replacementAllowed: json['replacementAllowed'] as bool,
      orderId: order,
      paymentId: payment,
      createdAt: created,
      updatedAt: updated,
      message: text('message'),
      preSdkAbortVerified: json['preSdkAbortVerified'] == true,
    );
  }
}

class PrintOrderRequestException implements Exception {
  const PrintOrderRequestException(this.code, this.statusCode);
  final String code;
  final int statusCode;
}

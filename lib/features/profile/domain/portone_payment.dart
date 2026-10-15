/// An SDK request prepared by the authenticated server bridge.
/// Environment is a gate here; PortOne itself selects test mode by channel.
class PortOnePaymentRequest {
  const PortOnePaymentRequest._({
    required this.storeId,
    required this.channelKey,
    required this.paymentId,
    required this.orderName,
    required this.totalAmount,
    required this.environment,
    this.redirectUrl,
  });

  final String storeId;
  final String channelKey;
  final String paymentId;
  final String orderName;
  final int totalAmount;
  final Uri? redirectUrl;
  String get currency => 'KRW';
  final String environment;
  String get appScheme => 'snapfit';

  factory PortOnePaymentRequest.fromPrepared(Map<String, dynamic> json) {
    String text(String key) => '${json[key] ?? ''}'.trim();
    final amount = json['totalAmount'];
    final rawRedirect = text('redirectUrl');
    final redirect = rawRedirect.isEmpty ? null : Uri.tryParse(rawRedirect);
    final isLocal =
        redirect != null &&
        redirect.scheme == 'http' &&
        {'localhost', '127.0.0.1', '::1'}.contains(redirect.host);
    if (text('status') != 'PREPARED' ||
        text('environment') != 'test' ||
        text('currency') != 'KRW' ||
        amount is! int ||
        amount <= 0 ||
        amount > 10000000 ||
        !RegExp(r'^store-[A-Za-z0-9-]{8,100}$').hasMatch(text('storeId')) ||
        !RegExp(
          r'^channel-key-[A-Za-z0-9-]{8,100}$',
        ).hasMatch(text('channelKey')) ||
        !RegExp(r'^SFPGT_[A-Za-z0-9_-]{16,80}$').hasMatch(text('paymentId')) ||
        text('orderName').isEmpty ||
        text('orderName').length > 200 ||
        rawRedirect.isNotEmpty &&
            (redirect == null ||
                !redirect.hasAuthority ||
                redirect.userInfo.isNotEmpty ||
                redirect.scheme != 'https' && !isLocal)) {
      throw const FormatException('portone_test_request_invalid');
    }
    return PortOnePaymentRequest._(
      storeId: text('storeId'),
      channelKey: text('channelKey'),
      paymentId: text('paymentId'),
      orderName: text('orderName'),
      totalAmount: amount,
      environment: 'test',
      redirectUrl: redirect,
    );
  }

  /// Customer checkout accepts an explicitly ready production invoice only.
  /// The caller must still match it to the owned prepared order and verify after SDK.
  factory PortOnePaymentRequest.fromProductionReady(Map<String, dynamic> json) {
    final paymentId = '${json['paymentId'] ?? ''}';
    if (json['status'] != 'READY' ||
        json['environment'] != 'production' ||
        paymentId.startsWith('SFPGT_') ||
        !RegExp(r'^[A-Za-z0-9_-]{16,100}$').hasMatch(paymentId)) {
      throw const FormatException('portone_production_request_invalid');
    }
    // Reuse the strict public SDK-field validation without allowing a test invoice
    // to be promoted into production by a callback or environment default.
    final validated = PortOnePaymentRequest.fromPrepared({
      ...json,
      'status': 'PREPARED',
      'environment': 'test',
      'paymentId': 'SFPGT_00000000-0000-4000-8000-000000000000',
    });
    return PortOnePaymentRequest._(
      storeId: validated.storeId,
      channelKey: validated.channelKey,
      paymentId: paymentId,
      orderName: validated.orderName,
      totalAmount: validated.totalAmount,
      environment: 'production',
      redirectUrl: validated.redirectUrl,
    );
  }

  PortOnePaymentRequest withReturnUrl(Uri uri) {
    final raw = {
      ...toBrowserJson(),
      'redirectUrl': uri.toString(),
      'environment': environment,
      'status': environment == 'test' ? 'PREPARED' : 'READY',
    };
    return environment == 'test'
        ? PortOnePaymentRequest.fromPrepared(raw)
        : PortOnePaymentRequest.fromProductionReady(raw);
  }

  Map<String, dynamic> toBrowserJson() => {
    'storeId': storeId,
    'channelKey': channelKey,
    'paymentId': paymentId,
    'orderName': orderName,
    'totalAmount': totalAmount,
    'currency': currency,
    'payMethod': 'CARD',
    'appScheme': appScheme,
    if (redirectUrl != null) 'redirectUrl': redirectUrl.toString(),
  };
}

enum PortOneSdkStatus { returned, canceled, failed }

/// A payment-window outcome, never a paid receipt. Always verify on the server.
class PortOneSdkResult {
  const PortOneSdkResult._(this.status, {this.paymentId, this.reasonCode});
  const PortOneSdkResult.canceled()
    : this._(PortOneSdkStatus.canceled, reasonCode: 'sdk_canceled');
  const PortOneSdkResult.failed(String reasonCode)
    : this._(PortOneSdkStatus.failed, reasonCode: reasonCode);

  final PortOneSdkStatus status;
  final String? paymentId;
  final String? reasonCode;

  /// Always query the original prepared payment ID after the SDK returns.
  /// Closing the window or receiving an error cannot prove that no charge ran.
  /// Recover that server state before preparing another payment attempt.
  bool get requiresServerVerification => true;

  factory PortOneSdkResult.fromCallback(
    Object? raw,
    PortOnePaymentRequest request,
  ) {
    if (raw == null) return const PortOneSdkResult.canceled();
    if (raw is! Map) {
      return const PortOneSdkResult.failed('sdk_response_invalid');
    }
    final code = '${raw['code'] ?? ''}'.trim();
    if (code.isNotEmpty) {
      return code.toUpperCase().contains('CANCEL')
          ? const PortOneSdkResult.canceled()
          : const PortOneSdkResult.failed('sdk_rejected');
    }
    if (raw['paymentId'] != request.paymentId) {
      return const PortOneSdkResult.failed('sdk_identity_mismatch');
    }
    return PortOneSdkResult._(
      PortOneSdkStatus.returned,
      paymentId: request.paymentId,
    );
  }
}

import '../../../core/commerce/commerce_policy.dart';

/// The server binds these affirmative choices to its own immutable quote,
/// artwork revision and acceptance time. A client timestamp is not evidence.
class PrintCheckoutConsent {
  const PrintCheckoutConsent({
    required this.orderReviewed,
    required this.policyAccepted,
    required this.customProductionAccepted,
  });

  static const version = 'PRINT_ORDER_CONSENT_2026_10_19';
  static const reviewNotice =
      '최종 인쇄 미리보기의 사진·글·페이지 순서, 제작 구성, 배송지와 금액을 확인했습니다.';

  final bool orderReviewed;
  final bool policyAccepted;
  final bool customProductionAccepted;

  bool get complete =>
      orderReviewed && policyAccepted && customProductionAccepted;

  Map<String, dynamic> toJson() {
    if (!complete) {
      throw const FormatException('print_checkout_consent_required');
    }
    return {
      'version': version,
      'policyVersion': CommercePolicy.refundVersion,
      'orderReviewed': true,
      'policyAccepted': true,
      'customProductionAccepted': true,
      'customProductionNotice': CommercePolicy.customProductionConsent,
    };
  }
}

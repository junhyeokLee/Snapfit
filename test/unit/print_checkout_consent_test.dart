import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/commerce/commerce_policy.dart';
import 'package:snap_fit/features/profile/domain/print_checkout_consent.dart';

void main() {
  test('a purchase requires every separate affirmative choice', () {
    for (var bits = 0; bits < 7; bits++) {
      final consent = PrintCheckoutConsent(
        orderReviewed: bits & 1 != 0,
        policyAccepted: bits & 2 != 0,
        customProductionAccepted: bits & 4 != 0,
      );
      expect(consent.complete, isFalse);
      expect(consent.toJson, throwsFormatException);
    }
  });

  test(
    'the request carries the exact versioned notice without client time',
    () {
      const consent = PrintCheckoutConsent(
        orderReviewed: true,
        policyAccepted: true,
        customProductionAccepted: true,
      );
      expect(consent.complete, isTrue);
      expect(consent.toJson(), {
        'version': 'PRINT_ORDER_CONSENT_2026_10_19',
        'policyVersion': CommercePolicy.refundVersion,
        'orderReviewed': true,
        'policyAccepted': true,
        'customProductionAccepted': true,
        'customProductionNotice': CommercePolicy.customProductionConsent,
      });
      expect(consent.toJson().containsKey('acceptedAt'), isFalse);
    },
  );
}

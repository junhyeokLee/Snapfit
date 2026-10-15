import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/billing/domain/billing_failure_copy.dart';

void main() {
  test('store unavailable copy points testers to store account setup', () {
    expect(billingStoreUnavailableMessage(), contains('Google Play'));
    expect(billingStoreUnavailableMessage(), contains('App Store'));
  });

  test('missing product copy does not expose internal store identifiers', () {
    final message = billingMissingProductsMessage([
      'snapfit_points_2500',
      'snapfit_points_8000',
    ]);

    expect(message, isNot(contains('sandbox')));
    expect(message, isNot(contains('snapfit_points_2500')));
    expect(message, isNot(contains('secret')));
    expect(message, isNot(contains('token')));
  });

  test('purchase update copy explains no point charge on failure', () {
    final message = billingPurchaseUpdateFailureMessage(
      code: 'billing_unavailable',
      message: 'StoreKit service unavailable',
    );

    expect(message, contains('스토어 로그인'));
    expect(message, isNot(contains('sandbox')));
  });

  test(
    'verification failure copy asks restore instead of leaking raw errors',
    () {
      final message = billingVerificationFailureMessage(
        Exception('invalid receipt token abc123'),
      );

      expect(message, contains('구매 복원'));
      expect(message, isNot(contains('abc123')));
      expect(message, isNot(contains('receipt token')));
    },
  );

  test('server credential failure copy stays operational and non-secret', () {
    final message = billingVerificationFailureMessage(
      Exception('GOOGLE_SERVICE_ACCOUNT_JSON private key missing'),
    );

    expect(message, contains('서버 설정'));
    expect(message, isNot(contains('private key')));
    expect(message, isNot(contains('GOOGLE_SERVICE_ACCOUNT_JSON')));
  });
}

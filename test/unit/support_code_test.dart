import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/billing/domain/billing_failure_copy.dart';

void main() {
  test('support code is short stable and hides raw identifiers', () {
    final code = snapfitSupportCode(
      scope: 'PAY',
      seed: 'STORE_TRANSACTION_ID_1234567890_TOKEN_SECRET',
    );

    expect(code, startsWith('SF-PAY-'));
    expect(code.length, lessThanOrEqualTo(16));
    expect(code, isNot(contains('TOKEN')));
    expect(code, isNot(contains('STORE_TRANSACTION_ID')));
  });

  test('verification failure can include a support code without raw error', () {
    final message = billingVerificationFailureMessage(
      Exception('invalid receipt token raw-token-123'),
      supportCode: 'SF-PAY-7K2D',
    );

    expect(message, contains('문의 코드: SF-PAY-7K2D'));
    expect(message, isNot(contains('raw-token-123')));
    expect(message, isNot(contains('receipt token')));
  });
}

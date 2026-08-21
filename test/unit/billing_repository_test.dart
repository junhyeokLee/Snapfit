import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  test('preflightStorage requires a Supabase client', () async {
    final tokenStorage = MockTokenStorage();
    final repository = BillingRepository(tokenStorage: tokenStorage);

    when(() => tokenStorage.getUserId()).thenAnswer((_) async => '1958142146');
    await expectLater(
      repository.preflightStorage(incomingBytes: 300),
      throwsA(isA<Exception>()),
    );
  });
}

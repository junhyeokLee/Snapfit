import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/network/legacy_backend_guard.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';

class MockDio extends Mock implements Dio {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  test('preflightStorage blocks legacy Spring fallback by default', () async {
    final dio = MockDio();
    final tokenStorage = MockTokenStorage();
    final repository = BillingRepository(dio: dio, tokenStorage: tokenStorage);

    when(() => tokenStorage.getUserId()).thenAnswer((_) async => '1958142146');
    await expectLater(
      repository.preflightStorage(incomingBytes: 300),
      throwsA(isA<LegacyBackendDisabledException>()),
    );
    verifyNever(
      () =>
          dio.post('/api/billing/storage/preflight', data: any(named: 'data')),
    );
  });
}

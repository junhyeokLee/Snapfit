import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/network/legacy_backend_guard.dart';
import 'package:snap_fit/features/auth/data/api/auth_api.dart' as backend;
import 'package:snap_fit/features/auth/domain/auth_service.dart';

class MockAuthApi extends Mock implements backend.AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  test(
    'loginWithKakaoToken blocks legacy Spring fallback by default',
    () async {
      final api = MockAuthApi();
      final storage = MockTokenStorage();
      final service = AuthService(api: api, tokenStorage: storage);

      await expectLater(
        service.loginWithKakaoToken('token'),
        throwsA(isA<LegacyBackendDisabledException>()),
      );
      verifyNever(() => api.loginWithKakao(any()));
    },
  );

  test('refresh blocks legacy Spring fallback by default', () async {
    final api = MockAuthApi();
    final storage = MockTokenStorage();
    final service = AuthService(api: api, tokenStorage: storage);

    await expectLater(
      service.refresh('old-refresh'),
      throwsA(isA<LegacyBackendDisabledException>()),
    );
    verifyNever(() => api.refresh(any()));
  });
}

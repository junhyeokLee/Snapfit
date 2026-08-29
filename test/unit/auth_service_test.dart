import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/auth/domain/auth_service.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  test('loginWithKakaoToken requires Supabase Kakao ID token', () async {
    final storage = MockTokenStorage();
    final service = AuthService(tokenStorage: storage);

    await expectLater(service.loginWithKakaoToken('token'), throwsException);
  });

  test('refresh requires Supabase session support', () async {
    final storage = MockTokenStorage();
    final service = AuthService(tokenStorage: storage);

    await expectLater(service.refresh('old-refresh'), throwsException);
  });

  test('signUpWithEmail requires Supabase auth support', () async {
    final storage = MockTokenStorage();
    final service = AuthService(tokenStorage: storage);

    await expectLater(
      service.signUpWithEmail(
        name: '준자',
        email: 'junja@example.com',
        password: 'password123',
      ),
      throwsException,
    );
  });
}

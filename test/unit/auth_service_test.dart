import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/auth/data/api/auth_api.dart' as backend;
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/domain/auth_service.dart';

class MockAuthApi extends Mock implements backend.AuthApi {}
class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  test('loginWithKakaoToken saves auth to token storage', () async {
    final api = MockAuthApi();
    final storage = MockTokenStorage();
    final service = AuthService(api: api, tokenStorage: storage);

    const response = AuthResponse(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 3600,
      user: UserInfo(id: 1, name: 'Tester', provider: 'KAKAO'),
    );

    when(() => api.loginWithKakao({'accessToken': 'token'}))
        .thenAnswer((_) async => response);
    when(() => storage.saveAuth(response)).thenAnswer((_) async {});

    final result = await service.loginWithKakaoToken('token');

    expect(result.accessToken, 'access');
    verify(() => storage.saveAuth(response)).called(1);
  });

  test('refresh saves new auth tokens', () async {
    final api = MockAuthApi();
    final storage = MockTokenStorage();
    final service = AuthService(api: api, tokenStorage: storage);

    const response = AuthResponse(
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
      expiresIn: 3600,
      user: UserInfo(id: 2, name: 'Tester', provider: 'GOOGLE'),
    );

    when(() => api.refresh({'refreshToken': 'old-refresh'}))
        .thenAnswer((_) async => response);
    when(() => storage.saveAuth(response)).thenAnswer((_) async {});

    final result = await service.refresh('old-refresh');

    expect(result.refreshToken, 'new-refresh');
    verify(() => storage.saveAuth(response)).called(1);
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide AuthApi;

import '../../../../config/env.dart';
import '../../../../core/auth/token_storage.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/api/auth_api.dart';
import '../../data/dto/auth_response.dart';
import '../../domain/auth_service.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = ref.read(dioProvider);
  return AuthApi(dio);
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    api: ref.read(authApiProvider),
    tokenStorage: ref.read(tokenStorageProvider),
  );
});

final authUserIdProvider = FutureProvider<String?>((ref) async {
  return ref.read(tokenStorageProvider).getUserId();
});

/// 홈 상단 로그인 상태 표시용
final authViewModelProvider =
    AsyncNotifierProvider<AuthViewModel, UserInfo?>(AuthViewModel.new);

class AuthViewModel extends AsyncNotifier<UserInfo?> {
  @override
  FutureOr<UserInfo?> build() async {
    return ref.read(tokenStorageProvider).getUserInfo();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }

  Future<void> logout() async {
    state = const AsyncData(null);
    unawaited(ref.read(authServiceProvider).logout());
  }

  Future<void> loginWithKakao() async {
    if (Env.kakaoNativeAppKey.isEmpty) {
      throw Exception('KAKAO_NATIVE_APP_KEY가 설정되지 않았습니다.');
    }
    final useTalk = await isKakaoTalkInstalled();
    OAuthToken token = useTalk
        ? await UserApi.instance.loginWithKakaoTalk()
        : await UserApi.instance.loginWithKakaoAccount();

    final accessToken = token.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('카카오 로그인 토큰을 가져올 수 없습니다.');
    }

    await ref.read(authServiceProvider).loginWithKakaoToken(accessToken);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }

  Future<void> loginWithGoogle() async {
    if (Env.googleWebClientId.isEmpty) {
      throw Exception('GOOGLE_WEB_CLIENT_ID가 설정되지 않았습니다.');
    }
    await GoogleSignIn.instance.initialize(
      serverClientId: Env.googleWebClientId,
    );
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('구글 ID 토큰을 가져올 수 없습니다.');
    }

    await ref.read(authServiceProvider).loginWithGoogleIdToken(idToken);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }
}

import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide AuthApi;

import 'dart:async';

import '../../../config/env.dart';
import '../../../core/interceptors/token_storage.dart';
import '../data/api/auth_api.dart' as backend;
import '../data/dto/auth_response.dart';

/// 인증 서비스 (로그인/토큰 저장/로그아웃)
class AuthService {
  AuthService({
    required this.api,
    required this.tokenStorage,
  });

  final backend.AuthApi api;
  final TokenStorage tokenStorage;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<AuthResponse> loginWithKakaoToken(String accessToken) async {
    final response = await api.loginWithKakao({'accessToken': accessToken});
    await tokenStorage.saveAuth(response);
    return response;
  }

  Future<AuthResponse> loginWithGoogleIdToken(String idToken) async {
    final response = await api.loginWithGoogle({'idToken': idToken});
    await tokenStorage.saveAuth(response);
    return response;
  }

  Future<AuthResponse> refresh(String refreshToken) async {
    final response = await api.refresh({'refreshToken': refreshToken});
    await tokenStorage.saveAuth(response);
    return response;
  }

  Future<void> logout() async {
    // 1) 로컬 토큰/유저정보 삭제 (즉시 반영)
    await tokenStorage.clear();

    // 2) SDK 로그아웃/연결 해제는 백그라운드 처리
    unawaited(_logoutFromGoogle());
    unawaited(_logoutFromKakao());
    unawaited(disconnectGoogle());
    unawaited(unlinkKakao());
  }

  Future<void> _logoutFromGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // SDK 로그아웃 실패 시에도 로컬 로그아웃은 진행
    }
  }

  /// 권한 해제(연동 끊기)까지 필요할 때 사용
  Future<void> disconnectGoogle() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
  }

  /// 카카오 계정 연결 해제
  Future<void> unlinkKakao() async {
    if (Env.kakaoNativeAppKey.isEmpty) return;
    try {
      await UserApi.instance.unlink();
    } catch (_) {}
  }

  Future<void> _logoutFromKakao() async {
    if (Env.kakaoNativeAppKey.isEmpty) return;
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // SDK 로그아웃 실패 시에도 로컬 로그아웃은 진행
    }
  }
}

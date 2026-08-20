import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthResponse;

import 'dart:async';

import '../../../config/env.dart';
import '../../../core/interceptors/token_storage.dart';
import '../../../core/notifications/fcm_notification_service.dart';
import '../data/dto/auth_response.dart';

/// 인증 서비스 (로그인/토큰 저장/로그아웃)
class AuthService {
  AuthService({required this.tokenStorage, this.supabase});

  final TokenStorage tokenStorage;
  final SupabaseClient? supabase;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  AuthResponse _fromSupabaseSession(
    Session session, {
    required String provider,
  }) {
    final user = session.user;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final displayName =
        metadata['name']?.toString() ??
        metadata['full_name']?.toString() ??
        metadata['nickname']?.toString() ??
        user.email ??
        'SnapFit 사용자';
    return AuthResponse(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      expiresIn: session.expiresIn ?? 3600,
      user: UserInfo(
        id: user.id,
        email: user.email,
        name: displayName,
        profileImageUrl:
            metadata['avatar_url']?.toString() ??
            metadata['picture']?.toString(),
        provider: provider,
      ),
    );
  }

  Future<void> _upsertSupabaseProfile(UserInfo user) async {
    if (supabase == null) return;
    await supabase!.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'name': user.name,
      'avatar_url': user.profileImageUrl,
      'provider': user.provider,
    });
  }

  Future<AuthResponse> loginWithKakaoToken(
    String accessToken, {
    String? idToken,
  }) async {
    if (supabase != null && idToken != null && idToken.isNotEmpty) {
      final response = await supabase!.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: idToken,
        accessToken: accessToken,
      );
      final session = response.session;
      if (session == null) {
        throw Exception('Supabase Kakao 로그인 세션을 가져올 수 없습니다.');
      }
      final auth = _fromSupabaseSession(session, provider: 'KAKAO');
      await _upsertSupabaseProfile(auth.user);
      await tokenStorage.saveAuth(auth);
      return auth;
    }
    throw Exception(
      'Supabase Kakao 로그인에는 ID token이 필요합니다. Kakao/Supabase OIDC 설정을 확인해주세요.',
    );
  }

  Future<AuthResponse> loginWithGoogleIdToken(String idToken) async {
    if (supabase != null) {
      final response = await supabase!.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      final session = response.session;
      if (session == null) {
        throw Exception('Supabase Google 로그인 세션을 가져올 수 없습니다.');
      }
      final auth = _fromSupabaseSession(session, provider: 'GOOGLE');
      await _upsertSupabaseProfile(auth.user);
      await tokenStorage.saveAuth(auth);
      return auth;
    }
    throw Exception('Supabase Google 로그인 환경이 준비되지 않았습니다.');
  }

  Future<AuthResponse> refresh(String refreshToken) async {
    if (supabase != null) {
      final response = await supabase!.auth.refreshSession(refreshToken);
      final session = response.session;
      if (session != null) {
        final provider = await tokenStorage.getProvider() ?? 'SUPABASE';
        final auth = _fromSupabaseSession(session, provider: provider);
        await _upsertSupabaseProfile(auth.user);
        await tokenStorage.saveAuth(auth);
        return auth;
      }
    }
    throw Exception('Supabase 세션 갱신 환경이 준비되지 않았습니다.');
  }

  Future<void> logout() async {
    await FcmNotificationService.clearDevicePushState();
    await FcmNotificationService.clearLocalNotificationPrefs();
    try {
      await supabase?.auth.signOut();
    } catch (_) {}

    // 1) 로컬 토큰/유저정보 삭제 (즉시 반영)
    await tokenStorage.clear();

    // 2) SDK 로그아웃/연결 해제는 백그라운드 처리
    unawaited(_logoutFromGoogle());
    unawaited(_logoutFromKakao());
    unawaited(disconnectGoogle());
    unawaited(unlinkKakao());
  }

  Future<void> deleteAccount() async {
    if (supabase != null) {
      try {
        await supabase!.functions.invoke('account-delete');
        await logout();
        return;
      } catch (e) {
        throw Exception('Supabase 계정 탈퇴 처리에 실패했습니다: $e');
      }
    }

    throw Exception('Supabase 계정 탈퇴 기능을 사용할 수 없습니다.');
  }

  Future<void> syncConsentIfPresent() async {
    final consent = await tokenStorage.getConsent();
    if (consent == null) return;
    final user = await tokenStorage.getUserInfo();
    if (supabase != null && user != null) {
      try {
        await supabase!.from('profiles').upsert({
          'id': user.id,
          'email': user.email,
          'name': user.name,
          'avatar_url': user.profileImageUrl,
          'provider': user.provider,
          'terms_version': consent.termsVersion,
          'privacy_version': consent.privacyVersion,
          'marketing_opt_in': consent.marketingOptIn,
          'consented_at': consent.agreedAtIso,
        });
        return;
      } catch (_) {
        // 동의 동기화 실패가 로그인 실패로 이어지지 않도록 비차단 처리.
        // 다음 로그인 시 Supabase profiles에 재동기화된다.
      }
    }
    // Supabase Auth/Profile 이외의 Spring fallback은 사용하지 않는다.
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

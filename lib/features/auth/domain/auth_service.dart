import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthResponse;

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

  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return const <String, dynamic>{};
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) return Map<String, dynamic>.from(payload);
    } catch (_) {}
    return const <String, dynamic>{};
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  String? _stringValue(Map<String, dynamic> source, Iterable<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _requireVerifiedProviderEmail(
    Session session, {
    required String provider,
    String? idToken,
  }) async {
    final user = session.user;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final claims = idToken == null || idToken.isEmpty
        ? const <String, dynamic>{}
        : _decodeJwtPayload(idToken);

    final email = user.email?.trim().isNotEmpty == true
        ? user.email!.trim()
        : _stringValue(claims, const ['email']) ??
              _stringValue(metadata, const ['email']);

    final emailVerified =
        _truthy(claims['email_verified']) ||
        _truthy(claims['verified_email']) ||
        _truthy(claims['is_email_verified']) ||
        _truthy(metadata['email_verified']) ||
        _truthy(metadata['verified_email']) ||
        _truthy(metadata['is_email_verified']);

    if (email == null || !emailVerified) {
      try {
        await supabase?.auth.signOut();
      } catch (_) {}
      throw Exception(
        '$provider 로그인은 인증된 이메일이 필요합니다. 이메일 제공/인증 동의 후 다시 시도해주세요.',
      );
    }
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
        // accessToken 생략: Supabase가 Kakao userinfo 엔드포인트를 호출해
        // 미인증 이메일을 받으면 422(provider_email_needs_verification) 발생.
        // idToken의 sub 클레임으로 사용자를 식별한다.
      );
      final session = response.session;
      if (session == null) {
        throw Exception('Supabase Kakao 로그인 세션을 가져올 수 없습니다.');
      }
      await _requireVerifiedProviderEmail(
        session,
        provider: '카카오',
        idToken: idToken,
      );
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
      await _requireVerifiedProviderEmail(
        session,
        provider: '구글',
        idToken: idToken,
      );
      final auth = _fromSupabaseSession(session, provider: 'GOOGLE');
      await _upsertSupabaseProfile(auth.user);
      await tokenStorage.saveAuth(auth);
      return auth;
    }
    throw Exception('Supabase Google 로그인 환경이 준비되지 않았습니다.');
  }

  Future<AuthResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (supabase != null) {
      final response = await supabase!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final session = response.session;
      if (session == null) {
        throw Exception('Supabase 이메일 로그인 세션을 가져올 수 없습니다.');
      }
      final auth = _fromSupabaseSession(session, provider: 'EMAIL');
      await _upsertSupabaseProfile(auth.user);
      await tokenStorage.saveAuth(auth);
      return auth;
    }
    throw Exception('Supabase 이메일 로그인 환경이 준비되지 않았습니다.');
  }

  Future<AuthResponse?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (supabase != null) {
      final response = await supabase!.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: Env.authRedirectUrl,
        data: {'name': name.trim(), 'full_name': name.trim()},
      );
      final session = response.session;
      if (session == null) {
        // Supabase email confirmation enabled: no session yet. The UI should
        // move to the email-confirmation state and wait for the user to verify.
        return null;
      }
      final auth = _fromSupabaseSession(session, provider: 'EMAIL');
      await _upsertSupabaseProfile(auth.user);
      await tokenStorage.saveAuth(auth);
      return auth;
    }
    throw Exception('Supabase 이메일 가입 환경이 준비되지 않았습니다.');
  }

  Future<void> requestPasswordReset(String email) async {
    if (supabase != null) {
      await supabase!.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: Env.authRedirectUrl,
      );
      return;
    }
    throw Exception('Supabase 비밀번호 재설정 환경이 준비되지 않았습니다.');
  }

  Future<void> resendEmailConfirmation(String email) async {
    if (supabase != null) {
      await supabase!.auth.resend(
        email: email.trim(),
        type: OtpType.signup,
        emailRedirectTo: Env.authRedirectUrl,
      );
      return;
    }
    throw Exception('Supabase 인증 메일 재전송 환경이 준비되지 않았습니다.');
  }

  Future<String?> handleAuthCallback(Uri uri) async {
    if (supabase != null) {
      final response = await supabase!.auth.getSessionFromUrl(uri);
      final auth = _fromSupabaseSession(response.session, provider: 'EMAIL');
      await _upsertSupabaseProfile(auth.user);
      await tokenStorage.saveAuth(auth);
      return response.redirectType;
    }
    throw Exception('Supabase 인증 링크 처리 환경이 준비되지 않았습니다.');
  }

  Future<AuthResponse> updatePassword(String password) async {
    if (supabase != null) {
      await supabase!.auth.updateUser(UserAttributes(password: password));
      final session = supabase!.auth.currentSession;
      if (session == null) {
        throw Exception('비밀번호 변경 후 Supabase 세션을 가져올 수 없습니다.');
      }
      final auth = _fromSupabaseSession(session, provider: 'EMAIL');
      await _upsertSupabaseProfile(auth.user);
      await tokenStorage.saveAuth(auth);
      return auth;
    }
    throw Exception('Supabase 비밀번호 변경 환경이 준비되지 않았습니다.');
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

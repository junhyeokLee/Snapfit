import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthResponse;

import '../../../config/env.dart';
import '../../../core/interceptors/token_storage.dart';
import '../../../core/notifications/fcm_notification_service.dart';
import '../data/dto/auth_response.dart';
import 'web_oauth.dart';
import 'account_deletion_request.dart';

/// 인증 서비스 (로그인/토큰 저장/로그아웃)
class AuthService {
  static const _authRequestTimeout = Duration(seconds: 20);

  AuthService({
    required this.tokenStorage,
    this.supabase,
    Future<bool> Function(OAuthProvider, String, String?)? webOAuthLauncher,
    Future<bool> Function(OAuthProvider)? webProviderEnabled,
    Uri Function()? browserUri,
    Future<void> Function()? prepareLogout,
  }) : _webOAuthLauncher = webOAuthLauncher,
       _webProviderEnabled = webProviderEnabled ?? isWebOAuthProviderEnabled,
       _browserUri = browserUri ?? (() => Uri.base),
       _prepareLogout = prepareLogout ?? _prepareLogoutPushState;

  final Future<bool> Function(OAuthProvider, String, String?)?
  _webOAuthLauncher;
  final Future<bool> Function(OAuthProvider) _webProviderEnabled;
  final Uri Function() _browserUri;
  final Future<void> Function() _prepareLogout;
  Future<void> _authStorageQueue = Future<void>.value();
  ({String email, String userId})? _pendingEmailConfirmation;

  // Auth events can start synchronization while a login is still writing its
  // tokens. Serialize these multi-key writes with clears so a late signed-out
  // observation cannot delete half of a newer account's stored session.
  Future<void> _mutateAuthStorage(Future<void> Function() mutation) {
    final result = Completer<void>();
    _authStorageQueue = _authStorageQueue.then((_) async {
      try {
        await mutation();
        result.complete();
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<void> _clearSignedOutAuth({String? expectedOwner}) =>
      _mutateAuthStorage(() async {
        if (supabase?.auth.currentSession != null) return;
        if (expectedOwner != null &&
            await tokenStorage.getUserId() != expectedOwner)
          return;
        if (supabase?.auth.currentSession != null) return;
        await tokenStorage.clear();
      });

  Future<void> _saveCurrentAuth(AuthResponse auth) =>
      _mutateAuthStorage(() async {
        _sameSessionOwner(auth.user.id);
        await tokenStorage.saveAuth(auth);
        if (supabase?.auth.currentSession?.user.id != auth.user.id) {
          if (await tokenStorage.getUserId() == auth.user.id) {
            await tokenStorage.clear();
          }
          throw const WebOAuthException('web_auth_owner_changed');
        }
      });

  Future<void> _discardRejectedSession(Session rejected) async {
    final client = supabase;
    final current = client?.auth.currentSession;
    if (client == null ||
        current?.user.id != rejected.user.id ||
        current?.accessToken != rejected.accessToken)
      return;
    // The SDK removes its local session before contacting Auth. An unavailable
    // logout response must not keep a server-rejected account on the device.
    unawaited(
      client.auth.signOut(scope: SignOutScope.local).catchError((Object _) {}),
    );
    await _clearSignedOutAuth(
      expectedOwner: rejected.user.id,
    ).timeout(_authRequestTimeout);
  }

  // A generic 401/bad_jwt may only mean the access token needs refreshing.
  // Discard a whole session only when Auth explicitly rejects its owner/session.
  bool _isRejectedSession(AuthException error) =>
      error is! AuthRetryableFetchException &&
      const {
        'user_not_found',
        'session_not_found',
        'session_expired',
        'user_banned',
      }.contains(error.code);

  String get _authRedirectUrl => kIsWeb
      ? webAuthRedirectUri(
          _browserUri(),
          configured: Env.authWebRedirectUrl,
        ).toString()
      : Env.authRedirectUrl;

  Future<void> loginWithWebProvider(OAuthProvider provider) async {
    final client = supabase;
    if (client == null) {
      throw const WebOAuthException('web_auth_configuration_unavailable');
    }
    if (provider != OAuthProvider.google && provider != OAuthProvider.kakao) {
      throw const WebOAuthException('web_auth_provider_unsupported');
    }
    final redirect = webAuthRedirectUri(
      _browserUri(),
      configured: Env.authWebRedirectUrl,
    ).toString();
    if (!await _webProviderEnabled(provider)) {
      throw const WebOAuthException('web_auth_provider_disabled');
    }
    final scopes = provider == OAuthProvider.kakao ? 'account_email' : null;
    final launched = _webOAuthLauncher != null
        ? await _webOAuthLauncher(provider, redirect, scopes)
        : await client.auth.signInWithOAuth(
            provider,
            redirectTo: redirect,
            scopes: scopes,
          );
    if (!launched) throw const WebOAuthException('web_auth_launch_failed');
    // A launched browser is not an authenticated user. The returned Supabase
    // session must pass synchronizeSupabaseSession after the OAuth redirect.
  }

  String _sessionProvider(User user) {
    switch (user.appMetadata['provider']) {
      case 'google':
        return 'GOOGLE';
      case 'kakao':
        return 'KAKAO';
      case 'email':
        return 'EMAIL';
      default:
        return 'SUPABASE';
    }
  }

  void _sameSessionOwner(String owner) {
    if (supabase?.auth.currentSession?.user.id != owner) {
      throw const WebOAuthException('web_auth_owner_changed');
    }
  }

  /// Browser persistence and callbacks never trust cached profile/JWT claims.
  /// Auth getUser validates the real session before profile/token sync.
  Future<AuthResponse?> synchronizeSupabaseSession() async {
    final client = supabase;
    if (client == null) {
      throw const WebOAuthException('web_auth_configuration_unavailable');
    }
    final initial = client.auth.currentSession;
    if (initial == null) {
      await _clearSignedOutAuth().timeout(_authRequestTimeout);
      if (kIsWeb) {
        final callbackError = failedWebAuthCallback(
          _browserUri(),
          current: _browserUri(),
          configured: Env.authWebRedirectUrl,
        );
        if (callbackError != null) throw callbackError;
      }
      return null;
    }
    User? verifiedUser;
    try {
      verifiedUser =
          (await client.auth
                  .getUser(initial.accessToken)
                  .timeout(_authRequestTimeout))
              .user;
    } on AuthException catch (error) {
      if (_isRejectedSession(error)) await _discardRejectedSession(initial);
      rethrow;
    }
    if (verifiedUser == null || verifiedUser.id != initial.user.id) {
      throw const WebOAuthException('web_auth_session_invalid');
    }
    _sameSessionOwner(verifiedUser.id);
    final session = client.auth.currentSession!.copyWith(user: verifiedUser);
    await _requireConfirmedEmailSession(session);
    var auth = _fromSupabaseSession(
      session,
      provider: _sessionProvider(verifiedUser),
    );
    // Restoring an OAuth session must preserve the name/photo the customer
    // edited in SnapFit, rather than overwriting it with provider metadata.
    final profile = await client
        .from('profiles')
        .select('name,avatar_url')
        .eq('id', verifiedUser.id)
        .maybeSingle()
        .timeout(_authRequestTimeout);
    _sameSessionOwner(verifiedUser.id);
    if (profile != null) {
      final name = profile['name'];
      final avatar = profile['avatar_url'];
      auth = auth.copyWith(
        user: auth.user.copyWith(
          name: name is String && name.trim().isNotEmpty
              ? name
              : auth.user.name,
          profileImageUrl: avatar is String && avatar.isNotEmpty
              ? avatar
              : auth.user.profileImageUrl,
        ),
      );
    }
    await _upsertSupabaseProfile(auth.user).timeout(_authRequestTimeout);
    _sameSessionOwner(verifiedUser.id);
    await _saveCurrentAuth(auth).timeout(_authRequestTimeout);
    return auth;
  }

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
      await _discardRejectedSession(session);
      throw AuthException(
        '$provider 로그인은 인증된 이메일이 필요합니다. 이메일 제공/인증 동의 후 다시 시도해주세요.',
        code: 'provider_email_needs_verification',
      );
    }
  }

  bool _hasConfirmedEmail(User user) {
    return user.email?.trim().isNotEmpty == true &&
        user.emailConfirmedAt?.trim().isNotEmpty == true;
  }

  Future<void> _requireConfirmedEmailSession(Session session) async {
    if (_hasConfirmedEmail(session.user)) return;
    await _discardRejectedSession(session);
    throw const AuthException(
      '이메일 인증을 완료한 뒤 다시 로그인해주세요.',
      code: 'email_not_confirmed',
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
    if (accessToken.trim().isEmpty) {
      throw const AuthException(
        '카카오 로그인 토큰을 가져올 수 없습니다.',
        code: 'kakao_token_unavailable',
      );
    }
    if (supabase != null && idToken != null && idToken.isNotEmpty) {
      final response = await supabase!.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: idToken,
        // Let Supabase verify at_hash when the Kakao ID token contains it.
        // Both tokens must come from the same SDK login/consent response.
        accessToken: accessToken,
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
      await _requireConfirmedEmailSession(session);
      final auth = _fromSupabaseSession(session, provider: 'KAKAO');
      await _upsertSupabaseProfile(auth.user);
      await _saveCurrentAuth(auth);
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
      await _requireConfirmedEmailSession(session);
      final auth = _fromSupabaseSession(session, provider: 'GOOGLE');
      await _upsertSupabaseProfile(auth.user);
      await _saveCurrentAuth(auth);
      return auth;
    }
    throw Exception('Supabase Google 로그인 환경이 준비되지 않았습니다.');
  }

  Future<AuthResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (_pendingEmailConfirmation?.email != email.trim().toLowerCase()) {
      _pendingEmailConfirmation = null;
    }
    if (supabase != null) {
      final response = await supabase!.auth
          .signInWithPassword(email: email.trim(), password: password)
          .timeout(_authRequestTimeout);
      final session = response.session;
      if (session == null) {
        throw Exception('Supabase 이메일 로그인 세션을 가져올 수 없습니다.');
      }
      await _requireConfirmedEmailSession(session);
      final auth = _fromSupabaseSession(session, provider: 'EMAIL');
      await _upsertSupabaseProfile(auth.user).timeout(_authRequestTimeout);
      await _saveCurrentAuth(auth).timeout(_authRequestTimeout);
      return auth;
    }
    throw Exception('Supabase 이메일 로그인 환경이 준비되지 않았습니다.');
  }

  Future<AuthResponse?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    _pendingEmailConfirmation = null;
    if (supabase != null) {
      final response = await supabase!.auth
          .signUp(
            email: email.trim(),
            password: password,
            emailRedirectTo: _authRedirectUrl,
            data: {'name': name.trim(), 'full_name': name.trim()},
          )
          .timeout(_authRequestTimeout);
      final session = response.session;
      if (session == null) {
        final user = response.user;
        final identities = user?.identities;
        if (user == null ||
            identities == null ||
            user.email?.trim().toLowerCase() != email.trim().toLowerCase()) {
          throw const AuthException(
            'Email signup response could not be verified.',
            code: 'signup_response_invalid',
          );
        }
        // With confirmation enabled, Auth can return a sanitized existing
        // account with a fresh ID/timestamp and identities: [] instead of an
        // error. This includes accounts originally created through OAuth.
        // A null session alone is therefore not evidence of an email request.
        if (identities.isEmpty ||
            user.emailConfirmedAt?.trim().isNotEmpty == true ||
            !identities.any((identity) => identity.provider == 'email')) {
          throw const AuthException(
            'User already registered',
            code: 'user_already_exists',
          );
        }
        // Only a real unconfirmed email identity reaches the waiting screen.
        _pendingEmailConfirmation = (
          email: email.trim().toLowerCase(),
          userId: user.id,
        );
        return null;
      }
      await _requireConfirmedEmailSession(session);
      final auth = _fromSupabaseSession(session, provider: 'EMAIL');
      await _upsertSupabaseProfile(auth.user).timeout(_authRequestTimeout);
      await _saveCurrentAuth(auth).timeout(_authRequestTimeout);
      return auth;
    }
    throw Exception('Supabase 이메일 가입 환경이 준비되지 않았습니다.');
  }

  Future<AuthResponse> verifyEmailConfirmation({
    required String email,
    required String token,
  }) async {
    final client = supabase;
    if (client == null) {
      throw const AuthException(
        'Email confirmation is unavailable.',
        code: 'email_confirmation_unavailable',
      );
    }
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedToken = token.trim();
    // This project issues eight digits. Do not silently remove characters from
    // a pasted code or accept a link token/password-recovery token here.
    if (!RegExp(r'^[0-9]{8}$').hasMatch(normalizedToken)) {
      throw const AuthException(
        'Enter the eight-digit confirmation code.',
        code: 'email_confirmation_code_invalid',
      );
    }
    if (normalizedEmail.isEmpty) {
      throw const AuthException('Invalid email.', code: 'invalid_email');
    }
    final pending = _pendingEmailConfirmation;
    if (pending != null && pending.email != normalizedEmail) {
      throw const AuthException(
        'The confirmation email changed.',
        code: 'email_confirmation_email_changed',
      );
    }
    bool matchesExpectedUser(User user) =>
        user.email?.trim().toLowerCase() == normalizedEmail &&
        (pending == null || user.id == pending.userId);

    final existing = client.auth.currentSession;
    if (existing != null && !matchesExpectedUser(existing.user)) {
      throw const AuthException(
        'A different account is already signed in.',
        code: 'email_confirmation_session_changed',
      );
    }
    final response = await client.auth
        .verifyOTP(
          email: normalizedEmail,
          token: normalizedToken,
          // Unlike the general `email` type, `signup` only checks the server's
          // confirmation token and cannot consume a recovery/magic-link OTP.
          type: OtpType.signup,
        )
        .timeout(_authRequestTimeout);
    final initial = response.session;
    if (initial == null ||
        response.user?.id != initial.user.id ||
        !matchesExpectedUser(initial.user) ||
        !_hasConfirmedEmail(initial.user)) {
      if (initial != null) await _discardRejectedSession(initial);
      throw const AuthException(
        'Email confirmation response could not be verified.',
        code: 'email_confirmation_response_invalid',
      );
    }

    User? verifiedUser;
    try {
      verifiedUser =
          (await client.auth
                  .getUser(initial.accessToken)
                  .timeout(_authRequestTimeout))
              .user;
    } on AuthException catch (error) {
      if (_isRejectedSession(error)) await _discardRejectedSession(initial);
      rethrow;
    }
    if (verifiedUser == null ||
        verifiedUser.id != initial.user.id ||
        !matchesExpectedUser(verifiedUser) ||
        !_hasConfirmedEmail(verifiedUser)) {
      await _discardRejectedSession(initial);
      throw const AuthException(
        'Confirmed email session could not be verified.',
        code: 'email_confirmation_response_invalid',
      );
    }
    // The response may refresh while getUser is in flight; use the SDK's current
    // token only after checking that it still belongs to the confirmed owner.
    _sameSessionOwner(verifiedUser.id);
    final session = client.auth.currentSession!.copyWith(user: verifiedUser);
    await _requireConfirmedEmailSession(session);
    final auth = _fromSupabaseSession(session, provider: 'EMAIL');
    await _upsertSupabaseProfile(auth.user).timeout(_authRequestTimeout);
    _sameSessionOwner(verifiedUser.id);
    await _saveCurrentAuth(auth).timeout(_authRequestTimeout);
    if (_pendingEmailConfirmation == pending) {
      _pendingEmailConfirmation = null;
    }
    return auth;
  }

  Future<void> requestPasswordReset(String email) async {
    _pendingEmailConfirmation = null;
    if (supabase != null) {
      await supabase!.auth
          .resetPasswordForEmail(email.trim(), redirectTo: _authRedirectUrl)
          .timeout(_authRequestTimeout);
      return;
    }
    throw Exception('Supabase 비밀번호 재설정 환경이 준비되지 않았습니다.');
  }

  Future<void> resendEmailConfirmation(String email) async {
    if (supabase != null) {
      await supabase!.auth
          .resend(
            email: email.trim(),
            type: OtpType.signup,
            emailRedirectTo: _authRedirectUrl,
          )
          .timeout(_authRequestTimeout);
      if (_pendingEmailConfirmation?.email != email.trim().toLowerCase()) {
        _pendingEmailConfirmation = null;
      }
      return;
    }
    throw Exception('Supabase 인증 메일 재전송 환경이 준비되지 않았습니다.');
  }

  Future<String?> handleAuthCallback(Uri uri) async {
    if (supabase != null) {
      if (!isTrustedAuthCallback(
        uri,
        current: _browserUri(),
        configured: Env.authWebRedirectUrl,
      )) {
        throw const WebOAuthException('web_auth_redirect_invalid');
      }
      final response = await supabase!.auth.getSessionFromUrl(uri);
      await _requireConfirmedEmailSession(response.session);
      await synchronizeSupabaseSession();
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
      await _saveCurrentAuth(auth);
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
        await _saveCurrentAuth(auth);
        return auth;
      }
    }
    throw Exception('Supabase 세션 갱신 환경이 준비되지 않았습니다.');
  }

  Future<void> logout() async {
    final session = supabase?.auth.currentSession;
    await _prepareLogout();
    if (supabase?.auth.currentSession?.user.id != session?.user.id ||
        supabase?.auth.currentSession?.accessToken != session?.accessToken) {
      return;
    }
    try {
      await supabase?.auth.signOut();
    } catch (_) {}

    // 1) 로컬 토큰/유저정보 삭제 (즉시 반영)
    await _clearSignedOutAuth(expectedOwner: session?.user.id);
    if (supabase?.auth.currentSession != null) return;

    // Browser OAuth sessions are owned by Supabase, not native plugins.
    if (kIsWeb) return;

    // 2) SDK 로그아웃/연결 해제는 백그라운드 처리
    unawaited(_logoutFromGoogle());
    unawaited(_logoutFromKakao());
    unawaited(disconnectGoogle());
    unawaited(unlinkKakao());
  }

  static Future<void> _prepareLogoutPushState() async {
    await FcmNotificationService.clearDevicePushState();
    await FcmNotificationService.clearLocalNotificationPrefs();
  }

  Future<void> deleteAccount() async {
    throw Exception('계정 설정의 삭제 요청을 이용해 주세요. 자동 즉시 삭제는 제공하지 않습니다.');
  }

  Future<AccountDeletionRequest> requestAccountDeletion() async {
    final client = supabase;
    if (client == null)
      throw Exception('삭제 요청을 접수할 수 없습니다. 문의: junhyeoklee616@gmail.com');
    try {
      final response = await client.functions.invoke(
        'account-delete',
        body: {'action': 'REQUEST_REVIEW'},
      );
      return AccountDeletionRequest.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (_) {
      throw Exception(
        '삭제 요청을 접수하지 못했습니다. 잠시 후 다시 시도하거나 junhyeoklee616@gmail.com으로 문의해 주세요.',
      );
    }
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

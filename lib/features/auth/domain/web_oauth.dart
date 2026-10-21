import 'dart:async';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/env.dart';
import 'native_kakao_login.dart';

class WebOAuthException implements Exception {
  const WebOAuthException(this.code);
  final String code;
  @override
  String toString() => code;
}

const _expiredAuthCallbackCodes = {
  'flow_state_expired',
  'flow_state_not_found',
  'flow_state_already_used',
  'bad_oauth_state',
  'otp_expired',
};
const _unverifiedAuthCallbackCodes = {
  'provider_email_needs_verification',
  'email_not_confirmed',
};
const _expiredAuthCallbackMessage =
    '인증 링크가 만료되었거나 이미 사용되었어요. 가장 최근 메일을 확인하거나 인증을 다시 요청해주세요. 로그인은 같은 브라우저에서 이어서 진행해주세요.';

bool _safeWebOrigin(Uri uri) =>
    uri.userInfo.isEmpty &&
    uri.host.isNotEmpty &&
    (uri.scheme == 'https' ||
        uri.scheme == 'http' &&
            const {'localhost', '127.0.0.1', '::1'}.contains(uri.host));

/// A browser login always returns to this app's origin, never a request's
/// returnTo/next URL. The root callback also works on a plain static dev server.
Uri webAuthRedirectUri(Uri current, {String configured = ''}) {
  if (!_safeWebOrigin(current)) {
    throw const WebOAuthException('web_auth_origin_invalid');
  }
  final result = configured.trim().isEmpty
      ? current.replace(path: '/', query: 'auth_callback=1').removeFragment()
      : Uri.tryParse(configured.trim());
  if (result == null ||
      !_safeWebOrigin(result) ||
      result.origin != current.origin ||
      result.hasFragment ||
      result.path != '/' ||
      result.queryParameters.length != 1 ||
      result.queryParameters['auth_callback'] != '1' ||
      result.queryParametersAll['auth_callback']?.length != 1) {
    throw const WebOAuthException('web_auth_redirect_invalid');
  }
  return result;
}

bool hasAuthCallbackParameters(Uri uri) {
  try {
    final fragment = Uri.splitQueryString(uri.fragment);
    return const {
      'code',
      'access_token',
      'error',
      'error_code',
      'error_description',
    }.any(
      (key) =>
          uri.queryParameters.containsKey(key) || fragment.containsKey(key),
    );
  } on FormatException {
    return false;
  }
}

/// For Supabase's URI detector: an album invite/payment `code` is not an OAuth
/// callback. Native email/deep links keep their existing exact callback URI.
bool isTrustedAuthCallback(
  Uri uri, {
  required Uri current,
  String configured = '',
}) {
  if (!hasAuthCallbackParameters(uri)) return false;
  if (current.scheme == 'http' || current.scheme == 'https') {
    try {
      final expected = webAuthRedirectUri(current, configured: configured);
      return _safeWebOrigin(uri) &&
          uri.origin == expected.origin &&
          uri.path == expected.path &&
          uri.queryParameters['auth_callback'] == '1' &&
          uri.queryParametersAll['auth_callback']?.length == 1;
    } on WebOAuthException {
      return false;
    }
  }
  final native = Uri.tryParse(Env.authRedirectUrl);
  return native != null &&
      uri.scheme == native.scheme &&
      uri.host == native.host &&
      uri.path == native.path &&
      uri.userInfo.isEmpty &&
      !uri.hasPort;
}

/// The SDK handles the initial web callback before the app subscribes to auth
/// events. A failed exchange leaves the callback URL in place, so preserve a
/// bounded explanation for the login screen without retrying a one-use code or
/// showing provider descriptions (which may contain account or token details).
WebOAuthException? failedWebAuthCallback(
  Uri uri, {
  required Uri current,
  String configured = '',
}) {
  if (!isTrustedAuthCallback(uri, current: current, configured: configured)) {
    return null;
  }
  Map<String, String> fragment;
  try {
    fragment = Uri.splitQueryString(uri.fragment);
  } on FormatException {
    return const WebOAuthException('web_auth_callback_failed');
  }
  String? parameter(String key) => uri.queryParameters[key] ?? fragment[key];
  final errorCode = parameter('error_code')?.trim().toLowerCase();
  final codes = [parameter('error')?.trim().toLowerCase(), errorCode];
  // Auth uses access_denied for several verification failures as well as
  // cancellation. Its specific error_code must take precedence.
  if (codes.any(_expiredAuthCallbackCodes.contains)) {
    return const WebOAuthException('web_auth_callback_expired');
  }
  if (codes.any(_unverifiedAuthCallbackCodes.contains)) {
    return const WebOAuthException('web_auth_email_unverified');
  }
  if (codes.contains('access_denied') &&
      (errorCode == null ||
          errorCode.isEmpty ||
          errorCode == 'access_denied')) {
    return const WebOAuthException('web_auth_callback_cancelled');
  }
  // No session and a leftover code also means the initial SDK exchange did
  // not finish. The caller checks session absence before using this helper.
  return const WebOAuthException('web_auth_callback_failed');
}

/// /settings is public Auth configuration. Only provider-enabled booleans are
/// read. OAuth client secrets stay in Supabase and never enter the app.
Future<bool> isWebOAuthProviderEnabled(
  OAuthProvider provider, {
  Dio? client,
}) async {
  if (provider != OAuthProvider.google && provider != OAuthProvider.kakao) {
    throw const WebOAuthException('web_auth_provider_unsupported');
  }
  final ownClient = client == null;
  final http =
      client ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 12)));
  try {
    final response = await http.get<Object?>(
      Uri.parse(Env.supabaseUrl).resolve('/auth/v1/settings').toString(),
      options: Options(
        headers: {'apikey': Env.supabaseAnonKey},
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
      ),
    );
    final body = response.data;
    if (body is! Map || body['external'] is! Map) {
      throw const WebOAuthException('web_auth_configuration_unavailable');
    }
    return (body['external'] as Map)[provider.name] == true;
  } on WebOAuthException {
    rethrow;
  } catch (_) {
    throw const WebOAuthException('web_auth_configuration_unavailable');
  } finally {
    if (ownClient) http.close();
  }
}

String socialAuthErrorMessage(Object error, {String provider = '소셜'}) {
  if (error is TimeoutException) {
    return '계정 확인 응답이 늦어지고 있어요. 인터넷 연결을 확인한 뒤 다시 시도해주세요.';
  }
  if (isKakaoLoginCancellation(error)) {
    return '로그인을 취소했어요. 원하는 로그인 방법을 다시 선택해주세요.';
  }
  final kakaoError = nativeKakaoAuthErrorMessage(error);
  if (kakaoError != null) return kakaoError;
  if (error is PostgrestException) {
    return '로그인은 확인했지만 스냅핏 계정 정보를 불러오지 못했어요. 다시 시도해주세요. 계속되면 고객지원에 알려주세요.';
  }
  final raw = error is WebOAuthException
      ? error.code
      : error is AuthException
      ? '${error.code ?? ''} ${error.message}'.toLowerCase()
      : '';
  // getSessionFromUrl represents callback error_code in statusCode, while
  // HTTP Auth responses use a numeric statusCode and the regular code field.
  final callbackDetail =
      error is AuthException &&
          error.statusCode?.trim().isNotEmpty == true &&
          int.tryParse(error.statusCode!.trim()) == null
      ? error.statusCode!.trim().toLowerCase()
      : null;
  if (raw == 'web_auth_provider_disabled' ||
      raw.contains('provider is not enabled') ||
      raw.contains('unsupported provider')) {
    return '$provider 웹 로그인이 아직 연결되지 않았어요. 이메일로 로그인해주세요.';
  }
  if (raw == 'web_auth_origin_invalid' || raw == 'web_auth_redirect_invalid') {
    return '이 주소에서는 웹 로그인으로 돌아올 수 없어요. 스냅핏 앱 주소를 다시 확인해주세요.';
  }
  if (error is AuthException &&
      const {
        'user_not_found',
        'session_not_found',
        'bad_jwt',
        'jwt_expired',
        'refresh_token_not_found',
        'refresh_token_already_used',
      }.contains(error.code)) {
    return '기존 로그인 정보가 만료되었거나 계정 연결이 해제되었어요. 다시 로그인해주세요.';
  }
  if (raw.contains('kakao_oidc_unavailable')) {
    return '카카오 로그인 연결 설정을 확인해야 해요. 지금은 Google 또는 이메일로 로그인해주세요.';
  }
  if (raw.contains('kakao_token_unavailable')) {
    return '카카오 로그인 정보를 받지 못했어요. 카카오 로그인을 다시 시작해주세요.';
  }
  if (raw.contains('unacceptable audience') || raw.contains('invalid_client')) {
    return '$provider 로그인 연결 설정을 확인해야 해요. 다른 로그인 방법을 이용해주세요.';
  }
  if (raw.contains('bad id token') ||
      raw.contains('nonces mismatch') ||
      raw.contains('invalid nonce')) {
    return '$provider 로그인 정보를 확인하지 못했어요. 로그인을 다시 시작해주세요. 계속되면 로그인 연결 설정을 확인해야 해요.';
  }
  if (raw == 'web_auth_callback_expired' ||
      _expiredAuthCallbackCodes.any(raw.contains) ||
      _expiredAuthCallbackCodes.contains(callbackDetail)) {
    return _expiredAuthCallbackMessage;
  }
  if (_unverifiedAuthCallbackCodes.contains(callbackDetail) ||
      raw.contains('email_not_confirmed') ||
      raw.contains('provider_email_needs_verification') ||
      raw == 'web_auth_email_unverified' ||
      raw.contains('인증된 이메일') ||
      raw.contains('이메일 인증')) {
    return '인증된 이메일이 필요해요. 이메일 제공·인증을 확인한 뒤 다시 로그인해주세요.';
  }
  if ((raw.contains('access_denied') || raw.contains('cancel')) &&
      (callbackDetail == null || callbackDetail == 'access_denied')) {
    return '로그인을 취소했어요. 원하는 로그인 방법을 다시 선택해주세요.';
  }
  if (raw == 'web_auth_callback_failed') {
    return '로그인 후 스냅핏으로 돌아왔지만 계정 확인을 완료하지 못했어요. 같은 브라우저에서 다시 로그인해주세요. 계속되면 로그인 연결 설정을 확인해야 해요.';
  }
  if (raw == 'web_auth_configuration_unavailable') {
    return '웹 로그인 연결 상태를 확인하지 못했어요. 잠시 후 다시 시도하거나 이메일로 로그인해주세요.';
  }
  return '$provider 로그인을 완료하지 못했어요. 잠시 후 다시 시도해주세요.';
}

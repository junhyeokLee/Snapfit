import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/env.dart';

class WebOAuthException implements Exception {
  const WebOAuthException(this.code);
  final String code;
  @override
  String toString() => code;
}

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
  final raw = error is WebOAuthException
      ? error.code
      : error is AuthException
      ? '${error.code ?? ''} ${error.message}'.toLowerCase()
      : '';
  if (raw == 'web_auth_provider_disabled' ||
      raw.contains('provider is not enabled') ||
      raw.contains('unsupported provider')) {
    return '$provider 웹 로그인이 아직 연결되지 않았어요. 이메일로 로그인해주세요.';
  }
  if (raw == 'web_auth_origin_invalid' || raw == 'web_auth_redirect_invalid') {
    return '이 주소에서는 웹 로그인으로 돌아올 수 없어요. 스냅핏 앱 주소를 다시 확인해주세요.';
  }
  if (raw.contains('email_not_confirmed') ||
      raw.contains('인증된 이메일') ||
      raw.contains('이메일 인증')) {
    return '인증된 이메일이 필요해요. 이메일 제공·인증을 확인한 뒤 다시 로그인해주세요.';
  }
  if (raw.contains('access_denied') || raw.contains('cancel')) {
    return '로그인을 취소했어요. 원하는 로그인 방법을 다시 선택해주세요.';
  }
  if (raw == 'web_auth_configuration_unavailable') {
    return '웹 로그인 연결 상태를 확인하지 못했어요. 잠시 후 다시 시도하거나 이메일로 로그인해주세요.';
  }
  return '$provider 로그인을 완료하지 못했어요. 잠시 후 다시 시도해주세요.';
}

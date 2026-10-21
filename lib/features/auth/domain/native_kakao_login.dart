import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

bool isKakaoLoginCancellation(Object error) =>
    error is PlatformException &&
        const {'CANCELED', 'CANCELLED'}.contains(error.code.toUpperCase()) ||
    error is KakaoClientException &&
        error.reason == ClientErrorCause.cancelled ||
    error is KakaoAuthException && error.error == AuthErrorCause.accessDenied;

/// Keep provider responses, keys, and token values out of the customer UI.
String? nativeKakaoAuthErrorMessage(Object error) {
  if (error is KakaoAuthException) {
    switch (error.error) {
      case AuthErrorCause.invalidClient:
      case AuthErrorCause.misconfigured:
      case AuthErrorCause.unauthorized:
        return '카카오 로그인 연결 설정을 확인해야 해요. 지금은 Google 또는 이메일로 로그인해주세요.';
      case AuthErrorCause.invalidScope:
        return '카카오 이메일 동의 설정을 확인해야 해요. 지금은 Google 또는 이메일로 로그인해주세요.';
      case AuthErrorCause.invalidGrant:
        return '카카오 로그인 정보가 만료되었어요. 카카오 로그인을 다시 시작해주세요.';
      default:
        return null;
    }
  }
  if (error is KakaoApiException &&
      error.code == ApiErrorCause.insufficientScope) {
    return '카카오 이메일 제공 동의를 완료한 뒤 다시 로그인해주세요.';
  }
  return null;
}

/// An installed Kakao Talk app can still fail to start authentication. Match
/// Kakao's recommended account-login fallback while respecting user cancel.
Future<OAuthToken> loginWithNativeKakao({
  Future<bool> Function()? talkInstalled,
  Future<OAuthToken> Function()? talkLogin,
  Future<OAuthToken> Function()? accountLogin,
}) async {
  final canUseTalk = await (talkInstalled ?? isKakaoTalkInstalled)();
  final withAccount =
      accountLogin ?? () => UserApi.instance.loginWithKakaoAccount();
  if (!canUseTalk) return withAccount();
  try {
    return await (talkLogin ?? () => UserApi.instance.loginWithKakaoTalk())();
  } catch (error) {
    if (isKakaoLoginCancellation(error)) rethrow;
    return withAccount();
  }
}

/// Kakao's native initial-login methods have no scopes parameter. Existing
/// customers may still need email consent after the app adds account_email.
/// Request only missing consent, and include openid so the replacement token
/// still contains the ID token required by Supabase.
Future<OAuthToken> ensureNativeKakaoEmailConsent(
  OAuthToken token, {
  Future<bool> Function()? emailNeedsAgreement,
  Future<OAuthToken> Function(List<String>)? requestScopes,
}) async {
  final hasIdToken = token.idToken?.isNotEmpty == true;
  if (hasIdToken && token.scopes?.contains('account_email') == true)
    return token;
  final needsEmail =
      await (emailNeedsAgreement ??
          () async =>
              (await UserApi.instance.me()).kakaoAccount?.emailNeedsAgreement ==
              true)();
  if (hasIdToken && !needsEmail) return token;
  final scopes = ['openid', if (needsEmail) 'account_email'];
  return (requestScopes ??
      (scopes) => UserApi.instance.loginWithNewScopes(scopes))(scopes);
}

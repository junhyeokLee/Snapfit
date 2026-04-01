import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../../features/auth/data/dto/auth_response.dart';

/// JWT + 사용자 정보 저장소 (Secure Storage)
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyAccessToken = 'snapfit_access_token';
  static const _keyRefreshToken = 'snapfit_refresh_token';
  static const _keyExpiresIn = 'snapfit_expires_in';
  static const _keyUserId = 'snapfit_user_id';
  static const _keyUserEmail = 'snapfit_user_email';
  static const _keyUserName = 'snapfit_user_name';
  static const _keyUserProfile = 'snapfit_user_profile';
  static const _keyProvider = 'snapfit_user_provider';
  static const _keyConsentTermsVersion = 'snapfit_consent_terms_version';
  static const _keyConsentPrivacyVersion = 'snapfit_consent_privacy_version';
  static const _keyConsentMarketing = 'snapfit_consent_marketing';
  static const _keyConsentAgreedAt = 'snapfit_consent_agreed_at';

  Future<void> saveAuth(AuthResponse response) async {
    await _storage.write(key: _keyAccessToken, value: response.accessToken);
    await _storage.write(key: _keyRefreshToken, value: response.refreshToken);
    await _storage.write(
      key: _keyExpiresIn,
      value: response.expiresIn.toString(),
    );
    await _storage.write(key: _keyUserId, value: response.user.id.toString());
    await _storage.write(key: _keyUserEmail, value: response.user.email);
    await _storage.write(key: _keyUserName, value: response.user.name);
    await _storage.write(
      key: _keyUserProfile,
      value: response.user.profileImageUrl,
    );
    await _storage.write(key: _keyProvider, value: response.user.provider);
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);

  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  Future<String?> getUserId() => _storage.read(key: _keyUserId);

  /// userId가 저장소에 없더라도 accessToken(sub)에서 복구한다.
  /// 복구 성공 시 secure storage에 다시 저장해 이후 호출도 안정화한다.
  Future<String?> getResolvedUserId() async {
    final stored = await _storage.read(key: _keyUserId);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }

    final accessToken = await _storage.read(key: _keyAccessToken);
    final fromToken = _extractSubFromJwt(accessToken);
    if (fromToken != null && fromToken.isNotEmpty) {
      await _storage.write(key: _keyUserId, value: fromToken);
      return fromToken;
    }
    return null;
  }

  Future<String?> getProvider() => _storage.read(key: _keyProvider);

  Future<UserInfo?> getUserInfo() async {
    final accessToken = await _storage.read(key: _keyAccessToken);
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }

    final idRaw = await _storage.read(key: _keyUserId);
    if (idRaw == null || idRaw.isEmpty) return null;

    final id = int.tryParse(idRaw) ?? 0;
    final email = await _storage.read(key: _keyUserEmail);
    final name = await _storage.read(key: _keyUserName) ?? '사용자';
    final profileImageUrl = await _storage.read(key: _keyUserProfile);
    final provider = await _storage.read(key: _keyProvider) ?? '';

    return UserInfo(
      id: id,
      email: email,
      name: name,
      profileImageUrl: profileImageUrl,
      provider: provider,
    );
  }

  /// 서버에서 받은 유저 정보로 로컬 프로필만 갱신 (토큰은 유지)
  Future<void> saveUserInfo(UserInfo user) async {
    await _storage.write(key: _keyUserId, value: user.id.toString());
    await _storage.write(key: _keyUserEmail, value: user.email);
    await _storage.write(key: _keyUserName, value: user.name);
    await _storage.write(key: _keyUserProfile, value: user.profileImageUrl);
    await _storage.write(key: _keyProvider, value: user.provider);
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<void> saveConsent({
    required String termsVersion,
    required String privacyVersion,
    required bool marketingOptIn,
    required String agreedAtIso,
  }) async {
    await _storage.write(key: _keyConsentTermsVersion, value: termsVersion);
    await _storage.write(key: _keyConsentPrivacyVersion, value: privacyVersion);
    await _storage.write(
      key: _keyConsentMarketing,
      value: marketingOptIn ? '1' : '0',
    );
    await _storage.write(key: _keyConsentAgreedAt, value: agreedAtIso);
  }

  Future<ConsentSnapshot?> getConsent() async {
    final termsVersion = await _storage.read(key: _keyConsentTermsVersion);
    final privacyVersion = await _storage.read(key: _keyConsentPrivacyVersion);
    final agreedAtIso = await _storage.read(key: _keyConsentAgreedAt);
    if (termsVersion == null ||
        termsVersion.isEmpty ||
        privacyVersion == null ||
        privacyVersion.isEmpty ||
        agreedAtIso == null ||
        agreedAtIso.isEmpty) {
      return null;
    }
    final marketingRaw = await _storage.read(key: _keyConsentMarketing);
    return ConsentSnapshot(
      termsVersion: termsVersion,
      privacyVersion: privacyVersion,
      marketingOptIn: marketingRaw == '1',
      agreedAtIso: agreedAtIso,
    );
  }

  Future<bool> hasRequiredConsent({
    required String termsVersion,
    required String privacyVersion,
  }) async {
    final snapshot = await getConsent();
    if (snapshot == null) return false;
    return snapshot.termsVersion == termsVersion &&
        snapshot.privacyVersion == privacyVersion;
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyExpiresIn);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyUserName);
    await _storage.delete(key: _keyUserProfile);
    await _storage.delete(key: _keyProvider);
    // 동의 이력은 재로그인 UX를 위해 기기에 유지한다.
  }

  String? _extractSubFromJwt(String? jwt) {
    if (jwt == null || jwt.isEmpty) return null;
    final parts = jwt.split('.');
    if (parts.length < 2) return null;

    try {
      final payloadRaw = parts[1];
      final normalized = base64Url.normalize(payloadRaw);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded);
      if (map is Map<String, dynamic>) {
        final sub = map['sub']?.toString().trim();
        if (sub != null && sub.isNotEmpty) {
          return sub;
        }
      }
    } catch (_) {
      // ignore: malformed token
    }
    return null;
  }
}

class ConsentSnapshot {
  const ConsentSnapshot({
    required this.termsVersion,
    required this.privacyVersion,
    required this.marketingOptIn,
    required this.agreedAtIso,
  });

  final String termsVersion;
  final String privacyVersion;
  final bool marketingOptIn;
  final String agreedAtIso;
}

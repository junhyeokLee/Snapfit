import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  Future<String?> getProvider() => _storage.read(key: _keyProvider);

  Future<UserInfo?> getUserInfo() async {
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

  Future<void> clear() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyExpiresIn);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyUserName);
    await _storage.delete(key: _keyUserProfile);
    await _storage.delete(key: _keyProvider);
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/env.dart';
import '../../../../core/interceptors/token_storage.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../data/dto/auth_response.dart';
import '../../domain/auth_service.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    tokenStorage: ref.read(tokenStorageProvider),
    supabase: ref.read(supabaseClientProvider),
  );
});

final authUserIdProvider = FutureProvider<String?>((ref) async {
  return ref.read(tokenStorageProvider).getResolvedUserId();
});

/// 홈 상단 로그인 상태 표시용
final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, UserInfo?>(
  AuthViewModel.new,
);

class AuthViewModel extends AsyncNotifier<UserInfo?> {
  Future<void>? _googleInitializeFuture;

  @override
  FutureOr<UserInfo?> build() async {
    return ref.read(tokenStorageProvider).getUserInfo();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }

  /// 프로필 이미지를 Supabase Storage에 업로드하고 로컬 유저 정보 갱신
  Future<void> updateProfileImage(File image) async {
    final fileToUpload = await _normalizeImageForUpload(image);
    final storage = ref.read(tokenStorageProvider);
    final current = await storage.getUserInfo();
    if (current == null) {
      throw Exception('로그인 후 프로필 이미지를 변경할 수 있습니다.');
    }
    final userId = current.id.trim();
    if (userId.isEmpty) {
      throw Exception('로그인 후 프로필 이미지를 변경할 수 있습니다.');
    }

    final supabase = ref.read(supabaseClientProvider);
    try {
      final ext = _profileImageExtension(fileToUpload.path);
      final objectPath =
          '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage
          .from('avatars')
          .upload(
            objectPath,
            fileToUpload,
            fileOptions: FileOptions(
              contentType: _profileImageContentType(ext),
              upsert: true,
            ),
          );
      final publicUrl = supabase.storage
          .from('avatars')
          .getPublicUrl(objectPath);
      await supabase.from('profiles').upsert({
        'id': userId,
        'email': current.email,
        'name': current.name,
        'provider': current.provider,
        'avatar_url': publicUrl,
      });
      await storage.saveUserInfo(current.copyWith(profileImageUrl: publicUrl));
      state = AsyncData(await storage.getUserInfo());
    } catch (e) {
      throw Exception('Supabase 프로필 이미지 업로드에 실패했습니다: $e');
    }
  }

  String _profileImageExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _profileImageContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<File> _normalizeImageForUpload(File image) async {
    final tmpDir = await getTemporaryDirectory();
    File result = image;
    int quality = 88;
    int minWidth = 1920;
    int minHeight = 1920;
    final targetSize = 900 * 1024;

    for (int i = 0; i < 4; i++) {
      final targetPath =
          '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}_profile_$i.jpg';
      try {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          result.absolute.path,
          targetPath,
          quality: quality,
          minWidth: minWidth,
          minHeight: minHeight,
          format: CompressFormat.jpeg,
        );
        if (compressed == null) break;
        result = File(compressed.path);
        if (await result.length() <= targetSize) {
          break;
        }
        quality = (quality - 14).clamp(45, 95).toInt();
        minWidth = (minWidth * 0.82).toInt();
        minHeight = (minHeight * 0.82).toInt();
      } catch (_) {
        break;
      }
    }
    return result;
  }

  Future<void> logout() async {
    state = const AsyncData(null);
    unawaited(ref.read(authServiceProvider).logout());
  }

  Future<void> deleteAccount() async {
    await ref.read(authServiceProvider).deleteAccount();
    state = const AsyncData(null);
  }

  Future<void> loginWithKakao() async {
    if (Env.kakaoNativeAppKey.isEmpty) {
      throw Exception('KAKAO_NATIVE_APP_KEY가 설정되지 않았습니다.');
    }
    final useTalk = await isKakaoTalkInstalled();
    OAuthToken token = useTalk
        ? await UserApi.instance.loginWithKakaoTalk()
        : await UserApi.instance.loginWithKakaoAccount();

    // Supabase Kakao OIDC requires an ID token. Kakao can return only an
    // access token when the OpenID scope has not been granted yet, so request
    // the missing OpenID scope once before failing the login.
    if (token.idToken == null || token.idToken!.isEmpty) {
      token = await UserApi.instance.loginWithNewScopes(['openid']);
    }

    final accessToken = token.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('카카오 로그인 토큰을 가져올 수 없습니다.');
    }
    final idToken = token.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        '카카오 ID 토큰을 가져올 수 없습니다. Kakao Developers에서 OpenID Connect를 활성화하고 Supabase Kakao Provider 설정을 확인해주세요.',
      );
    }

    await ref
        .read(authServiceProvider)
        .loginWithKakaoToken(accessToken, idToken: idToken);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInitializeFuture ??= GoogleSignIn.instance.initialize(
      clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
      serverClientId: Env.googleWebClientId,
    );
  }

  Future<void> loginWithGoogle() async {
    if (Env.googleWebClientId.isEmpty) {
      throw Exception('GOOGLE_WEB_CLIENT_ID가 설정되지 않았습니다.');
    }
    await _ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        '구글 ID 토큰을 가져올 수 없습니다. GOOGLE_WEB_CLIENT_ID가 Supabase Google Provider의 Web Client ID와 일치하는지, Android SHA-1/SHA-256 및 iOS client ID 설정이 등록되어 있는지 확인해주세요.',
      );
    }

    await ref.read(authServiceProvider).loginWithGoogleIdToken(idToken);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required bool marketingOptIn,
  }) async {
    final auth = await ref
        .read(authServiceProvider)
        .signUpWithEmail(name: name, email: email, password: password);
    if (auth != null) {
      state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
      await syncConsentIfPresent();
    }
  }

  Future<void> syncConsentIfPresent() async {
    await ref.read(authServiceProvider).syncConsentIfPresent();
  }
}

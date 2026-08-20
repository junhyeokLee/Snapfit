import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'
    hide AuthApi;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/env.dart';
import '../../../../core/interceptors/token_storage.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../data/api/auth_api.dart';
import '../../data/dto/auth_response.dart';
import '../../domain/auth_service.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = ref.read(dioProvider);
  return AuthApi(dio);
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    api: ref.read(authApiProvider),
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
      final objectPath = '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage.from('avatars').upload(
            objectPath,
            fileToUpload,
            fileOptions: FileOptions(
              contentType: _profileImageContentType(ext),
              upsert: true,
            ),
          );
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(objectPath);
      await supabase.from('profiles').upsert({
        'id': userId,
        'email': current.email,
        'name': current.name,
        'provider': current.provider,
        'avatar_url': publicUrl,
      });
      await storage.saveUserInfo(current.copyWith(profileImageUrl: publicUrl));
      state = AsyncData(await storage.getUserInfo());
      return;
    } catch (_) {
      // Supabase 업로드 실패 시 기존 REST 백엔드 경로로 1회 fallback.
    }

    final api = ref.read(authApiProvider);
    try {
      final userInfo = await api.updateProfile(profileImage: fileToUpload);
      await storage.saveUserInfo(userInfo);
      state = AsyncData(await storage.getUserInfo());
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 404) {
        throw Exception('프로필 이미지 저장 기능을 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.');
      }
      if (statusCode == 413) {
        throw Exception('이미지 용량이 너무 큽니다. 더 작은 이미지를 선택해 주세요.');
      }
      if (statusCode == 415) {
        throw Exception('지원하지 않는 이미지 형식입니다. JPG/PNG 이미지를 선택해 주세요.');
      }
      if (statusCode == 500) {
        throw Exception('이미지 저장소 설정 문제로 업로드에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
      rethrow;
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

    final accessToken = token.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('카카오 로그인 토큰을 가져올 수 없습니다.');
    }

    await ref.read(authServiceProvider).loginWithKakaoToken(accessToken);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }

  Future<void> loginWithGoogle() async {
    if (Env.googleWebClientId.isEmpty) {
      throw Exception('GOOGLE_WEB_CLIENT_ID가 설정되지 않았습니다.');
    }
    await GoogleSignIn.instance.initialize(
      serverClientId: Env.googleWebClientId,
    );
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('구글 ID 토큰을 가져올 수 없습니다.');
    }

    await ref.read(authServiceProvider).loginWithGoogleIdToken(idToken);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }

  Future<void> syncConsentIfPresent() async {
    await ref.read(authServiceProvider).syncConsentIfPresent();
  }
}

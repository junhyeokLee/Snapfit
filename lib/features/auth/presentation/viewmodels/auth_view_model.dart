import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'
    hide AuthApi;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../config/env.dart';
import '../../../../core/interceptors/token_storage.dart';
import '../../../../core/network/dio_provider.dart';
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
  );
});

final authUserIdProvider = FutureProvider<String?>((ref) async {
  return ref.read(tokenStorageProvider).getUserId();
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

  /// 프로필 이미지를 서버에 업로드하고 로컬 유저 정보 갱신
  Future<void> updateProfileImage(File image) async {
    final api = ref.read(authApiProvider);
    final fileToUpload = await _normalizeImageForUpload(image);

    try {
      final userInfo = await api.updateProfile(profileImage: fileToUpload);
      await ref.read(tokenStorageProvider).saveUserInfo(userInfo);
      state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
    } on DioException catch (e) {
      // 401 에러(토큰 만료) 발생 시 1회 재시도 (AuthInterceptor가 토큰은 갱신해둠)
      // FormData 재사용 불가 문제 해결을 위해 여기서 다시 호출
      if (e.response?.statusCode == 401) {
        try {
          // 토큰은 이미 인터셉터에서 갱신되었을 것이므로, 재시도만 하면 됨.
          // 혹시 모르니 잠시 대기 (인터셉터 갱신 완료 대기) - 실제로는 인터셉터가 401을 반환했다는 것은 갱신 시도 후 실패했거나,
          // FormData라서 패스한 경우임. 여기서는 "FormData라서 패스한 경우"를 가정하고 재호출.
          // 새 토큰은 TokenStorage에 저장되어 있고, 다음 요청 시 인터셉터가 새 토큰을 끼워줌.
          final userInfo = await api.updateProfile(
            profileImage:
                fileToUpload, // fileToUpload는 File 객체이므로 다시 FormData 생성됨
          );
          await ref.read(tokenStorageProvider).saveUserInfo(userInfo);
          state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
          return;
        } catch (retryError) {
          // 재시도도 실패하면 에러처리
        }
      }

      final statusCode = e.response?.statusCode;
      if (statusCode == 404) {
        throw Exception('서버에 프로필 저장 기능이 없습니다. 백엔드를 최신 버전으로 배포한 뒤 다시 시도해 주세요.');
      }
      if (statusCode == 413) {
        throw Exception('이미지 용량이 너무 큽니다. 더 작은 이미지를 선택해 주세요.');
      }
      if (statusCode == 415) {
        throw Exception('지원하지 않는 이미지 형식입니다. JPG/PNG 이미지를 선택해 주세요.');
      }
      if (statusCode == 500) {
        throw Exception('서버 이미지 저장소 설정 문제로 업로드에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
      rethrow;
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
}

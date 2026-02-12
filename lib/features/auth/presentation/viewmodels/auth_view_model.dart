import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide AuthApi;
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
final authViewModelProvider =
    AsyncNotifierProvider<AuthViewModel, UserInfo?>(AuthViewModel.new);

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

    // 1. 이미지 압축 로직 (Nginx 기본 설정 1MB 이하로 맞추기 위해 강력하게 압축)
    File fileToUpload = image;
    try {
      int sizeInBytes = await image.length();
      // 1MB 보다는 조금 더 안전하게 0.9MB 기준으로 잡음
      int targetSize = 900 * 1024; 

      if (sizeInBytes > targetSize) {
        final tmpDir = await getTemporaryDirectory();
        
        // 반복 압축을 위한 변수
        int quality = 85;
        int minWidth = 1920;
        int minHeight = 1920;
        
        // 최대 3번 시도
        for (int i = 0; i < 3; i++) {
            final targetPath =
                '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed_$i.jpg';

            final compressedXFile = await FlutterImageCompress.compressAndGetFile(
              image.absolute.path,
              targetPath,
              quality: quality, 
              minWidth: minWidth, 
              minHeight: minHeight,
            );

            if (compressedXFile != null) {
              final compressedFile = File(compressedXFile.path);
              final newSize = await compressedFile.length();
              
              if (newSize < targetSize) {
                  fileToUpload = compressedFile;
                  break; // 성공하면 루프 종료
              }
              
              // 실패하면 설정 낮춰서 재시도
              quality -= 15; // 85 -> 70 -> 55
              minWidth = (minWidth * 0.8).toInt(); // 1920 -> 1536 -> 1228
              minHeight = (minHeight * 0.8).toInt();
            }
        }
      }
    } catch (e) {
       // 실패 시 원본 사용 (하지만 413 에러 가능성 있음)
    }

    try {
      final userInfo = await api.updateProfile(
        profileImage: fileToUpload,
      );
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
             profileImage: fileToUpload, // fileToUpload는 File 객체이므로 다시 FormData 생성됨
           );
           await ref.read(tokenStorageProvider).saveUserInfo(userInfo);
           state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
           return;
        } catch (retryError) {
           // 재시도도 실패하면 에러처리
        }
      }

      if (e.response?.statusCode == 404) {
        throw Exception(
          '서버에 프로필 저장 기능이 없습니다. 백엔드를 최신 버전으로 배포한 뒤 다시 시도해 주세요.',
        );
      }
      rethrow;
    }
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

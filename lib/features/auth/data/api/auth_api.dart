import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../dto/auth_response.dart';

part 'auth_api.g.dart';

@RestApi()
abstract class AuthApi {
  factory AuthApi(Dio dio, {String? baseUrl}) = _AuthApi;

  @POST('/api/auth/login/kakao')
  Future<AuthResponse> loginWithKakao(
    @Body() Map<String, dynamic> body,
  );

  @POST('/api/auth/login/google')
  Future<AuthResponse> loginWithGoogle(
    @Body() Map<String, dynamic> body,
  );

  @POST('/api/auth/refresh')
  Future<AuthResponse> refresh(
    @Body() Map<String, dynamic> body,
  );

  /// 프로필 수정 (프로필 이미지 URL 등). Authorization: Bearer {token} 필요. POST 사용(서버가 PATCH/POST 둘 다 지원).
  @POST('/api/auth/profile')
  Future<UserInfo> updateProfile(
    @Body() Map<String, dynamic> body,
    @Header('Authorization') String authorization,
  );
}

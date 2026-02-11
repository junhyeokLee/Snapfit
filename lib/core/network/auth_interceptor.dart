import 'package:dio/dio.dart';
import '../auth/token_storage.dart';
import '../../config/env.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final Dio _dio;

  AuthInterceptor(this._tokenStorage, this._dio);

  @override
  Future<void> onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    // [DEBUG] 로그 추가
    print('[AuthInterceptor] path: ${options.path}');

    // 로그인 및 토큰 갱신 요청에는 헤더 추가 안 함
    if (options.path.contains('/login') || options.path.contains('/refresh')) {
      print('[AuthInterceptor] Skipping Authorization header for ${options.path}');
      return handler.next(options);
    }

    final token = await _tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      print('[AuthInterceptor] Added Authorization header');
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // 401 Unauthorized 에러이자, 아직 재시도하지 않은 요청인 경우
    if (err.response?.statusCode == 401 && err.requestOptions.headers['retry'] == null) {
      try {
        final refreshToken = await _tokenStorage.getRefreshToken();
        if (refreshToken == null) {
          // 리프레시 토큰 없음 -> 로그아웃
          await _tokenStorage.clear();
          return handler.next(err);
        }

        // 토큰 갱신 요청 (이 요청은 인터셉터를 타지 않도록 독립된 Dio 사용 권장하지만, 임시로 같은 Dio 사용시 무한루프 주의)
        // 여기서는 _dio를 사용하여 직접 호출하되, 인터셉터가 없는 순수 Dio를 쓰거나 경로를 잘 처리해야 함.
        // 편의상 dio.post를 쓰되, /refresh 경로는 onRequest에서 제외하거나 헤더를 안 넣는 방식을 쓸 수 있음.
        // 하지만 /refresh는 인증 헤더가 필요 없으므로 그냥 호출해도 무관.
        final response = await _dio.post(
          '${Env.baseUrl}/api/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
        
        if (response.statusCode == 200) {
          final newAccessToken = response.data['accessToken'];
          final newRefreshToken = response.data['refreshToken'];
          
          // 새 토큰 저장 (기존 정보 유지하며 업데이트)
          // 주의: AuthResponse 전체가 아니라 토큰만 올 수 있으므로 부분 업데이트 필요할 수 있음.
          // 현재 백엔드는 AuthResponse 전체를 줌.
          await _tokenStorage.updateTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          // 실패했던 요청 재시도
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newAccessToken';
          options.headers['retry'] = true; // 무한루프 방지용 플래그

          // 데이터 복구 (FormData 등은 재사용 시 에러 날 수 있으므로 주의)
          final clonedRequest = await _dio.request(
            options.path,
            options: Options(
              method: options.method,
              headers: options.headers,
            ),
            data: options.data,
            queryParameters: options.queryParameters,
          );
          
          return handler.resolve(clonedRequest);
        }
      } catch (e) {
        // 리프레시 실패 -> 로그아웃
        await _tokenStorage.clear();
      }
    }
    return handler.next(err);
  }
}
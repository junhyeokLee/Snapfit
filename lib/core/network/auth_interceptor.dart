import 'package:dio/dio.dart';
import '../interceptors/token_storage.dart';
import '../utils/app_logger.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final Dio _dio;
  Future<_RefreshResult?>? _refreshInFlight;

  AuthInterceptor(this._tokenStorage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // [DEBUG] 로그 추가
    AppLogger.debug('[AuthInterceptor] path: ${options.path}');

    // 로그인 및 토큰 갱신 요청에는 헤더 추가 안 함
    if (options.path.contains('/login') || options.path.contains('/refresh')) {
      AppLogger.debug(
        '[AuthInterceptor] Skipping Authorization header for ${options.path}',
      );
      return handler.next(options);
    }

    final token = await _tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      AppLogger.debug('[AuthInterceptor] Added Authorization header');
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final path = err.requestOptions.path;
    final isRefreshCall = path.contains('/api/auth/refresh');

    // 401 Unauthorized 에러이자, 아직 재시도하지 않은 요청인 경우
    if (err.response?.statusCode == 401 &&
        err.requestOptions.headers['retry'] == null &&
        !isRefreshCall) {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _tokenStorage.clear();
        return handler.next(err);
      }

      // FormData는 스트림이므로 재사용 불가 -> 뷰모델에서 수동 재시도하도록 401 그대로 반환
      if (err.requestOptions.data is FormData) {
        return handler.next(err);
      }

      // 동시 다발 401에서 refresh 중복 요청을 방지한다.
      _refreshInFlight ??= _refreshTokens(refreshToken).whenComplete(() {
        _refreshInFlight = null;
      });
      final refreshed = await _refreshInFlight;

      if (refreshed == null ||
          refreshed.accessToken.isEmpty ||
          refreshed.refreshToken.isEmpty) {
        await _tokenStorage.clear();
        return handler.next(err);
      }

      // 원 요청 재시도 실패는 세션 만료로 간주하지 않는다.
      try {
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
        options.headers['retry'] = true; // 무한루프 방지용 플래그

        final clonedRequest = await _dio.request(
          options.path,
          options: Options(method: options.method, headers: options.headers),
          data: options.data,
          queryParameters: options.queryParameters,
        );
        return handler.resolve(clonedRequest);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      }
    }
    return handler.next(err);
  }

  Future<_RefreshResult?> _refreshTokens(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      if (response.statusCode != 200) return null;
      final newAccessToken = response.data['accessToken'] as String?;
      final newRefreshToken = response.data['refreshToken'] as String?;
      if (newAccessToken == null ||
          newAccessToken.isEmpty ||
          newRefreshToken == null ||
          newRefreshToken.isEmpty) {
        return null;
      }
      await _tokenStorage.updateTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      return _RefreshResult(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
    } catch (_) {
      return null;
    }
  }
}

class _RefreshResult {
  final String accessToken;
  final String refreshToken;

  const _RefreshResult({
    required this.accessToken,
    required this.refreshToken,
  });
}

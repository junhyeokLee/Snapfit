import 'package:dio/dio.dart';

/// Retrofit 전용 Dio Factory
/// - HTTP 메서드 래핑 금지
/// - Dio 설정 + Interceptor만 담당
class DioClient {
  static Dio create({
    required String baseUrl,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // TODO: JWT 적용 시 여기서 Authorization 헤더 추가
          handler.next(options);
        },
        onError: (e, handler) {
          handler.next(e);
        },
      ),
    );

    return dio;
  }
}
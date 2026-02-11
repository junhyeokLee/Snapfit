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
          assert(() {
            // ignore: avoid_print
            print('[Dio] ${options.method} ${options.uri}');
            print('[Dio] Headers: ${options.headers}');
            print('[Dio] Body: ${options.data}');
            return true;
          }());
          handler.next(options);
        },
        onError: (e, handler) {
          assert(() {
            // ignore: avoid_print
            print('[Dio] Error: ${e.type} ${e.message}');
            if (e.type == DioExceptionType.connectionError) {
              // ignore: avoid_print
              print('[Dio] Connection refused(111) 체크: 1) 백엔드 0.0.0.0:8080 리스닝 2) PC·폰 같은 Wi‑Fi 3) dio_provider baseUrl = PC LAN IP');
            }
            return true;
          }());
          handler.next(e);
        },
      ),
    );

    return dio;
  }
}
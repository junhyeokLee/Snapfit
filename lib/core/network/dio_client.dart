import 'package:dio/dio.dart';
import '../utils/app_logger.dart';

/// Retrofit 전용 Dio Factory
/// - HTTP 메서드 래핑 금지
/// - Dio 설정 + Interceptor만 담당
class DioClient {
  static Dio create({required String baseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          AppLogger.debug('[Dio] ${options.method} ${options.uri}');
          AppLogger.debug('[Dio] Headers: ${options.headers}');
          AppLogger.debug('[Dio] Body: ${options.data}');
          handler.next(options);
        },
        onError: (e, handler) {
          AppLogger.warn('[Dio] Error: ${e.type} ${e.message}');
          if (e.type == DioExceptionType.connectionError) {
            AppLogger.warn(
              '[Dio] Connection refused(111) 체크: 1) 백엔드 0.0.0.0:8080 리스닝 2) PC·폰 같은 Wi-Fi 3) dio_provider baseUrl = PC LAN IP',
            );
          }
          handler.next(e);
        },
      ),
    );

    return dio;
  }
}

import 'package:dio/dio.dart';
import '../utils/app_logger.dart';

Future<void> _retryWithDelay(int attempt, int delayMs) async {
  await Future.delayed(Duration(milliseconds: delayMs * attempt));
}

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;
  final int delayMs;

  RetryInterceptor({required this.dio, this.retries = 3, this.delayMs = 1000});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      AppLogger.warn('네트워크 재시도 대상 에러 타입 = ${err.type}');
      for (int attempt = 1; attempt <= retries; attempt++) {
        try {
          await _retryWithDelay(attempt, delayMs);
          final response = await dio.request(
            err.requestOptions.path,
            options: Options(
              method: err.requestOptions.method,
              headers: err.requestOptions.headers,
            ),
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
          );
          return handler.resolve(response);
        } catch (e) {
          if (attempt == retries) {
            return handler.next(err);
          }
        }
      }
    }
    return super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    final method = err.requestOptions.method.toUpperCase();
    // 실서비스 안정성: 쓰기 요청(POST/PUT/PATCH/DELETE)은 자동 재시도하지 않음
    // 중복 생성/중복 삭제/동시성 충돌을 유발할 수 있으므로 조회 요청(GET/HEAD)만 재시도
    if (method != 'GET' && method != 'HEAD') {
      return false;
    }

    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError || // 인터넷 문제 포함
        err.response?.statusCode == 503;
  }
}

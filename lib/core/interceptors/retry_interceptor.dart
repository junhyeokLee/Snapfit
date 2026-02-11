import 'package:dio/dio.dart';

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
      print('에러 타입 = ${err.type}');
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
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError || // 인터넷 문제 포함
        err.response?.statusCode == 503;
  }
}

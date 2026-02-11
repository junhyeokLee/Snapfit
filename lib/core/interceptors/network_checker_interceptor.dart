import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

class NetworkCheckerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: '인터넷 연결 실패',
          type: DioExceptionType.connectionError,
        ),
      );
    } else {
      super.onRequest(options, handler);
    }
  }
}
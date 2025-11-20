// lib/core/network/dio_client.dart
import 'package:dio/dio.dart';

/// 전역에서 사용하는 Dio 래퍼
class DioClient {
  final Dio _dio;

  DioClient({
    Dio? dio,
    String baseUrl = 'https://api.snapfit.app', // 나중에 실제 주소로 교체
  }) : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

  /// 공통 GET
  Future<Response<T>> get<T>(
      String path, {
        Map<String, dynamic>? queryParameters,
      }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
    );
  }

  /// 공통 POST
  Future<Response<T>> post<T>(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
      }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  Dio get raw => _dio;
}
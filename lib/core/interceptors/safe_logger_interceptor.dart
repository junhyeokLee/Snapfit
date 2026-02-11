import 'dart:developer';
import 'package:dio/dio.dart';
import 'logger_interceptor.dart'; // 기존 로깅 인터셉터를 상속받음

/// 보안성을 강화한 로깅 인터셉터
class SafeLoggerInterceptor extends LoggerInterceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final sanitizedHeaders = {...options.headers}; // 원본 헤더 복사하여 수정
    if (sanitizedHeaders.containsKey('Authorization')) {
      sanitizedHeaders['Authorization'] = 'Bearer ***'; // 토큰 마스킹
    }

    // 요청 데이터 마스킹 (모든 알파벳을 '*'로 변환)
    final sanitizedData = options.data?.toString().replaceAll(RegExp(r'\w'), '*');

    // 로그 출력 (보안 적용된 값)
    log('Request Headers: $sanitizedHeaders');
    log('Request Data: $sanitizedData');

    // 기존 LoggerInterceptor 기능 유지
    super.onRequest(options, handler);
  }
}

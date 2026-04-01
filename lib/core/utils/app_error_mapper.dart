import 'package:dio/dio.dart';

class AppErrorMapper {
  static String toUserMessage(
    Object error, {
    String fallback = '요청 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
  }) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) return '로그인 세션이 만료되었습니다. 다시 로그인해주세요.';
      if (status == 403) return '권한이 없습니다. 다시 로그인 후 시도해주세요.';
      if (status == 404) return '요청한 정보를 찾을 수 없습니다.';
      if (status == 409) return '이미 처리된 요청입니다.';
      if (status == 422) return '입력값을 확인해주세요.';
      if (status == 429) return '요청이 많습니다. 잠시 후 다시 시도해주세요.';
      if (status != null && status >= 500) {
        return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return '네트워크 연결이 불안정합니다. 잠시 후 다시 시도해주세요.';
      }
      return fallback;
    }

    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty || text == 'Exception') return fallback;
    return text;
  }
}

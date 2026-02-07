import 'package:dio/dio.dart';

import 'api_error.dart';

/// API 에러를 도메인 모델로 변환하는 매퍼
/// DioException을 ApiError로 변환
class ApiErrorMapper {
  /// 에러 객체를 ApiError로 변환
  static ApiError from(Object error) {
    if (error is ApiError) return error;
    if (error is DioException) return _fromDio(error);
    return ApiError(
      message: '알 수 없는 오류가 발생했습니다.',
      cause: error,
    );
  }

  /// 에러 객체에서 사용자 친화적인 메시지만 추출
  static String message(Object error) => from(error).message;

  static ApiError _fromDio(DioException e) {
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;
    final serverMessage = _extractServerMessage(responseData);
    final serverCode = _extractServerCode(responseData);
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return ApiError(
        message: serverMessage,
        statusCode: statusCode,
        code: serverCode,
        cause: e,
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError(
          message: '요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.',
          statusCode: statusCode,
          cause: e,
        );
      case DioExceptionType.connectionError:
        return ApiError(
          message: '네트워크 연결이 불안정합니다. 연결 상태를 확인해주세요.',
          statusCode: statusCode,
          cause: e,
        );
      case DioExceptionType.badCertificate:
        return ApiError(
          message: '보안 연결에 실패했습니다. 잠시 후 다시 시도해주세요.',
          statusCode: statusCode,
          cause: e,
        );
      case DioExceptionType.badResponse:
        return ApiError(
          message: _messageFromStatus(statusCode),
          statusCode: statusCode,
          code: serverCode,
          cause: e,
        );
      case DioExceptionType.cancel:
        return ApiError(
          message: '요청이 취소되었습니다.',
          statusCode: statusCode,
          cause: e,
        );
      case DioExceptionType.unknown:
        return ApiError(
          message: '예기치 못한 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
          statusCode: statusCode,
          cause: e,
        );
    }
  }

  static String _messageFromStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return '요청이 올바르지 않습니다.';
      case 401:
        return '인증이 필요합니다.';
      case 403:
        return '권한이 없습니다.';
      case 404:
        return '요청한 리소스를 찾을 수 없습니다.';
      case 405:
        return '서버에서 해당 동작을 지원하지 않습니다.';
      case 409:
        return '이미 처리된 요청입니다.';
      case 422:
        return '입력 값이 올바르지 않습니다.';
      case 500:
        return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      case 502:
      case 503:
        return '서버가 일시적으로 응답하지 않습니다.';
      default:
        return '요청 처리 중 오류가 발생했습니다.';
    }
  }

  static String? _extractServerMessage(Object? data) {
    if (data == null) return null;
    if (data is String && data.trim().isNotEmpty) return data;

    if (data is Map<String, dynamic>) {
      final direct = _firstStringFrom(
        data['message'] ??
            data['msg'] ??
            data['error'] ??
            data['detail'] ??
            data['description'] ??
            data['errorMessage'] ??
            data['error_description'],
      );
      if (direct != null) return direct;

      final nested = _firstStringFrom(data['data']) ??
          _firstStringFrom(data['error']) ??
          _firstStringFrom(data['errors']);
      if (nested != null) return nested;

      for (final entry in data.entries) {
        final fromValue = _firstStringFrom(entry.value);
        if (fromValue != null) return fromValue;
      }
    }

    if (data is List) {
      for (final item in data) {
        final msg = _firstStringFrom(item);
        if (msg != null) return msg;
      }
    }
    return null;
  }

  static String? _extractServerCode(Object? data) {
    if (data is Map<String, dynamic>) {
      final code = data['code'] ??
          data['errorCode'] ??
          data['error_code'] ??
          data['statusCode'];
      final extracted = _firstStringFrom(code);
      if (extracted != null) return extracted;
      if (code is num) return code.toString();
    }
    return null;
  }

  static String? _firstStringFrom(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value;
    if (value is Map<String, dynamic>) {
      for (final v in value.values) {
        final msg = _firstStringFrom(v);
        if (msg != null) return msg;
      }
    }
    if (value is List) {
      for (final v in value) {
        final msg = _firstStringFrom(v);
        if (msg != null) return msg;
      }
    }
    return null;
  }
}

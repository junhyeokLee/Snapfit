import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_error.freezed.dart';

/// API 에러 도메인 모델
/// 네트워크 요청 실패 시 발생하는 에러를 표현
@freezed
abstract class ApiError with _$ApiError {
  const factory ApiError({
    /// 사용자에게 표시할 에러 메시지
    required String message,

    /// HTTP 상태 코드 (예: 400, 404, 500)
    int? statusCode,

    /// 서버에서 반환한 에러 코드 (예: "INVALID_INPUT", "NOT_FOUND")
    String? code,

    /// 원본 에러 객체 (디버깅용)
    Object? cause,
  }) = _ApiError;

  const ApiError._();

  /// 네트워크 연결 실패 여부
  bool get isNetworkError => statusCode == null;

  /// 클라이언트 에러 (4xx) 여부
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;

  /// 서버 에러 (5xx) 여부
  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// 인증 에러 (401) 여부
  bool get isUnauthorized => statusCode == 401;

  /// 권한 없음 (403) 여부
  bool get isForbidden => statusCode == 403;

  /// 리소스 없음 (404) 여부
  bool get isNotFound => statusCode == 404;
}

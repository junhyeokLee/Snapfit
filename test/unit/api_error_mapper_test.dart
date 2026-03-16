import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/network/api_error.dart';
import 'package:snap_fit/core/network/api_error_mapper.dart';

void main() {
  group('ApiErrorMapper', () {
    test('returns same ApiError instance when input is ApiError', () {
      const error = ApiError(message: '이미 처리된 에러', statusCode: 409);

      final mapped = ApiErrorMapper.from(error);

      expect(identical(mapped, error), isTrue);
    });

    test('extracts server message and code from DioException response data', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/albums'),
        statusCode: 400,
        data: {
          'message': '서버 에러 메시지',
          'error_code': 'INVALID_INPUT',
        },
      );
      final dioException = DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );

      final mapped = ApiErrorMapper.from(dioException);

      expect(mapped.message, '서버 에러 메시지');
      expect(mapped.statusCode, 400);
      expect(mapped.code, 'INVALID_INPUT');
      expect(mapped.cause, dioException);
    });

    test('maps timeout DioException to friendly message', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/timeout'),
        type: DioExceptionType.connectionTimeout,
      );

      final mapped = ApiErrorMapper.from(dioException);

      expect(mapped.message, '요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.');
      expect(mapped.statusCode, isNull);
      expect(mapped.cause, dioException);
    });

    test('maps bad response status to default message when no server message', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/missing'),
        statusCode: 404,
        data: null,
      );
      final dioException = DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );

      final mapped = ApiErrorMapper.from(dioException);

      expect(mapped.message, '요청한 리소스를 찾을 수 없습니다.');
      expect(mapped.statusCode, 404);
      expect(mapped.code, isNull);
    });
  });
}

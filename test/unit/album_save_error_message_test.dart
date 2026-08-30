import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/presentation/utils/album_save_error_message.dart';

void main() {
  test('maps storage quota exceeded to user friendly copy', () {
    final message = albumSaveErrorMessage(
      const StorageQuotaExceededException(
        hardLimitBytes: 1024,
        usedBytes: 1024,
        incomingBytes: 10,
        projectedBytes: 1034,
        reason: 'HARD_LIMIT_EXCEEDED',
      ),
    );

    expect(message, contains('저장 공간'));
    expect(message, isNot(contains('StorageQuotaExceededException')));
  });

  test('maps auth expiration errors to login copy', () {
    final message = albumSaveErrorMessage(
      Exception('로그인이 만료되었습니다. 다시 로그인 후 시도해주세요.'),
    );

    expect(message, contains('로그인이 만료'));
  });

  test('maps generic network errors without leaking exception wrapper', () {
    final message = albumSaveErrorMessage(
      StateError('Failed host lookup: supabase.co'),
    );

    expect(message, contains('연결'));
    expect(message, isNot(contains('Bad state')));
  });
}

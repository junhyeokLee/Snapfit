import 'package:supabase_flutter/supabase_flutter.dart';

class AlbumInviteFailure {
  const AlbumInviteFailure(
    this.title,
    this.message, {
    this.retryable = true,
    this.needsLogin = false,
  });
  final String title, message;
  final bool retryable;
  final bool needsLogin;

  factory AlbumInviteFailure.from(Object error) {
    final status = error is FunctionException ? error.status : null;
    final details = error is FunctionException ? error.details : null;
    final code = details is Map ? details['error'] : null;
    if (code == 'invite_expired' || status == 410) {
      return const AlbumInviteFailure(
        '초대 기간이 지났어요',
        '앨범을 만든 사람에게 새 초대 링크를 요청해 주세요.',
        retryable: false,
      );
    }
    if (code == 'invite_used' || status == 409) {
      return const AlbumInviteFailure(
        '이미 사용된 초대예요',
        '다른 사람이 참여한 링크예요. 새 초대 링크를 요청해 주세요.',
        retryable: false,
      );
    }
    if (code == 'invite_not_found' || status == 404 || status == 400) {
      return const AlbumInviteFailure(
        '초대를 찾을 수 없어요',
        '링크가 올바른지 확인하거나 새 초대 링크를 요청해 주세요.',
        retryable: false,
      );
    }
    if (status == 401) {
      return const AlbumInviteFailure(
        '로그인을 다시 확인해 주세요',
        '로그인 상태를 확인한 뒤 초대를 다시 수락해 주세요.',
        needsLogin: true,
      );
    }
    return const AlbumInviteFailure(
      '잠시 연결이 어려워요',
      '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
    );
  }
}

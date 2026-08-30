import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/service/album_invite_service.dart';

void main() {
  test('inviteErrorMessage does not leak raw auth or network errors', () {
    expect(
      AlbumInviteService.inviteErrorMessage(
        Exception('JWT expired: token abc'),
      ),
      '로그인이 만료되었어요. 다시 로그인한 뒤 초대 링크를 만들어주세요.',
    );
    expect(
      AlbumInviteService.inviteErrorMessage(
        Exception('SocketException: host lookup failed'),
      ),
      '연결이 불안정해요. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
    );
    expect(
      AlbumInviteService.inviteErrorMessage(
        Exception('PostgrestException(details: stack)'),
      ),
      '초대 링크를 만들지 못했어요. 잠시 후 다시 시도해주세요.',
    );
  });
}

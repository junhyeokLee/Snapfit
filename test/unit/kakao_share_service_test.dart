import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/service/kakao_share_service.dart';

void main() {
  test('parseShareableInviteUri allows only absolute web links', () {
    expect(
      KakaoShareService.parseShareableInviteUri(
        'https://snapfit.app/invite/abc',
      )?.toString(),
      'https://snapfit.app/invite/abc',
    );
    expect(
      KakaoShareService.parseShareableInviteUri('http://localhost/invite/abc'),
      isNotNull,
    );
    expect(
      KakaoShareService.parseShareableInviteUri('snapfit://invite/abc'),
      isNull,
    );
    expect(KakaoShareService.parseShareableInviteUri('not a url'), isNull);
    expect(KakaoShareService.parseShareableInviteUri(''), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/album_invite_link.dart';

void main() {
  test('app and trusted browser links identify the same invitation', () {
    for (final link in [
      'snapfit://invite?token=a-01_',
      'https://snapfit-c719d.web.app/invite/a-01_',
      'https://snapfit-c719d.firebaseapp.com/invite/a-01_',
      'https://snapfit-c719d.web.app/#/invite/a-01_',
      'https://snapfit-c719d.firebaseapp.com/#/invite/a-01_',
      'https://snapfit-c719d.web.app:443/invite/a-01_',
      'http://localhost:7357/invite/a-01_',
      'http://127.0.0.1:7357/#/invite/a-01_',
      'http://[::1]:7357/invite/a-01_',
    ]) {
      expect(albumInviteTokenFromUri(Uri.parse(link)), 'a-01_', reason: link);
    }
  });

  test('browser invitations reject unrelated origins and ambiguous tokens', () {
    for (final link in [
      'https://external.example/invite/a',
      'https://snapfit-c719d.web.app.external.example/invite/a',
      'https://user@snapfit-c719d.web.app/invite/a',
      'http://snapfit-c719d.web.app/invite/a',
      'https://snapfit-c719d.web.app:444/invite/a',
      'https://localhost.external.example/invite/a',
      '/invite/a',
      '//snapfit-c719d.web.app/invite/a',
      'https://snapfit-c719d.web.app/invite/',
      'https://snapfit-c719d.web.app/invite/a/extra',
      'https://snapfit-c719d.web.app/invite/a%2Fb',
      'https://snapfit-c719d.web.app/invite/a%20b',
      'https://snapfit-c719d.web.app/invite/%FF',
      'https://snapfit-c719d.web.app/invite/${'a' * 257}',
      'https://snapfit-c719d.web.app/invite/a?token=a&token=b',
      'https://snapfit-c719d.web.app/invite/a?token=a',
      'https://snapfit-c719d.web.app/invite/a#other',
      'https://snapfit-c719d.web.app/?token=a#/invite/a',
      'https://snapfit-c719d.web.app/#/invite/a?token=a&token=b',
      'https://snapfit-c719d.web.app/#/invite/a#other',
      'https://snapfit-c719d.web.app/feed#/invite/a',
      'https://snapfit-c719d.web.app/#//external.example/invite/a',
      'https://snapfit-c719d.web.app/?auth_callback=1&code=a',
      'https://snapfit-c719d.web.app/orders/a',
      'snapfit://auth/callback?code=a',
      'snapfit://invite?token=a&token=b',
      'snapfit://invite?token=%FF',
    ]) {
      expect(albumInviteTokenFromUri(Uri.parse(link)), isNull, reason: link);
    }
  });
}

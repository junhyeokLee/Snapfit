import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/album_invite_link.dart';
import 'package:snap_fit/features/referral/domain/referral_link.dart';

const _code = 'ABCD2345XY';

void main() {
  test('a shared code has one canonical public SnapFit address', () {
    final uri = referralShareUri('  abcd2345xy  ');
    expect(uri.toString(), 'https://snapfit-c719d.web.app/friends/$_code');
    expect(referralCodeFromUri(uri), _code);
    expect(uri.hasQuery, isFalse);
    expect(uri.hasFragment, isFalse);
    expect(() => referralShareUri('not-a-code'), throwsArgumentError);
  });

  test('ten readable characters normalize without accepting lookalikes', () {
    expect(normalizeReferralCode(' abcd2345xy '), _code);
    for (final code in [
      '',
      'ABCD2345X',
      'ABCD2345XYZ',
      'ABCD2345X0',
      'ABCD2345X1',
      'ABCD2345XI',
      'ABCD2345XL',
      'ABCD2345XO',
      'ABCD 345XY',
      'ABCD-345XY',
      'ＡBCD2345XY',
      'ABCD2345X\nY',
    ]) {
      expect(normalizeReferralCode(code), isNull, reason: code);
    }
  });

  test(
    'native and both deployed hosts accept direct and legacy hash links',
    () {
      for (final link in [
        'snapfit://friends?code=$_code',
        'snapfit://friends/?code=abcd2345xy',
        'https://snapfit-c719d.web.app/friends/$_code',
        'https://snapfit-c719d.firebaseapp.com/friends/$_code',
        'https://snapfit-c719d.web.app:443/friends/$_code',
        'https://snapfit-c719d.web.app/friends?code=$_code',
        'https://snapfit-c719d.web.app/#/friends/$_code',
        'https://snapfit-c719d.web.app/#/friends?code=$_code',
        'http://localhost:8080/friends/$_code',
        'http://127.0.0.1:8080/#/friends?code=$_code',
        'http://[::1]:8080/friends/$_code',
      ]) {
        expect(referralCodeFromUri(Uri.parse(link)), _code, reason: link);
      }
    },
  );

  test('a matching path on another host never becomes a SnapFit referral', () {
    for (final link in [
      'https://external.example/friends/$_code',
      'https://snapfit-c719d.web.app.external.example/friends/$_code',
      'https://snapfit-c719d.web.app@external.example/friends/$_code',
      'https://external.example@snapfit-c719d.web.app/friends/$_code',
      'http://snapfit-c719d.web.app/friends/$_code',
      'https://snapfit-c719d.web.app:444/friends/$_code',
      'ftp://snapfit-c719d.web.app/friends/$_code',
      '/friends/$_code',
    ]) {
      expect(referralCodeFromUri(Uri.parse(link)), isNull, reason: link);
    }
  });

  test('ambiguous or malformed sources cannot silently select a referral', () {
    for (final link in [
      'snapfit://friends?code=$_code&code=JKMP2345XY',
      'snapfit://friends?code=$_code&next=https://external.example',
      'snapfit://friends?code=',
      'snapfit://friends/$_code',
      'snapfit://friends:123?code=$_code',
      'snapfit://user@friends?code=$_code',
      'snapfit://friends?code=$_code#fragment',
      'https://snapfit-c719d.web.app/friends/$_code?code=$_code',
      'https://snapfit-c719d.web.app/friends/$_code/',
      'https://snapfit-c719d.web.app/friends/$_code/more',
      'https://snapfit-c719d.web.app/?code=$_code#/friends/$_code',
      'https://snapfit-c719d.web.app/feed#/friends/$_code',
      'https://snapfit-c719d.web.app/#//external.example/friends/$_code',
      'https://snapfit-c719d.web.app/#/friends/$_code#again',
      'https://snapfit-c719d.web.app/friends/ABCD2345X0',
      'https://snapfit-c719d.web.app/friends?code=%ZZ',
    ]) {
      expect(referralCodeFromUri(Uri.parse(link)), isNull, reason: link);
    }
  });

  test(
    'friend rewards, album collaboration and OAuth never share an intake',
    () {
      final referral = referralShareUri(_code);
      expect(albumInviteTokenFromUri(referral), isNull);
      for (final link in [
        'snapfit://invite?token=$_code',
        'https://snapfit-c719d.web.app/invite/$_code',
        'https://snapfit-c719d.web.app/#/invite/$_code',
        'snapfit://auth?code=$_code',
        'https://snapfit-c719d.web.app/?auth_callback=1&code=$_code',
        'https://snapfit-c719d.web.app/?code=$_code',
      ]) {
        expect(referralCodeFromUri(Uri.parse(link)), isNull, reason: link);
      }
    },
  );
}

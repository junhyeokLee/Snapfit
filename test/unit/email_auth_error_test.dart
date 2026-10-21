import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/auth/domain/email_auth_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('only explicit unconfirmed-email errors open confirmation', () {
    expect(
      isEmailConfirmationRequired(const AuthException('Email not confirmed')),
      isTrue,
    );
    expect(
      isEmailConfirmationRequired(
        const AuthException('private', code: 'email_not_confirmed'),
      ),
      isTrue,
    );
    for (final error in [
      const AuthException('Error sending confirmation email'),
      const AuthException('Email not confirmed', code: 'unexpected_failure'),
      Exception('email_not_confirmed'),
      const AuthException('SMTP error: email not confirmed'),
    ]) {
      expect(isEmailConfirmationRequired(error), isFalse);
    }
  });

  test(
    'confirmation notices distinguish format, expired code, pacing and network',
    () {
      String notice(Object error) => emailAuthErrorMessage(
        error,
        action: EmailAuthAction.verifyConfirmation,
      );
      expect(
        notice(
          const AuthException(
            'private',
            code: 'email_confirmation_code_invalid',
          ),
        ),
        contains('8자리'),
      );
      expect(
        notice(const AuthException('private', code: 'otp_expired')),
        contains('가장 최근 메일'),
      );
      expect(
        notice(const AuthException('private', statusCode: '429')),
        contains('조금 뒤'),
      );
      expect(notice(TimeoutException('private')), contains('인터넷 연결'));
      expect(
        notice(const AuthException('private detail')),
        isNot(contains('private')),
      );
    },
  );
  test(
    'duplicate accounts return to the original login method, including OAuth',
    () {
      for (final error in [
        const AuthException(
          'User already registered',
          code: 'user_already_exists',
        ),
        const AuthException('message', code: 'email_exists'),
        const AuthException('User already registered'),
      ]) {
        expect(
          emailAuthErrorMessage(error, action: EmailAuthAction.signUp),
          '이미 가입된 이메일이에요. 가입할 때 사용한 방법으로 로그인해주세요.',
        );
      }
    },
  );

  test('stable Auth codes take priority over misleading message text', () {
    expect(
      emailAuthErrorMessage(
        const AuthException(
          'Error sending confirmation email',
          code: 'email_address_not_authorized',
        ),
        action: EmailAuthAction.signUp,
      ),
      '이메일 발송을 이용할 수 없는 상태예요. 다른 로그인 방법을 이용하거나 고객센터에 문의해주세요.',
    );
    expect(
      emailAuthErrorMessage(
        const AuthException(
          'Error sending confirmation email',
          code: 'invalid_credentials',
        ),
        action: EmailAuthAction.signIn,
      ),
      '이메일 또는 비밀번호가 올바르지 않아요.',
    );
    expect(
      emailAuthErrorMessage(
        const AuthException('message', code: 'email_not_confirmed'),
        action: EmailAuthAction.signIn,
      ),
      '이메일 인증을 먼저 완료해주세요.',
    );
  });

  test('email delivery errors never claim email verification is required', () {
    for (final error in [
      const AuthException('Error sending confirmation email'),
      const AuthException(
        'Error sending confirmation email',
        code: 'unexpected_failure',
        statusCode: '500',
      ),
      Exception('SMTP delivery failed: private-detail'),
    ]) {
      expect(
        emailAuthErrorMessage(error, action: EmailAuthAction.signUp),
        '인증 메일을 보내지 못했어요. 잠시 후 다시 시도해주세요.',
      );
    }
    expect(
      emailAuthErrorMessage(
        const AuthException('Error sending recovery email'),
        action: EmailAuthAction.requestPasswordReset,
      ),
      '비밀번호 재설정 메일을 보내지 못했어요. 잠시 후 다시 시도해주세요.',
    );
  });

  test('rate limits explain email pacing for both codes and HTTP 429', () {
    for (final error in [
      const AuthException('message', code: 'over_email_send_rate_limit'),
      const AuthException('message', statusCode: '429'),
    ]) {
      expect(
        emailAuthErrorMessage(
          error,
          action: EmailAuthAction.resendConfirmation,
        ),
        '메일 요청이 잠시 제한됐어요. 잠시 후 다시 시도해주세요.',
      );
    }
  });

  test(
    'fallback notices describe the requested operation without raw details',
    () {
      const error = AuthException('private server detail');
      expect(
        emailAuthErrorMessage(
          error,
          action: EmailAuthAction.requestPasswordReset,
        ),
        '비밀번호 재설정 메일을 보내지 못했어요. 잠시 후 다시 시도해주세요.',
      );
      expect(
        emailAuthErrorMessage(
          error,
          action: EmailAuthAction.resendConfirmation,
        ),
        '인증 메일을 다시 보내지 못했어요. 잠시 후 다시 시도해주세요.',
      );
      expect(
        emailAuthErrorMessage(error, action: EmailAuthAction.updatePassword),
        '비밀번호를 변경하지 못했어요. 잠시 후 다시 시도해주세요.',
      );
    },
  );
}

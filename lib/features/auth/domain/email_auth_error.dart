import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

enum EmailAuthAction {
  signIn,
  signUp,
  requestPasswordReset,
  resendConfirmation,
  verifyConfirmation,
  updatePassword,
}

/// A sending/SMTP failure must never open a misleading confirmation screen.
bool isEmailConfirmationRequired(Object error) {
  if (error is! AuthException) return false;
  final code = error.code?.trim().toLowerCase();
  if (code != null && code.isNotEmpty) return code == 'email_not_confirmed';
  final message = error.message.trim().toLowerCase();
  return message == 'email not confirmed' || message == 'email_not_confirmed';
}

/// Uses Auth's stable error codes before interpreting older server messages.
/// Server response details are never copied into the customer-facing notice.
String emailAuthErrorMessage(Object error, {required EmailAuthAction action}) {
  final code = error is AuthException ? error.code?.toLowerCase() : null;
  final message = (error is AuthException ? error.message : error.toString())
      .toLowerCase();
  final isSendingEmail = switch (action) {
    EmailAuthAction.signUp ||
    EmailAuthAction.requestPasswordReset ||
    EmailAuthAction.resendConfirmation => true,
    _ => false,
  };

  String rateLimitMessage() => isSendingEmail
      ? '메일 요청이 잠시 제한됐어요. 잠시 후 다시 시도해주세요.'
      : '요청이 잠시 많아졌어요. 조금 뒤에 다시 시도해주세요.';
  String invalidCredentialsMessage() => action == EmailAuthAction.signIn
      ? '이메일 또는 비밀번호가 올바르지 않아요.'
      : '이메일 또는 비밀번호 형식을 확인해주세요.';
  String emailDeliveryMessage() =>
      action == EmailAuthAction.requestPasswordReset
      ? '비밀번호 재설정 메일을 보내지 못했어요. 잠시 후 다시 시도해주세요.'
      : '인증 메일을 보내지 못했어요. 잠시 후 다시 시도해주세요.';
  const invalidConfirmationCode =
      '인증번호가 올바르지 않거나 만료됐어요. 가장 최근 메일의 번호를 입력하거나 인증 메일을 다시 받아주세요.';

  switch (code) {
    case 'email_confirmation_code_invalid':
      return '메일에 있는 8자리 숫자 인증번호를 입력해주세요.';
    case 'email_confirmation_email_changed':
      return '인증 메일을 받은 이메일과 현재 이메일이 달라요. 가입한 이메일을 확인해주세요.';
    case 'email_confirmation_session_changed':
      return '다른 계정으로 로그인되어 있어요. 로그아웃 후 인증을 진행해주세요.';
    case 'email_confirmation_response_invalid':
      return '이메일 인증 결과를 확인하지 못했어요. 가입한 이메일로 다시 로그인해주세요.';
    case 'otp_expired':
    case 'otp_disabled':
      if (action == EmailAuthAction.verifyConfirmation) {
        return invalidConfirmationCode;
      }
      break;
    case 'email_address_not_authorized':
      return '이메일 발송을 이용할 수 없는 상태예요. 다른 로그인 방법을 이용하거나 고객센터에 문의해주세요.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return rateLimitMessage();
    case 'email_not_confirmed':
      return '이메일 인증을 먼저 완료해주세요.';
    case 'invalid_credentials':
      if (action == EmailAuthAction.verifyConfirmation) {
        return invalidConfirmationCode;
      }
      return invalidCredentialsMessage();
    case 'email_address_invalid':
    case 'invalid_email':
      return '이메일 형식을 확인해주세요.';
    case 'email_exists':
    case 'user_already_exists':
      return '이미 가입된 이메일이에요. 가입할 때 사용한 방법으로 로그인해주세요.';
    case 'weak_password':
      return '비밀번호는 8자 이상, 영문과 숫자를 함께 사용해주세요.';
    case 'same_password':
      return '현재 비밀번호와 다른 새 비밀번호를 입력해주세요.';
    case 'email_provider_disabled':
      return '현재 이메일 로그인을 이용할 수 없어요. 다른 로그인 방법을 이용해주세요.';
    case 'signup_disabled':
      return '현재 이메일 가입을 이용할 수 없어요. 다른 로그인 방법을 이용해주세요.';
  }

  if (error is AuthException && error.statusCode == '429') {
    return rateLimitMessage();
  }
  if (action == EmailAuthAction.verifyConfirmation) {
    if (error is TimeoutException || error is AuthRetryableFetchException) {
      return '연결이 원활하지 않아 인증 결과를 확인하지 못했어요. 인터넷 연결을 확인한 뒤 다시 시도해주세요.';
    }
    if (message.contains('token has expired') ||
        message.contains('otp_expired') ||
        message.contains('invalid otp') ||
        message.contains('invalid token')) {
      return invalidConfirmationCode;
    }
  }
  // Older Auth servers may omit a code for a delivery error. In particular,
  // "Error sending confirmation email" is not an unconfirmed-email session.
  if (message.contains('email address not authorized')) {
    return '이메일 발송을 이용할 수 없는 상태예요. 다른 로그인 방법을 이용하거나 고객센터에 문의해주세요.';
  }
  if (isSendingEmail &&
      (message.contains('error sending') || message.contains('smtp'))) {
    return emailDeliveryMessage();
  }
  if (message.contains('rate_limit') ||
      message.contains('rate limit') ||
      message.contains('too many')) {
    return rateLimitMessage();
  }
  if (message.contains('already registered') ||
      message.contains('already been registered') ||
      message.contains('user already exists')) {
    return '이미 가입된 이메일이에요. 가입할 때 사용한 방법으로 로그인해주세요.';
  }
  if (message.contains('email not confirmed') ||
      message.contains('email_not_confirmed')) {
    return '이메일 인증을 먼저 완료해주세요.';
  }
  if (message.contains('weak password')) {
    return '비밀번호는 8자 이상, 영문과 숫자를 함께 사용해주세요.';
  }
  if (message.contains('invalid') || message.contains('credential')) {
    return invalidCredentialsMessage();
  }
  return switch (action) {
    EmailAuthAction.signIn => '이메일 로그인을 완료하지 못했어요. 잠시 후 다시 시도해주세요.',
    EmailAuthAction.signUp => '이메일 가입을 완료하지 못했어요. 잠시 후 다시 시도해주세요.',
    EmailAuthAction.requestPasswordReset =>
      '비밀번호 재설정 메일을 보내지 못했어요. 잠시 후 다시 시도해주세요.',
    EmailAuthAction.resendConfirmation => '인증 메일을 다시 보내지 못했어요. 잠시 후 다시 시도해주세요.',
    EmailAuthAction.verifyConfirmation => '이메일 인증을 완료하지 못했어요. 잠시 후 다시 시도해주세요.',
    EmailAuthAction.updatePassword => '비밀번호를 변경하지 못했어요. 잠시 후 다시 시도해주세요.',
  };
}

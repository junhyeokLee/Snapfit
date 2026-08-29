import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email signup confirmation uses Snapfit auth callback redirect', () {
    final source = File(
      'lib/features/auth/domain/auth_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<AuthResponse?> signUpWithEmail');
    final end = source.indexOf('Future<void> requestPasswordReset', start);
    final methodSource = source.substring(start, end);

    expect(methodSource, contains('emailRedirectTo: Env.authRedirectUrl'));
  });

  test('auth callback syncs saved consent after email confirmation', () {
    final source = File(
      'lib/features/auth/presentation/viewmodels/auth_view_model.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<String?> handleAuthCallback');
    final end = source.indexOf('Future<void> updatePassword', start);
    final methodSource = source.substring(start, end);

    expect(methodSource, contains('await syncConsentIfPresent();'));
  });
}

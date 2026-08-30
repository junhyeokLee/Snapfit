import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FCM initialization does not log raw push token values', () {
    final source = File(
      'lib/core/notifications/fcm_notification_service.dart',
    ).readAsStringSync();

    expect(source, contains('token registered='));
    expect(source, isNot(contains(r'[FCM] token: $token')));
  });
}

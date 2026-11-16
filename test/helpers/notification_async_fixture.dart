import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';

/// FCM keeps process-wide futures. Move their completed tails back into the
/// real async zone before this widget test's fake clock stops being pumped.
/// This performs only the fixture's mocked SDK/HTTP calls.
Future<void> drainNotificationFixture(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  var finished = false;
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    unawaited(
      (() async {
        // The first call may join work created by the outgoing widget zone.
        // The second establishes fresh SDK queue tails in this real zone.
        await FcmNotificationService.syncSession();
        await FcmNotificationService.syncSession();
        await FcmNotificationService.loadSettings(refresh: true);
      })().then(
        (_) => finished = true,
        onError: (Object error, StackTrace stack) {
          failure = error;
          failureStack = stack;
          finished = true;
        },
      ),
    );
  });
  // Pump the outgoing fake zone while real SDK/storage/HTTP continuations run.
  // Bound the handoff so a broken fixture fails here instead of hanging the
  // next real setUp/tearDownAll, whose timeout does not cover this deadlock.
  for (var step = 0; step < 40 && !finished; step++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(
    finished,
    isTrue,
    reason: 'Notification fixture async handoff stalled.',
  );
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}

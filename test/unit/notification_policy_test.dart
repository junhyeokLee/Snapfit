import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/notifications/notification_policy.dart';
import 'package:snap_fit/features/notification/domain/entities/app_notification_item.dart';

void main() {
  test('quiet hours include 22:00 and end exactly at 08:00', () {
    bool at(int hour, int minute) => allowsNotification(
      all: true,
      categoryEnabled: true,
      nightMute: true,
      now: DateTime(2026, 9, 8, hour, minute),
    );
    expect(at(21, 59), isTrue);
    expect(at(22, 0), isFalse);
    expect(at(7, 59), isFalse);
    expect(at(8, 0), isTrue);
  });
  test('master and category opt-outs both suppress notifications', () {
    final now = DateTime(2026, 9, 8, 12);
    expect(
      allowsNotification(
        all: false,
        categoryEnabled: true,
        nightMute: false,
        now: now,
      ),
      isFalse,
    );
    expect(
      allowsNotification(
        all: true,
        categoryEnabled: false,
        nightMute: false,
        now: now,
      ),
      isFalse,
    );
    expect(
      allowsNotification(
        all: true,
        categoryEnabled: true,
        nightMute: false,
        now: now,
      ),
      isTrue,
    );
  });
  test(
    'bundled templates share new-template policy without marketing opt-in',
    () {
      expect(notificationCategory({'type': 'template_update'}), 'new_template');
      expect(notificationCategory({'type': 'invite_accepted'}), 'invite');
      expect(notificationCategory({'type': 'order_status'}), 'order');
    },
  );
  test('Supabase timestamp offsets preserve the actual event time', () {
    final item = AppNotificationItem.fromJson({
      'id': 1,
      'createdAt': '2026-09-08T10:00:00+00:00',
      'userId': 'owner',
      'data': {'orderId': 'ord_1'},
    });
    expect(item.createdAt.toUtc(), DateTime.utc(2026, 9, 8, 10));
    expect(item.copyWith(isRead: true).data['orderId'], 'ord_1');
    expect(item.copyWith(isRead: true).userId, 'owner');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/domain/order_detail_navigation.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15);

  test('startup does not consume a link before the navigator is ready', () {
    final navigation = OrderDetailNavigation()..receive('order-a');
    expect(
      navigation.take(ownerId: 'owner', navigatorReady: false, now: now),
      isNull,
    );
    expect(
      navigation.take(ownerId: 'owner', navigatorReady: true, now: now),
      'order-a',
    );
    expect(
      navigation.take(ownerId: 'owner', navigatorReady: true, now: now),
      isNull,
    );
  });

  test('an order link waits for login without trusting payment URL data', () {
    final navigation = OrderDetailNavigation()..receive('order-a');
    expect(
      navigation.take(ownerId: null, navigatorReady: true, now: now),
      isNull,
    );
    expect(
      navigation.take(ownerId: 'owner', navigatorReady: true, now: now),
      'order-a',
    );
  });

  test(
    'a notification for the previous account is never opened for another',
    () {
      final navigation = OrderDetailNavigation()
        ..receive('order-a', ownerId: 'owner-a');
      expect(
        navigation.take(ownerId: 'owner-b', navigatorReady: true, now: now),
        isNull,
      );
      expect(
        navigation.take(ownerId: 'owner-a', navigatorReady: true, now: now),
        isNull,
      );
    },
  );

  test('duplicate delivery of one link opens only once in the same moment', () {
    final navigation = OrderDetailNavigation()..receive('order-a');
    expect(
      navigation.take(ownerId: 'owner', navigatorReady: true, now: now),
      'order-a',
    );
    navigation.receive('order-a');
    expect(
      navigation.take(ownerId: 'owner', navigatorReady: true, now: now),
      isNull,
    );
    navigation.receive('order-a');
    expect(
      navigation.take(
        ownerId: 'owner',
        navigatorReady: true,
        now: now.add(const Duration(seconds: 3)),
      ),
      'order-a',
    );
  });

  test('another order does not get suppressed by the previous link', () {
    final navigation = OrderDetailNavigation()..receive('order-a');
    navigation.take(ownerId: 'owner', navigatorReady: true, now: now);
    navigation.receive('order-b');
    expect(
      navigation.take(ownerId: 'owner', navigatorReady: true, now: now),
      'order-b',
    );
  });

  test('empty or oversized references cannot replace a pending valid link', () {
    final navigation = OrderDetailNavigation()..receive('order-a');
    navigation.receive(' ');
    navigation.receive('x' * 201);
    expect(
      navigation.take(ownerId: 'owner', navigatorReady: true, now: now),
      'order-a',
    );
  });

  test(
    'a newer destination cancels both pending order and old duplicate window',
    () {
      final navigation = OrderDetailNavigation()
        ..receive('order-a', ownerId: 'owner');
      navigation.cancel();
      expect(navigation.hasPending, false);
      expect(
        navigation.take(ownerId: 'owner', navigatorReady: true, now: now),
        isNull,
      );
      navigation.receive('order-a', ownerId: 'owner');
      expect(
        navigation.take(ownerId: 'owner', navigatorReady: true, now: now),
        'order-a',
      );
      navigation.cancel();
      navigation.receive('order-a', ownerId: 'owner');
      expect(
        navigation.take(
          ownerId: 'owner',
          navigatorReady: true,
          now: now.add(const Duration(milliseconds: 100)),
        ),
        'order-a',
      );
    },
  );
}

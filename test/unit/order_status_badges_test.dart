import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';

void main() {
  group('OrderStatusBadges', () {
    late OrderRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = OrderRepository(dio: Dio(), tokenStorage: TokenStorage());
    });

    test('first snapshot stores baseline and returns zero badges', () async {
      final summary = OrderSummaryResult(
        paymentPending: 1,
        paymentCompleted: 0,
        inProduction: 0,
        shipping: 0,
        delivered: 0,
        canceled: 0,
        latestUpdatedAt: DateTime.parse('2026-04-01T00:00:00Z'),
      );

      final badges = await repository.computeUnreadStatusBadges(
        userId: 'u1',
        summary: summary,
      );

      expect(badges.hasAny, isFalse);
    });

    test('same counts + newer latestUpdatedAt triggers fallback badge', () async {
      final first = OrderSummaryResult(
        paymentPending: 0,
        paymentCompleted: 1,
        inProduction: 0,
        shipping: 0,
        delivered: 0,
        canceled: 0,
        latestUpdatedAt: DateTime.parse('2026-04-01T00:00:00Z'),
      );
      await repository.computeUnreadStatusBadges(userId: 'u2', summary: first);

      final changed = OrderSummaryResult(
        paymentPending: 0,
        paymentCompleted: 1,
        inProduction: 0,
        shipping: 0,
        delivered: 0,
        canceled: 0,
        latestUpdatedAt: DateTime.parse('2026-04-01T01:00:00Z'),
      );
      final badges = await repository.computeUnreadStatusBadges(
        userId: 'u2',
        summary: changed,
      );

      expect(badges.paymentCompleted, 1);
      expect(badges.hasAny, isTrue);
    });

    test('same counts + same latestUpdatedAt keeps zero badges', () async {
      final summary = OrderSummaryResult(
        paymentPending: 0,
        paymentCompleted: 0,
        inProduction: 1,
        shipping: 0,
        delivered: 0,
        canceled: 0,
        latestUpdatedAt: DateTime.parse('2026-04-01T02:00:00Z'),
      );
      await repository.computeUnreadStatusBadges(userId: 'u3', summary: summary);

      final badges = await repository.computeUnreadStatusBadges(
        userId: 'u3',
        summary: summary,
      );

      expect(badges.hasAny, isFalse);
    });
  });
}

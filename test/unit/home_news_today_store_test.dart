import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/home_news/data/home_news_today_store.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_providers.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_today_providers.dart';

HomeNewsExposureState stateAt(DateTime now) {
  final korean = now.toUtc().add(const Duration(hours: 9));
  final date = DateTime.utc(korean.year, korean.month, korean.day);
  return HomeNewsExposureState(
    serverNow: now,
    serverDate: date,
    weekStart: date.subtract(Duration(days: date.weekday - 1)),
    dailyCount: 5,
    weeklyCount: 9,
    history: const [],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Korean midnight uses server date across month/year/leap boundaries',
    () {
      for (final (now, expected) in [
        (
          DateTime.utc(2026, 10, 28, 14, 59, 59),
          DateTime.utc(2026, 10, 28, 15),
        ),
        (DateTime.utc(2026, 10, 28, 15), DateTime.utc(2026, 10, 29, 15)),
        (DateTime.utc(2026, 12, 31, 15), DateTime.utc(2027, 1, 1, 15)),
        (DateTime.utc(2028, 2, 28, 15), DateTime.utc(2028, 2, 29, 15)),
      ]) {
        expect(homeNewsNextKoreanMidnight(now), expected);
      }
    },
  );

  test(
    'a choice is immediately remembered and survives a fresh store instance',
    () async {
      final until = DateTime.utc(2026, 10, 28, 15);
      final store = PreferencesHomeNewsTodayStore();
      store.rememberUntil('owner-a', until);
      expect(await store.readUntil('owner-a'), until);
      await store.persistUntil('owner-a', until);
      expect(await PreferencesHomeNewsTodayStore().readUntil('owner-a'), until);
      expect(
        await PreferencesHomeNewsTodayStore().readUntil('owner-b'),
        isNull,
      );
    },
  );

  test(
    'a late earlier-day confirmation cannot replace a newer-day choice on disk or in memory',
    () async {
      final store = PreferencesHomeNewsTodayStore();
      final older = DateTime.utc(2026, 10, 28, 15);
      final newer = DateTime.utc(2026, 10, 29, 15);
      final writes = [
        store.persistUntil('owner-a', newer),
        store.persistUntil('owner-a', older),
      ];
      store.rememberUntil('owner-a', older);
      await Future.wait(writes);
      expect(await store.readUntil('owner-a'), newer);
      expect(await PreferencesHomeNewsTodayStore().readUntil('owner-a'), newer);
    },
  );

  test(
    'missing and malformed persisted preferences do not hide news',
    () async {
      SharedPreferences.setMockInitialValues({
        PreferencesHomeNewsTodayStore.key('a'): 'not-a-date',
        PreferencesHomeNewsTodayStore.key('b'): '2026-10-28T15:00:00',
      });
      final store = PreferencesHomeNewsTodayStore();
      expect(await store.readUntil('a'), isNull);
      expect(await store.readUntil('b'), isNull);
      expect(await store.readUntil('c'), isNull);
    },
  );

  test(
    'an expired choice releases at exact Korean midnight without restarting the store',
    () async {
      final store = PreferencesHomeNewsTodayStore();
      final until = DateTime.utc(2026, 10, 28, 15);
      await store.persistUntil('owner-a', until);
      var state = stateAt(until.subtract(const Duration(seconds: 1)));
      final container = ProviderContainer(
        overrides: [
          homeNewsCurrentOwnerProvider.overrideWithValue('owner-a'),
          homeNewsExposureStateProvider.overrideWith((_) async => state),
          homeNewsTodayStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      container.listen(homeNewsTodayHiddenProvider, (_, __) {});
      expect(await container.read(homeNewsTodayHiddenProvider.future), isTrue);
      state = stateAt(until);
      container.invalidate(homeNewsExposureStateProvider);
      expect(await container.read(homeNewsTodayHiddenProvider.future), isFalse);
    },
  );
}

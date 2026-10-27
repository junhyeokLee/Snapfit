import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/cache/storage_image_url_cache.dart';

void main() {
  test(
    'decoded URL aliases repair only their matching cached address without signing',
    () async {
      final cache = StorageImageUrlCache();
      var calls = 0;
      Future<String> sign() async {
        calls++;
        return 'url';
      }

      await cache.resolve('photo', sign);
      cache.invalidate('photo', failedUrl: 'url', failureVersion: 1);
      cache.acceptRecovery('photo', 'different', 1);
      expect(cache.peek('photo'), isNull);
      cache.acceptRecovery('photo', 'url', 1);
      expect(await cache.resolve('photo', sign), 'url');
      expect(calls, 1);
      cache.invalidate('photo', failedUrl: 'url', failureVersion: 2);
      cache.acceptRecovery('photo', 'url', 1);
      expect(cache.peek('photo'), isNull);
      cache.acceptRecovery('missing', 'url', 2);
      expect(cache.peek('missing'), isNull);
      cache.acceptRecovery('photo', 'url', 2);
      cache.invalidate('photo', failedUrl: 'url', failureVersion: 1);
      expect(cache.peek('photo'), 'url');
    },
  );

  test(
    'alias failure versions cannot invalidate a renewed identical URL twice',
    () async {
      final cache = StorageImageUrlCache();
      var calls = 0;
      Future<String> sign() async {
        calls++;
        return 'same-url';
      }

      await cache.resolve('photo', sign);
      expect(cache.consumedFailure('photo', 'same-url', 1), isFalse);
      cache.invalidate('photo', failedUrl: 'same-url', failureVersion: 1);
      expect(cache.peek('photo'), isNull);
      expect(cache.consumedFailure('photo', 'same-url', 1), isTrue);
      await cache.refresh('photo', 'same-url', sign);
      cache.invalidate('photo', failedUrl: 'same-url', failureVersion: 1);
      expect(cache.peek('photo'), 'same-url');
      expect(await cache.resolve('photo', sign), 'same-url');
      expect(calls, 2);
      cache.invalidate('photo', failedUrl: 'same-url', failureVersion: 2);
      expect(cache.peek('photo'), isNull);
      await cache.refresh('photo', 'same-url', sign, explicit: true);
      cache.invalidate('photo', failedUrl: 'same-url', failureVersion: 1);
      cache.invalidate('photo', failedUrl: 'same-url', failureVersion: 2);
      expect(cache.peek('photo'), 'same-url');
      expect(calls, 3);
      cache.clear();
      expect(cache.consumedFailure('photo', 'same-url', 2), isFalse);
    },
  );

  test('healthy metadata is reused until its bounded age expires', () async {
    var now = DateTime.utc(2026, 10, 25);
    final cache = StorageImageUrlCache(now: () => now);
    var calls = 0;
    Future<String> sign() async => 'url-${++calls}';
    expect(await cache.resolve('photo', sign), 'url-1');
    now = now.add(const Duration(minutes: 59));
    expect(await cache.resolve('photo', sign), 'url-1');
    now = now.add(const Duration(minutes: 2));
    expect(await cache.resolve('photo', sign), 'url-2');
    expect(calls, 2);
  });

  test('signed token expiry is refreshed before its deadline', () async {
    var now = DateTime.utc(2026, 10, 25);
    final cache = StorageImageUrlCache(now: () => now);
    var calls = 0;
    Future<String> sign() async {
      calls++;
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'exp':
                    now
                        .add(const Duration(minutes: 1))
                        .millisecondsSinceEpoch ~/
                    1000,
              }),
            ),
          )
          .replaceAll('=', '');
      return 'https://photo.test/object?token=e30.$payload.signature';
    }

    final first = await cache.resolve('photo', sign);
    now = now.add(const Duration(seconds: 29));
    expect(await cache.resolve('photo', sign), first);
    now = now.add(const Duration(seconds: 2));
    expect(await cache.resolve('photo', sign), isNot(first));
    expect(calls, 2);
  });

  test(
    'initial work and refreshes coalesce; late old failures retain the fresh URL',
    () async {
      final cache = StorageImageUrlCache();
      var calls = 0;
      final first = Completer<String>();
      Future<String> signFirst() {
        calls++;
        return first.future;
      }

      final a = cache.resolve('photo', signFirst);
      final b = cache.resolve('photo', signFirst);
      expect(calls, 1);
      first.complete('old');
      expect(await a, await b);
      final renewal = Completer<String>();
      Future<String> renew() {
        calls++;
        return renewal.future;
      }

      final c = cache.refresh('photo', 'old', renew);
      final d = cache.refresh('photo', 'old', renew);
      expect(calls, 2);
      renewal.complete('fresh');
      expect(await c, 'fresh');
      expect(await d, 'fresh');
      expect(await cache.refresh('photo', 'old', renew), 'fresh');
      cache.invalidate('photo', failedUrl: 'old');
      expect(cache.peek('photo'), 'fresh');
      expect(calls, 2);
    },
  );

  test(
    'late predecessor failures reuse a failed renewal until an explicit retry',
    () async {
      final cache = StorageImageUrlCache();
      var calls = 0;
      Future<String> sign() async => 'url-${++calls}';
      expect(await cache.resolve('photo', sign), 'url-1');
      cache.invalidate('photo', failedUrl: 'url-1');
      expect(await cache.refresh('photo', 'url-1', sign), 'url-2');
      cache.invalidate('photo', failedUrl: 'url-2');
      expect(cache.peek('photo'), isNull);
      expect(await cache.refresh('photo', 'url-1', sign), 'url-2');
      expect(calls, 2);
      expect(
        await cache.refresh('photo', 'url-2', sign, explicit: true),
        'url-3',
      );
      expect(calls, 3);
      cache.invalidate('photo', failedUrl: 'url-1');
      expect(cache.peek('photo'), 'url-3');
    },
  );

  test(
    'identical renewed URLs coalesce but new loads may authorize again',
    () async {
      final cache = StorageImageUrlCache();
      var calls = 0;
      Future<String> sign() async {
        calls++;
        return 'same-url';
      }

      await cache.resolve('photo', sign);
      cache.invalidate('photo', failedUrl: 'same-url');
      await cache.refresh('photo', 'same-url', sign);
      cache.invalidate('photo', failedUrl: 'same-url');
      expect(cache.peek('photo'), isNull);
      expect(await cache.refresh('photo', 'same-url', sign), 'same-url');
      expect(calls, 2);
      expect(await cache.resolve('photo', sign), 'same-url');
      expect(calls, 3);
    },
  );

  test(
    'completed LRU eviction never duplicates a still-pending request',
    () async {
      final cache = StorageImageUrlCache(capacity: 2);
      final slow = Completer<String>();
      var calls = 0;
      Future<String> sign() {
        calls++;
        return slow.future;
      }

      final waiting = cache.resolve('slow', sign);
      for (var i = 0; i < 12; i++) {
        await cache.resolve('photo-$i', () async => 'url-$i');
      }
      final returned = cache.resolve('slow', sign);
      expect(calls, 1);
      slow.complete('finished');
      expect(await waiting, await returned);
      expect(cache.peek('photo-0'), isNull);
      expect(cache.peek('slow'), 'finished');
    },
  );

  test(
    'pressure clears metadata and older completion cannot refill it',
    () async {
      final cache = StorageImageUrlCache();
      final slow = Completer<String>();
      final first = cache.resolve('photo', () => slow.future);
      cache.clear();
      final joined = cache.resolve(
        'photo',
        () async => throw StateError('duplicate'),
      );
      slow.complete('ready-for-visible-consumer');
      expect(await first, await joined);
      expect(cache.peek('photo'), isNull);
      expect(await cache.resolve('photo', () async => 'new'), 'new');
    },
  );

  test(
    'sync, async and empty signing failures permit a subsequent request',
    () async {
      final cache = StorageImageUrlCache();
      await expectLater(
        cache.resolve('photo', () => throw StateError('sync')),
        throwsStateError,
      );
      await expectLater(
        cache.resolve('photo', () async => throw StateError('async')),
        throwsStateError,
      );
      await expectLater(
        cache.resolve('photo', () async => ''),
        throwsStateError,
      );
      expect(await cache.resolve('photo', () async => 'healthy'), 'healthy');
    },
  );

  test(
    'a signing failure after its only consumer leaves has no unhandled error',
    () async {
      final cache = StorageImageUrlCache();
      final pending = Completer<String>();
      cache.resolve('photo', () => pending.future);
      pending.completeError(StateError('closed-route'));
      await Future<void>.delayed(Duration.zero);
      expect(cache.peek('photo'), isNull);
      expect(await cache.resolve('photo', () async => 'retry'), 'retry');
    },
  );
}

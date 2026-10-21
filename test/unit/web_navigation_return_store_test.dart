import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/core/navigation/web_navigation_return_store.dart';

class _BrowserStore {
  String? value;
  bool denied = false;
  bool failRemove = false;
  Completer<void>? writeBarrier;
  final events = <String>[];

  Future<String?> read() async {
    if (denied) throw StateError('storage_denied');
    return value;
  }

  Future<void> write(String next) async {
    events.add('write-start');
    if (writeBarrier != null) await writeBarrier!.future;
    if (denied) throw StateError('storage_denied');
    value = next;
    events.add('write-complete');
  }

  Future<void> remove() async {
    events.add('remove');
    if (denied || failRemove) throw StateError('storage_denied');
    value = null;
  }

  WebNavigationReturnStore bind(DateTime Function() now) =>
      WebNavigationReturnStore(
        read: read,
        write: write,
        remove: remove,
        now: now,
      );
}

void main() {
  final instant = DateTime.utc(2026, 10, 20, 3);
  const template = WebAppLocation(WebAppPage.template, '-9403');

  test(
    'guest template survives blocked storage and is consumed once',
    () async {
      final backing = _BrowserStore()..denied = true;
      final store = backing.bind(() => instant);
      await store.remember(template);
      expect(await store.take(), template);
      expect(await store.take(), isNull);
    },
  );

  test(
    'clear waits for a late save and cannot restore the old intent',
    () async {
      final backing = _BrowserStore()..writeBarrier = Completer<void>();
      final store = backing.bind(() => instant);
      final save = store.remember(template);
      await Future<void>.delayed(Duration.zero);
      expect(backing.events, ['write-start']);
      final clear = store.clear();
      final take = store.take();
      backing.writeBarrier!.complete();
      await save;
      await clear;
      expect(await take, isNull);
      expect(backing.value, isNull);
      expect(backing.events, [
        'write-start',
        'write-complete',
        'remove',
        'remove',
      ]);
    },
  );

  test('queued reads consume the intent that precedes them', () async {
    final backing = _BrowserStore();
    final store = backing.bind(() => instant);
    final firstSave = store.remember(template);
    final firstTake = store.take();
    final secondSave = store.remember(WebAppLocation.albums);
    final secondTake = store.take();
    await firstSave;
    await secondSave;
    expect(await firstTake, template);
    expect(await secondTake, WebAppLocation.albums);
  });

  test(
    'OAuth reload consumes the saved canonical path without callback data',
    () async {
      final backing = _BrowserStore();
      final beforeRedirect = backing.bind(() => instant);
      final location = WebAppLocation.parse(
        Uri.parse(
          'https://snapfit.example/designs/templates/-9403?code=private-code&email=private@example.com#access_token=private-token',
        ),
      );
      await beforeRedirect.remember(location);
      expect(
        backing.value,
        '${instant.millisecondsSinceEpoch}|/designs/templates/-9403',
      );
      final afterRedirect = backing.bind(
        () => instant.add(const Duration(minutes: 2)),
      );
      expect(await afterRedirect.take(), template);
      expect(backing.value, isNull);
      expect(await afterRedirect.take(), isNull);
    },
  );

  test(
    'the fifteen minute lifetime includes its boundary and rejects older records',
    () async {
      final backing = _BrowserStore();
      final store = backing.bind(() => instant);
      final created = instant.subtract(const Duration(minutes: 15));
      backing.value = '${created.millisecondsSinceEpoch}|/albums/42';
      expect(await store.take(), const WebAppLocation(WebAppPage.album, '42'));
      backing.value = '${created.millisecondsSinceEpoch - 1}|/albums/42';
      expect(await backing.bind(() => instant).take(), isNull);
      backing.value = '${instant.millisecondsSinceEpoch + 1}|/albums/42';
      expect(await backing.bind(() => instant).take(), isNull);
    },
  );

  test(
    'tampered or noncanonical stored paths never become return targets',
    () async {
      final stamp = instant.millisecondsSinceEpoch;
      for (final value in [
        'invalid|/albums/42',
        '$stamp|https://external.example/albums/42',
        '$stamp|/albums/42?access_token=secret',
        '$stamp|/albums/42#secret',
        '$stamp|/albums/0042',
        '$stamp|/unsupported',
        '$stamp|/login',
        '$stamp|/albums/42|extra',
      ]) {
        final backing = _BrowserStore()..value = value;
        expect(await backing.bind(() => instant).take(), isNull, reason: value);
        expect(backing.value, isNull);
      }
    },
  );

  test('a denied logout clear stays authoritative in this tab', () async {
    final backing = _BrowserStore();
    final store = backing.bind(() => instant);
    await store.remember(
      const WebAppLocation(WebAppPage.order, 'old-account-order'),
    );
    backing.failRemove = true;
    await store.clear();
    expect(backing.value, isNotNull);
    expect(await store.take(), isNull);
  });
}

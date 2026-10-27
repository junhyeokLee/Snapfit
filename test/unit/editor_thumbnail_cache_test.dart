import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_thumbnail_cache.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'slow work is bounded and shared across fast close/reopen and scrolls',
    () async {
      final dispatcher = EditorThumbnailDispatcher();
      final first = EditorThumbnailCache(dispatcher: dispatcher);
      final pending = <Completer<Uint8List?>>[];
      Future<Uint8List?> load() {
        final result = Completer<Uint8List?>();
        pending.add(result);
        return result.future;
      }

      final original = first.acquire('top', load);
      first.acquire('second', load);
      // Scrolling past 72 photos must not start native work for discarded rows.
      for (var i = 0; i < 72; i++) {
        first.acquire('off-screen-$i', load).release();
      }
      expect(pending, hasLength(2));
      first.dispose();
      final reopened = EditorThumbnailCache(dispatcher: dispatcher);
      final samePhoto = reopened.acquire('top', load);
      final next = reopened.acquire('next', load);
      expect(pending, hasLength(2));
      final bytes = Uint8List.fromList([1, 2, 3]);
      pending[0].complete(bytes);
      await _flush();
      expect(await original.future, same(bytes));
      expect(await samePhoto.future, same(bytes));
      expect(pending, hasLength(3)); // Only the new visible row starts next.
      reopened.dispose();
      pending[1].complete(null);
      pending[2].complete(null);
      await next.future;
      await _flush();
      expect(pending, hasLength(3));
    },
  );

  test(
    'completed LRU eviction cannot evict or duplicate an in-flight request',
    () async {
      final cache = EditorThumbnailCache(
        dispatcher: EditorThumbnailDispatcher(),
        maxEntries: 2,
      );
      final pending = Completer<Uint8List?>();
      var calls = 0;
      Future<Uint8List?> slow() {
        calls++;
        return pending.future;
      }

      final original = cache.acquire('slow', slow);
      for (var i = 0; i < 40; i++) {
        final lease = cache.acquire('done-$i', () async => null);
        await lease.future;
        lease.release();
      }
      final returned = cache.acquire('slow', slow);
      expect(calls, 1);
      pending.complete(Uint8List.fromList([42]));
      expect(await original.future, same(await returned.future));
      cache.dispose();
    },
  );

  test(
    'canceled queued work neither runs nor poisons later cache hits',
    () async {
      final cache = EditorThumbnailCache(
        dispatcher: EditorThumbnailDispatcher(maxConcurrent: 1),
      );
      final blocker = Completer<Uint8List?>();
      final active = cache.acquire('active', () => blocker.future);
      var calls = 0;
      Future<Uint8List?> load() async {
        calls++;
        return Uint8List.fromList([7]);
      }

      final canceled = cache.acquire('queued', load)..release();
      expect(await canceled.future, isNull);
      blocker.complete(null);
      await active.future;
      expect(calls, 0);
      expect(await cache.acquire('queued', load).future, [7]);
      expect(calls, 1);
      cache.dispose();
    },
  );

  test(
    'disposal drops queued rows and late results leave no global byte cache',
    () async {
      final dispatcher = EditorThumbnailDispatcher(maxConcurrent: 1);
      final cache = EditorThumbnailCache(dispatcher: dispatcher);
      final pending = Completer<Uint8List?>();
      final active = cache.acquire('photo', () => pending.future);
      var queuedCalls = 0;
      final queued = cache.acquire('gone', () async {
        queuedCalls++;
        return null;
      });
      cache.dispose();
      cache.dispose();
      expect(await queued.future, isNull);
      pending.complete(Uint8List.fromList([1]));
      await active.future;
      expect(queuedCalls, 0);
      final reopened = EditorThumbnailCache(dispatcher: dispatcher);
      var freshCalls = 0;
      expect(
        await reopened.acquire('photo', () async {
          freshCalls++;
          return Uint8List.fromList([2]);
        }).future,
        [2],
      );
      expect(freshCalls, 1);
      reopened.dispose();
    },
  );

  test(
    'completed entries obey recency and cache missing photos without retries',
    () async {
      final cache = EditorThumbnailCache(
        dispatcher: EditorThumbnailDispatcher(),
        maxEntries: 2,
      );
      final calls = <String>[];
      Future<void> visit(String id) async {
        final lease = cache.acquire(id, () async {
          calls.add(id);
          return null;
        });
        expect(await lease.future, isNull);
        lease.release();
      }

      await visit('a');
      await visit('b');
      await visit('a');
      await visit('c');
      await visit('a');
      await visit('b');
      expect(calls, ['a', 'b', 'c', 'b']);
      cache.dispose();
    },
  );

  test('byte budget and source pruning release completed originals', () async {
    final cache = EditorThumbnailCache(
      dispatcher: EditorThumbnailDispatcher(),
      maxBytes: 8,
    );
    final calls = <String>[];
    Future<void> visit(String id, int length) async {
      final lease = cache.acquire(id, () async {
        calls.add(id);
        return Uint8List(length);
      });
      await lease.future;
      lease.release();
    }

    await visit('a', 5);
    await visit('b', 5); // Exceeds the byte budget with only two entries.
    await visit('a', 5);
    await visit('large', 9);
    await visit('large', 9); // Oversize values are displayed but not retained.
    cache.retainOnly({'b'});
    await visit('a', 5);
    expect(calls, ['a', 'b', 'a', 'large', 'large', 'a']);
    cache.dispose();
  });

  test('sync and async photo failures release the dispatcher slot', () async {
    final cache = EditorThumbnailCache(
      dispatcher: EditorThumbnailDispatcher(maxConcurrent: 1),
    );
    expect(
      await cache.acquire('sync', () => throw StateError('gone')).future,
      isNull,
    );
    expect(
      await cache.acquire('async', () async => throw StateError('gone')).future,
      isNull,
    );
    expect(
      await cache.acquire('valid', () async => Uint8List.fromList([8])).future,
      [8],
    );
    cache.dispose();
  });
}

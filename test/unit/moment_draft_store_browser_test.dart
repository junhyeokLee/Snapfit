@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/browser_draft_database.dart';
import 'package:snap_fit/features/moments/data/moment_draft_store_base.dart';
import 'package:snap_fit/features/moments/data/moment_draft_store_web.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';

import '../helpers/moment_draft_fixtures.dart';

void main() {
  var index = 0;
  late String database;
  late BrowserMomentDraftStore store;
  setUp(() {
    database =
        'snapfit_moment_draft_test_${DateTime.now().microsecondsSinceEpoch}_${index++}';
    store = BrowserMomentDraftStore(databaseName: database);
  });

  test(
    'browser reload restores original photo bytes and immutable editing revision',
    () async {
      final saved = await store.save(
        'owner-a',
        momentDraftFixture(editing: true),
        expectedVersion: null,
      );
      final reloaded = BrowserMomentDraftStore(databaseName: database);
      final restored = (await reloaded.load('owner-a', saved.recordId))!;
      expect(
        restored.uploads.single.bytes,
        orderedEquals(saved.uploads.single.bytes),
      );
      expect(restored.originalRecord?.revision, 7);
      expect(restored.existingPhotos.single.url, isEmpty);
      expect(restored.version, saved.version);
    },
  );

  test(
    'two tabs racing one draft commit exactly one update and preserve siblings',
    () async {
      final saved = await store.save(
        'owner-a',
        momentDraftFixture(),
        expectedVersion: null,
      );
      await store.save(
        'owner-a',
        momentDraftFixture(recordId: 'sibling'),
        expectedVersion: null,
      );
      final second = BrowserMomentDraftStore(databaseName: database);
      Future<Object> write(
        BrowserMomentDraftStore writer,
        String caption,
      ) async {
        try {
          return await writer.save(
            'owner-a',
            saved.copyWith(caption: caption),
            expectedVersion: saved.version,
          );
        } catch (error) {
          return error;
        }
      }

      final outcomes = await Future.wait([
        write(store, '창 하나'),
        write(second, '창 둘'),
      ]);
      expect(outcomes.whereType<MomentDraft>().length, 1);
      expect(outcomes.whereType<MomentDraftConflictException>().length, 1);
      expect((await store.list('owner-a')).length, 2);
      expect((await store.load('owner-a', 'sibling'))?.caption, '다시 이어 쓸 순간');
    },
  );

  test(
    'different account cannot read a draft; stale tab cannot delete or recreate newer work',
    () async {
      final saved = await store.save(
        'owner-a',
        momentDraftFixture(),
        expectedVersion: null,
      );
      expect(await store.list('owner-b'), isEmpty);
      expect(await store.load('owner-b', saved.recordId), isNull);
      final next = await store.save(
        'owner-a',
        saved.copyWith(caption: '이어 쓴 기록'),
        expectedVersion: saved.version,
      );
      await expectLater(
        store.remove('owner-a', saved.recordId, expectedVersion: saved.version),
        throwsA(isA<MomentDraftConflictException>()),
      );
      await store.remove(
        'owner-a',
        saved.recordId,
        expectedVersion: next.version,
      );
      await expectLater(
        store.save('owner-a', next, expectedVersion: next.version),
        throwsA(isA<MomentDraftConflictException>()),
      );
      expect(await store.load('owner-a', saved.recordId), isNull);
    },
  );

  test(
    'summary recovery reads metadata while original-photo records stay separate',
    () async {
      final saved = await store.save(
        'owner-a',
        momentDraftFixture(),
        expectedVersion: null,
      );
      final summary = (await store.summaries('owner-a')).single;
      expect(summary.recordId, saved.recordId);
      expect(summary.version, saved.version);
      expect(summary.photoCount, 1);
      expect(summary.photoBytes, 5);
      expect(summary.hasContent, isTrue);
    },
  );

  test(
    'an uncloneable related photo write aborts its metadata index too',
    () async {
      final transport = BrowserDraftDatabase(databaseName: database);
      await expectLater(
        transport.transaction<void>(
          owner: 'atomic-owner',
          write: true,
          additionalPuts: {
            'photo-payload': _Uncloneable(callback: (() {}).toJS),
          },
          action: (_, put, __) => put(_TestValue(value: 'must-abort'.toJS)),
        ),
        throwsA(anything),
      );
      final indexAbsent = await transport.transaction<bool>(
        owner: 'atomic-owner',
        write: false,
        action: (value, _, __) => value == null,
      );
      final payloadAbsent = await transport.transaction<bool>(
        owner: 'photo-payload',
        write: false,
        action: (value, _, __) => value == null,
      );
      expect(indexAbsent, isTrue);
      expect(payloadAbsent, isTrue);
    },
  );
}

extension type _Uncloneable._(JSObject _) implements JSObject {
  external factory _Uncloneable({required JSFunction callback});
}

extension type _TestValue._(JSObject _) implements JSObject {
  external factory _TestValue({required JSString value});
}

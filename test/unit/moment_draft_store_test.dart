import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/moments/data/moment_draft_store.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';

import '../helpers/moment_draft_fixtures.dart';

void main() {
  late Directory folder;
  late LocalMomentDraftStore store;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('snapfit-moment-drafts-');
    store = LocalMomentDraftStore(directory: () async => folder);
  });
  tearDown(() async => folder.delete(recursive: true));

  test(
    'new store restores photo originals, caption/date and edit baseline without signed URL',
    () async {
      final draft = momentDraftFixture(editing: true);
      final saved = await store.save('owner-a', draft, expectedVersion: null);
      final reopened = LocalMomentDraftStore(directory: () async => folder);
      final restored = (await reopened.load('owner-a', draft.recordId))!;
      expect(restored.version, saved.version);
      expect(restored.caption, draft.caption);
      expect(restored.recordDate, draft.recordDate);
      expect(
        restored.uploads.single.bytes,
        orderedEquals(draft.uploads.single.bytes),
      );
      expect(restored.uploads.single.filename, '가을.jpg');
      expect(restored.originalRecord?.revision, 7);
      expect(restored.originalRecord?.caption, '원래 기록');
      expect(restored.existingPhotos.single.url, isEmpty);
      expect(restored.originalRecord?.photos.single.url, isEmpty);
      expect(
        () => restored.uploads.single.bytes[0] = 7,
        throwsUnsupportedError,
      );
    },
  );

  test(
    'accounts and record identities remain separate, including filesystem characters',
    () async {
      final a = momentDraftFixture(
        owner: '../owner/a',
        recordId: '../record/a',
      );
      final b = momentDraftFixture(
        owner: 'owner-b',
        recordId: '../record/a',
        caption: '다른 계정',
      );
      await store.save(a.ownerId, a, expectedVersion: null);
      await store.save(b.ownerId, b, expectedVersion: null);
      expect((await store.load(a.ownerId, a.recordId))?.caption, a.caption);
      expect((await store.load(b.ownerId, b.recordId))?.caption, b.caption);
      await expectLater(
        Future.sync(() => store.save('owner-b', a, expectedVersion: null)),
        throwsA(isA<MomentDraftException>()),
      );
    },
  );

  test(
    'list preserves sibling drafts and latestNew skips edited records',
    () async {
      final first = momentDraftFixture(recordId: 'first');
      final next = momentDraftFixture(
        recordId: 'next',
        updatedAt: DateTime.utc(2026, 10, 27),
      );
      final edit = momentDraftFixture(
        recordId: 'edit',
        editing: true,
        updatedAt: DateTime.utc(2026, 10, 28),
      );
      for (final draft in [first, edit, next]) {
        await store.save('owner-a', draft, expectedVersion: null);
      }
      expect((await store.list('owner-a')).map((draft) => draft.recordId), [
        'edit',
        'next',
        'first',
      ]);
      expect((await store.latestNew('owner-a'))?.recordId, 'next');
    },
  );

  test('simultaneous editors cannot replace a newer draft', () async {
    final saved = await store.save(
      'owner-a',
      momentDraftFixture(),
      expectedVersion: null,
    );
    final other = LocalMomentDraftStore(directory: () async => folder);
    Future<Object> trySave(LocalMomentDraftStore writer, String caption) async {
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
      trySave(store, '첫 번째 창'),
      trySave(other, '두 번째 창'),
    ]);
    expect(outcomes.whereType<MomentDraft>().length, 1);
    expect(outcomes.whereType<MomentDraftConflictException>().length, 1);
    expect(
      (await store.load('owner-a', saved.recordId))?.caption,
      outcomes.whereType<MomentDraft>().single.caption,
    );
  });

  test(
    'stale deletion preserves newer work; stale save cannot recreate deleted draft',
    () async {
      final saved = await store.save(
        'owner-a',
        momentDraftFixture(),
        expectedVersion: null,
      );
      final next = await store.save(
        'owner-a',
        saved.copyWith(caption: '새로운 글'),
        expectedVersion: saved.version,
      );
      await expectLater(
        store.remove('owner-a', saved.recordId, expectedVersion: saved.version),
        throwsA(isA<MomentDraftConflictException>()),
      );
      expect((await store.load('owner-a', saved.recordId))?.caption, '새로운 글');
      expect(
        await store.remove(
          'owner-a',
          saved.recordId,
          expectedVersion: next.version,
        ),
        isTrue,
      );
      await expectLater(
        store.save('owner-a', next, expectedVersion: next.version),
        throwsA(isA<MomentDraftConflictException>()),
      );
      expect(await store.load('owner-a', saved.recordId), isNull);
      expect(
        await store.remove(
          'owner-a',
          saved.recordId,
          expectedVersion: next.version,
        ),
        isFalse,
      );
    },
  );

  test(
    'incomplete file is reported and preserved instead of appearing empty',
    () async {
      final saved = await store.save(
        'owner-a',
        momentDraftFixture(),
        expectedVersion: null,
      );
      final ownerKey = base64Url.encode(utf8.encode('owner-a'));
      final recordKey = base64Url.encode(utf8.encode(saved.recordId));
      final file = File(
        '${folder.path}/moment_drafts/$ownerKey/$recordKey.draft',
      );
      final bytes = await file.readAsBytes();
      await file.writeAsBytes(bytes.take(bytes.length - 1).toList());
      await expectLater(
        store.load('owner-a', saved.recordId),
        throwsA(isA<MomentDraftException>()),
      );
      expect(await file.exists(), isTrue);
      expect(await file.length(), bytes.length - 1);
    },
  );

  test('invalid photo write leaves previous durable draft intact', () async {
    final saved = await store.save(
      'owner-a',
      momentDraftFixture(),
      expectedVersion: null,
    );
    final invalid = saved.copyWith(
      uploads: [
        MomentDraftUpload(
          id: 'bad',
          filename: 'empty.jpg',
          bytes: Uint8List(0),
        ),
      ],
    );
    await expectLater(
      Future.sync(
        () => store.save('owner-a', invalid, expectedVersion: saved.version),
      ),
      throwsA(isA<MomentDraftException>()),
    );
    expect(
      (await store.load('owner-a', saved.recordId))?.version,
      saved.version,
    );
    expect(
      (await store.load('owner-a', saved.recordId))?.uploads.single.bytes,
      isNotEmpty,
    );
  });

  test('upload snapshot never changes when picker buffer is reused', () {
    final source = Uint8List.fromList([1, 2, 3]);
    final photo = MomentDraftUpload(
      id: 'photo',
      filename: 'photo.jpg',
      bytes: source,
    );
    source[0] = 99;
    expect(photo.bytes, orderedEquals([1, 2, 3]));
  });

  test(
    'summary recovery lists metadata without exposing photo originals',
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
      expect(await store.summaries('owner-b'), isEmpty);
    },
  );

  test(
    'draft limit never evicts earlier work and still allows updating an existing draft',
    () async {
      MomentDraft? first;
      for (var index = 0; index < momentDraftMaximumDrafts; index++) {
        final saved = await store.save(
          'owner-a',
          momentDraftFixture(recordId: 'record-$index'),
          expectedVersion: null,
        );
        first ??= saved;
      }
      await expectLater(
        store.save(
          'owner-a',
          momentDraftFixture(recordId: 'too-many'),
          expectedVersion: null,
        ),
        throwsA(isA<MomentDraftException>()),
      );
      expect(
        (await store.summaries('owner-a')).length,
        momentDraftMaximumDrafts,
      );
      expect(await store.load('owner-a', 'too-many'), isNull);
      final updated = await store.save(
        'owner-a',
        first!.copyWith(caption: '계속 작성'),
        expectedVersion: first.version,
      );
      expect(
        (await store.load('owner-a', first.recordId))?.version,
        updated.version,
      );
      expect(
        (await store.summaries('owner-a')).length,
        momentDraftMaximumDrafts,
      );
    },
  );
}

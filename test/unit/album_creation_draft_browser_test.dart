import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_attempt.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:uuid/uuid.dart';

import '../helpers/legacy_browser_creation_fixture_stub.dart'
    if (dart.library.js_interop) '../helpers/legacy_browser_creation_fixture_web.dart';

AlbumCreationDraft _draft(
  String owner,
  String id, {
  String title = '내 앨범',
  String? requestId,
}) => AlbumCreationDraft(
  id: id,
  updatedAt: DateTime.utc(2026, 10, 29),
  title: title,
  cover: defaultCoverSize,
  pageCount: 20,
  step: 1,
  showPhotoFill: false,
  hasSelectedMode: true,
  sourceLabel: '직접 만들기',
  usesPhysicalCanvas: true,
  preserveTypography: true,
  creationAttempt: AlbumCreationAttempt(
    ownerId: owner,
    draftId: id,
    requestId: requestId ?? const Uuid().v4(),
    seed: const CreateAlbumRequest(
      ratio: '1.0',
      title: '최초 제목',
      coverLayersJson: '{"layers":[]}',
      coverImageUrl: '',
      coverThumbnailUrl: '',
    ),
  ),
);

Future<void> _begin(
  AlbumCreationDraftStore store,
  String owner,
  String id, {
  AlbumCreationDraft? restoring,
}) => (store as AlbumCreationDraftWriteSession).beginDraftWriteSession(
  owner,
  id,
  restoring: restoring,
);

void main() {
  test(
    'existing version-1 browser draft without a creation command still resumes',
    () async {
      final owner = const Uuid().v4(), id = const Uuid().v4();
      final metadata = _draft(owner, id).toJson()..remove('creationAttempt');
      await writeLegacyBrowserCreationDraft(owner, metadata);
      final store = createAlbumCreationDraftStore();
      final restored = (await store.load(owner))!;
      expect(restored.creationAttempt, isNull);
      await _begin(store, owner, id, restoring: restored);
      await store.save(
        owner,
        AlbumCreationDraft.fromJson(
          restored.toJson()..['title'] = '이전 초안을 이어 만들기',
        ),
      );
      expect((await store.load(owner))!.title, '이전 초안을 이어 만들기');
      await store.remove(owner, id);
    },
    skip: !kIsWeb,
  );

  test(
    'browser draft atomically retains a creation command across reopen and title edits',
    () async {
      final owner = const Uuid().v4(), id = const Uuid().v4();
      final first = createAlbumCreationDraftStore();
      final original = _draft(owner, id);
      await _begin(first, owner, id);
      await first.save(owner, original);
      final reopened = createAlbumCreationDraftStore();
      final restored = (await reopened.load(owner))!;
      expect(
        restored.creationAttempt!.toJson(),
        original.creationAttempt!.toJson(),
      );
      await _begin(reopened, owner, id, restoring: restored);
      await reopened.save(
        owner,
        AlbumCreationDraft.fromJson(restored.toJson()..['title'] = '바뀐 제목'),
      );
      final latest = (await reopened.load(owner))!;
      expect(latest.title, '바뀐 제목');
      expect(latest.creationAttempt!.seed.title, '최초 제목');
      expect(
        latest.creationAttempt!.requestId,
        original.creationAttempt!.requestId,
      );
      await reopened.remove(owner, id);
    },
    skip: !kIsWeb,
  );

  test(
    'browser competing first writes permit only one durable creation key',
    () async {
      final owner = const Uuid().v4(), id = const Uuid().v4();
      final first = createAlbumCreationDraftStore();
      final second = createAlbumCreationDraftStore();
      await _begin(first, owner, id);
      await _begin(second, owner, id);
      final a = _draft(owner, id), b = _draft(owner, id, title: '다른 창');
      final results = await Future.wait([
        first.save(owner, a).then((_) => true, onError: (_) => false),
        second.save(owner, b).then((_) => true, onError: (_) => false),
      ]);
      expect(results.where((value) => value), hasLength(1));
      final reopened = createAlbumCreationDraftStore();
      final winner = (await reopened.load(owner))!;
      expect(
        winner.creationAttempt!.requestId,
        anyOf(a.creationAttempt!.requestId, b.creationAttempt!.requestId),
      );
      await _begin(reopened, owner, id, restoring: winner);
      await reopened.remove(owner, id);
    },
    skip: !kIsWeb,
  );

  test(
    'same-millisecond different document cannot be removed by a stale browser tab',
    () async {
      final owner = const Uuid().v4(), id = const Uuid().v4();
      final first = createAlbumCreationDraftStore();
      final original = _draft(owner, id);
      await _begin(first, owner, id);
      await first.save(owner, original);
      final second = createAlbumCreationDraftStore();
      await _begin(second, owner, id, restoring: original);
      final edited = AlbumCreationDraft.fromJson(
        original.toJson()..['title'] = '나중에 편집한 내용',
      );
      await second.save(owner, edited);
      await expectLater(first.remove(owner, id), throwsA(anything));
      await expectLater(first.save(owner, original), throwsA(anything));
      expect((await second.load(owner))!.title, edited.title);
      await second.remove(owner, id);
    },
    skip: !kIsWeb,
  );
}

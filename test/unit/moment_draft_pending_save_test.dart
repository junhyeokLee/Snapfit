import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/moments/data/moment_draft_store.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';

import '../helpers/moment_draft_fixtures.dart';

void main() {
  test('legacy draft has no pending save reconciliation privilege', () {
    final draft = momentDraftFixture();
    final restored = MomentDraft.fromMetadata(
      draft.toMetadata(),
      photoBytes: draft.uploads.map((upload) => upload.bytes).toList(),
    );
    expect(restored.pendingSaveFingerprint, isNull);
    expect(restored.hasPendingSave, isFalse);
  });

  for (final editing in [false, true]) {
    test(
      'pending ${editing ? 'edited' : 'new'} payload survives store restart',
      () async {
        final folder = await Directory.systemTemp.createTemp('moment-pending-');
        try {
          final draft = momentDraftFixture(editing: editing);
          final pending = draft.copyWith(
            pendingSaveFingerprint: draft.saveFingerprint,
          );
          final first = LocalMomentDraftStore(directory: () async => folder);
          await first.save(draft.ownerId, pending, expectedVersion: null);
          final reopened = LocalMomentDraftStore(directory: () async => folder);
          final restored = (await reopened.load(
            draft.ownerId,
            draft.recordId,
          ))!;
          expect(restored.hasPendingSave, isTrue);
          expect(restored.pendingSaveFingerprint, pending.saveFingerprint);
          expect(
            restored.originalRecord?.revision,
            draft.originalRecord?.revision,
          );
        } finally {
          await folder.delete(recursive: true);
        }
      },
    );
  }

  test('changing caption or photo bytes invalidates a pending payload', () {
    final draft = momentDraftFixture();
    final pending = draft.copyWith(
      pendingSaveFingerprint: draft.saveFingerprint,
    );
    expect(pending.copyWith(caption: '다르게 쓴 글').hasPendingSave, isFalse);
    expect(
      pending
          .copyWith(
            uploads: [
              MomentDraftUpload(
                id: draft.uploads.single.id,
                filename: '바뀐 사진',
                bytes: Uint8List.fromList([1, 2, 3]),
              ),
            ],
            pendingSaveFingerprint: draft.saveFingerprint,
          )
          .hasPendingSave,
      isFalse,
    );
    expect(pending.copyWith(version: 'next-version').hasPendingSave, isTrue);
  });
}

import 'dart:typed_data';

import 'package:snap_fit/features/moments/domain/moment_draft.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';

MomentDraft momentDraftFixture({
  String owner = 'owner-a',
  String recordId = 'new-record',
  String caption = '다시 이어 쓸 순간',
  DateTime? updatedAt,
  bool editing = false,
}) {
  const existing = MomentPhoto(
    id: 'old-photo',
    path: 'owner-a/moments/original.jpg',
    url: 'https://private.test/photo?token=short-lived',
    width: 200,
    height: 300,
  );
  return MomentDraft(
    ownerId: owner,
    recordId: recordId,
    recordDate: DateTime.utc(2026, 10, 25),
    caption: caption,
    existingPhotos: editing ? [existing] : [],
    uploads: [
      MomentDraftUpload(
        id: 'new-photo',
        filename: '가을.jpg',
        bytes: Uint8List.fromList([0, 255, 4, 9, 1]),
      ),
    ],
    updatedAt: updatedAt ?? DateTime.utc(2026, 10, 26, 1),
    originalRecord: editing
        ? MomentRecord(
            id: recordId,
            recordDate: DateTime.utc(2026, 10, 24),
            caption: '원래 기록',
            photos: [existing],
            revision: 7,
          )
        : null,
  );
}

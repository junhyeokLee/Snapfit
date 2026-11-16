import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/moments/data/moment_draft_index.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';

import '../helpers/moment_draft_fixtures.dart';

void main() {
  test(
    'ten heavily decorated draft summaries fit the browser index while full drafts preserve every design',
    () {
      final design = MomentPhotoDesign.fromJson({
        'version': 1,
        'canvas': {'width': 500, 'height': 400},
        'backgroundColor': '#ffffffff',
        'layers': [
          {
            'id': 'photo',
            'type': 'IMAGE',
            'x': 0,
            'y': 0,
            'width': 1,
            'height': 1,
            'rotation': 0,
            'payload': {'originalUrl': momentPhotoOriginalSource},
          },
          for (var i = 0; i < 38; i++)
            {
              'id': 'text-$i',
              'type': 'TEXT',
              'x': 0,
              'y': 0,
              'width': 1,
              'height': .2,
              'rotation': 0,
              'payload': {'text': 'a' * 3000},
            },
        ],
      });
      final draft = momentDraftFixture(editing: true);
      final full = draft.toMetadata();
      full['version'] = 'saved-version';
      full['existingPhotos'][0]['design'] = design.toJson();
      full['uploads'][0]['design'] = design.toJson();
      full['originalRecord']['photos'][0]['design'] = design.toJson();
      final originalJson = jsonEncode(full);
      expect(
        utf8.encode(jsonEncode(List.filled(10, full))).length,
        greaterThan(1024 * 1024),
      );
      final compact = momentDraftIndexMetadata(full);
      expect(
        utf8.encode(jsonEncode(List.filled(10, compact))).length,
        lessThan(1024 * 1024),
      );
      expect(jsonEncode(compact), isNot(contains('"layers"')));
      expect(jsonEncode(full), originalJson);
      expect(momentDraftIndexMetadata(compact), compact);
      final summary = MomentDraftSummary.fromMetadata(compact);
      final completeSummary = MomentDraftSummary.fromMetadata(full);
      expect(summary.recordId, completeSummary.recordId);
      expect(summary.photoCount, completeSummary.photoCount);
      expect(summary.photoBytes, completeSummary.photoBytes);
      expect(summary.version, completeSummary.version);
      expect(summary.isEditing, isTrue);
      final restored = MomentDraft.fromMetadata(
        full,
        photoBytes: [draft.uploads.single.bytes],
      );
      expect(restored.existingPhotos.single.design!.toJson(), design.toJson());
      expect(restored.uploads.single.design!.toJson(), design.toJson());
      expect(
        restored.originalRecord!.photos.single.design!.toJson(),
        design.toJson(),
      );
    },
  );
}

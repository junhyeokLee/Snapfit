import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';

import 'album_creation_draft_test.dart' show creationDraftFixture;

AlbumCreationEditorCheckpoint _checkpoint(AlbumCreationDraft source) =>
    AlbumCreationEditorCheckpoint(
      pages: [
        for (var page = 0; page < source.pages!.length; page++)
          AlbumPage(
            id: 'page-$page',
            pageIndex: page,
            isCover: page == 0,
            layers: source.pages![page],
            backgroundColor: page == 0 ? 0xFFE3EEDC : null,
          ),
      ],
      pageIndex: 1,
      coverCanvas: const Size(500, 375),
      innerCanvas: const Size(500, 375),
      theme: CoverTheme.nature1,
      sourceTemplateProductKey: source.sourceTemplateProductKey,
    );

AlbumCreationDraft _roundtrip(AlbumCreationDraft source) =>
    AlbumCreationDraft.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );

void main() {
  test('checkpoint persists only the explicitly replaced remaining queue', () {
    final source = creationDraftFixture(
      sourceTemplateProductKey: 'template:summer-memory',
    );
    final leftover = AssetEntity(
      id: 'remaining-photo',
      typeInt: 1,
      width: 1800,
      height: 2400,
    );
    final queue = <AssetEntity>[leftover];
    final checkpoint = _checkpoint(source);
    final saved = source.withEditorCheckpoint(
      checkpoint,
      cover: source.cover,
      pendingPhotos: queue,
      selectedPhotoId: leftover.id,
      currentPage: 0,
    );
    // Later workspace edits must not change the checkpoint waiting to be saved.
    queue.clear();
    expect(saved.pendingPhotos, hasLength(1));
    expect(saved.pendingPhotos.single, same(leftover));
    expect(source.pendingPhotos.single.id, 'local-photo-1');

    final restored = _roundtrip(saved);
    expect(restored.pendingPhotos.map((photo) => photo.id), [
      'remaining-photo',
    ]);
    expect(restored.pendingPhotos.single.width, 1800);
    expect(restored.pendingPhotos.single.height, 2400);
    expect(restored.selectedPhotoId, 'remaining-photo');
    expect(restored.selectedSlot, isNull);
    expect(restored.currentPage, 0);
    expect(
      restored.editorCheckpoint!.pages.first.layers.first.asset!.id,
      'local-photo-1',
    );
    expect(restored.editorCheckpoint!.pages.first.backgroundColor, 0xFFE3EEDC);
    expect(restored.sourceTemplateProductKey, source.sourceTemplateProductKey);
    expect(
      restored.editorCheckpoint!.sourceTemplateProductKey,
      source.sourceTemplateProductKey,
    );
    expect(restored.title, source.title);
    expect(restored.cover.productId, source.cover.productId);
    expect(saved.pages, same(source.pages));
    expect(saved.basePages, same(source.basePages));
    expect(saved.variants, same(source.variants));
  });

  test(
    'an explicitly empty queue clears the saved photo and slot selection',
    () {
      final source = creationDraftFixture();
      final saved = source.withEditorCheckpoint(
        _checkpoint(source),
        cover: source.cover,
        pendingPhotos: const [],
      );
      final restored = _roundtrip(saved);
      expect(restored.pendingPhotos, isEmpty);
      expect(restored.selectedPhotoId, isNull);
      expect(restored.selectedSlot, isNull);
      expect(restored.currentPage, source.currentPage);
      expect(source.pendingPhotos, hasLength(1));
      expect(source.selectedPhotoId, isNotNull);
      expect(source.selectedSlot, isNotNull);
    },
  );

  test(
    'default checkpoint calls preserve the previous queue and selection',
    () {
      final source = creationDraftFixture();
      final saved = source.withEditorCheckpoint(
        _checkpoint(source),
        cover: source.cover,
      );
      final restored = _roundtrip(saved);
      expect(saved.pendingPhotos, same(source.pendingPhotos));
      expect(
        restored.pendingPhotos.map((photo) => photo.id),
        source.pendingPhotos.map((photo) => photo.id),
      );
      expect(restored.selectedPhotoId, source.selectedPhotoId);
      expect(restored.selectedSlot, source.selectedSlot);
      expect(restored.currentPage, source.currentPage);
    },
  );
}

import 'dart:async';
import 'dart:io' show FileSystemException;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';

AlbumCreationDraft creationDraftFixture({
  String id = 'draft-a',
  String title = '여행의 조각',
  List<List<LayerModel>>? pages,
  int step = 1,
  bool showPhotoFill = true,
}) {
  final photo = AssetEntity(
    id: 'local-photo-1',
    typeInt: 1,
    width: 2400,
    height: 1600,
  );
  final content =
      pages ??
      [
        [
          LayerModel(
            id: 'photo',
            type: LayerType.image,
            position: const Offset(24, 42),
            width: 300,
            height: 210,
            asset: photo,
            imageOffset: const Offset(12, -16),
            imageZoom: 1.7,
            imageBackground: 'archSoft',
            frameBaseWidth: 290,
            frameBaseHeight: 200,
            frameBasePosition: const Offset(22, 40),
            zIndex: 2,
          ),
          LayerModel(
            id: 'title',
            type: LayerType.text,
            position: const Offset(40, 310),
            width: 210,
            height: 40,
            text: '우리의 여름',
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontFamily: 'Pretendard',
              color: Colors.teal,
            ),
            textBackground: 'tag',
            textAlign: TextAlign.center,
          ),
        ],
        [
          LayerModel(
            id: 'empty',
            type: LayerType.image,
            position: const Offset(24, 42),
            width: 300,
            height: 210,
          ),
        ],
      ];
  return AlbumCreationDraft(
    id: id,
    updatedAt: DateTime.utc(2026, 10, 8, 9),
    title: title,
    cover: coverSizes[1].withCoverType(PrintCoverType.hard),
    pageCount: 24,
    step: step,
    showPhotoFill: showPhotoFill,
    hasSelectedMode: true,
    sourceLabel: '선택한 템플릿',
    usesPhysicalCanvas: true,
    preserveTypography: true,
    pages: content,
    basePages: content,
    variants: {'landscape': content},
    canvasSizes: {'landscape': const Size(500, 375)},
    baseCanvasSize: const Size(500, 375),
    templateTitle: '여름 여행',
    currentPage: 1,
    pendingPhotos: [photo],
    selectedPhotoId: photo.id,
    selectedSlot: (page: 1, id: 'empty'),
    editedCover: content.first,
    editedCoverCanvasSize: const Size(500, 375),
  );
}

class MemoryCreationDraftStore implements AlbumCreationDraftStore {
  AlbumCreationDraft? draft;
  bool failSave = false;
  bool failRemove = false;
  int writes = 0;
  Completer<void>? saving;
  @override
  Future<AlbumCreationDraft?> load(String owner) async => draft;
  @override
  Future<void> save(String owner, AlbumCreationDraft value) async {
    if (saving != null) await saving!.future;
    if (failSave) throw FileSystemException('Disk full');
    writes++;
    draft = value;
  }

  @override
  Future<void> remove(String owner, String id) async {
    if (failRemove) throw FileSystemException('Disk unavailable');
    if (draft?.id == id) draft = null;
  }

  @override
  Future<bool> updateLinked(
    String owner,
    String id,
    int albumId,
    AlbumCreationDraft Function(AlbumCreationDraft) update,
  ) async {
    if (saving != null) await saving!.future;
    if (failSave) throw FileSystemException('Disk full');
    final current = draft;
    if (current == null ||
        current.id != id ||
        current.createdAlbumId != albumId)
      return false;
    writes++;
    draft = update(current);
    return true;
  }
}

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel(this.user);
  final UserInfo? user;
  @override
  Future<UserInfo?> build() => Future.value(user);
}

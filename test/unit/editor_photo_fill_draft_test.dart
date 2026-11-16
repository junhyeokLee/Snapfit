import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_plan.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import '../helpers/mock_repositories.dart';
import 'album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

const _ownerId = 'photo-fill-owner';
const _sourceProduct = 'template:-9531';
const _canvas = Size(500, 500);
const _backgrounds = [0xFFFFF5E8, 0xFFE9F5EE, 0xFFEDF1FA];

class _Owner {
  String? value = _ownerId;
}

class _Photo extends Mock implements AssetEntity {}

AssetEntity _photo(int index) {
  final photo = _Photo();
  when(() => photo.id).thenReturn('new-photo-$index');
  return photo;
}

LayerModel _slot(int index) => LayerModel(
  id: 'photo-slot-$index',
  type: LayerType.image,
  position: const Offset(30, 40),
  width: 210,
  height: 260,
  imageBackground: 'polaroid',
  rotation: .1,
);

LayerModel _caption(int index) => LayerModel(
  id: 'caption-$index',
  type: LayerType.text,
  position: const Offset(32, 330),
  width: 240,
  height: 70,
  text: '원래 기록 $index',
  textStyle: const TextStyle(fontSize: 14),
);

String _document() => jsonEncode({
  'printProduct': {
    'id': 'REDP_200_HARD',
    'trimWidthMm': 200,
    'trimHeightMm': 200,
  },
  'sourceTemplate': {'productKey': _sourceProduct},
  'pages': [
    for (var page = 0; page < 3; page++)
      {
        'index': page,
        'isCover': page == 0,
        'backgroundColor': _backgrounds[page],
        'layers': [
          for (final layer in [_slot(page), _caption(page)])
            LayerExportMapper.toJson(
              layer,
              canvasSize: _canvas,
              isCover: page == 0,
            ),
        ],
      },
  ],
});

Future<({ProviderContainer container, AlbumEditorViewModel vm, _Owner owner})>
_boot({String role = 'OWNER'}) async {
  final owner = _Owner();
  final container = ProviderContainer(
    overrides: [
      albumEditorOwnerReaderProvider.overrideWithValue(() => owner.value),
      albumEditorOwnerChangesProvider.overrideWith((_) => const Stream.empty()),
      albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(albumEditorViewModelProvider.future);
  final vm = container.read(albumEditorViewModelProvider.notifier);
  await vm.prepareAlbumForEdit(
    Album(
      id: 17,
      userId: _ownerId,
      memberRole: role,
      title: '사진 채우기 원본',
      ratio: '1.0',
      targetPages: 2,
      coverLayersJson: _document(),
      updatedAt: '2026-11-11T00:00:00Z',
    ),
  );
  vm.loadPendingEditAlbumIfNeeded(_canvas);
  return (container: container, vm: vm, owner: owner);
}

void _expectMetadata(AlbumEditorViewModel vm) {
  final document = jsonDecode(vm.exportFullAlbumLayersJson(null)) as Map;
  expect(vm.pages, hasLength(3));
  expect(vm.pages.map((page) => page.backgroundColor), _backgrounds);
  expect(document['sourceTemplate'], {'productKey': _sourceProduct});
  expect(document['printProduct'], {
    'id': 'REDP_200_HARD',
    'trimWidthMm': 200,
    'trimHeightMm': 200,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'discarding a staged photo edit leaves the full document untouched',
    () async {
      final fixture = await _boot();
      final vm = fixture.vm;
      final before = vm.exportFullAlbumLayersJson(null);
      final draft = vm.beginPhotoFill()!;
      final staged = [
        for (final page in draft.pages) List<LayerModel>.of(page),
      ];
      staged[1][0] = staged[1][0].copyWith(asset: _photo(1));
      staged[0].clear();
      staged.removeLast();

      // Closing the workspace without apply must not need a rollback in the VM.
      expect(vm.exportFullAlbumLayersJson(null), before);
      expect(vm.pages[1].layers.first.asset, isNull);
      expect(
        fixture.container
            .read(albumEditorViewModelProvider)
            .requireValue
            .canUndo,
        isFalse,
      );
      expect(vm.isPhotoFillCurrent(draft), isTrue);
      _expectMetadata(vm);
    },
  );

  test(
    'apply keeps three pages and each changed page gains one undo entry',
    () async {
      final fixture = await _boot();
      final vm = fixture.vm;
      final pageIds = vm.pages.map((page) => page.id).toList();
      vm.goToPage(1);
      vm.updatePageLayers([
        vm.layers.first,
        vm.layers.last.copyWith(text: '사진보다 먼저 편집한 기록'),
      ]);
      final draft = vm.beginPhotoFill()!;
      final photos = [for (var index = 0; index < 3; index++) _photo(index)];
      final staged = TemplatePhotoFillPlan.create(
        pages: draft.pages,
        photos: photos,
      ).buildPages();

      expect(vm.applyPhotoFill(draft, staged), isTrue);
      expect(vm.currentPageIndex, 1);
      expect(vm.pages.map((page) => page.id), pageIds);
      for (var page = 0; page < 3; page++) {
        expect(vm.pages[page].layers.first.asset, same(photos[page]));
        expect(vm.pages[page].layers.first.imageBackground, 'polaroid');
      }
      expect(vm.pages[1].layers.last.text, '사진보다 먼저 편집한 기록');
      _expectMetadata(vm);

      for (final page in [0, 2, 1]) {
        vm.goToPage(page);
        vm.undo();
        expect(vm.currentPage!.layers.first.asset, isNull);
        expect(
          vm.currentPage!.layers.last.text,
          page == 1 ? '사진보다 먼저 편집한 기록' : '원래 기록 $page',
        );
        expect(
          fixture.container
              .read(albumEditorViewModelProvider)
              .requireValue
              .canUndo,
          page == 1,
        );
      }
      // A second undo on page 1 still reaches its pre-existing text edit.
      vm.undo();
      expect(vm.currentPage!.layers.last.text, '원래 기록 1');
      _expectMetadata(vm);
    },
  );

  for (final change in ['owner', 'session', 'document', 'cover', 'access']) {
    test('a stale $change cannot accept staged photo results', () async {
      final fixture = await _boot();
      final vm = fixture.vm;
      final draft = vm.beginPhotoFill()!;
      final staged = TemplatePhotoFillPlan.create(
        pages: draft.pages,
        photos: [_photo(0)],
      ).buildPages();
      switch (change) {
        case 'owner':
          // Exercise the live owner guard before an auth stream event arrives.
          fixture.owner.value = 'different-owner';
        case 'session':
          vm.resetForCreate();
        case 'document':
          vm.updatePageLayers([
            vm.layers.first,
            vm.layers.last.copyWith(text: '사진 선택 중 새로 쓴 기록'),
          ]);
        case 'cover':
          vm.selectCover(coverSizes[3]);
        case 'access':
          fixture.container
              .read(albumEditSyncStatusProvider.notifier)
              .update(17, AlbumEditSyncKind.accessRevoked);
      }
      final current = vm.exportFullAlbumLayersJson(null);
      expect(vm.isPhotoFillCurrent(draft), isFalse);
      expect(vm.applyPhotoFill(draft, staged), isFalse);
      expect(vm.exportFullAlbumLayersJson(null), current);
    });
  }

  test('view-only documents cannot start a photo workspace', () async {
    final fixture = await _boot(role: 'VIEWER');
    expect(fixture.vm.beginPhotoFill(), isNull);
  });

  test('a missing live owner cannot start a photo workspace', () async {
    final fixture = await _boot();
    fixture.owner.value = null;
    expect(fixture.vm.beginPhotoFill(), isNull);
  });
}

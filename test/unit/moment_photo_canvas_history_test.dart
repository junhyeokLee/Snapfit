import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_format.dart';

import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';
import 'album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

Future<ProviderContainer> _scope() async {
  final scope = ProviderContainer(
    overrides: [
      albumEditorOwnerReaderProvider.overrideWithValue(() => 'owner'),
      albumEditorOwnerChangesProvider.overrideWith((_) => const Stream.empty()),
      albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
    ],
  );
  addTearDown(scope.dispose);
  await scope.read(albumEditorViewModelProvider.future);
  return scope;
}

MomentPhotoDesign _current(AlbumEditorViewModel vm, Size canvas) =>
    MomentPhotoDesign.fromLayers(
      canvasSize: canvas,
      backgroundColor: Colors.white,
      layers: vm.layers,
      photoSource: momentPhotoOriginalSource,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local photo canvas and edited crop undo together through format changes',
    () async {
      final scope = await _scope();
      final vm = scope.read(albumEditorViewModelProvider.notifier);
      final base = newMomentPhotoDesign(photoSize: const Size(100, 200));
      final canvas = base.canvasSize;
      vm.startSinglePageDraft(
        canvasSize: canvas,
        layers: base.layersForPhoto(momentPhotoOriginalSource),
      );
      vm.updateLayer(
        vm.layers.single.copyWith(
          imageZoom: 1.7,
          imageOffset: const Offset(11, -8),
        ),
      );
      final cropped = _current(vm, canvas).toJson();
      vm.addTextLayer(
        '그대로 남기는 한 줄',
        canvasSize: canvas,
        style: const TextStyle(fontSize: 20),
        mode: TextStyleType.none,
      );
      final withText = _current(vm, canvas).toJson();
      final resized = resizeMomentPhotoDesign(
        _current(vm, canvas),
        coverSizes[1],
      );
      expect(
        vm.resizeSinglePageDraft(
          layers: resized.layersForPhoto(momentPhotoOriginalSource),
          canvasSize: resized.canvasSize,
        ),
        isTrue,
      );
      vm.undo();
      expect(
        scope.read(albumEditorViewModelProvider).value!.coverCanvasSize,
        canvas,
      );
      expect(_current(vm, canvas).toJson(), withText);
      vm.undo();
      expect(_current(vm, canvas).toJson(), cropped);
      vm.redo();
      expect(_current(vm, canvas).toJson(), withText);
      vm.redo();
      final state = scope.read(albumEditorViewModelProvider).value!;
      expect(state.coverCanvasSize, resized.canvasSize);
      expect(state.innerCanvasSize, resized.canvasSize);
      expect(state.selectedCover.ratio, closeTo(4 / 3, .00001));
      expect(vm.layers.first.imageZoom, 1.7);
    },
  );

  test(
    'canvas history survives its cap and discards a branched format redo',
    () async {
      final scope = await _scope();
      final vm = scope.read(albumEditorViewModelProvider.notifier);
      final base = newMomentPhotoDesign(photoSize: const Size(120, 80));
      vm.startSinglePageDraft(
        canvasSize: base.canvasSize,
        layers: base.layersForPhoto(momentPhotoOriginalSource),
      );
      for (var i = 0; i < 36; i++) {
        vm.updateLayer(vm.layers.single.copyWith(opacity: .2 + i / 100));
      }
      final first = resizeMomentPhotoDesign(
        _current(vm, base.canvasSize),
        coverSizes[2],
      );
      vm.resizeSinglePageDraft(
        layers: first.layersForPhoto(momentPhotoOriginalSource),
        canvasSize: first.canvasSize,
      );
      vm.undo();
      vm.updateLayer(vm.layers.single.copyWith(imageZoom: 1.4));
      expect(scope.read(albumEditorViewModelProvider).value!.canRedo, isFalse);
      vm.redo();
      expect(
        scope.read(albumEditorViewModelProvider).value!.coverCanvasSize,
        base.canvasSize,
      );
      final second = resizeMomentPhotoDesign(
        _current(vm, base.canvasSize),
        coverSizes[4],
      );
      vm.resizeSinglePageDraft(
        layers: second.layersForPhoto(momentPhotoOriginalSource),
        canvasSize: second.canvasSize,
      );
      vm.undo();
      expect(
        scope.read(albumEditorViewModelProvider).value!.coverCanvasSize,
        base.canvasSize,
      );
      expect(vm.layers.single.imageZoom, 1.4);
      vm.redo();
      expect(
        scope.read(albumEditorViewModelProvider).value!.coverCanvasSize,
        second.canvasSize,
      );
    },
  );

  test(
    'equal local layers still preserve distinct canvas history entries',
    () async {
      final scope = await _scope();
      final vm = scope.read(albumEditorViewModelProvider.notifier);
      final base = newMomentPhotoDesign(photoSize: const Size(100, 200));
      vm.startSinglePageDraft(
        canvasSize: base.canvasSize,
        layers: base.layersForPhoto(momentPhotoOriginalSource),
      );
      final unchanged = List<LayerModel>.of(vm.layers);
      final unchangedJson = _current(vm, base.canvasSize).toJson();
      vm.resizeSinglePageDraft(
        layers: unchanged,
        canvasSize: coverCanvasBaseSize(coverSizes[1]),
      );
      vm.resizeSinglePageDraft(
        layers: unchanged,
        canvasSize: coverCanvasBaseSize(coverSizes[4]),
      );
      vm.undo();
      expect(
        scope.read(albumEditorViewModelProvider).value!.coverCanvasSize,
        coverCanvasBaseSize(coverSizes[1]),
      );
      vm.undo();
      expect(
        scope.read(albumEditorViewModelProvider).value!.coverCanvasSize,
        base.canvasSize,
      );
      vm.redo();
      vm.redo();
      expect(
        scope.read(albumEditorViewModelProvider).value!.coverCanvasSize,
        coverCanvasBaseSize(coverSizes[4]),
      );
      expect(_current(vm, base.canvasSize).toJson(), unchangedJson);
    },
  );

  test(
    'local format API leaves normal new and saved album sessions unchanged',
    () async {
      final scope = await _scope();
      final vm = scope.read(albumEditorViewModelProvider.notifier);
      final design = newMomentPhotoDesign(photoSize: const Size(100, 200));
      vm.resetForCreate();
      final ordinary = vm.exportFullAlbumLayersJson(null);
      expect(
        vm.resizeSinglePageDraft(
          layers: design.layersForPhoto(momentPhotoOriginalSource),
          canvasSize: design.canvasSize,
        ),
        isFalse,
      );
      expect(vm.exportFullAlbumLayersJson(null), ordinary);
      vm.startSinglePageDraft(
        canvasSize: design.canvasSize,
        layers: design.layersForPhoto(momentPhotoOriginalSource),
      );
      await vm.prepareAlbumForEdit(
        fakeAlbum(id: 71).copyWith(userId: 'owner', memberRole: 'OWNER'),
      );
      final saved = vm.exportFullAlbumLayersJson(null);
      expect(
        vm.resizeSinglePageDraft(
          layers: design.layersForPhoto(momentPhotoOriginalSource),
          canvasSize: design.canvasSize,
        ),
        isFalse,
      );
      expect(vm.editingAlbumId, 71);
      expect(vm.exportFullAlbumLayersJson(null), saved);
    },
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/utils/album_progress.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import '../helpers/mock_repositories.dart';
import 'album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

class _PhotoStorage extends FakeStorageService {
  int uploads = 0;

  @override
  Future<UploadedUrls> uploadImageVariants(
    AssetEntity asset, {
    int previewMaxDimension = 1600,
    int? albumId,
  }) async {
    uploads++;
    return UploadedUrls(
      previewUrl: 'https://uploads.test/${asset.id}.jpg',
      originalUrl: 'https://uploads.test/${asset.id}-original.jpg',
    );
  }
}

Album _templateAlbum({required int firstPageSlots}) => Album(
  id: 9141,
  updatedAt: '2026-10-25T01:02:03.123456Z',
  title: '첫 내지 완성 확인',
  ratio: '1',
  targetPages: 2,
  coverLayersJson: jsonEncode({
    'pages': [
      for (var page = 0; page <= 2; page++)
        {
          'index': page,
          'isCover': page == 0,
          'layers': [
            for (var slot = 0; slot < (page == 1 ? firstPageSlots : 1); slot++)
              LayerExportMapper.toJson(
                LayerModel(
                  id: 'photo-$page-$slot',
                  type: LayerType.image,
                  position: const Offset(20, 20),
                  width: 120,
                  height: 120,
                  isTemplateContent: true,
                ),
                canvasSize: Size(page == 0 ? 500 : 300, page == 0 ? 500 : 300),
                isCover: page == 0,
              ),
          ],
        },
    ],
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    ),
  );

  for (final firstPageSlots in [1, 2]) {
    test(
      'first interior with $firstPageSlots slots counts independently through photo upload, save and reopen',
      () async {
        var saved = _templateAlbum(firstPageSlots: firstPageSlots);
        final repository = MockAlbumRepository();
        final storage = _PhotoStorage();
        when(
          () => repository.updateAlbum(
            saved.id,
            any(),
            expectedUpdatedAt: any(named: 'expectedUpdatedAt'),
            requestId: any(named: 'requestId'),
            expectedUserId: any(named: 'expectedUserId'),
          ),
        ).thenAnswer((call) async {
          final request = call.positionalArguments[1] as CreateAlbumRequest;
          saved = saved.copyWith(
            coverLayersJson: request.coverLayersJson,
            targetPages: request.targetPages,
          );
          return saved;
        });
        final container = ProviderContainer(
          overrides: [
            albumEditorOwnerReaderProvider.overrideWithValue(
              () => 'fixture-owner',
            ),
            albumRepositoryProvider.overrideWithValue(repository),
            albumEditorServiceProvider.overrideWithValue(
              const AlbumEditorService(),
            ),
            albumPersistenceServiceProvider.overrideWithValue(
              FakeAlbumPersistenceService(),
            ),
            storageServiceProvider.overrideWithValue(storage),
          ],
        );
        addTearDown(container.dispose);
        await container.read(albumEditorViewModelProvider.future);
        final vm = container.read(albumEditorViewModelProvider.notifier);

        Future<void> reopen() async {
          await vm.prepareAlbumForEdit(saved);
          vm.loadPendingEditAlbumIfNeeded(const Size(500, 500));
        }

        Future<void> saveAndCheck(int completed) async {
          expect(await vm.saveFullAlbum(), isTrue);
          final progress = calculateAlbumProgress(saved);
          expect(progress.completedPages, completed);
          expect(progress.targetPages, 2);
          final document = jsonDecode(saved.coverLayersJson) as Map;
          final pages = document['pages'] as List;
          expect(pages.first['isCover'], isTrue);
          expect(pages[1]['index'], 1);
          expect(pages[1]['isCover'], isFalse);
          await reopen();
          final reopened = saved.copyWith(
            coverLayersJson: vm.exportFullAlbumLayersJson(null),
          );
          expect(calculateAlbumProgress(reopened).completedPages, completed);
        }

        await reopen();
        // A cover photo is never interior page one.
        await vm.updateSlotImage(
          'photo-0-0',
          AssetEntity(id: 'cover', typeInt: 1, width: 100, height: 100),
        );
        await saveAndCheck(0);
        for (var slot = 0; slot < firstPageSlots; slot++) {
          vm.goToPage(1);
          await vm.updateSlotImage(
            'photo-1-$slot',
            AssetEntity(id: 'first-$slot', typeInt: 1, width: 100, height: 100),
          );
          await saveAndCheck(slot + 1 == firstPageSlots ? 1 : 0);
        }
        expect(storage.uploads, firstPageSlots + 1);
        expect(vm.pages[2].layers.single.hasImageSource, isFalse);

        vm.goToPage(2);
        await vm.updateSlotImage(
          'photo-2-0',
          AssetEntity(id: 'second', typeInt: 1, width: 100, height: 100),
        );
        await saveAndCheck(2);
        vm.goToPage(1);
        vm.updateLayer(vm.layers.first.copyWith(clearImage: true));
        await saveAndCheck(1);
      },
    );
  }
}

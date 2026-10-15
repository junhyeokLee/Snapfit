import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/design_templates.dart';
import 'package:snap_fit/core/constants/page_templates.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import '../helpers/mock_repositories.dart';
import 'album_editor_view_model_test.dart'
    show FakeStorageService, FakeAlbumPersistenceService;

void main() {
  for (final kind in ['layout', 'design']) {
    test(
      '$kind replacement remains one undo step with exact content and background restoration',
      () async {
        final container = ProviderContainer(
          overrides: [
            albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
            albumEditorServiceProvider.overrideWithValue(
              const AlbumEditorService(),
            ),
            albumPersistenceServiceProvider.overrideWithValue(
              FakeAlbumPersistenceService(),
            ),
            storageServiceProvider.overrideWithValue(FakeStorageService()),
          ],
        );
        addTearDown(container.dispose);
        await container.read(albumEditorViewModelProvider.future);
        final vm = container.read(albumEditorViewModelProvider.notifier);
        final original = LayerModel(
          id: 'original-text',
          type: LayerType.text,
          position: const Offset(70, 80),
          width: 250,
          height: 50,
          text: '소중한 원래 문구',
          textStyle: const TextStyle(fontSize: 24),
          textStyleType: TextStyleType.none,
        );
        vm.updatePageLayers([original]);
        vm.updatePageBackgroundColor(0xFFE9EFEA);
        if (kind == 'layout') {
          vm.applyTemplateToCurrentPage(
            pageTemplates.first,
            const Size(500, 500),
          );
        } else {
          vm.applyDesignTemplateToCurrentPage(
            DesignTemplate(
              id: 'history-design',
              name: '새 디자인',
              category: '일상',
              backgroundColor: const Color(0xFFFFFFFF),
              buildLayers: (_) => [
                original.copyWith(id: 'new-text', text: '새 문구'),
              ],
            ),
            const Size(500, 500),
          );
        }
        final appliedIds = vm.layers.map((l) => l.id).toList();
        expect(appliedIds, isNot(contains(original.id)));
        vm.undo();
        expect(vm.layers.single.id, original.id);
        expect(vm.layers.single.text, original.text);
        expect(vm.layers.single.position, original.position);
        expect(vm.currentPage!.backgroundColor, 0xFFE9EFEA);
        vm.redo();
        expect(vm.layers.map((l) => l.id), appliedIds);
      },
    );
  }
}

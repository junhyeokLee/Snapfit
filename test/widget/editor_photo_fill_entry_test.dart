import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_more_tools_sheet.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

void main() {
  testWidgets('more tools opens the optional multi-photo action', (
    tester,
  ) async {
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
        albumEditorOwnerReaderProvider.overrideWithValue(() => 'photo-owner'),
        albumEditorOwnerChangesProvider.overrideWith(
          (_) => const Stream.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(albumEditorViewModelProvider.future);
    final vm = container.read(albumEditorViewModelProvider.notifier)
      ..resetForCreate();
    vm.updatePageLayers([
      LayerModel(
        id: 'empty-photo-slot',
        type: LayerType.image,
        position: const Offset(24, 24),
        width: 180,
        height: 220,
      ),
    ], recordHistory: false);
    final actions = <EditorMoreAction>[];
    LayerInteractionManager? interaction;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final manager = interaction ??= LayerInteractionManager(
                  ref: ref,
                  coverKey: GlobalKey(),
                  setState: (update) => update(),
                  getCoverSize: () => const Size(500, 500),
                  onEditText: (_) {},
                );
                return EditorMoreToolsSheet(
                  interaction: manager,
                  session: vm.editSessionIdentity,
                  pageId: vm.currentPage!.id,
                  albumId: vm.editingAlbumId,
                  selectedId: null,
                  onAction: actions.add,
                  onClose: () {},
                );
              },
            ),
          ),
        ),
      ),
    );
    addTearDown(() => interaction?.dispose());
    await tester.pumpAndSettle();

    // Existing types keep RED focused on the missing user action, not compilation.
    final entry = find.text('사진 여러 장 넣기');
    expect(entry, findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(actions.map((action) => action.name), ['fillPhotos']);
    expect(tester.takeException(), isNull);
  });
}

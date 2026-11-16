import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import '../helpers/mock_repositories.dart';
import 'album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

Future<AlbumEditorViewModel> _editor() async {
  final container = ProviderContainer(
    overrides: [
      albumEditorOwnerReaderProvider.overrideWithValue(() => 'fixture-owner'),
      albumEditorOwnerChangesProvider.overrideWith(
        (ref) => const Stream.empty(),
      ),
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
  vm.resetForCreate(targetPages: 24);
  return vm;
}

LayerModel _photo(int page) => LayerModel(
  id: 'keep-photo-$page',
  type: LayerType.image,
  position: const Offset(10, 20),
  width: 100,
  height: 120,
  imageUrl: 'asset:fixture-$page.png',
);

void _unique(AlbumEditorViewModel vm) {
  final ids = vm.pages.map((page) => page.id).toList();
  expect(ids.toSet(), hasLength(ids.length));
  expect(vm.pages.first.id, 'cover_page');
  expect(
    vm.pages.map((page) => page.pageIndex),
    List.generate(vm.pages.length, (index) => index),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'page identity: append after a middle deletion preserves existing pages',
    () async {
      final vm = await _editor();
      final keep = _photo(24);
      vm.goToPage(24);
      vm.updatePageLayers([keep]);
      final retainedIds = vm.pages.skip(3).map((page) => page.id).toList();
      vm.goToPage(1);
      expect(vm.deleteCurrentPage(), isTrue);
      expect(vm.innerPageCount, 22);
      expect(vm.addPage(), isTrue);
      expect(vm.innerPageCount, 24);
      _unique(vm);
      expect(vm.pages.skip(1).take(22).map((page) => page.id), retainedIds);
      expect(vm.pages[22].layers.single, same(keep));
      expect(vm.pages.skip(23).every((page) => page.layers.isEmpty), isTrue);
      expect(vm.currentPageIndex, 23);
    },
  );

  test(
    'page identity: blank replacement cannot alias a retained authored page',
    () async {
      final vm = await _editor();
      final photos = [for (var page = 1; page <= 24; page++) _photo(page)];
      for (var page = 1; page <= 24; page++) {
        vm.goToPage(page);
        vm.updatePageLayers([photos[page - 1]]);
      }
      final retainedIds = vm.pages.skip(2).map((page) => page.id).toList();
      vm.goToPage(1);
      expect(vm.deleteCurrentPageDescription, contains('맨 뒤에 빈 쪽'));
      expect(vm.deleteCurrentPage(), isTrue);
      expect(vm.innerPageCount, 24);
      _unique(vm);
      expect(vm.pages.skip(1).take(23).map((page) => page.id), retainedIds);
      for (var page = 1; page <= 23; page++) {
        expect(vm.pages[page].layers.single, same(photos[page]));
      }
      expect(vm.pages.last.layers, isEmpty);
    },
  );

  test(
    'page identity: deleted tail IDs are not revived by fresh pages',
    () async {
      final vm = await _editor();
      final deletedIds = vm.pages.skip(23).map((page) => page.id).toSet();
      final session = vm.editSessionIdentity;
      vm.goToPage(23);
      expect(vm.deleteCurrentPage(), isTrue);
      expect(vm.addPage(), isTrue);
      _unique(vm);
      expect(vm.editSessionIdentity, same(session));
      expect(
        vm.pages.map((page) => page.id).toSet().intersection(deletedIds),
        isEmpty,
      );
    },
  );

  test(
    'page identity: template extension after deletion keeps targets distinct',
    () async {
      final vm = await _editor();
      final keep = _photo(24);
      vm.goToPage(24);
      vm.updatePageLayers([keep]);
      final oldTailId = vm.currentPage!.id;
      vm.goToPage(1);
      expect(vm.deleteCurrentPage(), isTrue);
      final template = List.generate(
        25,
        (page) => page >= 23 ? [_photo(page + 100)] : <LayerModel>[],
      );
      vm.applyTemplatePagesToCurrentAlbum(template);
      expect(vm.innerPageCount, 24);
      _unique(vm);
      expect(vm.pages[22].id, oldTailId);
      expect(vm.pages[23].layers.single.id, 'keep-photo-123');
      expect(vm.pages[24].layers.single.id, 'keep-photo-124');
    },
  );

  test(
    'page identity: repeated append and removal never reuse a target',
    () async {
      final vm = await _editor();
      final seen = vm.pages.map((page) => page.id).toSet();
      for (var cycle = 0; cycle < 30; cycle++) {
        vm.goToPage(23);
        expect(vm.deleteCurrentPage(), isTrue);
        expect(vm.addPage(), isTrue);
        _unique(vm);
        for (final page in vm.pages.skip(23)) {
          expect(seen.add(page.id), isTrue);
        }
      }
      expect(vm.innerPageCount, 24);
    },
  );
}

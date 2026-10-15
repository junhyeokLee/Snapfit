import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/page_templates.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_list_selector.dart';
import 'package:snap_fit/shared/widgets/snapfit_motion.dart';
import 'package:snap_fit/features/album/service/album_persistence_service.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';

class FakeStorageService implements StorageService {
  @override
  Future<String?> uploadProfileImage(File file, String userId) async => null;

  @override
  Future<String?> uploadFile(File file, String path) async => null;

  @override
  Future<UploadedUrls> uploadImageVariants(
    AssetEntity asset, {
    int previewMaxDimension = 1600,
  }) async => const UploadedUrls();

  @override
  Future<UploadedUrls> uploadCoverVariants(
    Uint8List pngBytes, {
    int originalMaxDimension = 4096,
    int previewMaxDimension = 1024,
  }) async => const UploadedUrls();

  @override
  Future<List<AiAlbumPreviewUpload>> uploadAiAlbumPreviews({
    required String draftId,
    required List<AssetEntity> assets,
    int maxDimension = 512,
  }) async => const [];

  @override
  Future<void> deleteAiAlbumPreviews(Iterable<String> paths) async {}
}

class FakeAlbumPersistenceService implements AlbumPersistenceService {
  @override
  Future<void> performBackgroundUpload({
    required int albumId,
    required Size canvasSize,
    required List<LayerModel> currentLayers,
    required Uint8List? coverImageBytes,
    required String themeLabel,
    required String title,
    required double coverRatio,
    required int targetPages,
    Map<String, dynamic>? printProduct,
    bool swallowErrors = true,
    void Function(int completed, int total)? onProgress,
  }) async {}

  @override
  Future<bool> pollAlbumCreation(int albumId) async => false;
}

class QuotaFailAlbumPersistenceService implements AlbumPersistenceService {
  @override
  Future<void> performBackgroundUpload({
    required int albumId,
    required Size canvasSize,
    required List<LayerModel> currentLayers,
    required Uint8List? coverImageBytes,
    required String themeLabel,
    required String title,
    required double coverRatio,
    required int targetPages,
    Map<String, dynamic>? printProduct,
    bool swallowErrors = true,
    void Function(int completed, int total)? onProgress,
  }) async {
    throw const StorageQuotaExceededException(
      hardLimitBytes: 1024,
      usedBytes: 1024,
      incomingBytes: 10,
      projectedBytes: 1034,
      reason: 'HARD_LIMIT_EXCEEDED',
    );
  }

  @override
  Future<bool> pollAlbumCreation(int albumId) async => false;
}

class MockAssetEntity extends Mock implements AssetEntity {}

Future<ProviderContainer> _pagePolicyContainer() async {
  final container = ProviderContainer(
    overrides: [
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
  return container;
}

Future<AlbumEditorViewModel> _pagePolicyEditor() async =>
    (await _pagePolicyContainer()).read(albumEditorViewModelProvider.notifier);

Widget _pagePolicySelector(ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(albumEditorViewModelProvider);
                final vm = ref.read(albumEditorViewModelProvider.notifier);
                return StatefulBuilder(
                  builder: (context, refresh) => PageListSelector(
                    pages: vm.pages,
                    currentPageIndex: vm.currentPageIndex,
                    onPageSelected: vm.goToPage,
                    onAddPage: vm.canAddPage
                        ? () {
                            vm.addPage();
                            refresh(() {});
                          }
                        : null,
                    addPageDescription: vm.addPageDescription,
                    canDeleteCurrentPage: vm.canDeleteCurrentPage,
                    onDeleteCurrentPage: () {
                      vm.deleteCurrentPage();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

void _restoreLegacyPageCount(AlbumEditorViewModel vm, int count) {
  vm.loadAlbum({
    'coverLayersJson': jsonEncode({
      'pages': [
        for (var index = 0; index <= count; index++)
          {'index': index, 'isCover': index == 0, 'layers': []},
      ],
    }),
  }, const Size(500, 500));
}

LayerModel _pageText(String text) => LayerModel(
  id: text,
  type: LayerType.text,
  position: const Offset(20, 30),
  width: 100,
  height: 40,
  text: text,
  textStyle: const TextStyle(fontSize: 16),
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1:1',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    );
  });

  group('printable editor page policy', () {
    testWidgets('20-page selector hides deletion and adds two pages', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = await _pagePolicyContainer();
      final vm = container.read(albumEditorViewModelProvider.notifier);
      vm.resetForCreate();
      vm.goToPage(1);
      await tester.pumpWidget(_pagePolicySelector(container));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(-10000, 0));
      await tester.pumpAndSettle();
      expect(find.byTooltip('빈 내지 2쪽 추가 · 표지 별도, 최대 80쪽'), findsOneWidget);
      await tester.tap(find.byKey(const Key('addInnerPagesButton')));
      await tester.pumpAndSettle();
      expect(vm.innerPageCount, 22);
      expect(vm.currentPageIndex, 21);
      expect(vm.pages.skip(21).every((p) => p.layers.isEmpty), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '79-page selector adds one then disables at 80 with explanation',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = await _pagePolicyContainer();
        final vm = container.read(albumEditorViewModelProvider.notifier);
        _restoreLegacyPageCount(vm, 79);
        await tester.pumpWidget(_pagePolicySelector(container));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(-20000, 0));
        await tester.pumpAndSettle();
        expect(find.byTooltip('빈 내지 1쪽 추가 · 표지 별도, 최대 80쪽'), findsOneWidget);
        await tester.tap(find.byKey(const Key('addInnerPagesButton')));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(vm.innerPageCount, 80);
        expect(find.byTooltip('내지는 최대 80쪽까지 추가할 수 있어요'), findsOneWidget);
        final button = tester.widget<SnapFitPressable>(
          find.byKey(const Key('addInnerPagesButton')),
        );
        expect(button.onTap, isNull);
        await tester.tap(find.byKey(const Key('addInnerPagesButton')));
        await tester.pumpAndSettle();
        expect(vm.innerPageCount, 80);
        expect(tester.takeException(), isNull);
      },
    );

    test('new albums pad to 20 and round odd selections upward', () async {
      final vm = await _pagePolicyEditor();
      for (final (requested, expected) in [
        (1, 20),
        (19, 20),
        (21, 22),
        (79, 80),
      ]) {
        vm.resetForCreate(
          initialCover: defaultCoverSize.withCoverType(PrintCoverType.hard),
          targetPages: requested,
        );
        expect(vm.innerPageCount, expected);
        expect(vm.pages.first.isCover, isTrue);
        expect(vm.selectedCover.coverType, PrintCoverType.hard);
      }
    });

    test('legacy load preserves odd and oversized page counts', () async {
      final vm = await _pagePolicyEditor();
      for (final count in [3, 19, 79, 81]) {
        _restoreLegacyPageCount(vm, count);
        expect(vm.innerPageCount, count);
      }
      final before = vm.exportFullAlbumLayersJson(const Size(500, 500));
      expect(vm.canAddPage, isFalse);
      expect(vm.addPage(), isFalse);
      expect(vm.exportFullAlbumLayersJson(const Size(500, 500)), before);
    });

    test('add pads legacy 19/79 once and adds two to an even album', () async {
      final vm = await _pagePolicyEditor();
      for (final (before, added) in [(19, 1), (20, 2), (78, 2), (79, 1)]) {
        _restoreLegacyPageCount(vm, before);
        expect(vm.pagesToAdd, added);
        expect(vm.addPage(), isTrue);
        expect(vm.innerPageCount, before + added);
        expect(vm.currentPageIndex, before + 1);
      }
      final ids = vm.pages.map((p) => p.id).toList();
      expect(vm.addPage(), isFalse);
      expect(vm.pages.map((p) => p.id), ids);
    });

    test(
      'template addition obeys cap and fills only its first new page',
      () async {
        final vm = await _pagePolicyEditor();
        const template = PageTemplate(
          id: 'text',
          name: 'text',
          slots: [
            PageTemplateSlot(
              type: 'text',
              left: .1,
              top: .1,
              width: .5,
              height: .2,
              defaultText: 'new page',
            ),
          ],
        );
        vm.resetForCreate(targetPages: 78);
        expect(vm.addPageFromTemplate(template, const Size(500, 500)), isTrue);
        expect(vm.innerPageCount, 80);
        expect(vm.pages[79].layers.single.text, 'new page');
        expect(vm.pages[80].layers, isEmpty);
        final before = vm.exportFullAlbumLayersJson(const Size(500, 500));
        expect(vm.addPageFromTemplate(template, const Size(500, 500)), isFalse);
        expect(vm.exportFullAlbumLayersJson(const Size(500, 500)), before);
        _restoreLegacyPageCount(vm, 79);
        expect(vm.addPageFromTemplate(template, const Size(500, 500)), isTrue);
        expect(vm.innerPageCount, 80);
        expect(vm.pages.last.layers.single.text, 'new page');
      },
    );

    test('minimum 20 blocks deletion through either entry point', () async {
      final vm = await _pagePolicyEditor();
      vm.resetForCreate();
      vm.goToPage(1);
      expect(vm.canDeleteCurrentPage, isFalse);
      expect(vm.deleteCurrentPage(), isFalse);
      expect(vm.removeLastPage(), isFalse);
      expect(vm.innerPageCount, 20);
    });

    test(
      'delete removes only selected content and a clearly empty partner',
      () async {
        final vm = await _pagePolicyEditor();
        vm.resetForCreate(targetPages: 22);
        vm.goToPage(1);
        vm.updatePageLayers([_pageText('selected')]);
        vm.goToPage(3);
        vm.updatePageLayers([_pageText('keep')]);
        final preserved = vm.pages[3];
        vm.goToPage(1);
        expect(vm.deleteCurrentPageDescription, contains('내용이 없는 2쪽'));
        expect(vm.deleteCurrentPage(), isTrue);
        expect(vm.innerPageCount, 20);
        expect(vm.pages[1].id, preserved.id);
        expect(vm.pages[1].layers.single.text, 'keep');
        expect(vm.pages.map((p) => p.pageIndex), List.generate(21, (i) => i));
      },
    );

    test(
      'authored partner and styled background survive with blank replacement',
      () async {
        final vm = await _pagePolicyEditor();
        vm.resetForCreate(targetPages: 22);
        for (var i = 1; i <= 22; i++) {
          vm.goToPage(i);
          vm.updatePageLayers([_pageText('page-$i')]);
        }
        vm.goToPage(2);
        vm.updatePageLayers([]);
        vm.updatePageBackgroundColor(Colors.blue.toARGB32());
        final keptIds = vm.pages.skip(2).map((p) => p.id).toList();
        vm.goToPage(1);
        expect(vm.deleteCurrentPageDescription, contains('맨 뒤에 빈 쪽'));
        vm.deleteCurrentPage();
        expect(vm.innerPageCount, 22);
        expect(vm.pages.skip(1).take(21).map((p) => p.id), keptIds);
        expect(vm.pages[1].backgroundColor, Colors.blue.toARGB32());
        expect(vm.pages.last.layers, isEmpty);
        expect(vm.pages.last.backgroundColor, isNull);
      },
    );

    test('legacy odd deletion removes only the selected page', () async {
      final vm = await _pagePolicyEditor();
      _restoreLegacyPageCount(vm, 21);
      final retainedId = vm.pages[2].id;
      vm.goToPage(1);
      expect(vm.deleteCurrentPage(), isTrue);
      expect(vm.innerPageCount, 20);
      expect(vm.pages[1].id, retainedId);
    });

    test(
      'oversized template operations reject atomically before modifying content',
      () async {
        final vm = await _pagePolicyEditor();
        vm.resetForCreate(
          initialCover: defaultCoverSize.withCoverType(PrintCoverType.hard),
        );
        vm.goToPage(1);
        vm.updatePageLayers([_pageText('keep me')]);
        final before = vm.exportFullAlbumLayersJson(const Size(500, 500));
        final oversized = List.generate(82, (_) => [_pageText('incoming')]);
        for (final action in <void Function()>[
          () => vm.startLocalTemplateAlbum(
            albumTitle: 'Too large',
            pages: oversized,
          ),
          () => vm.applyTemplatePagesToCurrentAlbum(oversized),
          () => vm.queueTemplatePagesForNextLoad(oversized),
        ]) {
          expect(
            action,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                AlbumEditorViewModel.pageLimitMessage,
              ),
            ),
          );
          expect(vm.exportFullAlbumLayersJson(const Size(500, 500)), before);
        }
      },
    );

    test(
      'bulk template completes an odd sheet and keeps untouched existing pages',
      () async {
        final vm = await _pagePolicyEditor();
        _restoreLegacyPageCount(vm, 21);
        vm.goToPage(21);
        vm.updatePageLayers([_pageText('last page stays')]);
        vm.applyTemplatePagesToCurrentAlbum([
          [],
          [_pageText('new first')],
        ]);
        expect(vm.innerPageCount, 22);
        expect(vm.pages[1].layers.single.text, 'new first');
        expect(vm.pages[21].layers.single.text, 'last page stays');
        expect(vm.pages[22].layers, isEmpty);
      },
    );
  });

  for (final size in coverSizes.expand(
    (size) => PrintCoverType.values.map(size.withCoverType),
  )) {
    test('saves and restores physical product ${size.productId}', () async {
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
      vm.resetForCreate(initialCover: size, targetPages: 2);
      final json = vm.exportFullAlbumLayersJson(const Size(500, 500));
      expect(jsonDecode(json)['printProduct'], size.printProduct);
      expect(
        jsonDecode(
          vm.exportCoverLayersJson(const Size(500, 500)),
        )['printProduct'],
        size.printProduct,
      );
      await vm.prepareAlbumForEdit(
        fakeAlbum(id: 2, ratio: '${size.ratio}', coverLayersJson: json),
      );
      final restored = container
          .read(albumEditorViewModelProvider)
          .value!
          .selectedCover;
      expect(restored.productId, size.productId);
      expect(restored.realSize, size.realSize);
      expect(restored.ratio, size.ratio);
    });
  }

  test(
    'legacy portrait retains its canvas and does not gain a print product',
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
      await vm.prepareAlbumForEdit(
        fakeAlbum(ratio: '0.75', coverLayersJson: '{"pages":[]}'),
      );
      final restored = container
          .read(albumEditorViewModelProvider)
          .value!
          .selectedCover;
      expect(restored.ratio, .75);
      expect(restored.realSize, const Size(14.5, 19.4));
      expect(restored.productId, isNull);
      expect(
        jsonDecode(
          vm.exportFullAlbumLayersJson(const Size(500, 500)),
        ).containsKey('printProduct'),
        isFalse,
      );
    },
  );

  test('resetForCreate initializes cover and pages', () async {
    final mockRepo = MockAlbumRepository();
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(mockRepo),
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

    final notifier = container.read(albumEditorViewModelProvider.notifier);
    final cover = coverSizes.first;
    notifier.resetForCreate(initialCover: cover, targetPages: 3);

    final state = container.read(albumEditorViewModelProvider).value;
    expect(state, isNotNull);
    expect(state!.selectedCover, cover);
    expect(notifier.pages.length, 21);
    expect(notifier.currentPageIndex, 0);
  });

  test('addPage and removeLastPage update page count', () async {
    final mockRepo = MockAlbumRepository();
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(mockRepo),
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

    final notifier = container.read(albumEditorViewModelProvider.notifier);
    notifier.resetForCreate();
    final initialCount = notifier.pages.length;

    notifier.addPage();
    expect(notifier.pages.length, initialCount + 2);

    notifier.removeLastPage();
    expect(notifier.pages.length, initialCount);
  });

  test('updatePageBackgroundColor and clearPageBackgroundColor work', () async {
    final mockRepo = MockAlbumRepository();
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(mockRepo),
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

    final notifier = container.read(albumEditorViewModelProvider.notifier);
    notifier.updatePageBackgroundColor(0xFF000000);
    expect(notifier.currentPage?.backgroundColor, 0xFF000000);

    notifier.clearPageBackgroundColor();
    expect(notifier.currentPage?.backgroundColor, isNull);
  });

  test('undo and redo restore layer changes', () async {
    final mockRepo = MockAlbumRepository();
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(mockRepo),
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

    final notifier = container.read(albumEditorViewModelProvider.notifier);
    final initialLayers = notifier.layers;

    final newLayer = LayerModel(
      id: 'layer-1',
      type: LayerType.text,
      position: const Offset(10, 10),
      width: 100,
      height: 40,
      text: 'hello',
      textStyle: const TextStyle(fontSize: 12),
      textStyleType: TextStyleType.none,
    );

    notifier.updatePageLayers([newLayer]);
    expect(notifier.layers.length, 1);

    notifier.undo();
    expect(notifier.layers.length, initialLayers.length);

    notifier.redo();
    expect(notifier.layers.length, 1);
    expect(notifier.layers.first.id, 'layer-1');
  });

  test(
    'saveFullAlbum uses edited cover layer url instead of stale initial url',
    () async {
      final mockRepo = MockAlbumRepository();
      CreateAlbumRequest? capturedRequest;

      final editingAlbum = fakeAlbum(
        id: 7,
        coverLayersJson: '{"layers":[]}',
        coverImageUrl: 'https://old.example/cover.jpg',
        coverThumbnailUrl: 'https://old.example/thumb.jpg',
      );

      when(
        () => mockRepo.fetchAlbum('7'),
      ).thenAnswer((_) async => editingAlbum);
      when(() => mockRepo.updateAlbum(7, any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[1] as CreateAlbumRequest;
        capturedRequest = request;
        return fakeAlbum(
          id: 7,
          ratio: request.ratio,
          coverLayersJson: request.coverLayersJson,
          coverImageUrl: request.coverImageUrl,
          coverThumbnailUrl: request.coverThumbnailUrl,
        );
      });

      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
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
      final notifier = container.read(albumEditorViewModelProvider.notifier);

      await notifier.prepareAlbumForEdit(editingAlbum);
      notifier.setCoverCanvasSize(const Size(500, 666.67), isCover: true);
      notifier.updatePageLayers([
        LayerModel(
          id: 'cover-1',
          type: LayerType.image,
          position: Offset.zero,
          width: 180,
          height: 180,
          previewUrl: 'https://new.example/cover.jpg',
          imageUrl: 'https://new.example/cover.jpg',
        ),
      ], recordHistory: false);

      final ok = await notifier.saveFullAlbum();

      expect(ok, isTrue);
      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.coverImageUrl, 'https://new.example/cover.jpg');
      expect(
        capturedRequest!.coverThumbnailUrl,
        'https://new.example/cover.jpg',
      );
    },
  );

  test(
    'updateSlotImage clears old urls so replaced photo can be uploaded',
    () async {
      final mockRepo = MockAlbumRepository();
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
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
      final notifier = container.read(albumEditorViewModelProvider.notifier);

      notifier.updatePageLayers([
        LayerModel(
          id: 'slot-1',
          type: LayerType.image,
          position: Offset.zero,
          width: 100,
          height: 100,
          previewUrl: 'https://old.example/preview.jpg',
          imageUrl: 'https://old.example/image.jpg',
          originalUrl: 'https://old.example/original.jpg',
          imageOffset: const Offset(25, -20),
          imageZoom: 2.4,
          imageBackground: 'materialLaceMount',
          imageTemplate: '1:1',
          rotation: .2,
          scale: 1.3,
          opacity: .8,
          zIndex: 3,
          decorationFillColor: '#112233',
          decorationBorderColor: '#445566',
          decorationBorderWidth: 2,
          decorationCornerRadius: 8,
          frameBaseWidth: 90,
          frameBaseHeight: 95,
          frameBasePosition: const Offset(10, 12),
        ),
      ], recordHistory: false);

      final newAsset = MockAssetEntity();
      await notifier.updateSlotImage('slot-1', newAsset);

      final layer = notifier.layers.first;
      expect(layer.asset, same(newAsset));
      expect(layer.previewUrl, isNull);
      expect(layer.imageUrl, isNull);
      expect(layer.originalUrl, isNull);
      expect(layer.imageZoom, 1);
      expect(layer.imageOffset, isNull);
      expect(layer.imageBackground, 'materialLaceMount');
      expect(layer.imageTemplate, '1:1');
      expect(layer.rotation, .2);
      expect(layer.scale, 1.3);
      expect(layer.opacity, .8);
      expect(layer.zIndex, 3);
      expect(layer.decorationFillColor, '#112233');
      expect(layer.decorationBorderColor, '#445566');
      expect(layer.decorationBorderWidth, 2);
      expect(layer.decorationCornerRadius, 8);
      expect(layer.frameBaseWidth, 90);
      expect(layer.frameBaseHeight, 95);
      expect(layer.frameBasePosition, const Offset(10, 12));
      notifier.undo();
      expect(
        notifier.layers.single.previewUrl,
        'https://old.example/preview.jpg',
      );
      expect(notifier.layers.single.imageZoom, 2.4);
      expect(notifier.layers.single.imageOffset, const Offset(25, -20));
      notifier.redo();
      expect(notifier.layers.single.asset, same(newAsset));
      expect(notifier.layers.single.imageZoom, 1);
      final sourcePage = notifier.currentPage!.id;
      final retained = notifier.layers.single;
      notifier.addPage();
      notifier.updatePageLayers([retained], recordHistory: false);
      await notifier.updateSlotImage(
        'slot-1',
        MockAssetEntity(),
        expectedPageId: sourcePage,
      );
      expect(notifier.layers.single.asset, same(newAsset));
      expect(notifier.pages.first.layers.single.asset, same(newAsset));
    },
  );

  test(
    'slot replacement commits photo and crop as a single undo step',
    () async {
      final vm = await _pagePolicyEditor();
      final original = LayerModel(
        id: 'replace-slot',
        type: LayerType.image,
        position: const Offset(10, 20),
        width: 240,
        height: 320,
        originalUrl: 'asset:old.jpg',
        imageZoom: 2.3,
        imageOffset: const Offset(20, -30),
        imageBackground: 'polaroid',
        frameBaseWidth: 250,
        frameBaseHeight: 350,
      );
      vm.updatePageLayers([original], recordHistory: false);
      final asset = MockAssetEntity();
      await vm.updateSlotImage(
        original.id,
        asset,
        expectedPageId: vm.currentPage!.id,
        expectedLayer: original,
        imageZoom: 1.7,
        imageOffset: const Offset(30, -15),
      );
      final applied = vm.layers.single;
      expect(applied.asset, same(asset));
      expect(applied.originalUrl, isNull);
      expect(applied.imageZoom, 1.7);
      expect(applied.imageOffset, const Offset(30, -15));
      expect(applied.imageBackground, original.imageBackground);
      expect(applied.frameBaseWidth, original.frameBaseWidth);
      expect(applied.frameBaseHeight, original.frameBaseHeight);
      vm.undo();
      expect(vm.layers.single.originalUrl, original.originalUrl);
      expect(vm.layers.single.imageZoom, 2.3);
      expect(vm.layers.single.imageOffset, original.imageOffset);
      expect(vm.layers.single.asset, isNull);
      vm.redo();
      expect(vm.layers.single.asset, same(asset));
      expect(vm.layers.single.imageZoom, 1.7);
      expect(vm.layers.single.imageOffset, applied.imageOffset);
    },
  );

  test(
    'stale slot replacement leaves the current photo and history unchanged',
    () async {
      final vm = await _pagePolicyEditor();
      final old = LayerModel(
        id: 'replace-slot',
        type: LayerType.image,
        position: Offset.zero,
        width: 200,
        height: 200,
        imageZoom: 2,
      );
      final current = old.copyWith(imageZoom: 3);
      vm.updatePageLayers([current], recordHistory: false);
      await vm.updateSlotImage(
        old.id,
        MockAssetEntity(),
        expectedLayer: old,
        imageZoom: 1.8,
        imageOffset: const Offset(10, -20),
      );
      expect(vm.layers.single, same(current));
      vm.undo();
      expect(vm.layers.single, same(current));
    },
  );

  test(
    'saveFullAlbum fails fast when image upload for replaced slot fails',
    () async {
      final mockRepo = MockAlbumRepository();
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          albumEditorServiceProvider.overrideWithValue(
            const AlbumEditorService(),
          ),
          albumPersistenceServiceProvider.overrideWithValue(
            FakeAlbumPersistenceService(),
          ),
          // FakeStorageService.uploadImageVariants returns empty URLs.
          storageServiceProvider.overrideWithValue(FakeStorageService()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(albumEditorViewModelProvider.future);
      final notifier = container.read(albumEditorViewModelProvider.notifier);
      await notifier.prepareAlbumForEdit(
        fakeAlbum(id: 8, coverLayersJson: '{"layers":[]}'),
      );
      notifier.setCoverCanvasSize(const Size(500, 500), isCover: true);
      notifier.updatePageLayers([
        LayerModel(
          id: 'slot-fail',
          type: LayerType.image,
          position: Offset.zero,
          width: 120,
          height: 120,
          asset: MockAssetEntity(),
        ),
      ], recordHistory: false);

      final ok = await notifier.saveFullAlbum();
      expect(ok, isFalse);
    },
  );

  test(
    'saveAlbumToBackend surfaces fatal upload errors during new album creation',
    () async {
      final mockRepo = MockAlbumRepository();
      when(() => mockRepo.createAlbum(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as CreateAlbumRequest;
        return fakeAlbum(
          id: 99,
          ratio: request.ratio,
          coverLayersJson: request.coverLayersJson,
          coverImageUrl: request.coverImageUrl,
          coverThumbnailUrl: request.coverThumbnailUrl,
        );
      });

      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          albumEditorServiceProvider.overrideWithValue(
            const AlbumEditorService(),
          ),
          albumPersistenceServiceProvider.overrideWithValue(
            QuotaFailAlbumPersistenceService(),
          ),
          storageServiceProvider.overrideWithValue(FakeStorageService()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(albumEditorViewModelProvider.future);
      final notifier = container.read(albumEditorViewModelProvider.notifier);
      final cover = coverSizes.first;
      notifier.resetForCreate(initialCover: cover, targetPages: 3);

      expect(
        () => notifier.saveAlbumToBackend(
          const Size(500, 500),
          coverImageBytes: Uint8List.fromList([0, 1, 2]),
          title: '새 앨범',
          targetPages: 3,
        ),
        throwsA(isA<StorageQuotaExceededException>()),
      );
    },
  );

  test(
    'beginCreatedAlbumForEdit opens regular created album without upload polling',
    () async {
      final mockRepo = MockAlbumRepository();
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
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
      final notifier = container.read(albumEditorViewModelProvider.notifier);
      final cover = coverSizes.firstWhere((s) => s.name == '정사각형');

      notifier.resetForCreate(initialCover: cover, targetPages: 3);
      notifier.beginCreatedAlbumForEdit(albumId: 77, albumTitle: '새 앨범');

      final state = container.read(albumEditorViewModelProvider).value;
      expect(state, isNotNull);
      expect(state!.isCreatingInBackground, isFalse);
      expect(notifier.editingAlbumId, 77);
      expect(notifier.pages.length, 21);
      expect(notifier.currentPageIndex, 0);
      verifyNever(() => mockRepo.fetchAlbum(any()));
    },
  );

  test(
    'beginCreatedTemplateAlbumForEdit opens template pages without waiting for upload polling',
    () async {
      final mockRepo = MockAlbumRepository();
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
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
      final notifier = container.read(albumEditorViewModelProvider.notifier);
      final cover = coverSizes.firstWhere((s) => s.name == '정사각형');
      final pages = [
        [
          LayerModel(
            id: 'cover-template-layer',
            type: LayerType.text,
            position: Offset.zero,
            width: 100,
            height: 40,
            text: '템플릿 표지',
            textStyle: const TextStyle(fontSize: 16),
            textStyleType: TextStyleType.none,
          ),
        ],
        [
          LayerModel(
            id: 'inner-template-layer',
            type: LayerType.text,
            position: Offset.zero,
            width: 100,
            height: 40,
            text: '템플릿 내지',
            textStyle: const TextStyle(fontSize: 16),
            textStyleType: TextStyleType.none,
          ),
        ],
      ];

      notifier.beginCreatedTemplateAlbumForEdit(
        albumId: 42,
        albumTitle: '템플릿 앨범',
        pages: pages,
        initialCover: cover,
      );

      final state = container.read(albumEditorViewModelProvider).value;
      expect(state, isNotNull);
      expect(state!.isCreatingInBackground, isFalse);
      expect(notifier.editingAlbumId, 42);
      expect(notifier.pages.length, 21);
      expect(notifier.pages.first.layers.single.id, 'cover-template-layer');
      expect(notifier.pages[1].layers.single.id, 'inner-template-layer');
    },
  );

  test(
    'explicit creation canvas preserves margins of sparse template pages',
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
      final photo = LayerModel(
        id: 'small-photo',
        type: LayerType.image,
        position: const Offset(30, 60),
        width: 90,
        height: 120,
      );
      vm.beginCreatedTemplateAlbumForEdit(
        albumId: 42,
        albumTitle: '여백',
        pages: [
          [photo],
          [photo],
        ],
        initialCover: defaultCoverSize,
        templateCanvasSize: const Size(300, 300),
      );
      final actual = vm.pages[1].layers.single;
      expect(actual.position.dx, closeTo(50, .001));
      expect(actual.position.dy, closeTo(100, .001));
      expect(actual.width, closeTo(150, .001));
      expect(actual.height, closeTo(200, .001));
    },
  );

  test(
    'beginCreatedTemplateAlbumForEdit preserves local AI photo assets for editor upload',
    () async {
      final mockRepo = MockAlbumRepository();
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
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
      final notifier = container.read(albumEditorViewModelProvider.notifier);
      final cover = coverSizes.firstWhere((s) => s.name == '정사각형');
      final coverAsset = MockAssetEntity();
      final storyAsset = MockAssetEntity();
      final pages = [
        [
          LayerModel(
            id: 'ai-cover-photo',
            type: LayerType.image,
            position: const Offset(60, 72),
            width: 380,
            height: 280,
            asset: coverAsset,
            imageTemplate: '4:3',
            imageBackground: 'mat',
          ),
        ],
        [
          LayerModel(
            id: 'ai-story-photo',
            type: LayerType.image,
            position: const Offset(40, 160),
            width: 220,
            height: 150,
            asset: storyAsset,
            imageTemplate: '4:3',
            imageBackground: 'mat',
          ),
        ],
      ];

      notifier.beginCreatedTemplateAlbumForEdit(
        albumId: 88,
        albumTitle: 'AI 초안 앨범',
        pages: pages,
        initialCover: cover,
      );

      final coverLayer = notifier.pages.first.layers.single;
      final storyLayer = notifier.pages[1].layers.single;
      expect(coverLayer.asset, same(coverAsset));
      expect(storyLayer.asset, same(storyAsset));
      expect(coverLayer.imageUrl, isNull);
      expect(coverLayer.originalUrl, isNull);
      expect(coverLayer.previewUrl, isNull);
      expect(storyLayer.imageUrl, isNull);
      expect(storyLayer.originalUrl, isNull);
      expect(storyLayer.previewUrl, isNull);
      expect(notifier.editingAlbumId, 88);
    },
  );

  test(
    'image template pages do not automatically overwrite background tone',
    () async {
      final mockRepo = MockAlbumRepository();
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
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
      final notifier = container.read(albumEditorViewModelProvider.notifier);

      notifier.startLocalTemplateAlbum(
        albumTitle: '배경 보호 앨범',
        pages: [
          [
            LayerModel(
              id: 'hero-photo',
              type: LayerType.image,
              position: Offset.zero,
              width: 500,
              height: 500,
              previewUrl:
                  'supabase://album-assets/user-123/albums/covers/cover.jpg',
            ),
          ],
          [
            LayerModel(
              id: 'inner-photo',
              type: LayerType.image,
              position: Offset.zero,
              width: 500,
              height: 500,
              previewUrl:
                  'supabase://album-assets/user-123/albums/images/page.jpg',
            ),
          ],
        ],
        initialCover: coverSizes.firstWhere((s) => s.name == '정사각형'),
      );

      expect(notifier.pages.first.layers.single.id, 'hero-photo');
      expect(notifier.pages.first.backgroundColor, isNull);
      expect(notifier.pages[1].layers.single.id, 'inner-photo');
      expect(notifier.pages[1].backgroundColor, isNull);
    },
  );

  test('AlbumPage.copyWith can explicitly clear backgroundColor to null', () {
    final page = AlbumPage(
      id: 'page-1',
      layers: const <LayerModel>[],
      pageIndex: 0,
      backgroundColor: 0xFF123456,
    );

    expect(page.copyWith().backgroundColor, 0xFF123456);
    expect(page.copyWith(backgroundColor: null).backgroundColor, isNull);
  });
}

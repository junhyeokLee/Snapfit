import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/presentation/views/add_cover_screen.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_creation_review_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_empty_state.dart';
import '../unit/album_creation_draft_test.dart' show creationDraftFixture;
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;
import 'home_screen_test.dart' show FakeAuthViewModel;
import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeStorageService, FakeAlbumPersistenceService;

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

List<List<LayerModel>> _pages() => List.generate(
  6,
  (page) => [
    LayerModel(
      id: 'photo-$page',
      type: LayerType.image,
      position: const Offset(24, 26),
      width: 452,
      height: 282,
      imageUrl: page == 1
          ? null
          : 'asset:assets/frame_preview/${['alpine_lake', 'forest_trail', 'ocean_shore'][page % 3]}.jpg',
      imageBackground: 'shadow',
    ),
    LayerModel(
      id: 'text-$page',
      type: LayerType.text,
      position: const Offset(28, 325),
      width: 440,
      height: 40,
      text: page == 0 ? '여행의 조각' : '함께 걸었던 순간',
      textStyle: const TextStyle(fontSize: 20, color: Colors.black),
    ),
  ],
);

AlbumCreationDraft _draft() {
  final cover = coverSizes[1].withCoverType(PrintCoverType.hard);
  final canvas = coverCanvasBaseSize(cover);
  final pages = AlbumCreationTemplate.preparePages(
    _pages(),
    sourceCanvas: const Size(500, 375),
    cover: cover,
    clearSamplePhotos: false,
  );
  final json = creationDraftFixture(pages: pages).toJson();
  final size = {'width': canvas.width, 'height': canvas.height};
  json['canvasSizes'] = {'landscape': size};
  json['baseCanvasSize'] = size;
  json['editedCoverCanvasSize'] = size;
  json['pendingPhotos'] = [];
  json['selectedPhotoId'] = null;
  json['currentPage'] = 1;
  json['selectedSlot'] = {'page': 1, 'id': 'photo-1'};
  return AlbumCreationDraft.fromJson(json);
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 44, right: 24, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('EDITOR_FLOW_QA')) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/editor-flow-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<ProviderContainer> _boot(
  WidgetTester tester,
  MemoryCreationDraftStore store, {
  GlobalKey? capture,
  bool dark = false,
  double textScale = 1,
  AlbumCreationDraft? initialDraft,
}) async {
  final container = ProviderContainer(
    overrides: [
      albumCreationDraftStoreProvider.overrideWithValue(store),
      albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      authViewModelProvider.overrideWith(
        () => FakeAuthViewModel(
          const UserInfo(id: 'user', name: '우리', provider: 'email'),
        ),
      ),
      albumCreationCatalogProvider.overrideWith((ref) => Stream.value([])),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authViewModelProvider.future);
  await container.read(albumEditorViewModelProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: capture,
        child: wrapCreation(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumCreateFlowScreen(
                    initialDraft: initialDraft ?? _draft(),
                  ),
                ),
              ),
              child: const Text('앨범 생성 열기'),
            ),
          ),
          dark: dark,
          textScale: textScale,
        ),
      ),
    ),
  );
  await tester.tap(find.text('앨범 생성 열기'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(loadCreationFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets('restores photo-fill page and writes a resumable local draft', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    final store = MemoryCreationDraftStore();
    final container = await _boot(tester, store);
    final fill = tester.widget<TemplatePhotoFillStep>(
      find.byType(TemplatePhotoFillStep),
    );
    expect(fill.session!.page, 1);
    expect(fill.session!.selectedSlot, (page: 1, id: 'photo-1'));
    await tester.tap(find.byKey(const ValueKey('creation-save-draft')));
    await tester.pumpAndSettle();
    expect(store.draft!.title, '여행의 조각');
    expect(store.draft!.pages!.length, 6);
    expect(store.draft!.currentPage, 1);
    expect(
      (await container.read(albumCreationDraftProvider.future))!.id,
      store.draft!.id,
    );
    expect(find.text('이 기기에 임시 저장했어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cover review opens the chosen inner page and preserves the workspace and cover edits',
    (tester) async {
      _size(tester, const Size(390, 844));
      final store = MemoryCreationDraftStore();
      final container = await _boot(tester, store);
      final session = tester
          .widget<TemplatePhotoFillStep>(find.byType(TemplatePhotoFillStep))
          .session!;
      tester
          .widget<TemplatePhotoFillStep>(find.byType(TemplatePhotoFillStep))
          .onContinue();
      await tester.pumpAndSettle();
      expect(find.byType(AddCoverScreen), findsOneWidget);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      vm.updatePageLayers([
        for (final layer in vm.layers)
          layer.type == LayerType.text
              ? layer.copyWith(text: '다듬은 표지 문구')
              : layer,
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('전체 확인').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumCreationReviewSheet), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('creation-review-page-1')));
      await tester.pumpAndSettle();
      final restored = tester.widget<TemplatePhotoFillStep>(
        find.byType(TemplatePhotoFillStep),
      );
      expect(identical(restored.session, session), isTrue);
      expect(restored.session!.page, 1);
      expect(
        restored.pages.first
            .where((layer) => layer.type == LayerType.text)
            .single
            .text,
        '다듬은 표지 문구',
      );
      await tester.tap(find.byKey(const ValueKey('creation-save-draft')));
      await tester.pumpAndSettle();
      expect(
        store.draft!.pages!.first
            .where((layer) => layer.type == LayerType.text)
            .single
            .text,
        '다듬은 표지 문구',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resuming a linked draft enters the existing album editor without recreating an album',
    (tester) async {
      _size(tester, const Size(844, 390));
      final json = _draft().toJson()..['createdAlbumId'] = 12;
      final draft = AlbumCreationDraft.fromJson(json);
      final store = MemoryCreationDraftStore()..draft = draft;
      final container = await _boot(tester, store, initialDraft: draft);
      expect(find.byType(PageEditorScreen), findsOneWidget);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      expect(vm.editingAlbumId, 12);
      expect(vm.pages.length, 25);
      expect(vm.pages[1].layers.any((layer) => layer.id == 'photo-1'), isTrue);
      expect(store.writes, 0);
      expect(store.draft, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a saved editor checkpoint resumes exact page, crop, background and separate canvases',
    (tester) async {
      _size(tester, const Size(844, 390));
      final linked = AlbumCreationDraft.fromJson(
        _draft().toJson()..['createdAlbumId'] = 12,
      );
      final checkpoint = AlbumCreationEditorCheckpoint(
        pages: List.generate(
          25,
          (index) => AlbumPage(
            id: 'restored-page-$index',
            pageIndex: index,
            isCover: index == 0,
            backgroundColor: index == 3 ? 0xFFDAE8E3 : null,
            layers: index == 3
                ? [
                    LayerModel(
                      id: 'edited-photo',
                      type: LayerType.image,
                      position: const Offset(18, 20),
                      width: 264,
                      height: 160,
                      imageUrl: 'asset:assets/frame_preview/ocean_shore.jpg',
                      imageZoom: 1.8,
                      imageOffset: const Offset(14, -7),
                      imageBackground: 'archSoft',
                    ),
                    LayerModel(
                      id: 'edited-text',
                      type: LayerType.text,
                      position: const Offset(18, 188),
                      width: 264,
                      height: 25,
                      text: '편집에서 바꾼 내용',
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                  ]
                : index == 0
                ? _pages().first
                : [],
          ),
        ),
        pageIndex: 3,
        coverCanvas: const Size(500, 375),
        innerCanvas: const Size(300, 225),
        theme: CoverTheme.nature1,
      );
      final draft = AlbumCreationDraft.fromJson(
        linked.withEditorCheckpoint(checkpoint, cover: linked.cover).toJson(),
      );
      final store = MemoryCreationDraftStore()..draft = draft;
      final container = await _boot(tester, store, initialDraft: draft);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(vm.editingAlbumId, 12);
      expect(vm.currentPageIndex, 3);
      expect(vm.pages.length, 25);
      expect(vm.pages[3].id, 'restored-page-3');
      expect(vm.pages[3].backgroundColor, 0xFFDAE8E3);
      expect(vm.layers.last.text, '편집에서 바꾼 내용');
      expect(vm.layers.first.width, 264);
      expect(vm.layers.first.imageZoom, 1.8);
      expect(vm.layers.first.imageOffset, const Offset(14, -7));
      expect(vm.selectedTheme, CoverTheme.nature1);
      final state = container.read(albumEditorViewModelProvider).value!;
      expect(state.coverCanvasSize, const Size(500, 375));
      expect(state.innerCanvasSize, const Size(300, 225));
      expect(state.canUndo, isFalse);
      expect(vm.hasUnsavedChanges, isTrue);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed draft save keeps the creation route and enables retry', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    final store = MemoryCreationDraftStore()..failSave = true;
    await _boot(tester, store);
    await tester.tap(find.byKey(const ValueKey('creation-exit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('임시 저장 후 나가기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumCreateFlowScreen), findsOneWidget);
    expect(store.draft, isNull);
    store.failSave = false;
    await tester.tap(find.byKey(const ValueKey('creation-exit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('임시 저장 후 나가기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumCreateFlowScreen), findsNothing);
    expect(store.draft, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'discard removes only the current draft and cancellation keeps work',
    (tester) async {
      _size(tester, const Size(390, 844));
      final store = MemoryCreationDraftStore()..draft = _draft();
      await _boot(tester, store);
      await tester.tap(find.byKey(const ValueKey('creation-exit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계속 만들기'));
      await tester.pumpAndSettle();
      expect(store.draft, isNotNull);
      await tester.tap(find.byKey(const ValueKey('creation-exit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장 안 함'));
      await tester.pumpAndSettle();
      expect(store.draft, isNull);
      expect(find.byType(AlbumCreateFlowScreen), findsNothing);
    },
  );

  testWidgets(
    'paused app saves the current workspace without a blocking dialog',
    (tester) async {
      _size(tester, const Size(390, 844));
      final store = MemoryCreationDraftStore();
      await _boot(tester, store);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(store.draft!.currentPage, 1);
      expect(find.byType(AlertDialog), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets(
    'duplicate saves and exit are disabled until persistence completes',
    (tester) async {
      _size(tester, const Size(390, 844));
      final store = MemoryCreationDraftStore()..saving = Completer<void>();
      await _boot(tester, store);
      await tester.tap(find.byKey(const ValueKey('creation-save-draft')));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('creation-save-draft')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('creation-exit')))
            .onPressed,
        isNull,
      );
      store.saving!.complete();
      await tester.pumpAndSettle();
      expect(store.writes, 1);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('creation workspace and exit dialog fit $size dark=$dark', (
        tester,
      ) async {
        _size(tester, size);
        final capture = GlobalKey();
        await _boot(
          tester,
          MemoryCreationDraftStore(),
          capture: capture,
          dark: dark,
        );
        await _capture(
          tester,
          capture,
          'creation-workspace-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        tester
            .widget<TemplatePhotoFillStep>(find.byType(TemplatePhotoFillStep))
            .onContinue();
        await tester.pumpAndSettle();
        await _capture(
          tester,
          capture,
          'creation-cover-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await tester.tap(find.byKey(const ValueKey('creation-exit')));
        await tester.pumpAndSettle();
        await _capture(
          tester,
          capture,
          'creation-draft-exit-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        expect(tester.takeException(), isNull);
      });
      testWidgets('home draft resume opens the saved page $size dark=$dark', (
        tester,
      ) async {
        _size(tester, size);
        final capture = GlobalKey();
        final store = MemoryCreationDraftStore()..draft = _draft();
        final repo = MockAlbumRepository();
        stubFetchMyAlbums(repo, []);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeUiStateProvider.overrideWith(
                () => HomeUiStateNotifier(initialIndex: 0),
              ),
              albumCreationDraftStoreProvider.overrideWithValue(store),
              albumRepositoryProvider.overrideWithValue(repo),
              authViewModelProvider.overrideWith(
                () => FakeAuthViewModel(
                  const UserInfo(id: 'user', name: '우리', provider: 'email'),
                ),
              ),
              albumCreationCatalogProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              notificationUnreadCountProvider.overrideWith((ref) async => 0),
            ],
            child: RepaintBoundary(
              key: capture,
              child: wrapCreation(
                const HomeScreen(),
                dark: dark,
                showShell: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('이어 만들기'), findsOneWidget);
        await _capture(
          tester,
          capture,
          'creation-home-resume-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await tester.tap(find.text('이어 만들기'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TemplatePhotoFillStep>(find.byType(TemplatePhotoFillStep))
              .session!
              .page,
          1,
        );
        expect(tester.takeException(), isNull);
      });
      testWidgets(
        'album review uses actual ratio, empty-slot status and page navigation $size dark=$dark',
        (tester) async {
          _size(tester, size);
          final capture = GlobalKey();
          int? selected;
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: wrapCreation(
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () async =>
                        selected = await showAlbumCreationReview(
                          context,
                          pages: _pages(),
                          innerPageCount: 24,
                          canvasSize: const Size(500, 375),
                        ),
                    child: const Text('전체 확인'),
                  ),
                ),
                dark: dark,
              ),
            ),
          );
          await tester.tap(find.text('전체 확인'));
          await tester.pumpAndSettle();
          expect(find.text('빈 사진 자리 1개'), findsOneWidget);
          expect(find.text('표지 · 내지 24쪽'), findsOneWidget);
          await _capture(
            tester,
            capture,
            'creation-review-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
          await tester.tap(
            find.byKey(const ValueKey('creation-review-page-1')),
          );
          await tester.pumpAndSettle();
          expect(selected, 1);
          await tester.tap(find.text('전체 확인'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('creation-review-start')));
          await tester.pumpAndSettle();
          expect(selected, -1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('empty home exposes resume independently from new album', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    var resumed = false;
    await tester.pumpWidget(
      wrapCreation(
        HomeEmptyState(onCreate: () {}, onResumeDraft: () => resumed = true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이어 만들기'));
    expect(resumed, isTrue);
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'creation header, cover actions, review and exit fit large text at $size',
      (tester) async {
        _size(tester, size);
        await _boot(tester, MemoryCreationDraftStore(), textScale: 1.6);
        tester
            .widget<TemplatePhotoFillStep>(find.byType(TemplatePhotoFillStep))
            .onContinue();
        await tester.pumpAndSettle();
        await tester.tap(find.text('전체 확인').first);
        await tester.pumpAndSettle();
        expect(find.byType(AlbumCreationReviewSheet), findsOneWidget);
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('creation-exit')));
        await tester.pumpAndSettle();
        expect(find.text('계속 만들기'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

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
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/moments/presentation/widgets/first_book_next_step_card.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_creation_review_sheet.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_empty_state.dart';
import '../unit/album_creation_draft_test.dart' show creationDraftFixture;
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;
import 'home_screen_test.dart' show FakeAuthViewModel;
import '../helpers/unified_creation_fixtures.dart';

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

AlbumCreationDraft _draft({bool pendingPhoto = false}) {
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
  if (!pendingPhoto) {
    json['pendingPhotos'] = [];
    json['selectedPhotoId'] = null;
  }
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
  AlbumCreateFlowScreen? initialScreen,
  RecordingCreationAlbums? albums,
}) async {
  final container = ProviderContainer(
    overrides: [
      albumCreationDraftStoreProvider.overrideWithValue(store),
      ...unifiedCreationBackendOverrides(
        albums: albums ?? RecordingCreationAlbums(owner: 'user'),
      ),
      albumEditorOwnerReaderProvider.overrideWithValue(() => 'user'),
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
                  builder: (_) =>
                      initialScreen ??
                      AlbumCreateFlowScreen(
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

Future<void> _continueToEditor(WidgetTester tester) async {
  // Setup owns the create boundary; all document editing starts in the editor.
  tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).onNext();
  await tester.pumpAndSettle();
  expect(find.byType(PageEditorScreen), findsOneWidget);
  expect(find.byType(AlbumCreateFlowScreen), findsNothing);
}

void main() {
  setUpAll(loadCreationFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets(
    'catalogue header back returns to methods before leaving creation',
    (tester) async {
      _size(tester, const Size(390, 844));
      final store = MemoryCreationDraftStore();
      await _boot(tester, store, initialScreen: const AlbumCreateFlowScreen());
      await tester.tap(find.byKey(const ValueKey('creation-open-catalog')));
      await tester.pumpAndSettle();
      expect(find.text('디자인 고르기'), findsOneWidget);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creation-hub-back')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('creation-manual-start')),
        findsOneWidget,
      );
      expect(find.text('앨범 만들기를 나갈까요?'), findsNothing);
      expect(store.writes, 0);
      await tester.tap(find.byKey(const ValueKey('creation-manual-start')));
      await tester.pumpAndSettle();
      expect(find.text('책장에 표시할 이름'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'automatic template previews stay examples and preserve local photos',
    (tester) async {
      _size(tester, const Size(390, 844));
      final store = MemoryCreationDraftStore();
      final local = AssetEntity(
        id: 'my-local-photo',
        typeInt: 1,
        width: 1600,
        height: 1200,
      );
      await _boot(
        tester,
        store,
        initialScreen: AlbumCreateFlowScreen(
          initialAlbumTitle: '템플릿 작업',
          initialCoverSize: coverSizes[1],
          initialTemplatePreviewImages: const [
            'asset:assets/frame_preview/alpine_lake.jpg',
          ],
          initialTemplatePages: [
            [],
            [
              LayerModel(
                id: 'example',
                type: LayerType.image,
                position: Offset.zero,
              ),
            ],
            [
              LayerModel(
                id: 'personal',
                type: LayerType.image,
                position: Offset.zero,
                asset: local,
              ),
            ],
          ],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('creation-save-draft')));
      await tester.pumpAndSettle();
      final pages = store.draft!.pages!;
      expect(pages[1].single.isTemplateContent, isTrue);
      expect(pages[2].single.asset?.id, local.id);
      expect(pages[2].single.previewUrl, isNull);
      expect(pages[2].single.isTemplateContent, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restores legacy photo-fill work at setup and saves a resumable draft',
    (tester) async {
      _size(tester, const Size(390, 844));
      final store = MemoryCreationDraftStore();
      final container = await _boot(tester, store);
      final setup = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      expect(setup.albumTitle, '여행의 조각');
      expect(setup.documentPages!.length, 6);
      expect(find.byType(PageEditorScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('creation-save-draft')));
      await tester.pumpAndSettle();
      expect(store.draft!.title, '여행의 조각');
      expect(store.draft!.pages!.length, 6);
      expect(store.draft!.currentPage, 1);
      expect(store.draft!.selectedSlot, (page: 1, id: 'photo-1'));
      expect(store.draft!.step, 0);
      expect(store.draft!.showPhotoFill, isFalse);
      expect(
        (await container.read(albumCreationDraftProvider.future))!.id,
        store.draft!.id,
      );
      expect(find.text('이 기기에 임시 저장했어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unified editor restores the photo queue and preserves cover edits across page navigation',
    (tester) async {
      _size(tester, const Size(390, 844));
      final store = MemoryCreationDraftStore();
      final albums = RecordingCreationAlbums(owner: 'user');
      final container = await _boot(
        tester,
        store,
        albums: albums,
        initialDraft: _draft(pendingPhoto: true),
      );
      await _continueToEditor(tester);
      final editor = tester.widget<PageEditorScreen>(
        find.byType(PageEditorScreen),
      );
      final session = editor.initialPhotoFillSession!;
      expect(session.page, 1);
      expect(session.selectedSlot, (page: 1, id: 'photo-1'));
      expect(session.pendingPhotos.single.id, 'local-photo-1');
      expect(session.selectedPhoto?.id, 'local-photo-1');
      expect(albums.creates, 1);
      expect(albums.requestedOwners, ['user']);
      expect(albums.requestIds.single, isNotEmpty);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      expect(vm.editingAlbumId, albums.albumId);
      expect(vm.currentPageIndex, 1);
      await tester.tap(find.byKey(const ValueKey('editor-page-0')));
      await tester.pumpAndSettle();
      expect(vm.currentPageIndex, 0);
      vm.updatePageLayers([
        for (final layer in vm.layers)
          layer.type == LayerType.text
              ? layer.copyWith(text: '다듬은 표지 문구')
              : layer,
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('editor-page-1')));
      await tester.pumpAndSettle();
      expect(vm.currentPageIndex, 1);
      expect(
        identical(
          tester
              .widget<PageEditorScreen>(find.byType(PageEditorScreen))
              .initialPhotoFillSession,
          session,
        ),
        isTrue,
      );
      expect(
        vm.pages.first.layers
            .where((layer) => layer.type == LayerType.text)
            .single
            .text,
        '다듬은 표지 문구',
      );
      await tester.tap(find.byKey(const ValueKey('editor-save-draft')));
      await tester.pumpAndSettle();
      expect(store.draft!.createdAlbumId, albums.albumId);
      expect(store.draft!.editorCheckpoint!.pageIndex, 1);
      expect(
        store.draft!.editorCheckpoint!.sourceUpdatedAt,
        RecordingCreationAlbums.revision,
      );
      expect(store.draft!.editorCheckpoint!.sourceOwnerId, 'user');
      expect(store.draft!.editorCheckpoint!.sourceMemberRole, 'OWNER');
      expect(store.draft!.pendingPhotos.single.id, 'local-photo-1');
      expect(store.draft!.selectedPhotoId, 'local-photo-1');
      expect(
        store.draft!.editorCheckpoint!.pages.first.layers
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
      final albums = RecordingCreationAlbums(owner: 'user', albumId: 12);
      final container = await _boot(
        tester,
        store,
        initialDraft: draft,
        albums: albums,
      );
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(albums.creates, 0);
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
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pumpAndSettle();
      }
      expect(store.draft!.currentPage, 1);
      expect(find.byType(AlertDialog), findsNothing);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pumpAndSettle();
      }
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
      testWidgets('creation setup, editor and exit dialog fit $size dark=$dark', (
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
          'creation-settings-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await _continueToEditor(tester);
        await _capture(
          tester,
          capture,
          'creation-editor-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await tester.tap(find.byTooltip('편집 마치기'));
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
        final albums = RecordingCreationAlbums(owner: 'user');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeUiStateProvider.overrideWith(
                () => HomeUiStateNotifier(initialIndex: 0),
              ),
              albumCreationDraftStoreProvider.overrideWithValue(store),
              ...unifiedCreationBackendOverrides(albums: albums),
              albumEditorOwnerReaderProvider.overrideWithValue(() => 'user'),
              authViewModelProvider.overrideWith(
                () => FakeAuthViewModel(
                  const UserInfo(id: 'user', name: '우리', provider: 'email'),
                ),
              ),
              albumCreationCatalogProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              notificationUnreadCountProvider.overrideWith((ref) async => 0),
              momentEntryJournalProvider.overrideWith(
                (ref) async => MomentJournal(
                  today: DateTime.utc(2026, 11, 11),
                  weekStart: DateTime.utc(2026, 11, 9),
                  month: DateTime.utc(2026, 11),
                  records: const [],
                  weekPhotoCount: 0,
                ),
              ),
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
        final resume = find.descendant(
          of: find.byType(FirstBookNextStepCard),
          matching: find.text('이어서 만들기'),
        );
        expect(resume, findsOneWidget);
        final dailyRecord = find.byKey(
          const ValueKey('home-monthly-feed-record'),
        );
        await tester.ensureVisible(dailyRecord);
        expect(dailyRecord.hitTestable(), findsOneWidget);
        await _capture(
          tester,
          capture,
          'creation-home-resume-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await tester.ensureVisible(resume);
        expect(resume.hitTestable(), findsOneWidget);
        await tester.tap(resume);
        await tester.pumpAndSettle();
        expect(find.byType(AlbumCreateStep1), findsOneWidget);
        expect(find.byType(PageEditorScreen), findsNothing);
        await _continueToEditor(tester);
        expect(
          tester
              .widget<PageEditorScreen>(find.byType(PageEditorScreen))
              .initialPhotoFillSession!
              .page,
          1,
        );
        expect(albums.creates, 1);
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

  testWidgets(
    'empty home keeps a new album action without a duplicate resume',
    (tester) async {
      _size(tester, const Size(390, 844));
      var created = false;
      await tester.pumpWidget(
        wrapCreation(HomeEmptyState(onCreate: () => created = true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('이어서 만들기'), findsNothing);
      final create = find.byKey(const ValueKey('empty-home-create'));
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      expect(created, isTrue);
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('creation settings, editor and exit fit large text at $size', (
      tester,
    ) async {
      _size(tester, size);
      final container = await _boot(
        tester,
        MemoryCreationDraftStore(),
        textScale: 1.6,
      );
      expect(find.byType(AlbumCreateStep1), findsOneWidget);
      await _continueToEditor(tester);
      expect(find.byKey(const ValueKey('editor-page-rail')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('editor-save-draft')));
      await tester.pumpAndSettle();
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final originalCount = vm.innerPageCount;
      final addPage = find.byKey(const Key('addInnerPagesButton'));
      await tester.ensureVisible(addPage);
      await tester.tap(addPage);
      await tester.pumpAndSettle();
      expect(vm.innerPageCount, originalCount + 2);
      expect(vm.hasUnsavedChanges, isTrue);
      await tester.tap(find.byTooltip('편집 마치기'));
      await tester.pumpAndSettle();
      expect(find.text('계속 편집'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

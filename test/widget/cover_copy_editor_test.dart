import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/cover_copy_editor.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../helpers/unified_creation_fixtures.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;
import 'album_settings_redesign_test.dart' show openAlbumSettingsSection;

class _Auth extends AuthViewModel {
  String ownerId = 'copy-owner';

  @override
  FutureOr<UserInfo?> build() =>
      UserInfo(id: ownerId, name: '우리', provider: 'email');
  void owner(String id) {
    ownerId = id;
    state = AsyncData(UserInfo(id: id, name: '우리', provider: 'email'));
  }
}

List<LayerModel> _cover({bool photo = false, String prefix = ''}) => [
  LayerModel(
    id: '${prefix}paper',
    type: LayerType.decoration,
    position: Offset.zero,
    width: 500,
    height: 500,
    decorationFillColor: '#FAF7F0',
    isTemplateContent: true,
    zIndex: -1,
  ),
  LayerModel(
    id: '${prefix}photo',
    type: LayerType.image,
    position: const Offset(35, 35),
    width: 430,
    height: 280,
    imageUrl: photo ? 'asset:assets/frame_preview/ocean_shore.jpg' : null,
    isTemplateContent: true,
  ),
  LayerModel(
    id: '${prefix}title',
    type: LayerType.text,
    position: const Offset(35, 337),
    width: 430,
    height: 64,
    text: '여행의 조각',
    textStyle: const TextStyle(
      fontFamily: 'NotoSans',
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: Color(0xff253d43),
    ),
    isTemplateContent: true,
  ),
  LayerModel(
    id: '${prefix}date',
    type: LayerType.text,
    position: const Offset(35, 425),
    width: 430,
    height: 28,
    text: 'OCTOBER, 2026',
    textStyle: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 16,
      color: Color(0xff667777),
    ),
    isTemplateContent: true,
  ),
];

AlbumCreationTemplate _template() => AlbumCreationTemplate(
  title: '책장 속 여행',
  previewUrl: '',
  isPremium: false,
  cover: defaultCoverSize,
  pages: [_cover(), []],
  pagesCanvasSize: const Size(500, 500),
  variants: {
    'landscape4x3': [_cover(prefix: 'wide-'), []],
  },
  variantCanvasSizes: {'landscape4x3': const Size(500, 500)},
  preserveTypography: true,
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  if (kIsWeb) {
    // Browser image streams can need another fake frame before precacheImage's
    // future completes. Keep yielding real asset work without awaiting that
    // stream from inside runAsync.
    for (var frame = 0; frame < 20; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    return;
  }
  // Native image streams also need fake-clock frames; never await an image
  // completion alone while the test clock is stopped.
  var stable = 0;
  for (var frame = 0; frame < 160; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 32));
    stable =
        PaintingBinding.instance.imageCache.pendingImageCount == 0 &&
            frame >= 12
        ? stable + 1
        : 0;
    if (stable == 4) break;
    if (frame == 159)
      fail('Cover copy artwork did not settle within 160 frames.');
  }
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  _Auth? auth,
  RecordingCreationAlbums? albums,
  MemoryCreationDraftStore? store,
  AlbumCreationDraft? draft,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final activeAuth = auth ?? _Auth();
  final container = ProviderContainer(
    overrides: [
      ...unifiedCreationBackendOverrides(
        albums: albums ?? RecordingCreationAlbums(owner: activeAuth.ownerId),
      ),
      authViewModelProvider.overrideWith(() => activeAuth),
      albumEditorOwnerReaderProvider.overrideWithValue(
        () => activeAuth.ownerId,
      ),
      albumEditorOwnerChangesProvider.overrideWith((_) => const Stream.empty()),
      albumCreationCatalogProvider.overrideWith((_) => Stream.value([])),
      albumCreationDraftStoreProvider.overrideWithValue(
        store ?? MemoryCreationDraftStore(),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    container.dispose();
  });
  await container.read(authViewModelProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: wrapCreation(
        AlbumCreateFlowScreen(
          initialCreationTemplate: draft == null ? _template() : null,
          initialDraft: draft,
        ),
        showShell: false,
      ),
    ),
  );
  await _settle(tester);
  return container;
}

AlbumCreateStep1 _setup(WidgetTester tester) =>
    tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1));
String _title(AlbumCreateStep1 setup) => setup.coverLayers!
    .firstWhere((layer) => layer.type == LayerType.text)
    .text!;

Future<void> _open(WidgetTester tester) async {
  await openAlbumSettingsSection(tester, 'name');
  final edit = find.byKey(const ValueKey('creation-cover-copy-edit'));
  await tester.ensureVisible(edit);
  await tester.pumpAndSettle();
  await tester.tap(edit);
  await _settle(tester);
  expect(find.byType(CoverCopyEditor), findsOneWidget);
}

void main() {
  setUpAll(() async {
    if (!kIsWeb) await loadCreationFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'bookshelf name is separate and applied cover words survive size, draft and editor entry',
    (tester) async {
      final store = MemoryCreationDraftStore();
      final albums = RecordingCreationAlbums(owner: 'copy-owner');
      final container = await _mount(tester, store: store, albums: albums);
      await openAlbumSettingsSection(tester, 'name');
      expect(find.text('책장에 표시할 이름'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('creation-album-title')),
        '가족의 제주 여행',
      );
      expect(_title(_setup(tester)), '여행의 조각');
      tester.testTextInput.hide();
      await _open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('cover-copy-field-title')),
        '우리의 제주',
      );
      await tester.pump();
      final preview = tester.widget<TemplatePageRenderer>(
        find.byKey(const ValueKey('cover-copy-preview')),
      );
      expect(
        preview.layers.firstWhere((layer) => layer.id == 'title').text,
        '우리의 제주',
      );
      expect(_title(_setup(tester)), '여행의 조각');
      await tester.tap(find.byKey(const ValueKey('cover-copy-apply')));
      await tester.pumpAndSettle();
      expect(_setup(tester).albumTitle, '가족의 제주 여행');
      expect(_title(_setup(tester)), '우리의 제주');
      expect(
        _setup(tester).coverLayers!
            .firstWhere((layer) => layer.id == 'date')
            .isTemplateContent,
        isTrue,
      );
      // Settings and its renderer remain available until the single editor entry.
      final renderedCover = tester
          .widgetList<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
          .where(
            (renderer) => renderer.layers.any((layer) => layer.id == 'title'),
          );
      expect(renderedCover, isNotEmpty);
      for (final renderer in renderedCover) {
        expect(
          renderer.layers.firstWhere((layer) => layer.id == 'title').text,
          '우리의 제주',
        );
      }
      _setup(tester).onCoverSelected(coverSizes[1]);
      await tester.pumpAndSettle();
      expect(_title(_setup(tester)), '우리의 제주');
      expect(_setup(tester).selectedCover!.ratio, 4 / 3);
      await tester.tap(find.byKey(const ValueKey('creation-save-draft')));
      await tester.pumpAndSettle();
      expect(store.draft!.title, '가족의 제주 여행');
      expect(
        store.draft!.pages!.first
            .firstWhere((layer) => layer.type == LayerType.text)
            .text,
        '우리의 제주',
      );
      for (final pages in store.draft!.variants!.values) {
        expect(
          pages.first.firstWhere((layer) => layer.type == LayerType.text).text,
          '우리의 제주',
        );
      }
      _setup(tester).onNext();
      await _settle(tester);
      final editor = tester.widget<PageEditorScreen>(
        find.byType(PageEditorScreen),
      );
      final vm = container.read(albumEditorViewModelProvider.notifier);
      expect(find.byType(AlbumCreateStep1), findsNothing);
      expect(find.byType(TemplatePhotoFillStep), findsNothing);
      expect(albums.creates, 1);
      expect(albums.requests.single.title, '가족의 제주 여행');
      expect(albums.requestedOwners, ['copy-owner']);
      expect(vm.editingAlbumId, albums.albumId);
      expect(vm.selectedCover.ratio, 4 / 3);
      expect(editor.creationDraftOwner, 'copy-owner');
      expect(editor.creationDraftId, store.draft!.id);
      expect(store.draft!.createdAlbumId, albums.albumId);
      expect(store.draft!.title, '가족의 제주 여행');
      final checkpoint = store.draft!.editorCheckpoint!;
      expect(checkpoint.sourceOwnerId, 'copy-owner');
      expect(checkpoint.pages, hasLength(vm.pages.length));
      expect(
        vm.pages.first.layers
            .firstWhere((layer) => layer.type == LayerType.text)
            .text,
        '우리의 제주',
      );
      expect(
        checkpoint.pages.first.layers
            .firstWhere((layer) => layer.type == LayerType.text)
            .text,
        '우리의 제주',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restored AI photo selection stays pending through unified editor entry',
    (tester) async {
      final pages = [_cover(), <LayerModel>[]];
      final photo = AssetEntity(
        id: 'accepted-ai-photo',
        typeInt: 1,
        width: 2400,
        height: 1600,
      );
      final store = MemoryCreationDraftStore();
      final container = await _mount(
        tester,
        store: store,
        draft: AlbumCreationDraft(
          id: 'accepted-ai-draft',
          updatedAt: DateTime.utc(2026, 10, 28),
          title: 'AI로 만든 여행',
          cover: defaultCoverSize,
          pageCount: 20,
          step: 1,
          showPhotoFill: true,
          hasSelectedMode: true,
          sourceLabel: 'AI 템플릿',
          usesPhysicalCanvas: true,
          preserveTypography: true,
          templateTitle: 'AI 디자인',
          pages: pages,
          basePages: pages,
          pendingPhotos: [photo],
          selectedPhotoId: photo.id,
          selectedSlot: (page: 0, id: 'photo'),
        ),
      );
      expect(find.byType(AlbumCreateStep1), findsOneWidget);
      expect(find.byType(TemplatePhotoFillStep), findsNothing);
      expect(_setup(tester).albumTitle, 'AI로 만든 여행');
      expect(_title(_setup(tester)), '여행의 조각');
      _setup(tester).onNext();
      await _settle(tester);
      final editor = tester.widget<PageEditorScreen>(
        find.byType(PageEditorScreen),
      );
      final vm = container.read(albumEditorViewModelProvider.notifier);
      expect(find.byType(TemplatePhotoFillStep), findsNothing);
      expect(editor.creationDraftOwner, 'copy-owner');
      expect(editor.initialSelectedLayerId, 'photo');
      expect(editor.initialPhotoFillSession!.pendingPhotos, [photo]);
      expect(editor.initialPhotoFillSession!.selectedPhoto, same(photo));
      expect(
        vm.pages.first.layers
            .firstWhere((layer) => layer.id == 'photo')
            .hasImageSource,
        isFalse,
      );
      final linked = store.draft!;
      expect(linked.createdAlbumId, vm.editingAlbumId);
      expect(linked.sourceLabel, 'AI 템플릿');
      expect(linked.pendingPhotos, [photo]);
      expect(linked.selectedPhotoId, photo.id);
      expect(
        linked.editorCheckpoint!.pages.first.layers
            .firstWhere((layer) => layer.id == 'photo')
            .hasImageSource,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancel leaves sample words and markers unchanged', (
    tester,
  ) async {
    await _mount(tester);
    final original = _setup(tester).coverLayers!;
    await _open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('cover-copy-field-title')),
      '적용하지 않을 문구',
    );
    await tester.tap(find.byKey(const ValueKey('cover-copy-cancel')));
    await tester.pumpAndSettle();
    expect(_setup(tester).coverLayers, same(original));
    expect(_title(_setup(tester)), '여행의 조각');
    expect(
      original.firstWhere((layer) => layer.id == 'title').isTemplateContent,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale editor callback cannot change a different cover', (
    tester,
  ) async {
    await _mount(tester);
    final setup = _setup(tester);
    await _open(tester);
    final editor = tester.widget<CoverCopyEditor>(find.byType(CoverCopyEditor));
    setup.onCoverSelected(defaultCoverSize.withCoverType(PrintCoverType.hard));
    await tester.pumpAndSettle();
    editor.onApply({'title': '오래된 창의 문구'});
    await tester.pumpAndSettle();
    expect(find.byType(CoverCopyEditor), findsNothing);
    expect(_setup(tester).selectedCover!.coverType, PrintCoverType.hard);
    expect(_title(_setup(tester)), '여행의 조각');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'owner change hides private preview and removes only its own route',
    (tester) async {
      final auth = _Auth();
      await _mount(tester, auth: auth);
      await _open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('cover-copy-field-title')),
        '비공개 작업 문구',
      );
      final navigation = Navigator.of(
        tester.element(find.byType(CoverCopyEditor)),
        rootNavigator: true,
      );
      unawaited(
        navigation.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('다른 화면은 유지')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      auth.owner('other-owner');
      await tester.pump();
      expect(find.byKey(const ValueKey('cover-copy-preview')), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('다른 화면은 유지'), findsOneWidget);
      expect(find.byType(CoverCopyEditor, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large text keyboard keeps apply and cancel reachable and exports actual preview',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [authViewModelProvider.overrideWith(_Auth.new)],
      );
      addTearDown(container.dispose);
      await container.read(authViewModelProvider.future);
      final key = GlobalKey();
      final cover = _cover(photo: true);
      var applied = <String, String>{};
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: wrapCreation(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(viewInsets: const EdgeInsets.only(bottom: 260)),
                child: RepaintBoundary(
                  key: key,
                  child: CoverCopyEditor(
                    layers: cover,
                    cover: defaultCoverSize,
                    ownerId: 'copy-owner',
                    isCurrent: () => true,
                    onApply: (value) => applied = value,
                    onCancel: () {},
                    preserveTypography: true,
                  ),
                ),
              ),
            ),
            showShell: false,
            dark: true,
            textScale: 1.8,
          ),
        ),
      );
      await _settle(tester);
      final field = find.byKey(const ValueKey('cover-copy-field-title'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '우리의 제주');
      await tester.pumpAndSettle();
      for (final id in ['cancel', 'apply']) {
        final action = find.byKey(ValueKey('cover-copy-$id'));
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(540));
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.byKey(const ValueKey('cover-copy-apply')));
      expect(applied['title'], '우리의 제주');
      expect(cover.firstWhere((layer) => layer.id == 'title').text, '여행의 조각');
      expect(tester.takeException(), isNull);
      const directory = String.fromEnvironment('COVER_COPY_CAPTURE_DIR');
      if (directory.isNotEmpty) {
        // Show the actual photo and edited lettering without the keyboard overlay.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: wrapCreation(
              RepaintBoundary(
                key: key,
                child: CoverCopyEditor(
                  layers: cover,
                  cover: defaultCoverSize,
                  ownerId: 'copy-owner',
                  isCurrent: () => true,
                  onApply: (_) {},
                  onCancel: () {},
                  preserveTypography: true,
                ),
              ),
              showShell: false,
            ),
          ),
        );
        await _settle(tester);
        await tester.enterText(
          find.byKey(const ValueKey('cover-copy-field-title')),
          '우리의 제주',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('cover-copy-preview')),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final picture = await boundary.toImage(pixelRatio: 2);
          try {
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final target = File('$directory/cover-copy-editor.png');
            await target.parent.create(recursive: true);
            await target.writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            picture.dispose();
          }
        });
      }
    },
  );
}

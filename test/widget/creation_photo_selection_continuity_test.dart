import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/data/gallery/browser_gallery_repository.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_files.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_photo_fill_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/gallery_thumb_tile.dart';

import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../helpers/unified_creation_fixtures.dart';
import '../support/store_detail_loading.dart' show settleStoreDetail;
import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

class _Auth extends AuthViewModel {
  _Auth({this.initialUser});
  final Future<UserInfo?>? initialUser;
  String? sessionOwner = 'owner-a';

  @override
  Future<UserInfo?> build() =>
      initialUser ??
      Future.value(
        const UserInfo(id: 'owner-a', name: '우리', provider: 'email'),
      );

  void changeTo(String id) {
    sessionOwner = id;
    state = AsyncData(UserInfo(id: id, name: '다른 계정', provider: 'email'));
  }

  void loading() => state = const AsyncLoading();

  void confirmLogout() {
    sessionOwner = null;
    state = const AsyncData(null);
  }
}

List<List<LayerModel>> _pages() {
  final canvas = coverCanvasBaseSize(defaultCoverSize);
  return [
    for (var index = 0; index < 3; index++)
      [
        LayerModel(
          id: 'old-photo-$index',
          type: LayerType.image,
          position: const Offset(40, 40),
          width: canvas.width - 80,
          height: canvas.height - 80,
          imageBackground: 'none',
        ),
      ],
  ];
}

AlbumCreationDraft _draft({List<BrowserPhotoAsset> pending = const []}) {
  final pages = _pages();
  return AlbumCreationDraft(
    id: 'pending-photos-draft',
    updatedAt: DateTime(2026, 10, 21),
    title: '사진을 고른 앨범',
    cover: defaultCoverSize,
    pageCount: 20,
    step: 1,
    showPhotoFill: true,
    hasSelectedMode: true,
    sourceLabel: '선택한 템플릿',
    usesPhysicalCanvas: true,
    preserveTypography: true,
    templateTitle: '원래 디자인',
    pages: pages,
    basePages: pages,
    baseCanvasSize: coverCanvasBaseSize(defaultCoverSize),
    pendingPhotos: pending,
    selectedPhotoId: pending.lastOrNull?.id,
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  var stableFrames = 0;
  for (var attempt = 0; attempt < 150; attempt++) {
    bool ready(Finder finder) => finder.evaluate().every(
      (element) => find
          .descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(RawImage),
          )
          .evaluate()
          .any((pixels) => (pixels.widget as RawImage).image != null),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 40));
    // A newly revealed lazy thumbnail may start its codec on the next frame.
    // Keep the real event loop moving until both the photos and UI are quiet.
    // Catalog artwork may intentionally resolve to its errorBuilder fallback.
    if (ready(find.byType(GalleryThumbTile)) &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        !tester.binding.hasScheduledFrame) {
      stableFrames++;
      if (stableFrames == 3) return;
    } else {
      stableFrames = 0;
    }
  }
  fail('Creation photos did not finish loading.');
}

TemplatePhotoFillStep _fill(WidgetTester tester) =>
    tester.widget<TemplatePhotoFillStep>(find.byType(TemplatePhotoFillStep));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await _settle(tester);
}

Future<
  ({
    ProviderContainer container,
    List<BrowserPhotoAsset> photos,
    MemoryCreationDraftStore store,
    RecordingCreationAlbums albums,
  })
>
_boot(
  WidgetTester tester, {
  bool restoredPhotos = false,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = false,
  Completer<UserInfo?>? authLoading,
  GlobalKey? capture,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final repository = BrowserGalleryRepository(currentOwner: () => 'owner-a');
  await tester.runAsync(
    () => repository.importFiles([
      for (final width in [40, 60])
        BrowserPhotoFile(
          name: 'photo-$width.png',
          size: browserPhotoFixture(width: width, height: 40).length,
          readBytes: () async => browserPhotoFixture(width: width, height: 40),
        ),
    ]),
  );
  final photos = repository.photos;
  final store = MemoryCreationDraftStore();
  final albums = RecordingCreationAlbums(owner: 'owner-a');
  final container = ProviderContainer(
    overrides: [
      albumCreationDraftStoreProvider.overrideWithValue(store),
      ...unifiedCreationBackendOverrides(albums: albums),
      albumEditorOwnerReaderProvider.overrideWith((ref) {
        final auth = ref.read(authViewModelProvider.notifier) as _Auth;
        var observed = ref.read(orderSessionOwnerProvider);
        ref.listen(orderSessionOwnerProvider, (_, next) => observed = next);
        // VM disposal also reads the owner, after provider reads are forbidden.
        return () {
          if (observed.observed) return observed.ownerId;
          return auth.sessionOwner;
        };
      }),
      albumCurrentSessionOwnerProvider.overrideWith((ref) {
        ref.watch(orderSessionOwnerProvider);
        ref.watch(authViewModelProvider);
        return ref.read(albumEditorOwnerReaderProvider)();
      }),
      galleryRepositoryProvider.overrideWithValue(repository),
      authViewModelProvider.overrideWith(
        () => _Auth(initialUser: authLoading?.future),
      ),
      albumCreationCatalogProvider.overrideWith(
        (ref) => Stream.value([bundledCreationTemplates.first]),
      ),
    ],
  );
  addTearDown(container.dispose);
  if (authLoading == null) {
    await container.read(authViewModelProvider.future);
  } else {
    container.read(authViewModelProvider);
  }
  await container.read(albumEditorViewModelProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: capture,
        child: wrapCreation(
          AlbumCreateFlowScreen(
            initialDraft: _draft(pending: restoredPhotos ? photos : []),
          ),
          dark: dark,
          textScale: textScale,
          showShell: false,
        ),
      ),
    ),
  );
  await _settle(tester);
  return (container: container, photos: photos, store: store, albums: albums);
}

Future<void> _memoryImage(WidgetTester tester, GlobalKey key, String id) async {
  if (!const bool.fromEnvironment('DESIGN_CONTINUATION_MEMORY_IMAGES')) return;
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final pixels = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
      // RAM-only inspection. No preview files or image exports are written.
      // ignore: avoid_print
      print(
        'SNAPFIT_MEMORY_IMAGE_V1:${jsonEncode({'id': id, 'mimeType': 'image/png', 'width': pixels.width, 'height': pixels.height, 'base64': base64Encode(bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))})}',
      );
    } finally {
      pixels.dispose();
    }
  });
}

Future<void> _enterEditor(WidgetTester tester) async {
  tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).onNext();
  await _settle(tester);
  expect(find.byType(PageEditorScreen), findsOneWidget);
  expect(find.byType(AlbumCreateFlowScreen), findsNothing);
}

Future<void> _openPhotoFill(WidgetTester tester) async {
  // Photo filling is an optional editor tool after creation has committed.
  final more = find.byKey(const ValueKey('editor-more-tools'));
  if (more.evaluate().isNotEmpty) await _tap(tester, more);
  await _tap(tester, find.text('사진 여러 장 넣기').last);
  expect(find.byType(EditorPhotoFillScreen), findsOneWidget);
  expect(find.byType(TemplatePhotoFillStep), findsOneWidget);
}

Future<void> _saveSetup(WidgetTester tester) =>
    _tap(tester, find.byKey(const ValueKey('creation-save-draft')));

void _expectFreshHistory(WidgetTester tester) {
  for (final action in ['undo', 'redo']) {
    expect(
      tester
          .widget<IconButton>(find.byKey(ValueKey('photo-fill-$action')))
          .onPressed,
      isNull,
    );
  }
}

Future<void> _expectOwnerBoundary(
  WidgetTester tester,
  ProviderContainer container,
  TemplatePhotoFillStep staleFill,
  Map<String, dynamic> editorBefore,
) async {
  expect(find.byType(TemplatePhotoFillStep), findsNothing);
  expect(find.byType(GalleryThumbTile), findsNothing);
  expect(
    find.byKey(const ValueKey('editor-photo-fill-owned-navigation')),
    findsNothing,
  );
  expect(find.text('앨범이나 계정이 변경됐어요. 사진 도구를 닫고 다시 열어주세요.'), findsOneWidget);
  // A callback retained by a removed photo tool must not apply another owner's work.
  staleFill.onContinue();
  await _settle(tester);
  expect(find.byType(EditorPhotoFillScreen), findsOneWidget);
  expect(
    container
        .read(albumEditorViewModelProvider.notifier)
        .captureCreationEditorCheckpoint()
        .toJson(),
    editorBefore,
  );
}

Future<void> _addThroughGallery(
  WidgetTester tester,
  List<BrowserPhotoAsset> photos,
) async {
  await _tap(tester, find.byKey(const ValueKey('fill-add-photos')));
  for (final photo in photos) {
    await _tap(
      tester,
      find.byKey(
        ValueKey('${kIsWeb ? 'browser' : 'gallery'}-photo-${photo.id}'),
      ),
    );
  }
  await _tap(
    tester,
    find.byKey(
      ValueKey(
        kIsWeb
            ? 'confirm-browser-photo-selection'
            : 'confirm-gallery-selection',
      ),
    ),
  );
}

void main() {
  late CatalogFavorites previousFavorites;
  setUpAll(() async {
    if (!kIsWeb) await loadCreationFonts();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    previousFavorites = CatalogFavorites.instance;
    CatalogFavorites.instance = CatalogFavorites(
      storage: MemoryFavoritesStorage(),
    );
    await CatalogFavorites.instance.load();
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    CatalogFavorites.instance = previousFavorites;
  });

  testWidgets(
    'setup size changes preserve resumed photo choices with fresh editor history',
    (tester) async {
      final boot = await _boot(tester, restoredPhotos: true);
      final oldPages = tester
          .widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1))
          .documentPages!;
      await _tap(
        tester,
        find.byKey(const ValueKey('print-size-REDP_200X150_SOFT')),
      );
      await _saveSetup(tester);
      expect(boot.store.draft!.pendingPhotos, boot.photos);
      expect(boot.store.draft!.selectedPhotoId, boot.photos[1].id);
      expect(boot.store.draft!.currentPage, 0);
      expect(boot.store.draft!.selectedSlot, isNull);
      expect(boot.albums.creates, 0);
      await _enterEditor(tester);
      expect(boot.albums.creates, 1);
      expect(boot.store.draft!.createdAlbumId, boot.albums.albumId);
      expect(boot.store.draft!.editorCheckpoint, isNotNull);
      await _openPhotoFill(tester);
      final after = _fill(tester);
      final session = after.session!;
      expect(after.cover.sizeProductId, 'REDP_200X150_SOFT');
      expect(
        after.pages.first.single.height,
        isNot(oldPages.first.single.height),
      );
      expect(
        after.pages.expand((page) => page).any((layer) => layer.hasImageSource),
        isFalse,
      );
      expect(session.pendingPhotos, boot.photos);
      expect(session.selectedPhoto, same(boot.photos[1]));
      expect(session.page, 0);
      expect(session.selectedSlot, isNull);
      _expectFreshHistory(tester);
      expect(find.text('넣을 사진 2장'), findsOneWidget);
      for (var i = 0; i < boot.photos.length; i++) {
        expect(
          boot.photos[i].originalBytes,
          orderedEquals(
            browserPhotoFixture(width: i == 0 ? 40 : 60, height: 40),
          ),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real multi-selection, undo and page choice survive applying and reopening the editor tool',
    (tester) async {
      final boot = await _boot(tester);
      await _enterEditor(tester);
      await _openPhotoFill(tester);
      await _addThroughGallery(tester, boot.photos);
      final session = _fill(tester).session!;
      expect(session.pendingPhotos, boot.photos);
      await _tap(
        tester,
        find.byKey(ValueKey('tray-photo-${boot.photos[1].id}')),
      );
      await _tap(tester, find.byTooltip('선택한 사진 제외'));
      await _tap(tester, find.byKey(const ValueKey('photo-fill-undo')));
      expect(session.selectedPhoto, same(boot.photos[1]));
      await _tap(tester, find.byKey(const ValueKey('fill-page-1')));
      await _tap(tester, find.byKey(const ValueKey('fill-next-empty')));
      expect(session.selectedSlot?.page, 1);
      await _tap(tester, find.byKey(const ValueKey('fill-continue')));
      expect(find.byType(EditorPhotoFillScreen), findsNothing);
      expect(boot.store.draft!.currentPage, 1);
      await _openPhotoFill(tester);
      final resumed = _fill(tester).session!;
      expect(resumed.pendingPhotos, boot.photos);
      expect(resumed.selectedPhoto, same(boot.photos[1]));
      expect(resumed.page, 1);
      expect(resumed.selectedSlot, isNull);
      _expectFreshHistory(tester);
      expect(boot.albums.creates, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('template browsing preserves the old document until a choice', (
    tester,
  ) async {
    final boot = await _boot(tester, restoredPhotos: true);
    final oldPages = tester
        .widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1))
        .documentPages;
    await _tap(tester, find.byKey(const ValueKey('creation-change-design')));
    final card = find.byKey(
      ValueKey('creation-template-${bundledCreationTemplates.first.id}'),
    );
    Future<void> openTemplate() async {
      final openCatalog = find.byKey(const ValueKey('creation-open-catalog'));
      if (openCatalog.evaluate().isNotEmpty) {
        await _tap(tester, openCatalog);
      }
      final catalog = find.byKey(const PageStorageKey('albumCreationHub'));
      expect(catalog, findsOneWidget);
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find
            .descendant(
              of: catalog,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _settle(tester);
      await _tap(tester, card);
      // 경로 애니메이션 후 시작하는 실제 문서 worker까지 기다린다.
      await settleStoreDetail(tester);
    }

    await openTemplate();
    expect(find.byType(CreationTemplatePreview), findsOneWidget);
    expect(boot.albums.creates, 0);
    Navigator.of(tester.element(find.byType(CreationTemplatePreview))).pop();
    await _settle(tester);
    // 목록에서 시작 방법으로 돌아온 뒤 한 번 더 뒤로 가면 기존 설정을 복원한다.
    await _tap(tester, find.byKey(const ValueKey('creation-hub-back')));
    expect(
      find.byKey(const ValueKey('creation-open-catalog')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(AlbumCreateStep1), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('creation-hub-back')));
    expect(find.byType(AlbumCreateStep1), findsOneWidget);
    expect(
      tester
          .widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1))
          .documentPages,
      same(oldPages),
    );
    await _saveSetup(tester);
    expect(boot.store.draft!.pendingPhotos, boot.photos);
    expect(boot.store.draft!.selectedPhotoId, boot.photos[1].id);
    await _tap(tester, find.byKey(const ValueKey('creation-change-design')));
    await openTemplate();
    expect(find.byType(CreationTemplatePreview), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, '이 디자인 선택'));
    expect(find.byType(AlbumCreateStep1), findsOneWidget);
    await _saveSetup(tester);
    expect(boot.store.draft!.pendingPhotos, boot.photos);
    expect(boot.store.draft!.selectedPhotoId, boot.photos[1].id);
    expect(boot.store.draft!.currentPage, 0);
    expect(boot.store.draft!.selectedSlot, isNull);
    await _enterEditor(tester);
    await _openPhotoFill(tester);
    expect(_fill(tester).pages, isNot(same(oldPages)));
    expect(_fill(tester).session!.pendingPhotos, boot.photos);
    expect(_fill(tester).session!.selectedPhoto, same(boot.photos[1]));
    expect(
      _fill(
        tester,
      ).pages.expand((page) => page).any((layer) => layer.asset != null),
      isFalse,
    );
    _expectFreshHistory(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'observed account changes hide photo choices and reject stale apply',
    (tester) async {
      final boot = await _boot(tester, restoredPhotos: true);
      await _enterEditor(tester);
      await _openPhotoFill(tester);
      final staleFill = _fill(tester);
      expect(staleFill.session!.pendingPhotos, boot.photos);
      final editorBefore = boot.container
          .read(albumEditorViewModelProvider.notifier)
          .captureCreationEditorCheckpoint()
          .toJson();
      boot.container
          .read(orderSessionOwnerProvider.notifier)
          .observe('owner-b');
      await _settle(tester);
      await _expectOwnerBoundary(
        tester,
        boot.container,
        staleFill,
        editorBefore,
      );
      (boot.container.read(authViewModelProvider.notifier) as _Auth).changeTo(
        'owner-b',
      );
      await _settle(tester);
      await _expectOwnerBoundary(
        tester,
        boot.container,
        staleFill,
        editorBefore,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same-owner profile refresh keeps the document and photo choices',
    (tester) async {
      final boot = await _boot(tester, restoredPhotos: true);
      final setup = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      final pages = setup.documentPages;
      final previousCover = setup.selectedCover;
      final auth = boot.container.read(authViewModelProvider.notifier) as _Auth;
      auth.loading();
      await _settle(tester);
      await _tap(
        tester,
        find.byKey(const ValueKey('print-size-REDP_200X150_SOFT')),
      );
      final unchanged = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      expect(unchanged.selectedCover, previousCover);
      expect(unchanged.documentPages, same(pages));
      expect(boot.albums.creates, 0);
      expect(find.text('계정 정보를 확인하고 있어요. 잠시 후 다시 시도해주세요.'), findsOneWidget);
      auth.changeTo('owner-a');
      await _settle(tester);
      await tester.drag(find.byType(SnackBar), const Offset(0, 100));
      await _settle(tester);
      expect(find.byType(SnackBar), findsNothing);
      await _enterEditor(tester);
      await _openPhotoFill(tester);
      final session = _fill(tester).session!;
      final editorPages = _fill(tester).pages;
      auth.loading();
      await _settle(tester);
      expect(_fill(tester).pages, same(editorPages));
      expect(session.pendingPhotos, boot.photos);
      expect(session.selectedPhoto, same(boot.photos[1]));
      auth.changeTo('owner-a');
      await _settle(tester);
      expect(_fill(tester).pages, same(editorPages));
      expect(session.pendingPhotos, boot.photos);
      expect(session.selectedPhoto, same(boot.photos[1]));
      expect(tester.takeException(), isNull);
    },
  );

  for (final nextOwner in <String?>[null, 'owner-b']) {
    testWidgets(
      'profile refresh rejects photo work after confirmed owner $nextOwner',
      (tester) async {
        final boot = await _boot(tester, restoredPhotos: true);
        await _enterEditor(tester);
        await _openPhotoFill(tester);
        final staleFill = _fill(tester);
        final session = staleFill.session!;
        final pages = staleFill.pages;
        final editorBefore = boot.container
            .read(albumEditorViewModelProvider.notifier)
            .captureCreationEditorCheckpoint()
            .toJson();
        final auth =
            boot.container.read(authViewModelProvider.notifier) as _Auth;
        auth.loading();
        await _settle(tester);
        expect(_fill(tester).pages, same(pages));
        expect(session.pendingPhotos, boot.photos);
        if (nextOwner == null) {
          auth.confirmLogout();
        } else {
          auth.changeTo(nextOwner);
        }
        await _settle(tester);
        await _expectOwnerBoundary(
          tester,
          boot.container,
          staleFill,
          editorBefore,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'initial authentication restoration keeps resumed photo choices',
    (tester) async {
      final authLoading = Completer<UserInfo?>();
      final boot = await _boot(
        tester,
        restoredPhotos: true,
        authLoading: authLoading,
      );
      final pages = tester
          .widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1))
          .documentPages;
      expect(find.byType(PageEditorScreen), findsNothing);
      expect(boot.albums.creates, 0);
      authLoading.complete(
        const UserInfo(id: 'owner-a', name: '우리', provider: 'email'),
      );
      await _settle(tester);
      expect(
        tester
            .widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1))
            .documentPages,
        same(pages),
      );
      await _enterEditor(tester);
      await _openPhotoFill(tester);
      final session = _fill(tester).session!;
      expect(session.pendingPhotos, boot.photos);
      expect(session.selectedPhoto, same(boot.photos[1]));
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    for (final dark in [false, true]) {
      testWidgets('pending guidance and choices fit 200% text $size dark=$dark', (
        tester,
      ) async {
        final capture = GlobalKey();
        final boot = await _boot(
          tester,
          restoredPhotos: true,
          size: size,
          textScale: 2,
          dark: dark,
          capture: capture,
        );
        await _enterEditor(tester);
        await _openPhotoFill(tester);
        expect(find.text('넣을 사진 2장'), findsOneWidget);
        final page = find
            .byWidgetPredicate(
              (widget) =>
                  widget is TemplatePageRenderer && widget.onLayerTap != null,
            )
            .first;
        await Scrollable.ensureVisible(tester.element(page), alignment: .5);
        await _settle(tester);
        expect(tester.getRect(page).height, greaterThanOrEqualTo(120));
        final workspace = tester.getRect(
          find.byKey(const ValueKey('photo-fill-workspace-scroll')),
        );
        expect(
          tester.getRect(page).intersect(workspace).height,
          greaterThanOrEqualTo(120),
        );
        expect(page.hitTestable(), findsOneWidget);
        if (!dark) {
          await _memoryImage(
            tester,
            capture,
            'photo-tray-guidance-${size.width.toInt()}x${size.height.toInt()}-200pct',
          );
        }
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('photo-fill-tray'))),
          alignment: .5,
        );
        await _settle(tester);
        final photo = find.byKey(ValueKey('tray-photo-${boot.photos[1].id}'));
        await tester.scrollUntilVisible(
          photo,
          70,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('photo-fill-tray')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await _settle(tester);
        await _tap(tester, photo);
        expect(_fill(tester).session!.selectedPhoto, same(boot.photos[1]));
        final continueButton = tester.getRect(
          find.byKey(const ValueKey('fill-continue')),
        );
        expect(continueButton.bottom, lessThanOrEqualTo(size.height));
        expect(continueButton.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

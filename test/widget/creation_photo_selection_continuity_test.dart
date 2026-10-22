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
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/gallery_thumb_tile.dart';

import '../helpers/mock_repositories.dart';
import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;
import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

class _Auth extends AuthViewModel {
  _Auth({this.initialUser});
  final Future<UserInfo?>? initialUser;

  @override
  Future<UserInfo?> build() =>
      initialUser ??
      Future.value(
        const UserInfo(id: 'owner-a', name: '우리', provider: 'email'),
      );

  void changeTo(String id) =>
      state = AsyncData(UserInfo(id: id, name: '다른 계정', provider: 'email'));

  void loading() => state = const AsyncLoading();

  void confirmLogout() => state = const AsyncData(null);
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

Future<({ProviderContainer container, List<BrowserPhotoAsset> photos})> _boot(
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
  final container = ProviderContainer(
    overrides: [
      albumCreationDraftStoreProvider.overrideWithValue(
        MemoryCreationDraftStore(),
      ),
      albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
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
  return (container: container, photos: photos);
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

Future<void> _backToSetup(WidgetTester tester) async {
  await _tap(tester, find.byTooltip(kIsWeb ? '이전 단계' : '뒤로가기'));
  expect(find.byType(AlbumCreateStep1), findsOneWidget);
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
    'real multi-selection survives a size change with fresh history',
    (tester) async {
      final boot = await _boot(tester);
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
      final oldPages = _fill(tester).pages;
      await _backToSetup(tester);
      await _tap(
        tester,
        find.byKey(const ValueKey('print-size-REDP_200X150_SOFT')),
      );
      expect(session.pendingPhotos, boot.photos);
      expect(session.selectedPhoto, same(boot.photos[1]));
      expect(session.page, 0);
      expect(session.selectedSlot, isNull);
      await _tap(tester, find.byKey(const ValueKey('creation-setup-next')));
      final after = _fill(tester);
      expect(after.cover.sizeProductId, 'REDP_200X150_SOFT');
      expect(
        after.pages.first.single.height,
        isNot(oldPages.first.single.height),
      );
      expect(
        after.pages.expand((page) => page).any((layer) => layer.hasImageSource),
        isFalse,
      );
      for (final action in ['undo', 'redo']) {
        expect(
          tester
              .widget<IconButton>(find.byKey(ValueKey('photo-fill-$action')))
              .onPressed,
          isNull,
        );
      }
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
      await tester.pumpWidget(const SizedBox());
      expect(session.pendingPhotos, isEmpty);
    },
  );

  testWidgets('template browsing preserves the old document until a choice', (
    tester,
  ) async {
    final boot = await _boot(tester, restoredPhotos: true);
    final session = _fill(tester).session!;
    final oldPages = _fill(tester).pages;
    await _backToSetup(tester);
    await _tap(tester, find.byTooltip('시작 방식 변경'));
    final card = find.byKey(
      ValueKey('creation-template-${bundledCreationTemplates.first.id}'),
    );
    Future<void> openTemplate() async {
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find
            .descendant(
              of: find.byType(AiAlbumStartStep),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _settle(tester);
      await _tap(tester, card);
    }

    await openTemplate();
    expect(find.byType(TemplateDetailScreen), findsOneWidget);
    expect(session.pendingPhotos, boot.photos);
    Navigator.of(tester.element(find.byType(TemplateDetailScreen))).pop();
    await _settle(tester);
    await _tap(tester, find.byTooltip(kIsWeb ? '이전 단계' : '뒤로가기'));
    expect(find.byType(AlbumCreateStep1), findsOneWidget);
    expect(
      tester
          .widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1))
          .documentPages,
      same(oldPages),
    );
    expect(session.pendingPhotos, boot.photos);
    await _tap(tester, find.byTooltip('시작 방식 변경'));
    await openTemplate();
    final keyedAction = find.byKey(const ValueKey('template-detail-use'));
    await _tap(
      tester,
      keyedAction.evaluate().isNotEmpty
          ? keyedAction
          : find.widgetWithText(FilledButton, '이 디자인 선택'),
    );
    expect(find.byType(AlbumCreateStep1), findsOneWidget);
    expect(session.pendingPhotos, boot.photos);
    expect(session.selectedPhoto, same(boot.photos[1]));
    expect(session.page, 0);
    expect(session.selectedSlot, isNull);
    await _tap(tester, find.byKey(const ValueKey('creation-setup-next')));
    expect(_fill(tester).pages, isNot(same(oldPages)));
    expect(
      _fill(
        tester,
      ).pages.expand((page) => page).any((layer) => layer.asset != null),
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('photo-fill-undo')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('account changes discard pending photos and old document state', (
    tester,
  ) async {
    final boot = await _boot(tester, restoredPhotos: true);
    final session = _fill(tester).session!;
    boot.container.read(orderSessionOwnerProvider.notifier).observe('owner-b');
    await _settle(tester);
    expect(session.pendingPhotos, isEmpty);
    expect(session.selectedPhoto, isNull);
    expect(session.selectedSlot, isNull);
    expect(find.byType(TemplatePhotoFillStep), findsNothing);
    expect(find.byType(AlbumCreateStep1), findsNothing);
    expect(find.byType(GalleryThumbTile), findsNothing);
    expect(find.text('사진을 고른 앨범'), findsNothing);
    (boot.container.read(authViewModelProvider.notifier) as _Auth).changeTo(
      'owner-b',
    );
    await _settle(tester);
    expect(session.pendingPhotos, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same-owner profile refresh keeps the document and photo choices',
    (tester) async {
      final boot = await _boot(tester, restoredPhotos: true);
      final session = _fill(tester).session!;
      final pages = _fill(tester).pages;
      final auth = boot.container.read(authViewModelProvider.notifier) as _Auth;
      auth.loading();
      await _settle(tester);
      expect(_fill(tester).pages, same(pages));
      expect(session.pendingPhotos, boot.photos);
      expect(session.selectedPhoto, same(boot.photos[1]));
      await _backToSetup(tester);
      final previousCover = tester
          .widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1))
          .selectedCover;
      await _tap(
        tester,
        find.byKey(const ValueKey('print-size-REDP_200X150_SOFT')),
      );
      final unchanged = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      expect(unchanged.selectedCover, previousCover);
      expect(unchanged.documentPages, same(pages));
      expect(session.pendingPhotos, boot.photos);
      expect(session.selectedPhoto, same(boot.photos[1]));
      expect(find.text('계정 정보를 확인하고 있어요. 잠시 후 다시 시도해주세요.'), findsOneWidget);
      auth.changeTo('owner-a');
      await _settle(tester);
      await tester.drag(find.byType(SnackBar), const Offset(0, 100));
      await _settle(tester);
      expect(find.byType(SnackBar), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('creation-setup-next')));
      expect(_fill(tester).pages, same(pages));
      expect(session.pendingPhotos, boot.photos);
      expect(session.selectedPhoto, same(boot.photos[1]));
      expect(tester.takeException(), isNull);
    },
  );

  for (final nextOwner in <String?>[null, 'owner-b']) {
    testWidgets(
      'profile refresh clears work after confirmed owner $nextOwner',
      (tester) async {
        final boot = await _boot(tester, restoredPhotos: true);
        final session = _fill(tester).session!;
        final pages = _fill(tester).pages;
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
        expect(session.pendingPhotos, isEmpty);
        expect(session.selectedPhoto, isNull);
        expect(session.selectedSlot, isNull);
        expect(find.byType(TemplatePhotoFillStep), findsNothing);
        expect(find.byType(GalleryThumbTile), findsNothing);
        expect(find.text('사진을 고른 앨범'), findsNothing);
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
      final session = _fill(tester).session!;
      final pages = _fill(tester).pages;
      authLoading.complete(
        const UserInfo(id: 'owner-a', name: '우리', provider: 'email'),
      );
      await _settle(tester);
      expect(_fill(tester).pages, same(pages));
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

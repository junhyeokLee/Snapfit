import '../support/store_detail_loading.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/shared/widgets/catalog_cover_skeleton.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_brief_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_point_confirmation_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_generating_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_design_review.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/cover_size_picker.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step2.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_creation_review_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_document_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_frozen_screen.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../fixtures/ai_template_design_fixture.dart';
import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../helpers/unified_creation_fixtures.dart';
import 'album_settings_redesign_test.dart' show openAlbumSettingsSection;

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Auth extends AuthViewModel {
  @override
  UserInfo? build() => const UserInfo(
    id: 'creation-workshop-owner',
    name: '제작 검수',
    provider: 'EMAIL',
  );
}

void main() {
  _Binding();
  final boundary = GlobalKey();
  late List<List<LayerModel>> pages;
  final template = publishedCreationTemplates.firstWhere(
    (item) => item.id == -9501,
  );
  final canvas = coverCanvasBaseSize(defaultCoverSize);
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List)
        loader.addFont(rootBundle.load(asset['asset'] as String));
      await loader.load();
    }
    final data = jsonDecode(template.templateJson!) as Map<String, dynamic>;
    final metadata = data['metadata'] as Map? ?? const {};
    final source = Size(
      (data['designWidth'] as num? ?? metadata['designWidth'] as num? ?? 500)
          .toDouble(),
      (data['designHeight'] as num? ?? metadata['designHeight'] as num? ?? 500)
          .toDouble(),
    );
    final raw = templateDocumentPages(data)
        .take(25)
        .map(
          (page) => DataTemplateEngine.buildLayersFromJson({
            'strictLayout': true,
            'designWidth': source.width,
            'designHeight': source.height,
            'layers': page['layers'],
          }, source),
        )
        .toList();
    pages = AlbumCreationTemplate.preparePages(
      raw,
      sourceCanvas: source,
      cover: defaultCoverSize,
      clearSamplePhotos: false,
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Finder key(String id) => find.byKey(ValueKey(id));
  void metrics(WidgetTester tester, Size size, {double keyboard = 0}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = size.width > size.height
        ? FakeViewPadding(left: 32, right: 48, bottom: keyboard > 0 ? 0 : 24)
        : FakeViewPadding(top: 24, bottom: keyboard > 0 ? 0 : 34);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  void reset(WidgetTester tester) {
    // Release image streams in their own fake-clock zone before the next case.
    addTearDown(() async {
      FocusManager.instance.primaryFocus?.unfocus();
      if (tester.testTextInput.isRegistered) tester.testTextInput.hide();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> mount(
    WidgetTester tester,
    Widget body, {
    bool dark = false,
    double scale = 1.3,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final albums = RecordingCreationAlbums(owner: 'creation-workshop-owner');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(_Auth.new),
          albumEditorOwnerReaderProvider.overrideWithValue(() => 'creation-workshop-owner'),
          albumEditorOwnerChangesProvider.overrideWith((ref) => const Stream.empty()),
          ...unifiedCreationBackendOverrides(albums: albums),
          albumCreationDraftStoreProvider.overrideWithValue(
            MemoryCreationDraftStore(),
          ),
          isFirstAiDraftFreeProvider.overrideWith((_) async => true),
          myPointBalanceProvider.overrideWith((_) async => 2000),
          aiAlbumDraftGenerationServiceProvider.overrideWithValue(
            AiAlbumDraftGenerationService(
              collectCandidates: (_) async =>
                  throw StateError('Request editing must not access photos.'),
            ),
          ),
          albumCreationCatalogProvider.overrideWith(
            (ref) => Stream.value(publishedCreationTemplates),
          ),
          pointShopCatalogProvider.overrideWith((ref) async => []),
          ownedPointShopKeysProvider.overrideWith((ref) async => <String>{}),
          storeDiscoveryProvider.overrideWith(
            (ref) async => const <String, StoreProductDiscovery>{},
          ),
          storeDiscoveryClockProvider.overrideWithValue(
            DateTime.utc(2026, 11, 11),
          ),
          storeCurationsProvider.overrideWith(
            (ref) async => const <String, StoreCuration>{},
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
              splashFactory: NoSplash.splashFactory,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home:
                body is CreationTemplatePreview ||
                    body is AlbumFrozenScreen ||
                    body is AlbumCreateFlowScreen
                ? body
                : Scaffold(
                    backgroundColor: dark
                        ? const Color(0xFF121212)
                        : Colors.white,
                    appBar: AppBar(
                      toolbarHeight:
                          tester.view.physicalSize.width >
                              tester.view.physicalSize.height
                          ? 48
                          : 60,
                      title: const Text(
                        '앨범 만들기',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    body: body,
                  ),
          ),
        ),
      ),
    );
    if (body is AiTemplateGeneratingStep ||
        (body is AiAlbumStartStep && body.templates.isLoading)) {
      await tester.pump(const Duration(milliseconds: 400));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void safe(
    WidgetTester tester,
    Finder finder,
    Size size, {
    double keyboard = 0,
  }) {
    final rect = tester.getRect(finder), wide = size.width > size.height;
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(wide ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (wide ? 48 : 0)));
    expect(
      rect.bottom,
      lessThanOrEqualTo(
        size.height -
            (keyboard > 0
                ? keyboard
                : wide
                ? 24
                : 34),
      ),
    );
    expect(finder.hitTestable(), findsOneWidget);
  }

  Future<void> capture(
    WidgetTester tester,
    String id,
    Size size,
    bool dark, {
    bool pending = false,
  }) async {
    // Decode native images while pumping frames; precache alone can wait forever
    // for artwork that schedules its next frame outside the fake clock.
    var stable = 0;
    for (var frame = 0; frame < 160; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 32));
      final ready =
          PaintingBinding.instance.imageCache.pendingImageCount == 0 &&
          find.byType(CatalogCoverSkeleton).evaluate().isEmpty;
      stable = ready && frame >= 12 ? stable + 1 : 0;
      if (stable == 4) break;
      if (frame == 159)
        fail('Workshop artwork did not settle within 160 frames.');
    }
    if (pending) {
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    if (!const bool.fromEnvironment('CREATION_WORKSHOP_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'output/all-screens-qa/$id-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  AlbumCreateStep1 setup({bool manual = false, VoidCallback? next}) =>
      AlbumCreateStep1(
        albumTitle: '오래 기억하고 싶은 우리의 여름',
        templateTitle: manual ? null : template.title,
        sourceLabel: manual ? '직접 만들기' : '템플릿 선택',
        selectedCover: defaultCoverSize,
        selectedPageCount: 24,
        minPageCount: 24,
        templatePageCount: 24,
        coverLayers: manual ? null : pages.first,
        documentPages: manual ? null : pages,
        preserveTypography: true,
        onTitleChanged: (_) {},
        onCoverSelected: (_) {},
        onPageCountChanged: (_) {},
        onNext: next ?? () {},
        onChangeDesign: () {},
      );
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('book-led complete creation presentation $size dark=$dark', (
        tester,
      ) async {
        reset(tester);
        metrics(tester, size);
        var manual = 0, selected = 0, use = 0, next = 0;
        final startTemplates = publishedCreationTemplates.take(8).toList();
        await mount(
          tester,
          AiAlbumStartStep(
            templates: AsyncData(startTemplates),
            onManualStart: () => manual++,
            onTemplateSelected: (_) => selected++,
          ),
          dark: dark,
        );
        await capture(tester, 'creation-atelier-start', size, dark);
        await tap(tester, key('creation-manual-start'));
        expect(manual, 1);
        expect(selected, 0);
        await tap(tester, key('creation-open-catalog'));
        expect(selected, 0, reason: 'Browsing never selects or buys a design');
        final firstCard = key('creation-template-${startTemplates.first.id}');
        await tester.scrollUntilVisible(
          firstCard,
          120,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tap(tester, firstCard);
        expect(selected, 1);
        // Profile insertion moves the grid. Korean titles may also deliberately
        // wrap at a word boundary, while retaining the original semantic label.
        final selectedTitle = find.descendant(
          of: firstCard,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.semanticsLabel == startTemplates.first.title,
          ),
        );
        await tester.scrollUntilVisible(
          selectedTitle,
          120,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(selectedTitle, findsOneWidget);
        expect(
          tester
              .widget<Text>(selectedTitle)
              .data!
              .replaceAll(RegExp(r'\s+'), ' '),
          startTemplates.first.title,
        );
        await capture(tester, 'creation-atelier-catalog', size, dark);
        await mount(
          tester,
          setup(manual: true, next: () => next++),
          dark: dark,
        );
        await capture(tester, 'creation-atelier-manual', size, dark);
        safe(tester, key('creation-setup-next'), size);
        await tap(tester, key('creation-setup-next'));
        expect(next, 1);
        await mount(
          tester,
          CreationTemplatePreview(
            title: template.title,
            isPremium: false,
            pages: pages,
            canvas: canvas,
            onUse: () => use++,
            onRetry: () {},
            preserveTypography: true,
            accessBadge: const Text('무료'),
          ),
          dark: dark,
        );
        await capture(tester, 'creation-atelier-preview', size, dark);
        await tap(tester, find.byTooltip('다음 페이지'));
        expect(
          tester
              .widget<CreationDocumentPreview>(
                find.byType(CreationDocumentPreview),
              )
              .showBookMaterial,
          true,
        );
        await capture(tester, 'creation-atelier-spread', size, dark);
        await tap(tester, find.text('이 디자인 선택'));
        expect(use, 1);
        await mount(tester, setup(), dark: dark);
        expect(
          tester.getSize(key('creation_document_canvas')).height,
          greaterThanOrEqualTo(64),
        );
        await capture(tester, 'creation-atelier-settings', size, dark);
        if (size.width > size.height) {
          final art = tester.getRect(key('creation-workspace-preview'));
          final action = tester.getRect(key('creation-setup-next'));
          expect(art.right, lessThanOrEqualTo(action.left));
          expect(art.bottom, greaterThan(action.top));
        }
        await tap(tester, find.byTooltip('다음 페이지'));
        if (size.width > size.height) {
          expect(key('template-book-spread-1'), findsOneWidget);
        }
        await capture(tester, 'creation-atelier-settings-spread', size, dark);
        await mount(
          tester,
          AiTemplateBriefStep(onBack: () {}, onContinue: (_) {}),
          dark: dark,
        );
        await capture(tester, 'creation-atelier-ai-brief', size, dark);
        final brief = AiTemplateBrief(
          prompt: '제주 바다와 우리의 여행. 큰 풍경, 짙은 초록, 정갈한 사진집.',
          aspect: AiTemplateAspect.square,
          printProductId: defaultCoverSize.productId,
          pageCount: 24,
        );
        await mount(
          tester,
          AiAlbumPointConfirmationStep(
            designBrief: brief,
            theme: AlbumTheme.custom,
            range: AiPhotoRange.manualSelection,
            pointCost: 300,
            balance: 1200,
            onConfirm: () {},
            onBack: () {},
          ),
          dark: dark,
        );
        await capture(tester, 'creation-atelier-ai-confirm', size, dark);
        await mount(
          tester,
          const AiTemplateGeneratingStep(innerPageCount: 24),
          dark: dark,
        );
        await capture(
          tester,
          'creation-atelier-ai-generating',
          size,
          dark,
          pending: true,
        );
        await mount(
          tester,
          AiTemplateDesignReview(
            design: templateDesignDraft().design!,
            onBack: () {},
            onAccept: () {},
            isAccepting: false,
          ),
          dark: dark,
        );
        await capture(tester, 'creation-atelier-ai-result', size, dark);
        await mount(
          tester,
          TemplatePhotoFillStep(
            pages: pages,
            cover: defaultCoverSize,
            preserveTypography: true,
            onChanged: (_) {},
            onContinue: () {},
          ),
          dark: dark,
        );
        await capture(tester, 'creation-atelier-photos', size, dark);
        await tester.scrollUntilVisible(
          key('fill-page-1'),
          60,
          scrollable: find.descendant(
            of: key('photo-fill-page-rail'),
            matching: find.byType(Scrollable),
          ),
        );
        await tap(tester, key('fill-page-1'));
        await capture(tester, 'creation-atelier-photos-spread', size, dark);
        await mount(tester, const SizedBox(), dark: dark);
        final context = tester.element(find.byType(Scaffold));
        final result = showAlbumCreationReview(
          context,
          pages: pages,
          innerPageCount: 24,
          canvasSize: canvas,
        );
        await tester.pumpAndSettle();
        await capture(tester, 'creation-atelier-review', size, dark);
        if (size.width > size.height) {
          await tap(tester, find.byTooltip('다음 페이지'));
          expect(key('template-book-spread-1'), findsOneWidget);
          await capture(tester, 'creation-atelier-review-spread', size, dark);
          metrics(tester, const Size(390, 844));
          await tester.pumpAndSettle();
          metrics(tester, size);
          await tester.pumpAndSettle();
          expect(key('template-book-spread-1'), findsOneWidget);
        }
        safe(tester, key('creation-review-start'), size);
        await tap(tester, key('creation-review-start'));
        expect(await result, -1);
        await mount(
          tester,
          AlbumCreateStep2(
            albumTitle: '오래 기억하고 싶은 우리의 여름',
            selectedCover: defaultCoverSize,
            selectedPageCount: 24,
            documentPages: pages,
            documentCanvas: canvas,
            onNext: () {},
            onBack: () {},
          ),
          dark: dark,
        );
        await capture(tester, 'creation-atelier-invite', size, dark);
        await tap(tester, find.byTooltip('다음 페이지'));
        await capture(tester, 'creation-atelier-invite-spread', size, dark);
        await tester.ensureVisible(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(find.byType(Switch).hitTestable(), findsOneWidget);
        await capture(tester, 'creation-atelier-invite-options', size, dark);
        expect(tester.takeException(), isNull);
      });
      testWidgets(
        'real creation shell enters a linked editor and keeps work when exit is cancelled $size dark=$dark',
        (tester) async {
          reset(tester);
          metrics(tester, size);
          await mount(
            tester,
            AlbumCreateFlowScreen(
              initialCreationTemplate: AlbumCreationTemplate(
                title: template.title,
                previewUrl: '',
                isPremium: false,
                cover: defaultCoverSize,
                pages: AlbumCreationTemplate.preparePages(
                  pages,
                  sourceCanvas: canvas,
                  cover: defaultCoverSize,
                ),
                pagesCanvasSize: canvas,
                preserveTypography: true,
              ),
            ),
            dark: dark,
          );
          expect(
            tester.getSize(key('creation_document_canvas')).height,
            greaterThanOrEqualTo(64),
          );
          await capture(tester, 'creation-atelier-shell-settings', size, dark);
          final acceptedCover = tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).coverLayers!;
          await tap(tester, key('creation-setup-next'));
          expect(find.byType(PageEditorScreen), findsOneWidget);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(PageEditorScreen)),
          );
          final vm = container.read(albumEditorViewModelProvider.notifier);
          final session = vm.editSessionIdentity;
          expect(vm.editingAlbumId, 71);
          expect(vm.currentPageIndex, 0);
          expect(vm.pages.length, pages.length);
          final preservedCover = vm.pages.first.layers.where((layer) => layer.id != 'creation-edited-background').toList();
          expect(preservedCover.map((layer) => layer.id), acceptedCover.map((layer) => layer.id));
          for (var index = 0; index < acceptedCover.length; index++) {
            final original = acceptedCover[index], preserved = preservedCover[index];
            expect(preserved.type, original.type);
            expect(preserved.text, original.text);
            expect(preserved.imageUrl, original.imageUrl);
            expect(preserved.imageBackground, original.imageBackground);
            expect(preserved.decorationFillColor, original.decorationFillColor);
            expect(preserved.imageZoom, original.imageZoom);
            expect(preserved.imageOffset, original.imageOffset);
          }
          final background = vm.pages.first.layers.singleWhere((layer) => layer.id == 'creation-edited-background');
          expect(background.type, LayerType.decoration);
          expect(background.zIndex, -100);
          expect(background.decorationFillColor, matches(RegExp(r'^#[0-9a-fA-F]{8}$')));
          expect(background.width, closeTo(500, .001));
          expect(background.height, closeTo(500 / vm.selectedCover.ratio, .001));
          final draft = (container.read(albumCreationDraftStoreProvider) as MemoryCreationDraftStore).draft!;
          expect(draft.title, template.title);
          expect(draft.createdAlbumId, 71);
          expect(draft.editorCheckpoint!.pages.length, pages.length);
          expect(draft.editorCheckpoint!.pages.first.layers.first.decorationFillColor, background.decorationFillColor);
          expect(
            tester.getSize(find.byType(EditCover)).height,
            greaterThanOrEqualTo(64),
          );
          await capture(tester, 'creation-atelier-shell-editor', size, dark);
          final addPage = key('addInnerPagesButton');
          await tap(tester, addPage);
          expect(vm.pages.length, pages.length + 2);
          expect(vm.hasUnsavedChanges, isTrue);
          await tap(tester, find.byTooltip('편집 마치기'));
          expect(find.byType(AlertDialog), findsOneWidget);
          await tap(tester, find.text('계속 편집'));
          expect(find.byType(PageEditorScreen), findsOneWidget);
          expect(vm.editSessionIdentity, same(session));
          expect(vm.pages.length, pages.length + 2);
          expect(draft.title, template.title);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets(
      'large text keyboard, multiline brief, current page and draft survive rotation $size',
      (tester) async {
        reset(tester);
        metrics(tester, size);
        AiTemplateBrief? accepted;
        await mount(
          tester,
          AiTemplateBriefStep(
            onContinue: (brief) => accepted = brief,
            onBack: () {},
          ),
          dark: true,
          scale: 1.8,
        );
        expect(tester.takeException(), isNull, reason: 'brief before keyboard');
        final field = find.byKey(const Key('ai_template_brief'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        const prompt = '제주 바다의 기록\n풍경은 크게, 사진 사이에는 여백을 넉넉하게 남겨 주세요.';
        await tester.enterText(field, prompt);
        await tester.pumpAndSettle();
        final input = tester.state<EditableTextState>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        final keyboard = size.width > size.height ? 140.0 : 260.0;
        metrics(tester, size, keyboard: keyboard);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'brief with keyboard');
        expect(input.widget.controller.text, prompt);
        expect(input.widget.focusNode.hasFocus, true);
        final continueButton = find.byKey(
          const Key('ai_template_brief_continue'),
        );
        if (continueButton.evaluate().isNotEmpty) {
          safe(tester, continueButton, size, keyboard: keyboard);
        } else {
          expect(field.hitTestable(), findsOneWidget);
        }
        final other = size.width > size.height
            ? const Size(390, 844)
            : const Size(648, 320);
        metrics(
          tester,
          other,
          keyboard: other.width > other.height ? 140 : 260,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'brief after rotation');
        expect(
          tester.state<EditableTextState>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          ),
          same(input),
        );
        expect(input.widget.controller.text, prompt);
        expect(input.widget.focusNode.hasFocus, true);
        FocusManager.instance.primaryFocus?.unfocus();
        metrics(tester, other);
        await tester.pumpAndSettle();
        await tap(tester, find.byKey(const Key('ai_template_brief_continue')));
        expect(accepted!.prompt, prompt);
        metrics(tester, size);
        await mount(tester, setup(), scale: 1.8);
        expect(tester.takeException(), isNull, reason: 'setup before rotation');
        safe(tester, key('creation-setup-next'), size);
        await tap(tester, find.byTooltip('다음 페이지'));
        expect(find.text('표지'), findsNothing);
        metrics(tester, other);
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(key('creation_document_position')).data,
          isNot('표지'),
        );
        expect(tester.takeException(), isNull);
        metrics(tester, size);
        await mount(
          tester,
          AlbumCreateStep2(
            albumTitle: '우리의 여름',
            selectedCover: defaultCoverSize,
            selectedPageCount: 24,
            documentPages: pages,
            documentCanvas: canvas,
            onNext: () {},
            onBack: () {},
          ),
          dark: true,
          scale: 1.8,
        );
        safe(tester, find.widgetWithText(FilledButton, '편집 시작'), size);
        await tester.ensureVisible(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(find.byType(Switch).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      'native manual settings survive browsing current designs $size',
      (tester) async {
        reset(tester);
        metrics(tester, size);
        final dark = size.width > size.height;
        await mount(
          tester,
          const AlbumCreateFlowScreen(),
          dark: dark,
          scale: 1.3,
        );
        await tap(tester, key('creation-manual-start'));
        await openAlbumSettingsSection(tester, 'name');
        final title = key('creation-album-title');
        await tester.ensureVisible(title);
        await tester.enterText(title, '우리의 주말 기록');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await openAlbumSettingsSection(tester, 'book');
        await tap(tester, key('print-cover-hard'));
        await openAlbumSettingsSection(tester, 'pages');
        await tap(tester, find.byTooltip('페이지 늘리기'));
        await tap(tester, key('creation-change-design'));
        expect(find.text('AI 템플릿'), findsNothing);
        await tap(tester, key('creation-open-catalog'));
        final firstCard = key(
          'creation-template-${publishedCreationTemplates.first.id}',
        );
        await tester.scrollUntilVisible(
          firstCard,
          120,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tap(tester, firstCard);
        await settleStoreDetail(tester);
        expect(find.byType(TemplateDetailScreen), findsOneWidget);
        expect(find.text('이 디자인 선택'), findsOneWidget);
        await tap(tester, find.byType(BackButton));
        await tap(tester, key('creation-hub-back'));
        await tap(tester, key('creation-manual-start'));
        final manual = tester.widget<AlbumCreateStep1>(
          find.byType(AlbumCreateStep1),
        );
        expect(manual.albumTitle, '우리의 주말 기록');
        expect(manual.selectedPageCount, 22);
        expect(manual.selectedCover!.coverType, PrintCoverType.hard);
        expect(manual.templateTitle, isNull);
        await openAlbumSettingsSection(tester, 'name');
        final input = tester.widget<TextField>(title).controller!;
        final other = size.width > size.height
            ? const Size(390, 844)
            : const Size(844, 390);
        metrics(tester, other);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(title).controller, same(input));
        expect(input.text, '우리의 주말 기록');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'AI request form resumes options and retains edits on rotation $size',
      (tester) async {
        reset(tester);
        metrics(tester, size);
        final dark = size.width > size.height;
        AiTemplateBrief? saved;
        var continued = 0;
        var backed = 0;
        Widget form() => AiTemplateBriefStep(
          initialBrief: saved,
          onChanged: (brief) => saved = brief,
          onBack: () => backed++,
          onContinue: (_) => continued++,
        );
        await mount(tester, form(), dark: dark, scale: 1.3);
        final prompt = find.byKey(const Key('ai_template_brief'));
        await tester.ensureVisible(prompt);
        const request = '봄날의 주말 기록. 초록 포인트, 겹친 종이 프레임, 짧은 문구.';
        await tester.enterText(prompt, request);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tap(tester, key('print-cover-hard'));
        await tap(tester, key('print-size-REDP_250X200_SOFT'));
        await tap(tester, find.byTooltip('2쪽 늘리기'));
        await tap(tester, find.byTooltip('2쪽 늘리기'));
        await tap(tester, find.byTooltip('이전'));
        expect(backed, 1);
        expect(continued, 0);
        expect(saved!.prompt, request);
        expect(saved!.pageCount, 24);
        expect(saved!.printProductId, 'REDP_250X200_HARD');
        await mount(tester, form(), dark: dark, scale: 1.3);
        final restored = tester.widget<AiTemplateBriefStep>(
          find.byType(AiTemplateBriefStep),
        );
        expect(restored.initialBrief, same(saved));
        expect(
          tester
              .widget<CoverSizePicker>(find.byType(CoverSizePicker))
              .selectedCover!
              .ratio,
          1.25,
        );
        final input = tester.widget<TextField>(prompt).controller!;
        expect(input.text, request);
        final other = size.width > size.height
            ? const Size(390, 844)
            : const Size(844, 390);
        metrics(tester, other);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(prompt).controller, same(input));
        expect(input.text, request);
        expect(continued, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'catalog filters follow entry and unavailable templates never become AI output',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final unlistedPaid = template.copyWith(isPremium: true);
      await mount(
        tester,
        AiAlbumStartStep(
          templates: AsyncData([unlistedPaid]),
          onManualStart: () {},
        ),
      );
      expect(key('creation-manual-start'), findsOneWidget);
      expect(key('creation-search'), findsNothing);
      await tap(tester, key('creation-open-catalog'));
      await tap(tester, key('creation-price-무료'));
      final paidCard = key('creation-template-${unlistedPaid.id}');
      expect(paidCard, findsNothing);
      expect(find.text('검색 결과가 없어요'), findsOneWidget);
      await tap(tester, key('creation-price-유료'));
      await tester.scrollUntilVisible(
        paidCard,
        120,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(paidCard.hitTestable(), findsOneWidget);
      expect(find.text('판매 준비 중'), findsOneWidget);
      expect(find.byType(AiTemplateGeneratingStep), findsNothing);
      await mount(
        tester,
        AiAlbumStartStep(templates: const AsyncLoading(), onManualStart: () {}),
      );
      await tester.tap(key('creation-open-catalog'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(paidCard, findsNothing);
      expect(find.byType(AiTemplateGeneratingStep), findsNothing);
      expect(find.byType(TemplatePageRenderer), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

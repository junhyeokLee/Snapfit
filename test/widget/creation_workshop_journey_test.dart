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
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_brief_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_point_confirmation_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_generating_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_design_review.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_creation_review_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_document_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_frozen_screen.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../fixtures/ai_template_design_fixture.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumCreationCatalogProvider.overrideWith(
            (ref) => Stream.value(publishedCreationTemplates),
          ),
          pointShopCatalogProvider.overrideWith((ref) async => []),
          ownedPointShopKeysProvider.overrideWith((ref) async => <String>{}),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
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
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate())
        await precacheImage((element.widget as Image).image, element);
    });
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
        var manual = 0, ai = 0, selected = 0, use = 0, next = 0;
        await mount(
          tester,
          AiAlbumStartStep(
            templates: AsyncData(publishedCreationTemplates.take(8).toList()),
            onManualStart: () => manual++,
            onAiStart: () => ai++,
            onTemplateSelected: (_) => selected++,
          ),
          dark: dark,
        );
        await capture(tester, 'creation-atelier-start', size, dark);
        await tap(tester, find.text('직접 만들기'));
        await tap(tester, find.text('AI 템플릿'));
        await tap(tester, key('creation-collection-showcase'));
        expect(manual, 1);
        expect(ai, 1);
        expect(selected, 1);
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
        safe(tester, key('creation-review-start'), size);
        await tap(tester, key('creation-review-start'));
        expect(await result, -1);
        expect(tester.takeException(), isNull);
      });
      testWidgets(
        'real creation shell setup to photos and back $size dark=$dark',
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
          await tap(tester, key('creation-setup-next'));
          expect(find.byType(TemplatePhotoFillStep), findsOneWidget);
          expect(
            tester.getSize(key('template-book-cover')).height,
            greaterThanOrEqualTo(64),
          );
          await capture(tester, 'creation-atelier-shell-photos', size, dark);
          await tap(tester, find.byTooltip('뒤로가기'));
          expect(find.byType(AlbumCreateStep1), findsOneWidget);
          expect(
            tester
                .widget<TextField>(key('creation-album-title'))
                .controller!
                .text,
            template.title,
          );
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
      },
    );
  }
  testWidgets(
    'filtered catalog removes the featured artwork and unavailable templates never become AI output',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(
        tester,
        AiAlbumStartStep(
          templates: AsyncData([template]),
          onAiStart: () {},
          onManualStart: () {},
        ),
      );
      await tap(tester, find.text('유료').first);
      expect(key('creation-collection-showcase'), findsNothing);
      await mount(
        tester,
        AiAlbumStartStep(
          templates: const AsyncLoading(),
          onAiStart: () {},
          onManualStart: () {},
        ),
      );
      expect(key('creation-collection-showcase'), findsNothing);
      expect(find.byType(TemplatePageRenderer), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

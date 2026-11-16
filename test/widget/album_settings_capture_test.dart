import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_document_preview.dart';
import 'package:snap_fit/shared/widgets/album_stage_style.dart';
import 'package:snap_fit/shared/widgets/catalog_cover_skeleton.dart';
import 'package:snap_fit/shared/widgets/experience_form_style.dart';

// These are actual AlbumCreateStep1 component captures in a representative host.
// The AppBar/progress below are fixtures, not AlbumCreateFlowScreen captures.
// Keyboard coverage uses a simulated view inset; it does not draw an OS keyboard.
class _CaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const _albumName = '우리의 결혼 기록';
const _defaultOutput = 'docs/verification/album-settings-design-2026-11-11';
const _pixelRatio = 2.0;

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _loadRealFonts() async {
  // setUpAll runs outside testWidgets' fake clock; load real document/UI faces.
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final font in manifest) {
    final loader = FontLoader(font['family'] as String);
    for (final asset in font['fonts'] as List) {
      loader.addFont(rootBundle.load(asset['asset'] as String));
    }
    await loader.load();
  }
}

List<List<LayerModel>> _weddingPages() {
  // Match creation_workshop_journey_test's published wedding fixture.
  final template = publishedCreationTemplates.firstWhere(
    (item) => item.id == -9501,
  );
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
  return AlbumCreationTemplate.preparePages(
    raw,
    sourceCanvas: source,
    cover: defaultCoverSize,
    // These are bundled sample photographs, never personal uploads.
    clearSamplePhotos: false,
  );
}

void _metrics(WidgetTester tester, Size size, {double keyboard = 0}) {
  tester.view.devicePixelRatio = _pixelRatio;
  tester.view.physicalSize = size * _pixelRatio;
  tester.view.padding = size.width > size.height
      ? FakeViewPadding(
          left: 32 * _pixelRatio,
          right: 48 * _pixelRatio,
          bottom: keyboard > 0 ? 0 : 24 * _pixelRatio,
        )
      : FakeViewPadding(top: 24 * _pixelRatio, bottom: 34 * _pixelRatio);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * _pixelRatio);
}

Future<void> _settleArtwork(WidgetTester tester) async {
  var stableFrames = 0;
  for (var frame = 0; frame < 160; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 32));
    final ready =
        PaintingBinding.instance.imageCache.pendingImageCount == 0 &&
        find.byType(CatalogCoverSkeleton).evaluate().isEmpty;
    // Focused inputs keep scheduling cursor frames, so images are the bound.
    stableFrames = ready && frame >= 12 ? stableFrames + 1 : 0;
    if (stableFrames == 4) {
      expect(tester.takeException(), isNull);
      return;
    }
  }
  fail('Album settings artwork did not settle within 160 bounded frames.');
}

Future<void> _openSection(WidgetTester tester, String section) async {
  final toggle = _key('creation-settings-$section-toggle');
  await tester.ensureVisible(toggle);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(toggle);
  await tester.pump(const Duration(milliseconds: 250));
  await _settleArtwork(tester);
}

Widget _host(
  GlobalKey boundary,
  List<List<LayerModel>> pages, {
  required bool dark,
  required double textScale,
  required ValueChanged<String> onNameChanged,
}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, __) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
      splashFactory: NoSplash.splashFactory,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: RepaintBoundary(key: boundary, child: child!),
    ),
    home: Builder(
      builder: (context) => Scaffold(
        backgroundColor: AlbumStageStyle.top(context),
        appBar: AppBar(
          backgroundColor: AlbumStageStyle.top(context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          toolbarHeight: 52,
          leading: IconButton(
            tooltip: '뒤로가기',
            onPressed: () {},
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
          ),
          title: Text(
            '앨범 설정',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExperienceFormStyle.text(
              context,
              19,
              weight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              tooltip: '임시 저장',
              onPressed: () {},
              icon: const Icon(Icons.save_outlined, size: 21),
            ),
            IconButton(
              tooltip: '앨범 만들기 나가기',
              onPressed: () {},
              icon: const Icon(Icons.close_rounded, size: 21),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Text(
                    '2 / 5 · 설정',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: .4,
                      minHeight: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AlbumCreateStep1(
                albumTitle: _albumName,
                templateTitle: publishedCreationTemplates
                    .firstWhere((item) => item.id == -9501)
                    .title,
                sourceLabel: '선택한 템플릿',
                selectedCover: defaultCoverSize,
                availableCovers: coverSizes,
                selectedPageCount: 24,
                minPageCount: 24,
                templatePageCount: 24,
                coverLayers: pages.first,
                documentPages: pages,
                preserveTypography: true,
                onTitleChanged: onNameChanged,
                onCoverSelected: (_) =>
                    fail('Capture must not resize artwork.'),
                onPageCountChanged: (_) =>
                    fail('Capture must not change pages.'),
                onNext: () => fail('Capture must not create an album.'),
                onChangeDesign: () => fail('Capture must not change designs.'),
                onEditCoverText: () =>
                    fail('Capture must not edit cover copy.'),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  Directory output,
  String filename,
  Size size,
) async {
  await _settleArtwork(tester);
  expect(tester.getTopLeft(find.text('앨범 설정')).dy, greaterThanOrEqualTo(0));
  // Re-record retained layers before reading the software renderer's scene.
  // This prevents an old scrolled display list leaking into a later capture.
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  repaint(boundary.currentContext!.findRenderObject()!);
  await tester.pump(const Duration(milliseconds: 32));
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: _pixelRatio);
    try {
      expect(image.width, (size.width * _pixelRatio).round());
      expect(image.height, (size.height * _pixelRatio).round());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('PNG encoding failed: $filename');
      await output.create(recursive: true);
      await File('${output.path}/$filename').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    } finally {
      image.dispose();
    }
  });
}

void main() {
  // Keep image output opt-in so ordinary widget runs do not launch captures.
  final directory = Platform.environment['ALBUM_SETTINGS_CAPTURE_DIR']?.trim();
  if (!const bool.fromEnvironment('ALBUM_SETTINGS_CAPTURE') &&
      directory == null) {
    return;
  }
  _CaptureBinding();
  final output = Directory(
    directory == null || directory.isEmpty ? _defaultOutput : directory,
  );
  late List<List<LayerModel>> pages;
  setUpAll(() async {
    await _loadRealFonts();
    pages = _weddingPages();
    expect(pages, hasLength(25));
  });

  for (final state in [
    'book',
    'book-scrolled',
    'name',
    'pages',
    'dark',
    'small-text2',
    'landscape-keyboard',
  ]) {
    testWidgets('capture album settings component host $state', (tester) async {
      addTearDown(tester.view.reset);
      final dark = state == 'dark';
      final largeText = state == 'small-text2';
      final keyboard = state == 'landscape-keyboard';
      final size = largeText ? const Size(320, 568) : const Size(390, 844);
      _metrics(tester, size);
      final originals = pages.map((page) => [...page]).toList();
      final boundary = GlobalKey();
      var name = _albumName;
      try {
        await tester.pumpWidget(
          _host(
            boundary,
            pages,
            dark: dark,
            textScale: largeText ? 2 : 1,
            onNameChanged: (value) => name = value,
          ),
        );
        await _settleArtwork(tester);
        var captureSize = size;
        if (state == 'name' || keyboard) {
          await _openSection(tester, 'name');
          final input = _key('creation-album-title');
          await tester.ensureVisible(input);
          await tester.pump(const Duration(milliseconds: 200));
          if (keyboard) {
            await tester.showKeyboard(input);
            tester.testTextInput.updateEditingValue(
              TextEditingValue(
                text: _albumName,
                selection: TextSelection.collapsed(offset: _albumName.length),
                composing: TextRange(
                  start: _albumName.length - 1,
                  end: _albumName.length,
                ),
              ),
            );
            await tester.pump();
            final controller = tester.widget<TextField>(input).controller!;
            final editing = controller.value;
            captureSize = const Size(844, 390);
            _metrics(tester, captureSize, keyboard: 140);
            await _settleArtwork(tester);
            expect(
              tester.widget<TextField>(input).controller,
              same(controller),
            );
            expect(controller.value, editing);
          }
        } else if (state == 'book-scrolled') {
          await tester.ensureVisible(_key('creation-settings-pages-toggle'));
        } else if (state == 'pages') {
          await _openSection(tester, 'pages');
          await tester.ensureVisible(find.byTooltip('페이지 늘리기'));
        } else if (largeText) {
          await tester.ensureVisible(_key('creation-settings-book-toggle'));
        }

        final preview = tester.widget<CreationDocumentPreview>(
          find.byType(CreationDocumentPreview, skipOffstage: false),
        );
        expect(preview.pages, same(pages));
        expect(preview.canvas, coverCanvasBaseSize(defaultCoverSize));
        expect(preview.preserveTypography, isTrue);
        expect(
          pages,
          originals,
          reason: 'Capture must retain original layers.',
        );
        expect(name, _albumName);
        await _capture(
          tester,
          boundary,
          output,
          'after-$state-${captureSize.width.toInt()}x${captureSize.height.toInt()}.png',
          captureSize,
        );
      } finally {
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
    });
  }
}

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as bitmap;
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/photo_crop_sheet.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/web/web_design.dart';

import 'photo_crop_sheet_test.dart' show waitForCropPhoto;

const _emitMemory = bool.fromEnvironment('PHOTO_WORKFLOW_MEMORY_IMAGES');
final _boundary = GlobalKey();

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

BrowserPhotoAsset _photo(String id, int red) {
  final pixels = bitmap.Image(width: 160, height: 100);
  bitmap.fill(pixels, color: bitmap.ColorRgb8(red, 100, 150));
  final bytes = Uint8List.fromList(bitmap.encodePng(pixels));
  return BrowserPhotoAsset.fromStored(
    ownerId: 'local-context-test',
    id: 'browser_$id',
    name: '$id.png',
    width: 160,
    height: 100,
    createdAtSecond: 0,
    originalBytes: bytes,
    previewBytes: bytes,
    contentSha256: sha256.convert(bytes).toString(),
  );
}

Future<void> _memoryImage(WidgetTester tester, String id) async {
  if (!_emitMemory) return;
  for (var attempt = 0; attempt < 80; attempt++) {
    final photos = tester.widgetList<RawImage>(find.byType(RawImage));
    if (photos.isNotEmpty && photos.every((p) => p.image != null)) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  expect(
    tester
        .widgetList<RawImage>(find.byType(RawImage))
        .every((p) => p.image != null),
    isTrue,
  );
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      // RAM-only protocol. Never write image or preview files.
      // ignore: avoid_print
      print(
        'SNAPFIT_MEMORY_IMAGE_V1:${jsonEncode({'id': id, 'mimeType': 'image/png', 'width': image.width, 'height': image.height, 'base64': base64Encode(data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))})}',
      );
    } finally {
      image.dispose();
    }
  });
}

void main() {
  _PaintBinding();
  setUpAll(() async {
    if (!_emitMemory || kIsWeb) return;
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts.whereType<Map>()) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in (font['fonts'] as List).whereType<Map>()) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });

  final source = _photo('selected', 80);
  final otherSource = _photo('other', 180);
  final original = LayerModel(
    id: 'selected-photo',
    type: LayerType.image,
    position: Offset.zero,
    width: 500,
    height: 500,
    asset: source,
    imageBackground: 'none',
  );
  final title = LayerModel(
    id: 'fixed-title',
    type: LayerType.text,
    position: const Offset(40, 50),
    width: 420,
    height: 70,
    text: '같은 표지 안에서',
    zIndex: 1,
    textStyle: const TextStyle(fontSize: 30, color: Colors.white),
  );
  final other = LayerModel(
    id: 'other-photo',
    type: LayerType.image,
    position: const Offset(350, 350),
    width: 100,
    height: 100,
    asset: otherSource,
    zIndex: 2,
  );
  Finder key(String id) => find.byKey(ValueKey(id));
  TemplatePageRenderer current(WidgetTester tester) =>
      tester.widget<TemplatePageRenderer>(find.byType(TemplatePageRenderer));

  Widget host({
    required PhotoCropPageContext pageContext,
    required ValueChanged<LayerModel?> onResult,
    double textScale = 1,
    bool dark = false,
    LayerModel? photo,
  }) => MaterialApp(
    theme: kIsWeb
        ? SnapFitWebTheme.from(SnapFitTheme.light())
        : SnapFitTheme.light(),
    darkTheme: kIsWeb
        ? SnapFitWebTheme.from(SnapFitTheme.dark())
        : SnapFitTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: RepaintBoundary(key: _boundary, child: child!),
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => onResult(
            await showPhotoCropSheet(
              context,
              layer: photo ?? original,
              pageContext: pageContext,
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  PhotoCropPageContext context({
    ValueChanged<LayerModel>? onDraft,
    VoidCallback? onPageTap,
  }) => PhotoCropPageContext(
    canvasSize: const Size(500, 500),
    builder: (draft) {
      onDraft?.call(draft);
      return TemplatePageRenderer(
        layers: [draft, title, other],
        width: 500,
        height: 500,
        designCanvasSize: const Size(500, 500),
        preserveTypography: true,
        onLayerTap: (_) => onPageTap?.call(),
      );
    },
  );

  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'page context shows the crop draft, preserves other artwork and cannot edit it',
    (tester) async {
      viewport(tester, const Size(390, 844));
      LayerModel? result, draft;
      var pageTaps = 0;
      await tester.pumpWidget(
        host(
          pageContext: context(
            onDraft: (value) => draft = value,
            onPageTap: () => pageTaps++,
          ),
          onResult: (value) => result = value,
        ),
      );
      await tester.tap(find.text('open'));
      await waitForCropPhoto(tester);
      expect(key('photo-crop-page-context'), findsNothing);
      await tester.tap(find.byTooltip('사진 확대'));
      await tester.drag(key('photo-crop-preview'), const Offset(-25, 10));
      await tester.pumpAndSettle();
      final edited = current(tester).layers.single;
      await tester.tap(key('photo-crop-context-toggle'));
      await tester.pumpAndSettle();
      expect(key('photo-crop-page-context'), findsOneWidget);
      expect(find.text(title.text!), findsOneWidget);
      expect(current(tester).layers[1], same(title));
      expect(current(tester).layers[2], same(other));
      expect(draft!.imageZoom, edited.imageZoom);
      expect(draft!.imageOffset, edited.imageOffset);
      expect(draft!.asset, same(source));
      expect(draft!.position, original.position);
      expect(key('photo-crop-zoom'), findsNothing);
      await tester.tapAt(tester.getCenter(key('photo-crop-page-context')));
      await tester.dragFrom(
        tester.getCenter(key('photo-crop-page-context')),
        const Offset(30, -20),
      );
      await tester.pumpAndSettle();
      expect(pageTaps, 0);
      expect(draft!.imageOffset, edited.imageOffset);
      expect(original.imageZoom, 1);
      await tester.tap(key('photo-crop-context-toggle'));
      await waitForCropPhoto(tester);
      expect(current(tester).layers.single.imageOffset, edited.imageOffset);
      await tester.tap(key('photo-crop-apply'));
      await tester.pumpAndSettle();
      expect(result!.imageZoom, edited.imageZoom);
      expect(result!.imageOffset, edited.imageOffset);
      expect(other.asset, same(otherSource));
      expect(
        source.contentSha256,
        sha256.convert(source.originalBytes).toString(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelling from page context preserves the original crop', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    LayerModel? result = original;
    await tester.pumpWidget(
      host(pageContext: context(), onResult: (value) => result = value),
    );
    await tester.tap(find.text('open'));
    await waitForCropPhoto(tester);
    await tester.tap(find.byTooltip('사진 확대'));
    await tester.tap(key('photo-crop-context-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(key('photo-crop-cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(original.imageZoom, 1);
    expect(original.imageOffset ?? Offset.zero, Offset.zero);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(640, 320),
    const Size(320, 320),
  ]) {
    testWidgets(
      'page confirmation and crop actions remain reachable at 200% $size',
      (tester) async {
        viewport(tester, size);
        await tester.pumpWidget(
          host(
            pageContext: context(),
            onResult: (_) {},
            textScale: 2,
            dark: true,
          ),
        );
        await tester.tap(find.text('open'));
        await waitForCropPhoto(tester);
        for (var mode = 0; mode < 2; mode++) {
          for (final id in [
            'photo-crop-context-toggle',
            'photo-crop-cancel',
            'photo-crop-apply',
          ]) {
            final button = key(id);
            expect(
              button.hitTestable(),
              findsOneWidget,
              reason: '$id $size mode $mode',
            );
            final bounds = tester.getRect(button);
            expect(bounds.left, greaterThanOrEqualTo(0));
            expect(bounds.right, lessThanOrEqualTo(size.width));
            expect(bounds.bottom, lessThanOrEqualTo(size.height));
          }
          await tester.tap(key('photo-crop-context-toggle'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  if (_emitMemory && !kIsWeb) {
    testWidgets('travel cover crop and page context are inspected in RAM', (
      tester,
    ) async {
      viewport(tester, const Size(390, 844));
      final design = publishedPremiumTemplates.firstWhere(
        (template) => template.id == -9522,
      );
      final doc = jsonDecode(design.templateJson!) as Map<String, dynamic>;
      final canvas = Size(
        (doc['designWidth'] as num).toDouble(),
        (doc['designHeight'] as num).toDouble(),
      );
      final layers = DataTemplateEngine.buildLayersFromJson({
        'strictLayout': true,
        'designWidth': canvas.width,
        'designHeight': canvas.height,
        'layers': templateDocumentPages(doc).first['layers'],
      }, canvas);
      final photo = layers
          .where((layer) => layer.type == LayerType.image)
          .reduce((a, b) => a.width * a.height > b.width * b.height ? a : b);
      await tester.pumpWidget(
        host(
          photo: photo,
          onResult: (_) {},
          pageContext: PhotoCropPageContext(
            canvasSize: canvas,
            builder: (draft) => TemplatePageRenderer(
              layers: [
                for (final layer in layers)
                  layer.id == draft.id ? draft : layer,
              ],
              width: canvas.width,
              height: canvas.height,
              designCanvasSize: canvas,
              preserveTypography: true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await waitForCropPhoto(tester);
      await _memoryImage(tester, 'travel-cover-photo-crop');
      await tester.tap(key('photo-crop-context-toggle'));
      await tester.pumpAndSettle();
      await _memoryImage(tester, 'travel-cover-in-page-context');
      expect(tester.takeException(), isNull);
    });
  }
}

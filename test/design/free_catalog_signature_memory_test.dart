import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

const _emitImages = bool.fromEnvironment('FREE_CATALOG_MEMORY_IMAGES');
const _renderWidth = 240.0;

class _CoverPaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.whereType<Map>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).whereType<Map>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<({ui.Image image, int decoded})> _capture(
  WidgetTester tester,
  AuthoredCollection collection,
  CollectionAspect aspect,
) async {
  final document = collection.document(aspect);
  final layers = DataTemplateEngine.buildLayersFromJson(
    Map<String, dynamic>.from(document['cover'] as Map),
    aspect.canvas,
  );
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSans'),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: TemplatePageRenderer(
              layers: layers,
              width: _renderWidth,
              height: _renderWidth / aspect.canvas.aspectRatio,
              designCanvasSize: aspect.canvas,
              preserveTypography: true,
              normalizeToContentBounds: false,
              showCanvasChrome: false,
              imageDecodeWidth: 1024,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  final images = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
  expect(
    images.length,
    greaterThanOrEqualTo(layers.where((l) => l.type == LayerType.image).length),
    reason: '${collection.id}/${aspect.name}: actual sample photos must decode',
  );
  expect(
    images.every((image) => image.image != null),
    isTrue,
    reason: '${collection.id}/${aspect.name}: unloaded image',
  );
  expect(
    tester.takeException(),
    isNull,
    reason: '${collection.id}/${aspect.name}',
  );
  final image = (await tester.runAsync(
    () => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
        .toImage(),
  ))!;
  return (image: image, decoded: images.length);
}

void _label(
  Canvas canvas,
  String value,
  Offset offset, {
  double width = _renderWidth,
  double size = 14,
}) {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: 'NotoSans',
        fontSize: size,
        height: 1.25,
        color: const Color(0xFF273A35),
      ),
    ),
  )..layout(maxWidth: width);
  painter.paint(canvas, offset);
  painter.dispose();
}

Future<ui.Image> _contactSheet(
  String category,
  List<AuthoredCollection> collections,
  List<ui.Image> images,
) async {
  const padding = 24.0, gutter = 20.0, rowHeight = 390.0, header = 70.0;
  final width = (padding * 2 + _renderWidth * 3 + gutter * 2).ceil();
  final height = (header + rowHeight * collections.length + padding).ceil();
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFF1F0EB), BlendMode.src);
  _label(
    canvas,
    '$category · 무료 표지 / 실제 편집 레이어',
    const Offset(padding, 15),
    width: width - padding * 2,
    size: 20,
  );
  for (final (column, aspect) in CollectionAspect.values.indexed) {
    final x = padding + column * (_renderWidth + gutter);
    _label(canvas, aspect.name, Offset(x, 45), size: 12);
  }
  for (final (row, collection) in collections.indexed) {
    final y = header + row * rowHeight;
    for (var column = 0; column < 3; column++) {
      final image = images[row * 3 + column];
      final x = padding + column * (_renderWidth + gutter);
      canvas.drawImage(image, Offset(x, y), Paint());
      _label(canvas, collection.title, Offset(x, y + image.height + 8));
      _label(
        canvas,
        '${collection.bundledId} · ${collection.id}',
        Offset(x, y + image.height + 29),
        size: 10,
      );
    }
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

void main() {
  _CoverPaintBinding();
  testWidgets('all 126 free covers render with real fonts and photos in RAM', (
    tester,
  ) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(authoredCollections, hasLength(42));
    final categories = authoredCollections.map((c) => c.category).toSet();
    expect(categories, hasLength(7));
    final summaries = <Map<String, Object?>>[];
    for (final category in categories) {
      final collections = authoredCollections
          .where((c) => c.category == category)
          .toList();
      final captures = <ui.Image>[];
      try {
        for (final collection in collections) {
          for (final aspect in CollectionAspect.values) {
            final result = await _capture(tester, collection, aspect);
            captures.add(result.image);
            summaries.add({
              'collection': collection.id,
              'aspect': aspect.name,
              'width': result.image.width,
              'height': result.image.height,
              'decodedImages': result.decoded,
            });
          }
        }
        if (_emitImages) {
          final sheet = (await tester.runAsync(
            () => _contactSheet(category, collections, captures),
          ))!;
          try {
            await tester.runAsync(() async {
              final bytes = (await sheet.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              // RAM-only protocol: never redirect image-enabled stdout to
              // disk. There are intentionally no file/export APIs here.
              // ignore: avoid_print
              print(
                'SNAPFIT_MEMORY_IMAGE_V1:${jsonEncode({'id': 'free-catalog-$category', 'mimeType': 'image/png', 'width': sheet.width, 'height': sheet.height, 'base64': base64Encode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))})}',
              );
            });
          } finally {
            sheet.dispose();
          }
        }
      } finally {
        for (final image in captures) image.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
    }
    expect(summaries, hasLength(126));
    // ignore: avoid_print
    print('SNAPFIT_FREE_CATALOG_METRICS_V1:${jsonEncode(summaries)}');
  }, timeout: const Timeout(Duration(minutes: 8)));
}

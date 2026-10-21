import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

const _emit = bool.fromEnvironment('FREE_EDITORIAL_MEMORY_IMAGES');
// Early visual diagnosis only. Release verification must leave this false.
const _representativesOnly = bool.fromEnvironment(
  'FREE_EDITORIAL_REPRESENTATIVES_ONLY',
);
const _emitCollection = String.fromEnvironment(
  'FREE_EDITORIAL_MEMORY_COLLECTION',
);
const _emitAspect = String.fromEnvironment('FREE_EDITORIAL_MEMORY_ASPECT');
const _emitPages = String.fromEnvironment('FREE_EDITORIAL_MEMORY_PAGES');
const _width = 240.0;
final _sheets = <String, Map<String, Map<int, Uint8List>>>{};
var _rendered = 0, _decoded = 0, _fittedPhotos = 0;

Future<void> _fonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final raw in manifest.whereType<Map>()) {
    final loader = FontLoader(raw['family'] as String);
    for (final font in (raw['fonts'] as List).whereType<Map>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

String? _assetName(ImageProvider provider) {
  if (provider is AssetImage) return provider.assetName;
  if (provider is ResizeImage) return _assetName(provider.imageProvider);
  return null;
}

ui.Image? _rawImage(Element element) {
  final widget = element.widget;
  if (widget is RawImage) return widget.image;
  ui.Image? result;
  element.visitChildren((child) {
    result ??= _rawImage(child);
  });
  return result;
}

Set<int> _representatives(List<Map<String, dynamic>> pages) {
  final spreadCount = (pages.length - 1) ~/ 2;
  final densities = <int, int>{};
  for (var spread = 1; spread <= spreadCount; spread++) {
    var length = 0;
    for (final index in [spread * 2 - 1, spread * 2]) {
      for (final layer in (pages[index]['layers'] as List).cast<Map>()) {
        if (layer['type'] != 'text') continue;
        length += (layer['editorialSourceText'] ?? layer['text'] ?? '')
            .toString()
            .length;
      }
    }
    densities[spread] = length;
  }
  final chosen = <int>{1, math.max(2, (spreadCount / 2).round())};
  final ranked = densities.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in ranked) {
    chosen.add(entry.key);
    if (chosen.length == 3) break;
  }
  return {
    0,
    for (final spread in chosen) ...[spread * 2 - 1, spread * 2],
  };
}

Future<({ui.Image image, int decoded, int fitted})> _capture(
  WidgetTester tester,
  List<LayerModel> layers,
  CollectionAspect aspect,
  String book,
  int page,
  double width,
) async {
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
              width: width,
              height: width / aspect.canvas.aspectRatio,
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
  final label = '$book/$page';
  final rawImages = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
  final photos = layers.where((l) => l.type == LayerType.image).toList();
  expect(rawImages.length, greaterThanOrEqualTo(photos.length), reason: label);
  expect(
    rawImages.every((image) => image.image != null),
    isTrue,
    reason: '$label: decoded images',
  );
  expect(tester.takeException(), isNull, reason: label);
  final decodedAssets = <String, ui.Image>{};
  for (final element in find.byType(Image).evaluate()) {
    final path = _assetName((element.widget as Image).image);
    final image = _rawImage(element);
    if (path != null && image != null) decodedAssets[path] = image;
  }
  var fitted = 0;
  for (final photo in photos) {
    final path = photo.imageUrl?.replaceFirst(RegExp(r'^asset:'), '');
    final decoded = decodedAssets[path];
    expect(
      decoded,
      isNotNull,
      reason: '$label/${photo.id}: actual source must decode',
    );
    if (decoded == null || page == 0) continue; // Cover crops are intentional.
    final sourceRatio = decoded.width / decoded.height;
    final frameRatio = photo.width / photo.height;
    final retention = math.min(
      frameRatio / sourceRatio,
      sourceRatio / frameRatio,
    );
    expect(
      retention,
      greaterThanOrEqualTo(.98),
      reason:
          '$label/${photo.id}: source $sourceRatio in $frameRatio frame crops content',
    );
    fitted++;
  }
  final image = (await tester.runAsync(
    () => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
        .toImage(),
  ))!;
  return (image: image, decoded: rawImages.length, fitted: fitted);
}

Future<Uint8List> _bytes(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  return Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

void _label(
  Canvas canvas,
  String value,
  Offset at,
  double width, {
  double size = 13,
}) {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: 'NotoSans',
        fontSize: size,
        height: 1.25,
        color: const Color(0xFF263A35),
      ),
    ),
  )..layout(maxWidth: width);
  painter.paint(canvas, at);
  painter.dispose();
}

Future<void> _emitImage(String id, ui.Image image) async {
  final bytes = await _bytes(image);
  // Stdout is a RAM-only image protocol. Never redirect it to a log file.
  // No filesystem, preview, PDF, golden or export APIs are imported here.
  // ignore: avoid_print
  print(
    'SNAPFIT_MEMORY_IMAGE_V1:${jsonEncode({'id': id, 'mimeType': 'image/png', 'width': image.width, 'height': image.height, 'base64': base64Encode(bytes)})}',
  );
}

Future<void> _emitCategory(
  String category,
  List<AuthoredCollection> books,
) async {
  const padding = 24.0, gap = 8.0, rowHeight = _width + 54;
  final width = (padding * 2 + _width * 7 + gap * 6).ceil();
  final height = (64 + books.length * rowHeight + padding).ceil();
  final images = <ui.Image>[];
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFF1F0EB), BlendMode.src);
  _label(
    canvas,
    '$category · 표지와 세 펼침면 · 정사각형',
    const Offset(padding, 18),
    width - padding * 2,
    size: 21,
  );
  try {
    for (final (row, book) in books.indexed) {
      final captures = _sheets[category]![book.id]!;
      var column = 0;
      for (final page in captures.entries) {
        final codec = await ui.instantiateImageCodec(page.value);
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        images.add(image);
        final at = Offset(
          padding + column * (_width + gap),
          64 + row * rowHeight,
        );
        canvas.drawImage(image, at, Paint());
        _label(
          canvas,
          '${book.title} · ${page.key == 0 ? '표지' : '${page.key}쪽'}',
          at + const Offset(0, _width + 8),
          _width,
          size: 12,
        );
        column++;
      }
    }
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        await _emitImage('free-editorial-$category', image);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    for (final image in images) image.dispose();
    _sheets.remove(category);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_fonts);
  final categories = authoredCollections.map((c) => c.category).toSet();
  final requestedPages = _emitPages
      .split(',')
      .map(int.tryParse)
      .whereType<int>()
      .toSet();
  for (final category in categories) {
    final books = authoredCollections
        .where((c) => c.category == category)
        .toList();
    for (final collection in books) {
      for (final aspect in CollectionAspect.values.where(
        (a) => !_representativesOnly || a == CollectionAspect.square,
      )) {
        testWidgets(
          '${collection.id}/${aspect.name}: every page renders and source photographs fit',
          (tester) async {
            tester.view.physicalSize = const Size(1400, 1200);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final document = collection.document(aspect);
            final pages = templateDocumentPages(document);
            final selected = _representatives(pages);
            final detailed =
                _emit &&
                _emitCollection.isNotEmpty &&
                _emitCollection == collection.id &&
                (_emitAspect.isEmpty || _emitAspect == aspect.name);
            final captures = <int, Uint8List>{};
            var count = 0, decoded = 0, fitted = 0;
            for (final (page, raw) in pages.indexed) {
              if (_representativesOnly && !selected.contains(page)) continue;
              final layers = DataTemplateEngine.buildLayersFromJson(
                raw,
                aspect.canvas,
              );
              final detailPage =
                  detailed &&
                  (requestedPages.isEmpty
                      ? selected.contains(page)
                      : requestedPages.contains(page));
              final result = await _capture(
                tester,
                layers,
                aspect,
                '${collection.id}/${aspect.name}',
                page,
                detailPage ? 480 : _width,
              );
              try {
                if (_emit &&
                    _emitCollection.isEmpty &&
                    aspect == CollectionAspect.square &&
                    selected.contains(page) &&
                    !detailPage) {
                  captures[page] = (await tester.runAsync(
                    () => _bytes(result.image),
                  ))!;
                }
                if (detailPage)
                  await tester.runAsync(
                    () => _emitImage(
                      'free-editorial-${collection.id}-${aspect.name}-$page',
                      result.image,
                    ),
                  );
                count++;
                decoded += result.decoded;
                fitted += result.fitted;
              } finally {
                result.image.dispose();
                await tester.pumpWidget(const SizedBox.shrink());
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
              }
            }
            if (_emit &&
                _emitCollection.isEmpty &&
                aspect == CollectionAspect.square &&
                !detailed) {
              (_sheets[category] ??= {})[collection.id] = captures;
            }
            _rendered += count;
            _decoded += decoded;
            _fittedPhotos += fitted;
            expect(
              count,
              _representativesOnly ? selected.length : pages.length,
            );
            // ignore: avoid_print
            print(
              'SNAPFIT_FREE_EDITORIAL_BOOK_METRICS_V1:${jsonEncode({'collection': collection.id, 'scope': _representativesOnly ? 'visual-diagnosis' : 'complete-book', 'aspect': aspect.name, 'pages': count, 'decodedImages': decoded, 'sourceAspectChecks': fitted, 'representativePages': selected.toList()..sort()})}',
            );
          },
          timeout: const Timeout(Duration(minutes: 3)),
        );
      }
    }
    if (_emit && _emitCollection.isEmpty) {
      test('emit $category representative spreads in RAM', () async {
        await _emitCategory(category, books);
      });
    }
  }
  test('the full free catalogue render covered every page', () {
    expect(_rendered, _representativesOnly ? 294 : 3174);
    expect(_decoded, greaterThan(0));
    expect(_fittedPhotos, greaterThan(0));
    // ignore: avoid_print
    print(
      'SNAPFIT_FREE_EDITORIAL_ALL_METRICS_V1:${jsonEncode({'books': _representativesOnly ? 42 : 126, 'scope': _representativesOnly ? 'visual-diagnosis' : 'complete-catalogue', 'pages': _rendered, 'decodedImages': _decoded, 'sourceAspectChecks': _fittedPhotos, 'previewFiles': 0})}',
    );
  });
}

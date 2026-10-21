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
import '../unit/paid_editorial_book_quality_test.dart'
    show PaidEditorialBook, paidEditorialBooks, loadPaidEditorialFonts;

const _emit = bool.fromEnvironment('PAID_EDITORIAL_MEMORY_IMAGES');
const _coversOnly = bool.fromEnvironment('PAID_EDITORIAL_COVERS_ONLY');
// Early visual diagnosis only. Release verification must leave this false.
const _representativesOnly = bool.fromEnvironment(
  'PAID_EDITORIAL_REPRESENTATIVES_ONLY',
);
const _emitCollection = String.fromEnvironment(
  'PAID_EDITORIAL_MEMORY_COLLECTION',
);
const _emitAspect = String.fromEnvironment('PAID_EDITORIAL_MEMORY_ASPECT');
const _emitPages = String.fromEnvironment('PAID_EDITORIAL_MEMORY_PAGES');
const _width = 240.0;
const _coverWidth = 320.0;

class _CoverPaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

final _sheets = <String, Map<String, Map<int, Uint8List>>>{};
var _rendered = 0, _decoded = 0, _fittedPhotos = 0;

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
  List<PaidEditorialBook> books,
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
      final captures = _sheets[category]![book.key]!;
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
          '${book.template.title} ${book.count}쪽 · ${page.key == 0 ? '표지' : '${page.key}쪽'}',
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
        await _emitImage('paid-editorial-$category', image);
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

Future<void> _emitCoverCategory(
  String category,
  List<PaidEditorialBook> books,
) async {
  const padding = 24.0, gap = 20.0;
  const aspects = [
    CollectionAspect.portrait,
    CollectionAspect.square,
    CollectionAspect.landscape,
  ];
  final products = <int, List<PaidEditorialBook>>{};
  for (final book in books) {
    (products[book.template.id] ??= []).add(book);
  }
  final imageHeight = aspects
      .map((aspect) => _coverWidth / aspect.canvas.aspectRatio)
      .reduce(math.max);
  final rowHeight = imageHeight + 64;
  final width = (padding * 2 + _coverWidth * 3 + gap * 2).ceil();
  final height = (88 + products.length * rowHeight + padding).ceil();
  final images = <ui.Image>[];
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFF1F0EB), BlendMode.src);
  _label(
    canvas,
    '$category · 전체 표지 사진 구도 · 3가지 비율',
    const Offset(padding, 18),
    width - padding * 2,
    size: 21,
  );
  for (final (column, aspect) in aspects.indexed) {
    _label(
      canvas,
      switch (aspect) {
        CollectionAspect.portrait => '세로 · portrait',
        CollectionAspect.square => '정사각 · square',
        CollectionAspect.landscape => '가로 · landscape',
      },
      Offset(padding + column * (_coverWidth + gap), 52),
      _coverWidth,
      size: 14,
    );
  }
  try {
    for (final (row, editions) in products.values.indexed) {
      expect(editions, hasLength(3));
      for (final (column, aspect) in aspects.indexed) {
        final book = editions.singleWhere((book) => book.aspect == aspect);
        final capture = _sheets[category]![book.key]![0]!;
        final codec = await ui.instantiateImageCodec(capture);
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        images.add(image);
        final at = Offset(
          padding + column * (_coverWidth + gap),
          88 + row * rowHeight,
        );
        canvas.drawImage(image, at, Paint());
        _label(
          canvas,
          '${book.template.title} · ${aspect.name}\n${book.count}쪽 기본 선택 표지',
          at + Offset(0, imageHeight + 8),
          _coverWidth,
          size: 13,
        );
      }
    }
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        await _emitImage('paid-editorial-covers-$category', image);
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
  _CoverPaintBinding();
  setUpAll(loadPaidEditorialFonts);
  final cases = <PaidEditorialBook>[];
  final coveredProducts = <String>{};
  for (final book in paidEditorialBooks()) {
    if (_coversOnly) {
      // The first authored count is the basic edition. Longer editions reuse
      // that same cover, so review each product and aspect exactly once.
      if (!coveredProducts.add('${book.template.id}/${book.aspect.name}')) {
        continue;
      }
    } else if (_representativesOnly && book.aspect != CollectionAspect.square) {
      continue;
    }
    cases.add(book);
  }
  final categories = cases
      .map((book) => (book.template.category ?? '기타'))
      .toSet();
  final requestedPages = _emitPages
      .split(',')
      .map(int.tryParse)
      .whereType<int>()
      .toSet();
  for (final category in categories) {
    final books = cases
        .where((book) => (book.template.category ?? '기타') == category)
        .toList();
    for (final book in books) {
      testWidgets('${book.key}: every paid page renders and photographs fit', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final aspect = book.aspect;
        final pages = templateDocumentPages(book.document);
        final selected = _coversOnly ? <int>{0} : _representatives(pages);
        final matches =
            _emitCollection == book.productKey ||
            _emitCollection == book.productKey.split(':').last ||
            _emitCollection == book.template.id.toString() ||
            _emitCollection == book.key;
        final detailed =
            _emit &&
            _emitCollection.isNotEmpty &&
            matches &&
            (_emitAspect.isEmpty || _emitAspect == aspect.name);
        final captures = <int, Uint8List>{};
        var count = 0, decoded = 0, fitted = 0;
        for (final (page, raw) in pages.indexed) {
          if ((_coversOnly || _representativesOnly) &&
              !selected.contains(page)) {
            continue;
          }
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
            book.key,
            page,
            detailPage ? 480 : (_coversOnly ? _coverWidth : _width),
          );
          try {
            if (_emit &&
                _emitCollection.isEmpty &&
                (_coversOnly || aspect == CollectionAspect.square) &&
                selected.contains(page)) {
              captures[page] = (await tester.runAsync(
                () => _bytes(result.image),
              ))!;
            }
            if (detailPage)
              await tester.runAsync(
                () => _emitImage(
                  'paid-editorial-${book.key}-$page',
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
            (_coversOnly || aspect == CollectionAspect.square)) {
          (_sheets[category] ??= {})[book.key] = captures;
        }
        _rendered += count;
        _decoded += decoded;
        _fittedPhotos += fitted;
        expect(
          count,
          _coversOnly || _representativesOnly ? selected.length : pages.length,
        );
        // ignore: avoid_print
        print(
          'SNAPFIT_PAID_EDITORIAL_BOOK_METRICS_V1:${jsonEncode({'book': book.key, 'product': book.productKey, 'innerPages': book.count, 'scope': _coversOnly ? 'cover-crop-review' : (_representativesOnly ? 'visual-diagnosis' : 'complete-book'), 'pages': count, 'decodedImages': decoded, 'sourceAspectChecks': fitted, 'representativePages': selected.toList()..sort()})}',
        );
      }, timeout: const Timeout(Duration(minutes: 3)));
    }
    if (_emit && _emitCollection.isEmpty) {
      test('emit paid $category representatives in RAM', () async {
        if (_coversOnly) {
          await _emitCoverCategory(category, books);
        } else {
          await _emitCategory(
            category,
            books
                .where((book) => book.aspect == CollectionAspect.square)
                .toList(),
          );
        }
      });
    }
  }
  test('the complete paid catalogue has rendered every edition and page', () {
    expect(_rendered, _coversOnly ? 78 : (_representativesOnly ? 217 : 2757));
    expect(_decoded, greaterThan(0));
    expect(_fittedPhotos, _coversOnly ? equals(0) : greaterThan(0));
    if (_coversOnly) {
      expect(cases, hasLength(78));
      expect(cases.map((book) => book.template.id).toSet(), hasLength(26));
      for (final aspect in CollectionAspect.values) {
        expect(cases.where((book) => book.aspect == aspect), hasLength(26));
      }
    }
    // ignore: avoid_print
    print(
      'SNAPFIT_PAID_EDITORIAL_ALL_METRICS_V1:${jsonEncode({'products': 26, 'editionChoices': _coversOnly ? 26 : 31, 'books': _coversOnly ? 78 : (_representativesOnly ? 31 : 93), 'scope': _coversOnly ? 'cover-crop-review' : (_representativesOnly ? 'visual-diagnosis' : 'complete-catalogue'), 'pages': _rendered, if (_coversOnly) 'covers': _rendered, 'decodedImages': _decoded, 'sourceAspectChecks': _fittedPhotos, 'previewFiles': 0})}',
    );
  });
}

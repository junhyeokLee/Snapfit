import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_text_preflight.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

const _input = String.fromEnvironment('AI_TEMPLATE_LIVE_QUALITY_RUN');
const _emitImages = bool.fromEnvironment('AI_TEMPLATE_MEMORY_IMAGES');
const _metricsOutput = String.fromEnvironment('AI_TEMPLATE_MEMORY_METRICS');

// Images stay in RAM. The caller must consume this stdout protocol in memory,
// never redirect image-enabled stdout into a log file.
const _imagePrefix = 'SNAPFIT_MEMORY_IMAGE_V1:';
const _metricsPrefix = 'SNAPFIT_MEMORY_METRICS_V1:';
const _photos = [
  'assets/templates/jeju_travel/images/sources/jeju_ocean.jpg',
  'assets/templates/jeju_travel/images/sources/jeju_seongsan.jpg',
  'assets/templates/jeju_travel/images/sources/jeju_aerial.jpg',
  'assets/templates/jeju_travel/images/sources/jeju_rocky_coast.jpg',
  'assets/templates/jeju_travel/images/sources/jeju_sunset.jpg',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual generated book and premium references render and round-trip entirely in memory'
    '${_input.isEmpty ? ' [skipped: set AI_TEMPLATE_LIVE_QUALITY_RUN; no automatic AI request]' : ''}',
    (tester) async {
      final report = jsonDecode(File(_input).readAsStringSync()) as Map;
      expect(
        report['mode'],
        'live',
        reason: 'A fixture is not actual model output.',
      );
      expect(report['schemaVersion'], 1);
      final accepted = (report['results'] as List)
          .whereType<Map>()
          .where((entry) => entry['status'] == 'accepted')
          .toList();
      expect(
        accepted,
        isNotEmpty,
        reason: 'The live run has no accepted result.',
      );
      // Native font loading precedes authored factories, which may measure copy
      // while building their editable layer documents.
      final loadedFonts = (await tester.runAsync(_loadActualFonts))!;
      tester.view.physicalSize = const Size(1500, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final summaries = <Map<String, Object?>>[];
      for (final entry in accepted) {
        final brief = entry['brief'] as Map;
        final design = AiTemplateDesign.fromJson(
          Map<String, Object?>.from(entry['document'] as Map),
          brief['pageCount'] as int,
        );
        expect(
          design.pages.length,
          21,
          reason:
              'This comparison inspects one cover and all 20 generated interiors.',
        );
        expect(design.artDirection, isNotNull);
        expect(design.aspect.name, brief['aspect']);
        expect(
          inspectAiTemplateText(design),
          isEmpty,
          reason:
              'Actual bundled-font overflow must fail the generated result.',
        );
        final id = (entry['id'] as String).replaceAll(
          RegExp('[^a-zA-Z0-9_-]'),
          '_',
        );
        final generated = _Book(
          id: 'generated-$id',
          title: '실제 AI 결과',
          canvas: design.canvasSize,
          pages: design.buildLayers(),
          roles: [for (final page in design.pages) page.purpose],
          premium: false,
        );
        final references = [
          _premiumReference(-9502, design),
          _premiumReference(-9512, design),
        ];
        for (final book in [generated, ...references]) {
          final usedFonts = book.pages
              .expand((page) => page)
              .where((layer) => layer.type == LayerType.text)
              .map((layer) => layer.textStyle?.fontFamily)
              .whereType<String>()
              .toSet();
          expect(
            loadedFonts,
            containsAll(usedFonts),
            reason:
                '${book.id}: every named typeface must be a loaded bundle font',
          );
          final pages = <Map<String, Object?>>[];
          final selected = book.premium
              ? <int>[
                  0,
                  1,
                  2,
                  3,
                  4,
                  book.pages.length - 2,
                  book.pages.length - 1,
                ]
              : List<int>.generate(book.pages.length, (index) => index);
          final images = <ui.Image>[];
          final indexes = <int>[];
          try {
            for (final (pageIndex, layers) in book.pages.indexed) {
              // Photo slots use photoBuilder. Every remaining artwork source
              // must also be a local bundle asset before the renderer is built.
              for (final layer in layers.where(
                (layer) => layer.type != LayerType.image,
              )) {
                for (final source in [
                  layer.imageUrl,
                  layer.originalUrl,
                  layer.previewUrl,
                  layer.textFillImageUrl,
                ].whereType<String>()) {
                  expect(
                    source.isEmpty ||
                        source.startsWith('asset:') ||
                        source.startsWith('assets/'),
                    isTrue,
                    reason: '${book.id}: nonlocal artwork source is forbidden',
                  );
                }
              }
              final textIssues = _textIssues(layers);
              if (!book.premium)
                expect(textIssues, isEmpty, reason: '${book.id}/$pageIndex');
              final drift = _verifyLayerRoundTrip(layers, book.canvas);
              var decoded = 0;
              if (selected.contains(pageIndex)) {
                final rendered = await _capturePage(
                  tester,
                  book,
                  pageIndex,
                  width: 225,
                );
                decoded = rendered.decoded;
                images.add(rendered.image);
                indexes.add(pageIndex);
              }
              pages.add({
                'index': pageIndex,
                'role': book.roles[pageIndex],
                'photoCount': layers
                    .where((layer) => layer.type == LayerType.image)
                    .length,
                'textCount': layers
                    .where((layer) => layer.type == LayerType.text)
                    .length,
                'photoAreaSumNormalized': layers
                    .where((layer) => layer.type == LayerType.image)
                    .fold<double>(
                      0,
                      (sum, layer) =>
                          sum +
                          layer.width *
                              layer.height /
                              (book.canvas.width * book.canvas.height),
                    ),
                'largestPhotoAreaNormalized': layers
                    .where((layer) => layer.type == LayerType.image)
                    .fold<double>(
                      0,
                      (value, layer) => math.max(
                        value,
                        layer.width *
                            layer.height /
                            (book.canvas.width * book.canvas.height),
                      ),
                    ),
                'rendered': selected.contains(pageIndex),
                'decodedImages': decoded,
                'textIssues': textIssues,
                'saveLoadMaxDrift': drift,
              });
              // The 21 generated pages form two sheets of eleven and ten pages.
              if (!book.premium &&
                  (images.length == 11 || pageIndex == book.pages.length - 1)) {
                if (_emitImages) {
                  final sheet = (await tester.runAsync(
                    () => _contactSheet(images, indexes, book.title),
                  ))!;
                  try {
                    await tester.runAsync(
                      () => _emit(
                        sheet,
                        '${book.id}-contact-${pageIndex ~/ 11 + 1}',
                      ),
                    );
                  } finally {
                    sheet.dispose();
                  }
                }
                for (final image in images) image.dispose();
                images.clear();
                indexes.clear();
              }
            }
            if (book.premium && _emitImages) {
              final sheet = (await tester.runAsync(
                () => _contactSheet(images, indexes, book.title),
              ))!;
              try {
                await tester.runAsync(
                  () => _emit(sheet, '${book.id}-selected-contact'),
                );
              } finally {
                sheet.dispose();
              }
            }
          } finally {
            for (final image in images) image.dispose();
          }
          if (book.premium && _emitImages) {
            await _emitEnlargement(tester, book, [
              1,
              2,
            ], '${book.id}-opening-spread');
          }
          summaries.add({
            'id': book.id,
            'title': book.title,
            'premiumDesignReference': book.premium,
            'paidAvailabilityVerified': false,
            'canvas': {
              'width': book.canvas.width,
              'height': book.canvas.height,
            },
            'pageCount': book.pages.length,
            'renderedPageIndexes': selected,
            'pages': pages,
          });
        }
        if (_emitImages) {
          await _emitEnlargement(tester, generated, [
            0,
          ], '${generated.id}-cover');
          // The opening, development and ending remain whole facing pairs.
          for (final pair in const [
            [1, 2],
            [9, 10],
            [19, 20],
          ]) {
            await _emitEnlargement(
              tester,
              generated,
              pair,
              '${generated.id}-spread-${pair.first}-${pair.last}',
            );
          }
        }
      }
      final metrics = <String, Object?>{
        'schemaVersion': 1,
        'sourceRunId': report['id'],
        'mode': 'actual-live-run-offline-render',
        'networkOrAiCallsPerformed': false,
        'previewFilesWritten': false,
        'fontValidation':
            'Native bundle fonts loaded before authored factories and measurement.',
        'photoSource': _photos,
        'photoPolicy':
            'The same local public bundle photos enter the renderer through photoBuilder only; no customer image or source document is changed.',
        'comparisonLimits':
            'Premium is the public bundle design classification, not current sale eligibility. Objective guards and agent visual review do not replace user aesthetic approval or print proof.',
        'books': summaries,
      };
      final encoded = jsonEncode(metrics);
      expect(utf8.encode(encoded).length, lessThan(512 * 1024));
      if (_metricsOutput.isNotEmpty) {
        if (!_metricsOutput.endsWith('.json')) {
          throw ArgumentError(
            'AI_TEMPLATE_MEMORY_METRICS must name a JSON file.',
          );
        }
        final output = File(_metricsOutput);
        await tester.runAsync(() async {
          await output.parent.create(recursive: true);
          await output.writeAsString(encoded);
        });
      }
      // Metrics are small text. Image-enabled stdout must stay out of disk logs.
      // ignore: avoid_print
      print('$_metricsPrefix$encoded');
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    },
    skip: _input.isEmpty,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

class _Book {
  const _Book({
    required this.id,
    required this.title,
    required this.canvas,
    required this.pages,
    required this.roles,
    required this.premium,
  });
  final String id, title;
  final Size canvas;
  final List<List<LayerModel>> pages;
  final List<String> roles;
  final bool premium;
}

_Book _premiumReference(int id, AiTemplateDesign generated) {
  final published = publishedPremiumTemplates.singleWhere(
    (template) => template.id == id,
  );
  expect(published.isPremium, isTrue);
  final aspect = CollectionAspect.values.byName(generated.aspect.name);
  // These are the same factories used by publishedPremiumTemplates, with their
  // current default cover/quality refinement enabled, never old archive JSON.
  final document = id == -9502
      ? PremiumVolume.travel.document(aspect, innerPages: 24)
      : ConceptVolume.shoreDays.document(aspect);
  expect(document['accessTier'], 'premium');
  final source = Size(
    (document['designWidth'] as num).toDouble(),
    (document['designHeight'] as num).toDouble(),
  );
  final raw = templateDocumentPages(document);
  final layers = [
    for (final page in raw)
      DataTemplateEngine.buildLayersFromJson({
        'strictLayout': true,
        'designWidth': source.width,
        'designHeight': source.height,
        'layers': page['layers'],
      }, source),
  ];
  return _Book(
    id: 'premium-${-id}',
    title: published.title,
    canvas: generated.canvasSize,
    pages: AlbumCreationTemplate.preparePages(
      layers,
      sourceCanvas: source,
      cover: generated.coverSize,
      clearSamplePhotos: false,
    ),
    roles: [for (final page in raw) '${page['role'] ?? page['name']}'],
    premium: true,
  );
}

Future<Set<String>> _loadActualFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  final loaded = <String>{};
  for (final entry in manifest.whereType<Map>()) {
    final family = entry['family'] as String;
    final loader = FontLoader(family);
    for (final font in (entry['fonts'] as List).whereType<Map>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
    loaded.add(family);
  }
  return loaded;
}

List<Map<String, Object>> _textIssues(List<LayerModel> layers) {
  final issues = <Map<String, Object>>[];
  for (final layer in layers.where((layer) => layer.type == LayerType.text)) {
    final style = layer.textStyle!.copyWith(
      letterSpacing: 0,
      height: math.max(layer.textStyle!.height ?? 1, 1),
    );
    final painter = TextPainter(
      text: TextSpan(text: layer.text, style: style),
      textAlign: layer.textAlign ?? TextAlign.center,
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: true,
        applyHeightToLastDescent: true,
      ),
    );
    try {
      painter.layout(maxWidth: layer.width);
      final width = painter.computeLineMetrics().fold<double>(
        0,
        (value, line) => math.max(value, line.width),
      );
      if (painter.height > layer.height + .5 || width > layer.width + .5) {
        issues.add({
          'id': layer.id,
          'requiredHeight': painter.height,
          'availableHeight': layer.height,
          'requiredWidth': width,
          'availableWidth': layer.width,
        });
      }
    } finally {
      painter.dispose();
    }
  }
  return issues;
}

double _verifyLayerRoundTrip(List<LayerModel> layers, Size canvas) {
  var drift = 0.0;
  for (final layer in layers) {
    for (final factor in [1.0, .8]) {
      final restored = LayerExportMapper.fromJson(
        LayerExportMapper.toJson(layer, canvasSize: canvas),
        canvasSize: canvas * factor,
      );
      expect(restored.id, layer.id);
      expect(restored.type, layer.type);
      expect(restored.imageBackground, layer.imageBackground);
      expect(restored.imageTemplate, layer.imageTemplate);
      expect(restored.zIndex, layer.zIndex);
      expect(restored.rotation, layer.rotation);
      expect(restored.scale, layer.scale);
      expect(restored.opacity, layer.opacity);
      if (layer.type == LayerType.decoration ||
          layer.type == LayerType.sticker) {
        expect(restored.decorationFillColor, layer.decorationFillColor);
        expect(restored.decorationBorderColor, layer.decorationBorderColor);
        expect(restored.decorationBorderWidth, layer.decorationBorderWidth);
        expect(restored.decorationCornerRadius, layer.decorationCornerRadius);
      }
      if (layer.type == LayerType.image || layer.type == LayerType.sticker) {
        expect(restored.originalUrl, layer.originalUrl);
        expect(restored.previewUrl, layer.previewUrl ?? layer.imageUrl);
      }
      for (final difference in [
        restored.position.dx - layer.position.dx * factor,
        restored.position.dy - layer.position.dy * factor,
        restored.width - layer.width * factor,
        restored.height - layer.height * factor,
      ])
        drift = math.max(drift, difference.abs());
      if (layer.type == LayerType.text) {
        expect(restored.text, layer.text);
        expect(restored.textAlign, layer.textAlign);
        expect(restored.textFillMode, layer.textFillMode);
        expect(restored.textStyle!.fontFamily, layer.textStyle!.fontFamily);
        expect(restored.textStyle!.fontWeight, layer.textStyle!.fontWeight);
        expect(restored.textStyle!.height, layer.textStyle!.height);
        expect(restored.textStyle!.color, layer.textStyle!.color);
        drift = math.max(
          drift,
          (restored.textStyle!.fontSize! - layer.textStyle!.fontSize! * factor)
              .abs(),
        );
      }
    }
  }
  expect(drift, lessThan(.001));
  return drift;
}

Future<({ui.Image image, int decoded})> _capturePage(
  WidgetTester tester,
  _Book book,
  int pageIndex, {
  required double width,
}) async {
  final key = GlobalKey();
  final photos =
      book.pages[pageIndex]
          .where((layer) => layer.type == LayerType.image)
          .toList()
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  final ordinals = {
    for (final (index, layer) in photos.indexed) layer.id: index,
  };
  final layerCount = photos.length;
  expect(
    ordinals.length,
    layerCount,
    reason: '${book.id}/$pageIndex has duplicate photo IDs',
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSans'),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: TemplatePageRenderer(
              layers: book.pages[pageIndex],
              width: width,
              height: width / book.canvas.aspectRatio,
              designCanvasSize: book.canvas,
              normalizeToContentBounds: false,
              preserveTypography: true,
              showCanvasChrome: false,
              cacheNetworkImages: false,
              photoBuilder: (layer, _) => Image.asset(
                _photos[(pageIndex + ordinals[layer.id]!) % _photos.length],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 1000,
              ),
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
  final raw = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
  expect(
    raw.length,
    greaterThanOrEqualTo(layerCount),
    reason: '${book.id}/$pageIndex missing photo pixels',
  );
  expect(raw.every((image) => image.image != null), isTrue);
  expect(
    tester.takeException(),
    isNull,
    reason: '${book.id}/$pageIndex render failure',
  );
  final image = await tester.runAsync(
    () => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
        .toImage(),
  );
  return (image: image!, decoded: raw.length);
}

Future<ui.Image> _contactSheet(
  List<ui.Image> images,
  List<int> indexes,
  String title,
) async {
  const gap = 12, header = 30, labelHeight = 22;
  final columns = math.min(5, images.length);
  final rows = (images.length / columns).ceil();
  final cellWidth = images.first.width,
      cellHeight = images.first.height + labelHeight;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final width = columns * (cellWidth + gap) + gap;
  final height = rows * (cellHeight + gap) + gap + header;
  canvas.drawColor(Colors.white, BlendMode.src);
  _label(canvas, title, const Offset(12, 5), width.toDouble() - 2 * gap, 15);
  for (final (index, image) in images.indexed) {
    final offset = Offset(
      (gap + (index % columns) * (cellWidth + gap)).toDouble(),
      (header + gap + (index ~/ columns) * (cellHeight + gap)).toDouble(),
    );
    _label(
      canvas,
      indexes[index] == 0 ? '앞표지' : '내지 ${indexes[index]}쪽',
      offset,
      cellWidth.toDouble(),
      12,
    );
    canvas.drawImage(image, offset + const Offset(0, 22), Paint());
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

void _label(
  Canvas canvas,
  String text,
  Offset offset,
  double width,
  double size,
) {
  final paragraph =
      (ui.ParagraphBuilder(
              ui.ParagraphStyle(
                fontFamily: 'NotoSans',
                fontSize: size,
                maxLines: 1,
              ),
            )
            ..pushStyle(ui.TextStyle(color: Colors.black87))
            ..addText(text))
          .build()
        ..layout(ui.ParagraphConstraints(width: width));
  try {
    canvas.drawParagraph(paragraph, offset);
  } finally {
    paragraph.dispose();
  }
}

Future<void> _emit(ui.Image image, String id) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(bytes, isNotNull);
  // A single unwrapped protocol line is consumed directly from stdout in RAM.
  // ignore: avoid_print
  print(
    '$_imagePrefix${jsonEncode({'id': id, 'mimeType': 'image/png', 'width': image.width, 'height': image.height, 'base64': base64Encode(bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))})}',
  );
}

Future<void> _emitEnlargement(
  WidgetTester tester,
  _Book book,
  List<int> pages,
  String id,
) async {
  final images = <ui.Image>[];
  try {
    for (final page in pages) {
      images.add((await _capturePage(tester, book, page, width: 500)).image);
    }
    final sheet = (await tester.runAsync(
      () => _contactSheet(images, pages, book.title),
    ))!;
    try {
      await tester.runAsync(() => _emit(sheet, id));
    } finally {
      sheet.dispose();
    }
  } finally {
    for (final image in images) image.dispose();
  }
}

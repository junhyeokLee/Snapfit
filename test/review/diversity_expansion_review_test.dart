import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/data/catalog_preview.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

// One book at a time, no app build and no backend/customer writes:
// flutter test --no-pub --concurrency=1
//   --dart-define=EXPORT_DIVERSITY_REVIEW=true
//   --dart-define=DIVERSITY_REVIEW_IDS=-9772
//   test/review/diversity_expansion_review_test.dart
const _export = bool.fromEnvironment('EXPORT_DIVERSITY_REVIEW');
const _output = 'output/diversity-expansion-20261103/review';
const _ids = <int>[
  -9772,
  -9773,
  -9774,
  -9775,
  -9776,
  -9777,
  -9778,
  -9779,
  -9780,
  -9781,
  -9782,
  -9783,
  -9784,
  -9785,
];
// The exact union used by the14 books, including folio text. Loading the whole
// project font manifest would retain unrelated typefaces for the entire run.
const _families = <String>{
  'NotoSans',
  'BookMyungjo',
  'Poppins',
  'Cormorant Garamond',
  'Eulyoo',
  'Arita',
  'Tenada',
  'Samlip',
  'NanumPen',
  'Arirang2',
  'Maker',
  'Paece',
  'Doldam',
};

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Widget _page(Map<String, dynamic> source, CollectionAspect aspect) =>
    TemplatePageRenderer(
      layers: DataTemplateEngine.buildLayersFromJson(source, aspect.canvas),
      width: 500,
      height: 500 / aspect.canvas.aspectRatio,
      designCanvasSize: aspect.canvas,
      preserveTypography: true,
      normalizeToContentBounds: false,
      showCanvasChrome: false,
      imageDecodeWidth: 768,
    );

int _sourcePhotoCount(Iterable<Map<String, dynamic>> pages) => pages.fold(
  0,
  (count, page) =>
      count +
      (page['layers'] as List)
          .whereType<Map>()
          .where((layer) => '${layer['type']}'.toLowerCase() == 'image')
          .length,
);

Future<void> _capture(
  WidgetTester tester,
  List<Map<String, dynamic>> sourcePages,
  CollectionAspect aspect,
  String destination,
) async {
  final expectedPhotos = _sourcePhotoCount(sourcePages);
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final source in sourcePages) _page(source, aspect),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  try {
    await tester.runAsync(() async {
      // Precache one mounted page/spread only. A book containing text-only
      // spreads is valid; source photographs must nevertheless decode fully.
      for (final element in find.byType(Image).evaluate()) {
        Object? failure;
        await precacheImage(
          (element.widget as Image).image,
          element,
          onError: (error, _) => failure = error,
        );
        expect(failure, isNull, reason: destination);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: destination);
    final images = tester.widgetList<RawImage>(find.byType(RawImage));
    if (expectedPhotos > 0) {
      expect(
        images.length,
        greaterThanOrEqualTo(expectedPhotos),
        reason: '$destination: source photographs must reach the real renderer',
      );
    }
    expect(
      images.every((widget) => widget.image != null),
      isTrue,
      reason: '$destination: no pending or failed photo decode',
    );
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final picture = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        expect(bytes, isNotNull, reason: destination);
        File(destination).writeAsBytesSync(
          bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } finally {
        // Screenshots are written immediately, never accumulated in a list.
        picture.dispose();
      }
    });
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }
}

Future<void> _renderBook(WidgetTester tester, int id) async {
  final directory = Directory('$_output/$id');
  directory.createSync(recursive: true);
  final template = publishedCreationTemplateById(id)!;
  // This scope holds exactly one decoded canonical book. The outer loop does
  // not collect sources, preview models, widgets, encoded PNGs or image handles.
  final source = jsonDecode(template.templateJson!) as Map<String, dynamic>;
  File('${directory.path}/document.json').writeAsStringSync(jsonEncode(source));
  var captures = 0;
  for (final aspect in CollectionAspect.printable) {
    final document = Map<String, dynamic>.from(
      (source['variants'] as Map)[aspect.name] as Map,
    );
    final pages = (document['pages'] as List).cast<Map<String, dynamic>>();
    expect(pages, hasLength(24), reason: '$id/${aspect.name}');
    await _capture(
      tester,
      [Map<String, dynamic>.from(document['cover'] as Map)],
      aspect,
      '${directory.path}/${aspect.name}-cover.png',
    );
    captures++;
    for (var spread = 0; spread < 12; spread++) {
      await _capture(
        tester,
        [pages[spread * 2], pages[spread * 2 + 1]],
        aspect,
        '${directory.path}/${aspect.name}-spread-${spread + 1}.png',
      );
      captures++;
    }
  }
  expect(
    captures,
    39,
    reason: '$id: cover and every spread at three sale ratios',
  );
  File('${directory.path}/review.json').writeAsStringSync(
    jsonEncode({
      'id': id,
      'title': template.title,
      'captures': captures,
      'ratios': CollectionAspect.printable.map((a) => a.name).toList(),
      'decodeWidth': 768,
      'photoDecodesVerified': true,
    }),
  );
  // ignore: avoid_print
  print('DIVERSITY_NATIVE_REVIEW_COMPLETE:$id:$captures');
}

void main() {
  _PaintBinding();
  testWidgets(
    'render the14 new diversity books one at a time with native fonts',
    (tester) async {
      if (!_export) return;
      final selected = const String.fromEnvironment('DIVERSITY_REVIEW_IDS')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map(int.parse)
          .toSet();
      expect(
        selected.difference(_ids.toSet()),
        isEmpty,
        reason: 'Unknown review IDs must not silently skip requested books.',
      );
      final publishedIds = publishedCreationTemplates.map((t) => t.id).toSet();
      expect(publishedIds, containsAll(_ids));
      final missingFonts = {..._families};
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final entry in manifest.cast<Map>().where(
        (row) => _families.contains(row['family']),
      )) {
        final family = entry['family'] as String;
        final loader = FontLoader(family);
        for (final face in (entry['fonts'] as List).cast<Map>()) {
          loader.addFont(rootBundle.load(face['asset'] as String));
        }
        await loader.load();
        missingFonts.remove(family);
      }
      expect(missingFonts, isEmpty, reason: 'Designed fonts must be bundled.');
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cache = PaintingBinding.instance.imageCache;
      final oldSize = cache.maximumSize, oldBytes = cache.maximumSizeBytes;
      cache.maximumSize = 8;
      cache.maximumSizeBytes = 24 * 1024 * 1024;
      addTearDown(() {
        cache.clear();
        cache.clearLiveImages();
        cache.maximumSize = oldSize;
        cache.maximumSizeBytes = oldBytes;
        clearBundledTemplateDocumentCache();
        CatalogPreviews.clearCache();
      });
      for (final id in _ids.where(
        (id) => selected.isEmpty || selected.contains(id),
      )) {
        try {
          await _renderBook(tester, id);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          cache.clear();
          cache.clearLiveImages();
          clearBundledTemplateDocumentCache();
          CatalogPreviews.clearCache();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

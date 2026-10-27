import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

const _export = bool.fromEnvironment('EXPORT_QUALITY_REFRESH');
const _lettering = bool.fromEnvironment('EXPORT_LETTERING_REFRESH');
const _root = _lettering
    ? 'output/catalog-lettering-refresh'
    : 'output/catalog-quality-refresh';
const _covers = _lettering
    ? [-9303, -9302, -9412, -9452, -9463]
    : [-9303, -9471, -9302, -9412, -9452, -9455, -9463, -9517];
const _books = _lettering ? <int>[] : [-9512, -9513, -9516, -9517];

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> _fonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _capture(
  WidgetTester tester,
  Map<String, dynamic> page,
  CollectionAspect aspect,
  String name,
) async {
  final key = GlobalKey();
  const width = 500.0;
  final layers = DataTemplateEngine.buildLayersFromJson(page, aspect.canvas);
  await tester.pumpWidget(
    MaterialApp(
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
  expect(tester.takeException(), isNull, reason: name);
  expect(
    tester
        .widgetList<RawImage>(find.byType(RawImage))
        .every((e) => e.image != null),
    isTrue,
    reason: name,
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File('$_root/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  _PaintBinding();
  testWidgets(
    'export real editable cover and paid material proofs',
    (tester) async {
      await tester.runAsync(_fonts);
      final cache = PaintingBinding.instance.imageCache;
      final previousBudget = cache.maximumSizeBytes;
      const budget = 24 * 1024 * 1024;
      cache.maximumSizeBytes = budget;
      addTearDown(() {
        cache.clear();
        cache.maximumSizeBytes = previousBudget;
      });
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.runAsync(() async {
        Directory(_root).createSync(recursive: true);
      });
      final beforeBooks =
          jsonDecode(
                utf8.decode(
                  gzip.decode(
                    File(
                      _lettering
                          ? 'test/fixtures/catalog_lettering_before.json.gz'
                          : 'test/fixtures/catalog_quality_refresh_before.json.gz',
                    ).readAsBytesSync(),
                  ),
                ),
              )
              as Map;
      for (final id in {..._covers, ..._books}) {
        final after =
            jsonDecode(
                  publishedCreationTemplates
                      .singleWhere((t) => t.id == id)
                      .templateJson!,
                )
                as Map<String, dynamic>;
        final before = beforeBooks['$id'] as Map<String, dynamic>;
        for (final aspect in CollectionAspect.printable) {
          for (final entry in {'before': before, 'after': after}.entries) {
            final doc = (entry.value['variants'] as Map)[aspect.name] as Map;
            if (_covers.contains(id)) {
              await _capture(
                tester,
                Map<String, dynamic>.from(doc['cover'] as Map),
                aspect,
                '$id-${aspect.name}-${entry.key}',
              );
            }
            if (_books.contains(id) && aspect == CollectionAspect.square) {
              for (final index in [0, 5, 6, 7, 8, 11, 16, 17, 21, 22]) {
                await _capture(
                  tester,
                  Map<String, dynamic>.from(
                    (doc['pages'] as List)[index] as Map,
                  ),
                  aspect,
                  '$id-page-${index + 1}-${entry.key}',
                );
              }
            }
          }
        }
      }
      expect(cache.currentSizeBytes, lessThanOrEqualTo(budget));
      expect(cache.liveImageCount, 0);
      expect(cache.pendingImageCount, 0);
      cache.clear();
      cache.clearLiveImages();
    },
    skip: !_export && !_lettering,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

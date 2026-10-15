import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/catalog_preview_assets.g.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_catalog_cover.dart';

double _difference(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var total = 0;
  for (var i = 0; i < a.length; i += 4) {
    for (var c = 0; c < 3; c++) total += (a[i + c] - b[i + c]).abs();
  }
  return total / (a.length / 4 * 3);
}

Future<Uint8List> _pixels(String path, {int? size}) async {
  final codec = await ui.instantiateImageCodec(
    File(path).readAsBytesSync(),
    targetWidth: size,
    targetHeight: size,
  );
  final image = (await codec.getNextFrame()).image;
  final pixels = (await image.toByteData())!.buffer.asUint8List();
  image.dispose();
  codec.dispose();
  return pixels;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all 51 cached covers are visually distinct, not renamed duplicates',
    () async {
      final fingerprints = <String, Uint8List>{};
      for (final template in publishedCreationTemplates) {
        final path = catalogPreviewAssets['template:${template.id}']!;
        final pixels = await _pixels(path, size: 32);
        for (final prior in fingerprints.entries) {
          expect(
            _difference(pixels, prior.value),
            greaterThan(2),
            reason: '${template.title}: $path repeats ${prior.key}',
          );
        }
        fingerprints[template.title] = pixels;
      }
      expect(fingerprints, hasLength(51));
    },
  );

  testWidgets('cached covers match the actual published native artwork', (
    tester,
  ) async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final issues = <String>[];
    final results = <Map<String, Object>>[];
    for (final template in publishedCreationTemplates) {
      final boundary = GlobalKey();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: boundary,
                  child: SizedBox.square(
                    dimension: 220,
                    child: CreationCatalogCover(
                      template: template,
                      useThumbnail: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage(
            (element.widget as Image).image,
            element,
            onError: (error, _) =>
                throw StateError('${template.title}: $error'),
          );
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: template.title);
      final mean = (await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
        final fresh = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();
        final cached = await _pixels(
          catalogPreviewAssets['template:${template.id}']!,
        );
        return _difference(fresh, cached);
      }))!;
      if (mean > .2)
        issues.add('${template.id} ${template.title}: pixel difference $mean');
      results.add({
        'id': template.id,
        'title': template.title,
        'meanPixelDifference': mean,
        'matches': mean <= .2,
      });
    }
    if (const bool.fromEnvironment('EXPORT_COVER_AUDIT')) {
      File('output/settings-template-qa/catalog-cover-audit.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'publishedCoverCount': results.length,
            'cachedCoverMatches': results
                .where((r) => r['matches'] == true)
                .length,
            'results': results,
          }),
        );
    }
    expect(issues, isEmpty, reason: 'Regenerate stale catalog thumbnails.');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

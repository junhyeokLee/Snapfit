import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/catalog_preview_assets.g.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
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

Uint8List _fingerprint(Uint8List pixels, {required int width}) {
  expect(pixels.length, width * width * 4);
  final result = Uint8List(32 * 32 * 4);
  for (var y = 0; y < 32; y++) {
    for (var x = 0; x < 32; x++) {
      final source = ((y * width ~/ 32) * width + x * width ~/ 32) * 4;
      final target = (y * 32 + x) * 4;
      result.setRange(target, target + 4, pixels, source);
    }
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all 68 cached covers are visually distinct, not renamed duplicates',
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
      expect(fingerprints, hasLength(68));
    },
  );

  testWidgets('catalog thumbnail mode keeps the current published artwork', (
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
    expect(publishedCreationTemplates, hasLength(68));
    final fingerprints = <String, Uint8List>{};
    for (final template in publishedCreationTemplates) {
      expect(usesLiveCatalogArtwork(template), isTrue, reason: template.title);
      final document =
          jsonDecode(template.templateJson!) as Map<String, dynamic>;
      final cover = templateDocumentPages(document).first;
      final expectedIds = (cover['layers'] as List)
          .map((layer) => layer['id'] as String)
          .toList();
      Future<Uint8List> render({required bool thumbnail}) async {
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
                        useThumbnail: thumbnail,
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
        // A legacy PNG must never replace the current editable cover, even
        // when a lazy catalog card requests thumbnail mode.
        final artwork = tester.widget<TemplatePageRenderer>(
          find.byType(TemplatePageRenderer),
        );
        expect(
          artwork.layers.map((layer) => layer.id),
          expectedIds,
          reason: '${template.title}: current cover layers',
        );
        expect(find.byType(RawImage), findsWidgets, reason: template.title);
        for (final image in tester.widgetList<RawImage>(
          find.byType(RawImage),
        )) {
          expect(image.image, isNotNull, reason: template.title);
        }
        return (await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 3);
          final pixels = (await image.toByteData())!.buffer.asUint8List();
          image.dispose();
          return pixels;
        }))!;
      }

      // Compare two actual UI paths on the same engine. Historical cached
      // bitmaps are neither the published source nor a portable font baseline.
      final fullArtwork = await render(thumbnail: false);
      final cardArtwork = await render(thumbnail: true);
      expect(_difference(fullArtwork, cardArtwork), 0, reason: template.title);
      final fingerprint = _fingerprint(fullArtwork, width: 660);
      for (final previous in fingerprints.entries) {
        expect(
          _difference(fingerprint, previous.value),
          greaterThan(2),
          reason: '${template.title}: current artwork repeats ${previous.key}',
        );
      }
      fingerprints[template.title] = fingerprint;
    }
    expect(fingerprints, hasLength(68));
  }, timeout: const Timeout(Duration(minutes: 3)));
}

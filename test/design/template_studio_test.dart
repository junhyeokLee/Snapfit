import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../../tool/template_studio/reference_designs.dart';

const _export = bool.fromEnvironment('EXPORT_TEMPLATE_STUDIO');
const _out = 'output/template-studio';

Future<void> _fonts() async {
  for (final entry in {
    'NotoSans': [
      'NotoSansKR-Regular.ttf',
      'NotoSansKR-SemiBold.ttf',
      'NotoSansKR-Bold.ttf',
    ],
    'Raleway': ['Raleway-Regular.ttf', 'Raleway-ExtraBold.ttf'],
    'Poppins': ['Poppins-Regular.otf', 'Poppins-Bold.otf'],
    'Cormorant Garamond': ['Cormorant-Regular.ttf', 'Cormorant-SemiBold.ttf'],
    'Eulyoo': ['Eulyoo1945-Regular.ttf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_fonts);

  for (final direction in studioDirections) {
    for (final aspect in StudioAspect.values) {
      final label = '${direction.id}_${aspect.name}';
      final doc = buildStudioDocument(direction.id, aspect);
      test(
        '$label is an editable, bounded, physically proportioned specimen',
        () {
          final source = aspect.canvas;
          expect(doc.pages.length, 5);
          expect(templateDocumentPages(doc.toJson()).length, 5);
          expect(doc.toJson()['aiGenerated'], isFalse);
          expect(doc.toJson()['catalogPublishable'], isFalse);
          expect(
            source.aspectRatio,
            closeTo(aspect.cover.realSize.aspectRatio, .000001),
          );
          final ids = <String>{};
          for (var i = 0; i < doc.pages.length; i++) {
            final layers = doc.layers(i);
            expect(layers.any((l) => l.type == LayerType.image), isTrue);
            expect(layers.any((l) => l.type == LayerType.text), isTrue);
            expect(layers.first.decorationFillColor, isNotNull);
            for (final layer in layers) {
              expect(ids.add(layer.id), isTrue, reason: layer.id);
              expect(layer.position.dx, greaterThanOrEqualTo(0));
              expect(layer.position.dy, greaterThanOrEqualTo(0));
              expect(
                layer.position.dx + layer.width,
                lessThanOrEqualTo(source.width + .01),
              );
              expect(
                layer.position.dy + layer.height,
                lessThanOrEqualTo(source.height + .01),
              );
              if (layer.type == LayerType.image) {
                expect(File(layer.imageUrl!.substring(6)).existsSync(), isTrue);
              }
              if (layer.type == LayerType.text) {
                final style = layer.textStyle!;
                final painter = TextPainter(
                  text: TextSpan(text: layer.text, style: style),
                  textDirection: TextDirection.ltr,
                  strutStyle: StrutStyle.fromTextStyle(
                    style,
                    forceStrutHeight: true,
                  ),
                )..layout(maxWidth: layer.width);
                expect(
                  painter.height,
                  lessThanOrEqualTo(layer.height + .5),
                  reason: '$label ${layer.id}: ${layer.text}',
                );
                if (!layer.text!.contains('\n')) {
                  expect(
                    painter.computeLineMetrics().length,
                    1,
                    reason: '$label ${layer.id}: ${layer.text} wraps',
                  );
                }
                painter.dispose();
              }
            }
            final target = coverCanvasBaseSize(aspect.cover);
            final cleared = AlbumCreationTemplate.preparePages(
              [layers],
              sourceCanvas: source,
              cover: aspect.cover,
            ).single;
            for (var j = 0; j < layers.length; j++) {
              final before = layers[j], after = cleared[j];
              expect(
                after.position.dx / target.width,
                closeTo(before.position.dx / source.width, .000001),
              );
              expect(
                after.width / target.width,
                closeTo(before.width / source.width, .000001),
              );
              expect(after.text, before.text);
              expect(after.textStyle?.fontFamily, before.textStyle?.fontFamily);
              if (after.type == LayerType.image) {
                expect(after.imageUrl, isNull);
                expect(after.decorationFillColor, isNotNull);
              }
            }
          }
        },
      );

      testWidgets('$label renders photos and empty slots with the app renderer', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1200, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.runAsync(() async {
          if (_export) {
            await Directory('$_out/renders').create(recursive: true);
            await Directory('$_out/documents').create(recursive: true);
            await File('$_out/documents/$label.json').writeAsString(
              const JsonEncoder.withIndent('  ').convert(doc.toJson()),
            );
          }
        });
        for (final photos in [true, false]) {
          for (var i = 0; i < doc.pages.length; i++) {
            final key = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: RepaintBoundary(
                      key: key,
                      child: TemplatePageRenderer(
                        layers: doc.layers(i, photos: photos),
                        designCanvasSize: aspect.canvas,
                        width: aspect.canvas.width,
                        height: aspect.canvas.height,
                      ),
                    ),
                  ),
                ),
              ),
            );
            // Keep on-screen listeners alive while decoding. Preloading the
            // whole high-resolution set can evict earlier images from cache.
            await tester.runAsync(() async {
              for (final element in find.byType(Image).evaluate()) {
                final widget = element.widget as Image;
                await precacheImage(widget.image, element);
              }
            });
            await tester.pumpAndSettle();
            final decoded = tester.widgetList<RawImage>(find.byType(RawImage));
            expect(
              decoded.length,
              photos
                  ? doc.layers(i).where((l) => l.type == LayerType.image).length
                  : 0,
            );
            expect(
              decoded.every((image) => image.image != null),
              isTrue,
              reason: '$label/$i must include all decoded photos',
            );
            expect(tester.takeException(), isNull, reason: '$label/$i/$photos');
            if (_export) {
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1.6);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$_out/renders/${label}_${photos ? 'photo' : 'empty'}_$i.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }
        }
      });
    }
  }

  test(
    'formats reflow compositions instead of stretching the same placement',
    () {
      for (final direction in studioDirections) {
        List<Offset> positions(StudioAspect aspect) {
          final doc = buildStudioDocument(direction.id, aspect);
          return doc
              .layers(0)
              .where((l) => l.type == LayerType.image)
              .map(
                (l) => Offset(
                  l.position.dx / aspect.canvas.width,
                  l.position.dy / aspect.canvas.height,
                ),
              )
              .toList();
        }

        expect(
          positions(StudioAspect.landscape),
          isNot(positions(StudioAspect.square)),
        );
      }
    },
  );

  if (_export) {
    test(
      'exports the local review workspace without publishing to the catalog',
      () async {
        await File('tool/template_studio/index.html').copy('$_out/index.html');
        await File('$_out/catalog.js').writeAsString(
          'window.STUDIO = ${jsonEncode({
            'directions': studioDirections.map((d) => {'id': d.id, 'name': d.name, 'label': d.label, 'color': d.color}).toList(),
            'aspects': StudioAspect.values.map((a) => {'id': a.name, 'name': a.cover.name, 'width': a.cover.realSize.width, 'height': a.cover.realSize.height}).toList(),
          })};',
        );
      },
    );
  }
}

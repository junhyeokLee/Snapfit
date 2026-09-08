import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';

const _export = bool.fromEnvironment('EXPORT_AUTHORED_COLLECTIONS');
const _out = 'output/template-preview/collections';

class _PreviewInteraction extends Mock implements LayerInteractionManager {
  @override
  Widget buildInteractiveLayer({
    required LayerModel layer,
    required double baseWidth,
    required double baseHeight,
    required Widget child,
    bool isCover = false,
  }) => SizedBox(width: baseWidth, height: baseHeight, child: child);
}

Future<void> _fonts() async {
  for (final entry in {
    'NotoSans': ['NotoSansKR-Regular.ttf', 'NotoSansKR-Bold.ttf'],
    'Raleway': ['Raleway-Regular.ttf', 'Raleway-ExtraBold.ttf'],
    'Poppins': ['Poppins-Regular.otf', 'Poppins-Bold.otf'],
    'Cormorant Garamond': ['Cormorant-Regular.ttf'],
    'Eulyoo': ['Eulyoo1945-Regular.ttf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
}

Future<ui.Image> _capture(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(key: key, child: child),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  for (final raw in tester.widgetList<RawImage>(find.byType(RawImage))) {
    expect(
      raw.image,
      isNotNull,
      reason: 'Actual bundled photograph must decode',
    );
  }
  return (await tester.runAsync(
    () => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
        .toImage(),
  ))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_fonts);
  test('only approved free originals survive catalog refresh', () {
    expect(bundledCreationTemplates.length, 36);
    final server = bundledCreationTemplates.first.copyWith(
      id: 321,
      title: 'Server title',
      isPremium: true,
    );
    final result = withBundledCreationTemplates([
      server,
      ...bundledCreationTemplates,
    ]);
    expect(result.length, 36);
    expect(result.any((t) => t.id == server.id), false);
    expect(
      bundledCreationTemplates.every((t) => !t.isPremium && t.id < 0),
      isTrue,
    );
    for (final template in bundledCreationTemplates) {
      final data = jsonDecode(template.templateJson!) as Map<String, dynamic>;
      expect(data['aiGenerated'], false);
      expect(templateDocumentPages(data).length, template.pageCount + 1);
      expect(template.pageCount, template.id == windAtlasBundledId ? 32 : 24);
      expect((data['variants'] as Map).length, 3);
    }
  });

  for (final collection in retiredAuthoredCollections) {
    for (final aspect in CollectionAspect.values) {
      final label = '${collection.id}_${aspect.name}';
      final data = collection.document(aspect);
      final pages = templateDocumentPages(data)
          .map((p) => DataTemplateEngine.buildLayersFromJson(p, aspect.canvas))
          .toList();
      test(
        '$label: twenty inner pages, fitted text, editable masks and save roundtrip',
        () {
          expect(pages.length, 21);
          expect(collection.title, matches(RegExp(r'^[가-힣 ]+$')));
          expect(data['title'], collection.title);
          final coverTitle = pages.first.singleWhere(
            (l) => l.id.endsWith('_title'),
          );
          expect(coverTitle.text!.replaceAll('\n', ' '), collection.title);
          final specifications = templateDocumentPages(data);
          expect((data['chapters'] as List).length, 5);
          expect(
            specifications.map((p) => p['role']).toSet().length,
            greaterThanOrEqualTo(12),
          );
          final photoLayouts = pages
              .map(
                (page) => jsonEncode([
                  for (final layer in page.where(
                    (l) => l.type == LayerType.image,
                  ))
                    [
                      layer.position.dx,
                      layer.position.dy,
                      layer.width,
                      layer.height,
                    ],
                ]),
              )
              .toSet();
          expect(
            photoLayouts.length,
            greaterThanOrEqualTo(16),
            reason: 'Page count must not grow through repeated photo layouts',
          );
          expect(
            pages
                .expand((p) => p)
                .where((l) => l.type == LayerType.image)
                .length,
            greaterThanOrEqualTo(32),
          );
          for (var i = 1; i < specifications.length; i++) {
            expect(specifications[i]['spreadIndex'], (i + 1) ~/ 2);
            expect(specifications[i]['side'], i.isOdd ? 'left' : 'right');
            expect(specifications[i]['name'], isNotEmpty);
          }
          final ids = <String>{};
          for (final page in pages) {
            expect(page.any((l) => l.type == LayerType.image), isTrue);
            final photos = page
                .where((l) => l.type == LayerType.image)
                .toList();
            expect(
              photos.map((l) => l.imageUrl).toSet().length,
              photos.length,
              reason: '$label: a photo grid needs distinct sample photographs',
            );
            final cleared = AlbumCreationTemplate.preparePages(
              [page],
              sourceCanvas: aspect.canvas,
              cover: aspect.cover,
            ).single;
            for (var i = 0; i < page.length; i++) {
              final layer = page[i];
              expect(ids.add(layer.id), isTrue, reason: '$label / ${layer.id}');
              expect(layer.position.dx, greaterThanOrEqualTo(0));
              expect(layer.position.dy, greaterThanOrEqualTo(0));
              expect(
                layer.position.dx + layer.width,
                lessThanOrEqualTo(aspect.canvas.width + .01),
              );
              expect(
                layer.position.dy + layer.height,
                lessThanOrEqualTo(aspect.canvas.height + .01),
                reason: '$label / ${layer.id} exceeds page height',
              );
              final restored = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(layer, canvasSize: aspect.canvas),
                canvasSize: aspect.canvas,
              );
              expect(restored.imageBackground, layer.imageBackground);
              expect(restored.decorationFillColor, layer.decorationFillColor);
              expect(restored.rotation, layer.rotation);
              if (layer.type == LayerType.image) {
                expect({
                  ...StudioMaterial.photoStyles,
                  'none',
                }, contains(layer.imageBackground));
                expect(File(layer.imageUrl!.substring(6)).existsSync(), isTrue);
                expect(cleared[i].imageUrl, isNull);
                expect(cleared[i].imageBackground, layer.imageBackground);
                final replaced = cleared[i].copyWith(
                  imageUrl: 'asset:assets/snapfit_home_square.jpg',
                );
                expect(replaced.imageBackground, layer.imageBackground);
                expect(replaced.width, cleared[i].width);
              }
              if (layer.type == LayerType.text) {
                final painter = TextPainter(
                  text: TextSpan(text: layer.text, style: layer.textStyle),
                  textDirection: TextDirection.ltr,
                  strutStyle: StrutStyle.fromTextStyle(
                    layer.textStyle!,
                    forceStrutHeight: true,
                  ),
                )..layout(maxWidth: layer.width);
                expect(
                  painter.height,
                  lessThanOrEqualTo(layer.height + .6),
                  reason: '$label / ${layer.text}',
                );
                expect(
                  painter.computeLineMetrics().length,
                  layer.text!.split('\n').length,
                  reason: '$label / ${layer.text} must not unexpectedly wrap',
                );
                painter.dispose();
              }
            }
          }
        },
      );

      testWidgets(
        '$label renders all photographs and produces a contact sheet',
        (tester) async {
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final images = <ui.Image>[];
          for (final page in pages) {
            final picture = await _capture(
              tester,
              TemplatePageRenderer(
                layers: page,
                width: 350,
                height: 350 / aspect.canvas.aspectRatio,
                designCanvasSize: aspect.canvas,
                preserveTypography: true,
                imageDecodeWidth: 900,
              ),
            );
            if (page.any(
              (l) => StudioMaterial.photoStyles.contains(l.imageBackground),
            )) {
              expect(find.byType(StudioMaterial), findsWidgets);
            }
            images.add(picture);
          }
          if (_export) {
            await tester.runAsync(() async {
              final recorder = ui.PictureRecorder();
              final canvas = Canvas(recorder);
              final tileH = images.first.height + 24;
              canvas.drawColor(const Color(0xFFE1E4E2), BlendMode.src);
              for (var i = 0; i < images.length; i++) {
                canvas.drawImage(
                  images[i],
                  Offset(
                    16 + (i % 3) * 366.0,
                    16 + (i ~/ 3) * tileH.toDouble(),
                  ),
                  Paint(),
                );
              }
              final picture = recorder.endRecording();
              final contact = await picture.toImage(
                1114,
                tileH * ((images.length + 2) ~/ 3) + 8,
              );
              final png = await contact.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(_out).create(recursive: true);
              final spreads = Directory('$_out/$label');
              await spreads.create(recursive: true);
              for (var i = 1; i < images.length; i += 2) {
                final spreadRecorder = ui.PictureRecorder();
                final spreadCanvas = Canvas(spreadRecorder);
                spreadCanvas.drawImage(images[i], Offset.zero, Paint());
                spreadCanvas.drawImage(
                  images[i + 1],
                  Offset(images[i].width.toDouble(), 0),
                  Paint(),
                );
                final spreadPicture = spreadRecorder.endRecording();
                final spread = await spreadPicture.toImage(
                  images[i].width * 2,
                  images[i].height,
                );
                final spreadPng = await spread.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '${spreads.path}/spread-${(i + 1) ~/ 2}.png',
                ).writeAsBytes(spreadPng!.buffer.asUint8List());
                spread.dispose();
                spreadPicture.dispose();
              }
              await File(
                '$_out/$label.png',
              ).writeAsBytes(png!.buffer.asUint8List());
              await File(
                '$_out/$label.json',
              ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
              contact.dispose();
              picture.dispose();
            });
          }
          for (final image in images) {
            image.dispose();
          }
        },
      );
    }
  }

  for (final size in [
    const Size(240, 300),
    const Size(280, 280),
    const Size(320, 240),
  ]) {
    for (final shape in {...StudioMaterial.photoStyles, 'none'}) {
      testWidgets(
        '$size $shape uses identical photo pixels in native editor and catalog',
        (tester) async {
          final layer = LayerModel(
            id: 'photo',
            type: LayerType.image,
            position: Offset.zero,
            width: size.width,
            height: size.height,
            imageBackground: shape,
            imageOffset: const Offset(36, -18),
            imageUrl: 'asset:assets/snapfit_home_square.jpg',
          );
          final native = await _capture(
            tester,
            LayerBuilder(_PreviewInteraction(), () => size).buildImage(layer),
          );
          final catalog = await _capture(
            tester,
            TemplatePageRenderer(
              layers: [layer],
              width: size.width,
              height: size.height,
              designCanvasSize: size,
            ),
          );
          final nativeBytes = await tester.runAsync(() => native.toByteData()),
              catalogBytes = await tester.runAsync(() => catalog.toByteData());
          expect(
            nativeBytes!.buffer.asUint8List(),
            orderedEquals(catalogBytes!.buffer.asUint8List()),
          );
          final path = StudioMaterialClipper(shape).getClip(size);
          expect(path.contains(size.center(Offset.zero)), isTrue);
          // These mats have square outer corners; oval apertures and postage
          // perforations are inset and do not remove the corner itself.
          const squareCorners = {
            'none',
            'studioDoubleMat',
            'studioPhotoCorners',
            'studioOvalMat',
            'studioLinen',
            'studioPostcard',
            'studioPostage',
          };
          expect(
            path.contains(const Offset(.1, .1)),
            squareCorners.contains(shape),
          );
          native.dispose();
          catalog.dispose();
        },
      );
    }
  }
}

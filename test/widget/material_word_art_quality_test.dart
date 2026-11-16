import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_preview_composition.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

const _ids = ['bold-cut', 'ticket-label', 'hand-note', 'diecut'];
const _fixture = 'test/fixtures/material_word_art_before_20261102';

class _Interaction extends Mock implements LayerInteractionManager {
  @override
  bool get isPrintPreview => false;

  @override
  bool get isPreviewMode => false;

  @override
  Widget buildInteractiveLayer({
    required LayerModel layer,
    required double baseWidth,
    required double baseHeight,
    required Widget child,
    bool isCover = false,
  }) => SizedBox(width: baseWidth, height: baseHeight, child: child);
}

List<LayerModel> _readLayers(dynamic json, Size canvas) => [
  for (final layer in json as List)
    LayerExportMapper.fromJson(
      (layer as Map).cast<String, dynamic>(),
      canvasSize: canvas,
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> before;
  setUpAll(() async {
    before = (jsonDecode(File('$_fixture.json').readAsStringSync()) as Map)
        .cast<String, dynamic>();
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest.cast<Map>()) {
      final loader = FontLoader(font['family'] as String);
      for (final face in (font['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(face['asset'] as String));
      }
      await loader.load();
    }
  });

  test('refined word art retains identity and editable source geometry', () {
    for (final id in _ids) {
      final art = studioWordArtById(id)!;
      final original = before[id] as Map;
      expect(art.productKey, original['productKey']);
      expect(art.favoriteKey, original['favoriteKey']);
      expect(art.text, original['text']);
      expect([
        art.sourceSize.width,
        art.sourceSize.height,
      ], original['sourceSize']);
      final layers = art.previewLayers();
      expect(layers.length, greaterThan(3), reason: id);
      expect(layers.map((l) => l.id).toSet().length, layers.length);
      expect(layers.map((l) => l.zIndex).toList(), [
        for (var index = 0; index < layers.length; index++) index,
      ]);
      final originalMain = _readLayers(
        original['previewLayers'],
        art.sourceSize,
      ).singleWhere((l) => l.text == art.text);
      final main = layers.singleWhere((l) => l.text == art.text);
      expect(main.type, LayerType.text);
      expect(main.textStyle!.fontFamily, originalMain.textStyle!.fontFamily);
      expect(main.textFillMode, originalMain.textFillMode);
      expect(layers.last.id, main.id);
      expect(
        layers
            .where((l) => l.imageBackground != null)
            .map((l) => l.imageBackground),
        _readLayers(
          original['previewLayers'],
          art.sourceSize,
        ).where((l) => l.imageBackground != null).map((l) => l.imageBackground),
        reason: '$id must not require a new purchased material',
      );
      for (final layer in layers) {
        expect(layer.type, isIn([LayerType.text, LayerType.decoration]));
        expect(layer.imageUrl, isNull, reason: '$id remains editable');
      }
    }
  });

  for (final aspect in CollectionAspect.printable) {
    test('${aspect.name}: real fonts fit and every layer survives saving', () {
      final canvas = aspect.canvas;
      final bounds = (Offset.zero & canvas).inflate(.001);
      for (final id in _ids) {
        for (final layer in studioWordArtById(id)!.buildLayers(canvas)) {
          final rect = layer.position & Size(layer.width, layer.height);
          expect(bounds.contains(rect.topLeft), isTrue, reason: layer.id);
          expect(bounds.contains(rect.bottomRight), isTrue, reason: layer.id);
          expect(layer.isTemplateContent, isTrue);
          if (layer.type == LayerType.text) {
            final painter = TextPainter(
              text: TextSpan(text: layer.text, style: layer.textStyle),
              textDirection: TextDirection.ltr,
              textAlign: layer.textAlign ?? TextAlign.center,
            )..layout();
            expect(
              painter.width,
              lessThanOrEqualTo(layer.width + .01),
              reason: '${layer.id} must stay on one line',
            );
            // Actual font hinting can round inserted line metrics by a pixel.
            expect(
              painter.height,
              lessThanOrEqualTo(layer.height + 1),
              reason: '${layer.id} must not clip',
            );
            painter.dispose();
          }
          final json = LayerExportMapper.toJson(layer, canvasSize: canvas);
          final restored = LayerExportMapper.fromJson(json, canvasSize: canvas);
          expect(restored.id, layer.id);
          expect(
            (restored.position - layer.position).distance,
            lessThan(.00001),
          );
          expect(restored.width, closeTo(layer.width, .00001));
          expect(restored.height, closeTo(layer.height, .00001));
          expect(restored.text, layer.text);
          expect(restored.textStyle?.fontFamily, layer.textStyle?.fontFamily);
          if (layer.textStyle?.fontSize case final double fontSize) {
            expect(restored.textStyle?.fontSize, closeTo(fontSize, .00001));
          }
          expect(restored.textFillMode, layer.textFillMode);
          expect(restored.decorationFillColor, layer.decorationFillColor);
          expect(restored.imageBackground, layer.imageBackground);
          expect(restored.isTemplateContent, isTrue);
        }
      }
    });
  }

  test('story application previews keep source ratio and visible motifs', () {
    for (final edition in storyEditions) {
      final art = studioWordArtById(edition.id)!;
      final wordArt = MaterialPreviewComposition.forProduct(
        art.productKey,
        '문구',
      );
      expect(
        wordArt.materialRect.width / wordArt.materialRect.height,
        closeTo(art.sourceSize.aspectRatio, .00001),
        reason: art.id,
      );
      expect(wordArt.materialRect.overlaps(wordArt.photoRect!), isFalse);
      final motif = MaterialPreviewComposition.forProduct(
        'sticker:${edition.motifId}',
        '스티커',
      );
      expect(motif.materialRect.width, greaterThanOrEqualTo(200));
      expect(motif.materialRect.overlaps(motif.photoRect!), isFalse);
      expect(motif.materialRect.overlaps(motif.captionRect!), isFalse);
      final paper = MaterialPreviewComposition.forProduct(
        'sticker:${edition.paperId}',
        '종이',
      );
      expect(
        paper.materialRect.width / paper.materialRect.height,
        closeTo(studioDecorationById(edition.paperId)!.aspectRatio, .00001),
      );
      final covered = paper.materialRect.intersect(paper.photoRect!);
      expect(
        covered.width *
            covered.height /
            (paper.materialRect.width * paper.materialRect.height),
        lessThan(.35),
      );
      expect(
        paper.photoRect!.width / paper.photoRect!.height,
        closeTo(1.5, .00001),
      );
    }
  });

  testWidgets(
    'four refined materials match the editor in all three album ratios',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final aspect in CollectionAspect.printable) {
        final canvas = aspect.canvas;
        for (final id in _ids) {
          final layers = studioWordArtById(id)!.buildLayers(canvas);
          final builder = LayerBuilder(_Interaction(), () => canvas);
          final textLayers = layers
              .where((l) => l.type == LayerType.text)
              .toList();
          final nativeRects = <String, Rect>{};
          for (final native in [true, false]) {
            final boundary = GlobalKey();
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
                    key: boundary,
                    child: ColoredBox(
                      color: const Color(0xFFF8F6F2),
                      child: SizedBox.fromSize(
                        size: canvas,
                        child: native
                            ? Stack(
                                children: [
                                  for (final layer in layers)
                                    Positioned(
                                      left: layer.position.dx,
                                      top: layer.position.dy,
                                      child: layer.type == LayerType.text
                                          ? builder.buildText(layer)
                                          : builder.buildImage(layer),
                                    ),
                                ],
                              )
                            : TemplatePageRenderer(
                                layers: layers,
                                width: canvas.width,
                                height: canvas.height,
                                designCanvasSize: canvas,
                                preserveTypography: true,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${aspect.name}/$id',
            );
            for (final layer in textLayers) {
              final rect = tester.getRect(find.text(layer.text!));
              if (native) {
                nativeRects[layer.id] = rect;
              } else {
                expect(
                  (rect.center - nativeRects[layer.id]!.center).distance,
                  lessThan(2),
                  reason: '${aspect.name}/${layer.id} baseline',
                );
              }
            }
            if (const bool.fromEnvironment('EXPORT_MATERIAL_APPLICATIONS')) {
              await tester.runAsync(() async {
                final image =
                    await (boundary.currentContext!.findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage(pixelRatio: 2);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'output/store-quality-20261102/materials-after-native/'
                  '${id}_${aspect.name}_${native ? 'editor' : 'saved'}.png',
                );
                file.parent.createSync(recursive: true);
                file.writeAsBytesSync(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }
        }
      }
    },
  );

  testWidgets('actual saved word art still matches the pre-refinement pixels', (
    tester,
  ) async {
    // Match the native catalog exporter that captured these four original images.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final id in _ids) {
      final original = before[id] as Map;
      final source = (original['sourceSize'] as List).cast<num>();
      final canvas = Size(source[0].toDouble(), source[1].toDouble());
      final layers = _readLayers(original['previewLayers'], canvas);
      final key = GlobalKey();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox.square(
                    dimension: 96,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: TemplatePageRenderer(
                        layers: layers,
                        width: canvas.width,
                        height: canvas.height,
                        designCanvasSize: canvas,
                        preserveTypography: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: id);
      await tester.runAsync(() async {
        final actual =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 4);
        final codec = await ui.instantiateImageCodec(
          File('$_fixture/phrase_collage-$id.png').readAsBytesSync(),
        );
        final expected = (await codec.getNextFrame()).image;
        expect(actual.width, expected.width);
        expect(actual.height, expected.height);
        final actualBytes = (await actual.toByteData())!.buffer.asUint8List();
        final expectedBytes = (await expected.toByteData())!.buffer
            .asUint8List();
        expect(
          actualBytes,
          orderedEquals(expectedBytes),
          reason: '$id saved artwork must not be rebuilt from the new catalog',
        );
        actual.dispose();
        expected.dispose();
        codec.dispose();
      });
    }
  });
}

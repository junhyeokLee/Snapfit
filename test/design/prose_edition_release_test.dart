import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../../tool/template_studio/luminous_edition_preview.dart';
import '../widget/ai_album_start_step_test.dart'
    show loadCreationFonts, wrapCreation;
import '../widget/studio_decorations_test.dart' show capture;

bool paperContainsText(LayerModel paper, LayerModel text) {
  Offset rotate(Offset p, double angle) => Offset(
    p.dx * math.cos(angle) - p.dy * math.sin(angle),
    p.dx * math.sin(angle) + p.dy * math.cos(angle),
  );
  final textCenter = text.position + Offset(text.width / 2, text.height / 2);
  final paperCenter =
      paper.position + Offset(paper.width / 2, paper.height / 2);
  for (final x in [-text.width / 2, text.width / 2]) {
    for (final y in [-text.height / 2, text.height / 2]) {
      final corner =
          textCenter + rotate(Offset(x, y), text.rotation * math.pi / 180);
      final local = rotate(
        corner - paperCenter,
        -paper.rotation * math.pi / 180,
      );
      if (local.dx.abs() > paper.width / 2 + .5 ||
          local.dy.abs() > paper.height / 2 + .5)
        return false;
    }
  }
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    for (final f in [
      ('Eulyoo', 'Eulyoo1945-Regular.ttf'),
      ('BookMyungjo', 'BookkMyungjo_Bold.ttf'),
      ('Samlip', 'samlip-regular.ttf'),
      ('RiaSans', 'RiaSans-Bold.ttf'),
      ('Poppins', 'Poppins-Regular.otf'),
      ('Yeongwol', 'YeongwolTTF.ttf'),
      ('NanumPen', 'NanumPenScript-Regular.ttf'),
      ('Cormorant Garamond', 'Cormorant-Regular.ttf'),
    ]) {
      await (FontLoader(
        f.$1,
      )..addFont(rootBundle.load('assets/fonts/${f.$2}'))).load();
    }
  });
  test('complete free edition is published, candidate is not purchasable', () {
    final free = bundledCreationTemplates.singleWhere(
      (t) => t.id == proseAlbumBundledId,
    );
    expect(free.isPremium, false);
    expect(free.pageCount, 24);
    expect(free.category, '커플·기념일');
    expect(
      bundledCreationTemplates.any((t) => t.title == luminousEditionTitle),
      false,
    );
    expect(luminousCopyFits(const LuminousCopy()), true);
    expect(luminousCopyFits(const LuminousCopy(second: '')), false);
    expect(
      luminousCopyFits(
        const LuminousCopy(
          first: '함께',
          second: '반짝인',
          third: '계절',
          names: '민서와 도윤',
        ),
      ),
      true,
    );
  });
  for (final premium in [false, true]) {
    for (final aspect in CollectionAspect.values) {
      testWidgets(
        '${premium ? 'candidate' : 'free'}/${aspect.name}: editable pages fit and render',
        (tester) async {
          final doc = premium
              ? buildLuminousEdition(aspect)
              : buildProseAlbum(aspect);
          final raw = templateDocumentPages(doc);
          expect(raw.length, premium ? luminousEditionInnerPageCount + 1 : 25);
          expect(doc['accessTier'], premium ? 'unassigned' : 'free');
          final ids = <String>{}, issues = <String>[];
          final images = <ui.Image>[];
          for (final page in raw.indexed) {
            final layers = DataTemplateEngine.buildLayersFromJson(
              page.$2,
              aspect.canvas,
            );
            final prepared = AlbumCreationTemplate.preparePages(
              [layers],
              sourceCanvas: aspect.canvas,
              cover: aspect.cover,
            ).single;
            for (final entry in layers.indexed) {
              final l = entry.$2, r = l.position & Size(l.width, l.height);
              if (!ids.add(l.id)) issues.add('duplicate ${l.id}');
              if (r.left < -.1 ||
                  r.top < -.1 ||
                  r.right > aspect.canvas.width + .1 ||
                  r.bottom > aspect.canvas.height + .1)
                issues.add('${l.id}: bounds');
              final restored = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(l, canvasSize: aspect.canvas),
                canvasSize: aspect.canvas,
              );
              expect(restored.text, l.text);
              expect(restored.textFillMode, l.textFillMode);
              expect(restored.imageBackground, l.imageBackground);
              if (l.type == LayerType.image)
                expect(prepared[entry.$1].imageUrl, isNull);
              if (l.type != LayerType.text) continue;
              final t = TextPainter(
                text: TextSpan(text: l.text, style: l.textStyle),
                textDirection: TextDirection.ltr,
                strutStyle: StrutStyle.fromTextStyle(
                  l.textStyle!,
                  forceStrutHeight: true,
                ),
              )..layout(maxWidth: l.width);
              if (t.height > l.height + .5)
                issues.add('${l.id}: ${t.height} > ${l.height} ${l.text}');
              t.dispose();
              for (final o in layers.where(
                (o) => o.type == LayerType.image || o.type == LayerType.text,
              )) {
                if (l.id != o.id &&
                    r
                        .deflate(.5)
                        .overlaps(
                          (o.position & Size(o.width, o.height)).deflate(.5),
                        )) {
                  final sourceLayer = (page.$2['layers'] as List)
                      .cast<Map<String, dynamic>>()
                      .singleWhere((raw) => raw['id'] == l.id);
                  final backingId = sourceLayer['backingLayerId'];
                  final backing = layers
                      .where((b) => b.id == backingId)
                      .firstOrNull;
                  final paperBackedPhotoOverlay =
                      premium &&
                      o.type == LayerType.image &&
                      backing != null &&
                      backing.type == LayerType.decoration &&
                      backing.zIndex > o.zIndex &&
                      backing.zIndex < l.zIndex &&
                      backing.opacity == 1 &&
                      backing.decorationFillColor != null &&
                      paperContainsText(backing, l);
                  final coverTypeZones = [
                    Rect.fromLTWH(
                      .06 * aspect.canvas.width,
                      .04 * aspect.canvas.height,
                      .88 * aspect.canvas.width,
                      .21 * aspect.canvas.height,
                    ),
                    Rect.fromLTWH(
                      .06 * aspect.canvas.width,
                      .90 * aspect.canvas.height,
                      .88 * aspect.canvas.width,
                      .075 * aspect.canvas.height,
                    ),
                  ];
                  final safeCoverOverlay =
                      premium &&
                      page.$1 == 0 &&
                      o.type == LayerType.image &&
                      o.zIndex < l.zIndex &&
                      sourceLayer['overlayImageId'] == o.id &&
                      l.rotation == 0 &&
                      coverTypeZones.any(
                        (zone) =>
                            zone.contains(r.topLeft) &&
                            zone.contains(r.bottomRight),
                      );
                  if (!paperBackedPhotoOverlay && !safeCoverOverlay)
                    issues.add('${l.id} overlaps ${o.id}');
                }
              }
            }
            images.add(
              await capture(
                tester,
                TemplatePageRenderer(
                  layers: layers,
                  width: 400,
                  height: 400 / aspect.canvas.aspectRatio,
                  designCanvasSize: aspect.canvas,
                  preserveTypography: true,
                  showCanvasChrome: false,
                ),
              ),
            );
          }
          if (const bool.fromEnvironment('EXPORT_EDITION')) {
            await tester.runAsync(() async {
              final dir = Directory(
                'output/template-preview/${premium ? 'luminous-edition' : 'prose-free'}/${aspect.name}',
              );
              await dir.create(recursive: true);
              for (final e in images.indexed) {
                await File('${dir.path}/page-${e.$1}.png').writeAsBytes(
                  (await e.$2.toByteData(
                    format: ui.ImageByteFormat.png,
                  ))!.buffer.asUint8List(),
                );
              }
              final w = images.first.width.toDouble(),
                  h = images.first.height.toDouble();
              for (var i = 1; i + 1 < images.length; i += 2) {
                final spreadRecorder = ui.PictureRecorder();
                final spreadCanvas = Canvas(spreadRecorder);
                spreadCanvas.drawImage(images[i], Offset.zero, Paint());
                spreadCanvas.drawImage(images[i + 1], Offset(w, 0), Paint());
                final spreadPicture = spreadRecorder.endRecording();
                final spreadImage = await spreadPicture.toImage(
                  (w * 2).ceil(),
                  h.ceil(),
                );
                await File(
                  '${dir.path}/spread-${(i + 1) ~/ 2}.png',
                ).writeAsBytes(
                  (await spreadImage.toByteData(
                    format: ui.ImageByteFormat.png,
                  ))!.buffer.asUint8List(),
                );
                spreadImage.dispose();
                spreadPicture.dispose();
              }
              final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
              canvas.drawColor(const Color(0xFFE2E5E4), BlendMode.src);
              for (final e in images.indexed) {
                canvas.drawImage(
                  e.$2,
                  Offset(
                    e.$1 == 0 ? 0 : (e.$1 - 1) % 2 * w,
                    e.$1 == 0 ? 0 : ((e.$1 - 1) ~/ 2 + 1) * (h + 16),
                  ),
                  Paint(),
                );
              }
              final picture = recorder.endRecording(),
                  contact = await picture.toImage(
                    (2 * w).ceil(),
                    ((h + 16) * ((images.length - 1) / 2 + 1)).ceil(),
                  );
              await File('${dir.path}/contact.png').writeAsBytes(
                (await contact.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!.buffer.asUint8List(),
              );
              await File(
                '${dir.path}/document.json',
              ).writeAsString(jsonEncode(doc));
              picture.dispose();
              contact.dispose();
            });
          }
          for (final i in images) {
            i.dispose();
          }
          expect(issues, isEmpty);
        },
      );
    }
  }
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('$size: candidate title stays editable', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrapCreation(const LuminousEditionPreview()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('문구 편집'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '반짝인');
      await tester.tap(find.byTooltip('문구 적용'));
      await tester.pumpAndSettle();
      expect(find.byType(LuminousCopySheet), findsNothing);
      await tester.tap(find.byTooltip('문구 편집'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        '반짝인',
      );
      expect(tester.takeException(), isNull);
    });
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../../tool/template_studio/concept_volume_preview.dart';
import '../../tool/template_studio/heirloom_preview.dart';
import '../widget/ai_album_start_step_test.dart' show loadCreationFonts;
import '../widget/studio_decorations_test.dart' show capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    for (final f in [
      ('Eulyoo', 'Eulyoo1945-Regular.ttf'),
      ('BookMyungjo', 'BookkMyungjo_Bold.ttf'),
      ('Cormorant Garamond', 'Cormorant-Regular.ttf'),
      ('NanumPen', 'NanumPenScript-Regular.ttf'),
    ]) {
      await (FontLoader(
        f.$1,
      )..addFont(rootBundle.load('assets/fonts/${f.$2}'))).load();
    }
  });
  test('approved designs and new candidates stay outside the free catalog', () {
    expect(ConceptVolume.values, hasLength(7));
    expect(authoredCollections, hasLength(37));
    expect(premiumStudyEntries, hasLength(7));
    expect(allPremiumStudyEntries, hasLength(14));
    for (final v in ConceptVolume.values) {
      expect(ConceptVolume.byId(v.id), v);
      expect(v.chapters.toSet(), hasLength(12));
      expect(authoredCollections.any((c) => c.id == v.id), false);
      final doc = v.document(CollectionAspect.square);
      expect(
        doc['approvalStatus'],
        v.isApprovedDesign
            ? 'approved-volume-design'
            : 'awaiting-design-review',
      );
      expect(doc['catalogPublishable'], false);
      expect(doc.containsKey('approvedAt'), v.isApprovedDesign);
      expect(doc['aiGenerated'], false);
      expect(
        templateVisualMaterialKeys(doc),
        contains('sticker:${v.signatureMaterial}'),
      );
      expect(conceptCopyFits(v, v.defaultCopy), true, reason: v.id);
      expect(
        conceptCopyFits(
          v,
          const EditorialCopy(place: '', period: '', byline: '', note: ''),
        ),
        false,
      );
      final changed = v.document(
        CollectionAspect.square,
        copy: const EditorialCopy(
          place: '우리의 기록',
          period: '2027',
          byline: '우리 둘',
          note: '오래 기억할 날.',
        ),
      );
      expect(jsonEncode(changed['cover']), contains('우리의 기록'));
      if (v == ConceptVolume.sharedSeasons) {
        expect(jsonEncode(changed['pages']), contains('오래 기억할 날.'));
        expect(jsonEncode(changed['pages']), contains('우리 둘'));
      }
    }
    expect(ConceptVolume.byId('unknown'), isNull);
  });

  test('approved concept artwork remains identical across all three sizes', () {
    expect(approvedConceptVolumes, hasLength(4));
    expect(lifeConceptVolumes, hasLength(4));
    for (final volume in approvedConceptVolumes.where(
      (v) => v != ConceptVolume.sharedSeasons,
    )) {
      for (final aspect in CollectionAspect.values) {
        final baseline =
            jsonDecode(
                  File(
                    'tool/template_studio/archives/approved-concept-wave/${volume.id}/${aspect.name}.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final current = volume.document(aspect);
        for (final key in ['cover', 'pages', 'chapters']) {
          expect(
            current[key],
            baseline[key],
            reason: '${volume.id}/${aspect.name}/$key',
          );
        }
      }
    }
  });

  testWidgets(
    'new cutouts have real alpha, visible pixels and stable catalog identities',
    (tester) async {
      for (final spec in conceptWaveDecorations.where(
        (s) => s.assetPath != null,
      )) {
        expect(studioDecorationById(spec.id), spec);
        expect(studioDecorationByAsset(spec.assetPath), spec);
        await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(
            File(spec.assetPath!).readAsBytesSync(),
          );
          final image = (await codec.getNextFrame()).image;
          final rgba = (await image.toByteData())!.buffer.asUint8List();
          var transparent = 0, visible = 0;
          for (var i = 3; i < rgba.length; i += 4) {
            if (rgba[i] == 0) transparent++;
            if (rgba[i] > 200) visible++;
          }
          expect(image.width / image.height, spec.aspectRatio);
          expect(transparent / (rgba.length / 4), greaterThan(.20));
          expect(visible / (rgba.length / 4), greaterThan(.05));
          image.dispose();
          codec.dispose();
        });
      }
    },
  );

  for (final volume in ConceptVolume.values) {
    for (final aspect in CollectionAspect.values) {
      testWidgets(
        '${volume.id}/${aspect.name}: 25 editable pages, typography, assets and visual export',
        (tester) async {
          final doc = volume.document(aspect),
              raw = templateDocumentPages(volume.document(aspect));
          final issues = <String>[], ids = <String>{}, geometry = <String>{};
          final images = <ui.Image>[];
          expect(raw, hasLength(25));
          expect(raw.map((p) => p['role']).toSet(), hasLength(25));
          for (final entry in raw.indexed) {
            final page = entry.$2, pageIndex = entry.$1;
            expect(
              page['side'],
              pageIndex == 0
                  ? 'cover'
                  : pageIndex.isOdd
                  ? 'left'
                  : 'right',
            );
            expect(page['spreadIndex'], (pageIndex + 1) ~/ 2);
            final layers = DataTemplateEngine.buildLayersFromJson(
              page,
              aspect.canvas,
            );
            final prepared = AlbumCreationTemplate.preparePages(
              [layers],
              sourceCanvas: aspect.canvas,
              cover: aspect.cover,
            ).single;
            final photos = layers
                .where((l) => l.type == LayerType.image)
                .toList();
            geometry.add(
              photos
                  .map(
                    (l) =>
                        '${l.position}:${l.width}:${l.height}:${l.imageBackground}',
                  )
                  .join('|'),
            );
            if (pageIndex == 0) {
              expect(photos, hasLength(1));
              expect(photos.single.position, Offset.zero);
              expect(
                Size(photos.single.width, photos.single.height),
                aspect.canvas,
              );
            }
            for (final indexed in layers.indexed) {
              final l = indexed.$2, r = l.position & Size(l.width, l.height);
              if (!ids.add(l.id)) issues.add('duplicate ${l.id}');
              if (r.left < -.1 ||
                  r.top < -.1 ||
                  r.right > aspect.canvas.width + .1 ||
                  r.bottom > aspect.canvas.height + .1) {
                issues.add('${l.id} outside page: $r');
              }
              final restored = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(l, canvasSize: aspect.canvas),
                canvasSize: aspect.canvas,
              );
              expect(restored.type, l.type);
              expect(restored.text, l.text);
              expect(restored.imageBackground, l.imageBackground);
              if (l.imageUrl?.startsWith('asset:') == true) {
                expect(
                  File(l.imageUrl!.substring(6)).existsSync(),
                  true,
                  reason: l.id,
                );
              }
              if (l.type == LayerType.image)
                expect(prepared[indexed.$1].imageUrl, isNull);
              if (l.type == LayerType.sticker)
                expect(prepared[indexed.$1].imageUrl, l.imageUrl);
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
                issues.add(
                  '${l.id} "${l.text}": text ${t.height} > ${l.height}',
                );
              t.dispose();
              for (final other in layers.where(
                (o) =>
                    o.id != l.id &&
                    (o.type == LayerType.text || o.type == LayerType.image),
              )) {
                if (!r
                    .deflate(.7)
                    .overlaps(
                      (other.position & Size(other.width, other.height))
                          .deflate(.7),
                    ))
                  continue;
                final intentionalPhotoOverlay =
                    other.type == LayerType.image &&
                    (pageIndex == 0 ||
                        page['role'] == 'veil-gatefold' ||
                        (page['photoOverlayTextIds'] as List? ?? []).contains(
                          l.id,
                        ));
                if (!intentionalPhotoOverlay)
                  issues.add('${l.id} "${l.text}" overlaps ${other.id}');
              }
            }
            for (final layer in page['layers'] as List) {
              final spec =
                  studioDecorationById(
                    layer['style'] is String ? layer['style'] : '',
                  ) ??
                  studioDecorationByAsset(
                    (layer['imageUrl'] as String?)?.replaceFirst('asset:', ''),
                  );
              if (spec != null)
                expect(
                  layer['w'] *
                      aspect.canvas.width /
                      (layer['h'] * aspect.canvas.height),
                  closeTo(spec.aspectRatio, .0001),
                );
            }
            images.add(
              await capture(
                tester,
                TemplatePageRenderer(
                  layers: layers,
                  width: 360,
                  height: 360 / aspect.canvas.aspectRatio,
                  designCanvasSize: aspect.canvas,
                  preserveTypography: true,
                  showCanvasChrome: false,
                ),
              ),
            );
          }
          expect(geometry.length, greaterThanOrEqualTo(19));
          if (const bool.fromEnvironment('EXPORT_CONCEPTS')) {
            await tester.runAsync(() async {
              final out = Directory(
                'output/template-preview/concept-wave/${volume.id}/${aspect.name}',
              )..createSync(recursive: true);
              File('${out.path}/document.json').writeAsStringSync(
                const JsonEncoder.withIndent('  ').convert(doc),
              );
              Future<void> png(ui.Image image, String name) async =>
                  File('${out.path}/$name.png').writeAsBytes(
                    (await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    ))!.buffer.asUint8List(),
                  );
              await png(images.first, 'cover');
              final w = images.first.width, h = images.first.height;
              for (var first = 1; first < 25; first += 6) {
                final recorder = ui.PictureRecorder(),
                    canvas = Canvas(recorder);
                canvas.drawColor(const Color(0xFFD2DADD), BlendMode.src);
                for (var n = 0; n < 6; n++) {
                  canvas.drawImage(
                    images[first + n],
                    Offset((n % 2) * w.toDouble(), (n ~/ 2) * (h + 12.0)),
                    Paint(),
                  );
                }
                final picture = recorder.endRecording(),
                    image = await picture.toImage(w * 2, (h + 12) * 3);
                await png(image, 'review-${(first - 1) ~/ 6 + 1}');
                image.dispose();
                picture.dispose();
              }
            });
          }
          for (final image in images) {
            image.dispose();
          }
          expect(issues, isEmpty);
        },
      );
    }
  }
}

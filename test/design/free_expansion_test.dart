import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../../tool/template_studio/free_collection_preview.dart';
import '../widget/studio_decorations_test.dart' show capture;
import '../widget/ai_album_start_step_test.dart'
    show loadCreationFonts, wrapCreation;

const _export = bool.fromEnvironment('EXPORT_FREE_EXPANSION');
const _longCopy = EditorialCopy(
  place: '초여름의 작은 마을에서 함께 보낸 시간',
  period: '2026년 6월 12일 ~ 6월 18일',
  byline: '수연과 지후의 소중한 기록',
  note:
      '좋았던 순간들을 이렇게 한 권에 남겨 둡니다. 바쁜 날에도 잠시 멈춰 주변을 바라볼 수 있기를, '
      '익숙한 장소에서도 새로운 장면을 발견할 수 있기를 바라요. 함께 웃고 이야기를 나누던 날의 마음은 '
      '오래 기억하고 싶어요. 다음 계절에도 우리만의 속도로 좋은 날들을 차곡차곡 모아 보아요.',
);

String _geometry(Map<String, dynamic> page) => jsonEncode([
  for (final layer in page['layers'] as List)
    [
      for (final key in ['type', 'x', 'y', 'w', 'h', 'frame']) layer[key],
    ],
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    await (FontLoader(
      'Eulyoo',
    )..addFont(rootBundle.load('assets/fonts/Eulyoo1945-Regular.ttf'))).load();
  });
  test(
    'thirty-six free collections, six travel and five per other category',
    () {
      expect(authoredCollections.length, 36);
      expect(bundledCreationTemplates.map((t) => t.id).toSet().length, 36);
      for (final category in [
        '웨딩',
        '여행',
        '일상',
        '성장·육아',
        '가족·친구',
        '커플·기념일',
        '반려동물',
      ]) {
        expect(
          authoredCollections.where((c) => c.category == category).length,
          category == '여행' ? 6 : 5,
        );
      }
      expect(
        bundledCreationTemplates.every(
          (t) =>
              !t.isPremium &&
              t.pageCount == (t.id == windAtlasBundledId ? 32 : 24),
        ),
        true,
      );
      expect(bundledCreationTemplates.any(isRetiredAuthoredTemplate), false);
      expect(bundledCreationTemplates.take(3).map((t) => t.id), [
        -9301,
        -9302,
        -9303,
      ]);
      for (final aspect in CollectionAspect.values) {
        final covers = <String>{};
        final old =
            [...baselineAuthoredCollections, ...retiredAuthoredCollections]
                .expand((c) => templateDocumentPages(c.document(aspect)))
                .map(_geometry)
                .toSet();
        for (final volume in FreeCollectionVolume.values) {
          final document = volume.document(aspect);
          final pages = templateDocumentPages(document);
          expect(pages.length, 25);
          expect((document['chapters'] as List).length, 12);
          expect(document['accessTier'], 'free');
          expect(document['aiGenerated'], false);
          expect(
            covers.add(_geometry(pages.first)),
            true,
            reason: 'Each cover has its own composition',
          );
          expect(
            pages.any((page) => old.contains(_geometry(page))),
            false,
            reason: '${volume.id} cannot recycle a baseline or retired page',
          );
          expect(
            pages.map(_geometry).toSet().length,
            greaterThanOrEqualTo(22),
            reason: '${volume.id} needs a full book, not repeated page padding',
          );
          expect(pages.map((p) => p['role']).toSet().length, 25);
        }
      }
    },
  );

  testWidgets('category overview renders all thirty-six real covers', (
    tester,
  ) async {
    final images = <ui.Image>[];
    final ordered = [
      for (final category in [
        '웨딩',
        '여행',
        '일상',
        '성장·육아',
        '가족·친구',
        '커플·기념일',
        '반려동물',
      ])
        ...authoredCollections.where((c) => c.category == category),
    ];
    for (final collection in ordered) {
      final document = collection.document(CollectionAspect.square);
      images.add(
        await capture(
          tester,
          TemplatePageRenderer(
            layers: DataTemplateEngine.buildLayersFromJson(
              document['cover'],
              const Size(500, 500),
            ),
            width: 300,
            height: 300,
            designCanvasSize: const Size(500, 500),
            preserveTypography: true,
            showCanvasChrome: false,
          ),
        ),
      );
    }
    if (_export) {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFFE8ECEA), BlendMode.src);
        final categories = ordered.map((c) => c.category).toSet().toList();
        for (final entry in ordered.indexed) {
          final group = ordered
              .where((c) => c.category == entry.$2.category)
              .toList();
          final column = group.indexOf(entry.$2);
          final x = 24.0 + column * 284;
          final y = 52.0 + categories.indexOf(entry.$2.category) * 332;
          final image = images[entry.$1];
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            Rect.fromLTWH(x, y, 260, 260),
            Paint(),
          );
          final label = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: entry.$2.title,
              style: const TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 14,
                color: Color(0xFF293B36),
              ),
            ),
          )..layout(maxWidth: 260);
          label.paint(canvas, Offset(x, y + 273));
          label.dispose();
          if (column == 0) {
            final heading = TextPainter(
              textDirection: TextDirection.ltr,
              text: TextSpan(
                text: '${entry.$2.category} · 무료 ${group.length}종',
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF293B36),
                ),
              ),
            )..layout(maxWidth: 260);
            heading.paint(canvas, Offset(x, y - 32));
            heading.dispose();
          }
        }
        final picture = recorder.endRecording();
        final columns = categories
            .map(
              (category) => ordered.where((c) => c.category == category).length,
            )
            .reduce((a, b) => a > b ? a : b);
        final image = await picture.toImage(
          24 + columns * 284,
          40 + categories.length * 332,
        );
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/template-preview/free-expansion/catalog.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
    }
    for (final image in images) image.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final volume in FreeCollectionVolume.values) {
    for (final aspect in CollectionAspect.values) {
      test(
        '${volume.id}/${aspect.name}: text, photos, masks, identity and saved roundtrip',
        () {
          final issues = <String>[];
          for (final copy in [volume.defaultCopy, _longCopy]) {
            final pages = freeCollectionPreviewPages(volume, aspect, copy);
            final ids = <String>{};
            var photos = 0;
            for (final page in pages) {
              final images = page
                  .where((l) => l.type == LayerType.image)
                  .toList();
              expect(
                images.map((l) => l.imageUrl).toSet().length,
                images.length,
              );
              final cleared = AlbumCreationTemplate.preparePages(
                [page],
                sourceCanvas: aspect.canvas,
                cover: aspect.cover,
              ).single;
              for (final indexed in page.indexed) {
                final layer = indexed.$2;
                expect(ids.add(layer.id), true);
                final rect = layer.position & Size(layer.width, layer.height);
                if (rect.left < -.1 ||
                    rect.top < -.1 ||
                    rect.right > aspect.canvas.width + .1 ||
                    rect.bottom > aspect.canvas.height + .1) {
                  issues.add('${layer.id}: outside canvas $rect');
                }
                final restored = LayerExportMapper.fromJson(
                  LayerExportMapper.toJson(layer, canvasSize: aspect.canvas),
                  canvasSize: aspect.canvas,
                );
                expect(restored.imageBackground, layer.imageBackground);
                expect(restored.text, layer.text);
                if (layer.type == LayerType.decoration &&
                    layer.imageBackground != null) {
                  expect(
                    studioDecorationById(layer.imageBackground),
                    isNotNull,
                  );
                }
                if (layer.type == LayerType.sticker) {
                  expect(File(layer.imageUrl!.substring(6)).existsSync(), true);
                }
                if (layer.type == LayerType.image) {
                  photos++;
                  expect({
                    'none',
                    ...studioPhotoFrames,
                  }, contains(layer.imageBackground));
                  expect(File(layer.imageUrl!.substring(6)).existsSync(), true);
                  expect(cleared[indexed.$1].imageUrl, isNull);
                  expect(
                    cleared[indexed.$1].imageBackground,
                    layer.imageBackground,
                  );
                  final target = coverCanvasBaseSize(aspect.cover);
                  expect(
                    cleared[indexed.$1].width / target.width,
                    closeTo(layer.width / aspect.canvas.width, .0001),
                  );
                  if (layer.imageUrl!.contains('daily_friends') ||
                      layer.imageUrl!.contains('lightbound_guests')) {
                    expect(layer.width / layer.height, closeTo(1.5, .00001));
                  }
                }
                if (layer.type != LayerType.text) continue;
                final painter = TextPainter(
                  text: TextSpan(text: layer.text, style: layer.textStyle),
                  textDirection: TextDirection.ltr,
                  strutStyle: StrutStyle.fromTextStyle(
                    layer.textStyle!,
                    forceStrutHeight: true,
                  ),
                )..layout(maxWidth: layer.width);
                if (painter.height > layer.height + .5)
                  issues.add(
                    '${layer.id}: text ${painter.height} > ${layer.height}: ${layer.text}',
                  );
                painter.dispose();
                for (final other in page.where(
                  (l) => l.type == LayerType.image || l.type == LayerType.text,
                )) {
                  if (other.id != layer.id &&
                      rect
                          .deflate(.05)
                          .overlaps(
                            (other.position & Size(other.width, other.height))
                                .deflate(.05),
                          )) {
                    issues.add('${layer.id} overlaps ${other.id}');
                  }
                }
              }
            }
            expect(photos, greaterThanOrEqualTo(24));
          }
          expect(issues.toSet(), isEmpty);
        },
      );

      testWidgets('${volume.id}/${aspect.name}: render all pages', (
        tester,
      ) async {
        final images = <ui.Image>[];
        for (final page in freeCollectionPreviewPages(
          volume,
          aspect,
          volume.defaultCopy,
        )) {
          images.add(
            await capture(
              tester,
              TemplatePageRenderer(
                layers: page,
                width: 300,
                height: 300 / aspect.canvas.aspectRatio,
                designCanvasSize: aspect.canvas,
                preserveTypography: true,
                showCanvasChrome: false,
              ),
            ),
          );
          for (final raw in tester.widgetList<RawImage>(
            find.byType(RawImage),
          )) {
            expect(raw.image, isNotNull);
          }
        }
        if (_export)
          await tester.runAsync(() => _contactSheet(volume, aspect, images));
        for (final image in images) image.dispose();
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('${volume.id}: contents and personal copy editing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrapCreation(FreeCollectionPreview(volume: volume)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('목차'));
      await tester.pumpAndSettle();
      final end = find.text('23–24 / ${volume.chapters.last}');
      await tester.ensureVisible(end);
      await tester.tap(end);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('문구 편집'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '우리의 좋은 계절');
      await tester.tap(find.byTooltip('문구 적용'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
      expect(freeCollectionCopyFits(volume, _longCopy), true);
    });
  }
}

Future<void> _contactSheet(
  FreeCollectionVolume volume,
  CollectionAspect aspect,
  List<ui.Image> pages,
) async {
  const width = 280.0, gap = 16.0;
  final height = width / aspect.canvas.aspectRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(5 * (width + gap) + gap, 5 * (height + 30) + gap);
  canvas.drawColor(const Color(0xFFE2E5E3), BlendMode.src);
  for (final entry in pages.indexed) {
    final x = gap + (entry.$1 % 5) * (width + gap);
    final y = gap + (entry.$1 ~/ 5) * (height + 30);
    canvas.drawImageRect(
      entry.$2,
      Rect.fromLTWH(
        0,
        0,
        entry.$2.width.toDouble(),
        entry.$2.height.toDouble(),
      ),
      Rect.fromLTWH(x, y, width, height),
      Paint(),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.ceil(), size.height.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(
    'output/template-preview/free-expansion/${volume.id}-${aspect.name}.png',
  );
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

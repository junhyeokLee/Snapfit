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
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.whereType<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).whereType<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  test('forty-two free collections retain at least five per topic', () {
    expect(authoredCollections.length, 42);
    expect(bundledCreationTemplates.map((t) => t.id).toSet().length, 42);
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
        6,
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
      final coverGrids = <String>{};
      final coverPhotos = <String>{};
      final coverTypeDirections = <String>{};
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
        coverGrids.add(_geometry(pages.first));
        expect(document['artDirection'], volume.id);
        final coverLayers = (pages.first['layers'] as List).cast<Map>();
        final title = coverLayers.singleWhere(
          (layer) => layer['typographyRole'] == 'signature-title',
        );
        expect(
          (title['text'] as String).replaceAll(RegExp(r'\s+'), ''),
          volume.title.replaceAll(RegExp(r'\s+'), ''),
        );
        final style = title['style'] as Map;
        coverTypeDirections.add(
          jsonEncode([
            style['fontFamily'],
            style['fontWeight'],
            title['align'],
            (title['text'] as String).split('\n').length,
          ]),
        );
        final hero = coverLayers.firstWhere(
          (layer) => layer['type'] == 'image',
        );
        expect(
          coverPhotos.add(hero['imageUrl'] as String),
          isTrue,
          reason: '${volume.id}: keep an independently chosen cover subject',
        );
        expect(
          pages.skip(1).any((page) => old.contains(_geometry(page))),
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
      expect(
        coverGrids.length,
        greaterThanOrEqualTo(8),
        reason: 'Eight jacket directions may share deliberate editorial grids',
      );
      expect(
        coverTypeDirections.length,
        greaterThanOrEqualTo(4),
        reason:
            'Collection identity includes distinct typography, not only recoloring',
      );
    }
  });

  testWidgets('category overview renders all forty-two real covers in RAM', (
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
                    studioDecorationById(layer.imageBackground) != null ||
                        photoCoverShadeStyles.contains(layer.imageBackground),
                    true,
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
                  // The sea jacket puts native opaque paper over its backdrop.
                  // Other jackets keep lettering outside the photograph.
                  final fullPhotoBackdrop =
                      identical(page, pages.first) &&
                      other.type == LayerType.image &&
                      other.width == aspect.canvas.width &&
                      other.height == aspect.canvas.height;
                  if (fullPhotoBackdrop) {
                    expect(
                      page.any((paper) {
                        final paperRect =
                            paper.position & Size(paper.width, paper.height);
                        return paper.type == LayerType.decoration &&
                            paper.decorationFillColor != null &&
                            paper.opacity == 1 &&
                            paper.zIndex > other.zIndex &&
                            paper.zIndex < layer.zIndex &&
                            paperRect.left <= rect.left + .1 &&
                            paperRect.top <= rect.top + .1 &&
                            paperRect.right >= rect.right - .1 &&
                            paperRect.bottom >= rect.bottom - .1;
                      }),
                      isTrue,
                      reason:
                          '${layer.id}: photo-safe paper must cover the text box',
                    );
                    continue;
                  }
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

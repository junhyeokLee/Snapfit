import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/catalog_favorite_keys.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../../tool/template_studio/wind_atlas_preview.dart';
import '../widget/ai_album_start_step_test.dart'
    show loadCreationFonts, wrapCreation;
import '../widget/studio_decorations_test.dart' show capture;

const exporting = bool.fromEnvironment('EXPORT_WIND_ATLAS');
String geometry(Map<String, dynamic> p) => jsonEncode([
  for (final l in p['layers'] as List)
    [
      for (final k in ['type', 'x', 'y', 'w', 'h']) l[k],
    ],
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    await (FontLoader(
      'Eulyoo',
    )..addFont(rootBundle.load('assets/fonts/Eulyoo1945-Regular.ttf'))).load();
    await (FontLoader(
      'Cormorant Garamond',
    )..addFont(rootBundle.load('assets/fonts/Cormorant-Regular.ttf'))).load();
  });
  test(
    'store entry keeps artwork identity without assuming a free shop price',
    () {
      final collection = authoredCollections.singleWhere(
        (c) => c.id == windAtlasId,
      );
      final template = bundledCreationTemplates.singleWhere(
        (t) => t.id == windAtlasBundledId,
      );
      expect(template.isPremium, false);
      expect(template.pageCount, 32);
      expect(template.tags, isNot(contains('무료')));
      expect(collection.chapters, windAtlasSpreads);
      final catalog = jsonDecode(template.templateJson!) as Map;
      expect(
        (catalog['variants'] as Map).keys,
        containsAll(['portrait', 'square', 'landscape']),
      );
      for (final aspect in CollectionAspect.values) {
        expect(catalog['variants'][aspect.name], buildWindAtlas(aspect));
      }
      expect(
        CatalogFavoriteKeys.template(windAtlasBundledId),
        CatalogFavoriteKeys.design(windAtlasId),
      );
    },
  );
  test(
    '32 distinct inner pages, 3 real covers, approved free without paid publication',
    () {
      expect(bundledCreationTemplates.length, 37);
      expect(bundledCreationTemplates.every((t) => !t.isPremium), true);
      for (final aspect in CollectionAspect.values) {
        final existing = authoredCollections
            .where((c) => c.id != windAtlasId)
            .expand((c) => templateDocumentPages(c.document(aspect)))
            .map(geometry)
            .toSet();
        final doc = buildWindAtlas(aspect);
        final pages = templateDocumentPages(doc);
        expect(doc['innerPageCount'], 32);
        expect(pages.length, 33);
        expect(doc['accessTier'], 'free');
        expect(doc['publicationStatus'], 'bundled');
        expect(doc['catalogPublishable'], false);
        expect(doc['aiGenerated'], false);
        expect(pages.map((p) => p['role']).toSet().length, 33);
        expect(pages.map(geometry).toSet().length, 33);
        expect(pages.map(geometry).any(existing.contains), false);
        expect(
          WindAtlasCover.values
              .map((c) => geometry(buildWindAtlas(aspect, cover: c)['cover']))
              .toSet()
              .length,
          3,
        );
        for (var i = 1; i < 33; i++) {
          expect(pages[i]['side'], i.isOdd ? 'left' : 'right');
          expect(pages[i]['spreadIndex'], (i + 1) ~/ 2);
        }
      }
    },
  );
  for (final aspect in CollectionAspect.values) {
    test(
      '${aspect.name}: bounds, typography, binding and editable roundtrip',
      () {
        final issues = <String>[];
        for (final cover in WindAtlasCover.values) {
          final pages = windAtlasPreviewPages(aspect, cover: cover);
          final ids = <String>{};
          for (var index = 0; index < pages.length; index++) {
            final page = pages[index];
            final cleared = AlbumCreationTemplate.preparePages(
              [page],
              sourceCanvas: aspect.canvas,
              cover: aspect.cover,
            ).single;
            for (final entry in page.indexed) {
              final l = entry.$2, rect = l.position & Size(l.width, l.height);
              expect(ids.add(l.id), true);
              if (rect.left < -.1 ||
                  rect.top < -.1 ||
                  rect.right > aspect.canvas.width + .1 ||
                  rect.bottom > aspect.canvas.height + .1)
                issues.add('${l.id} bounds: $rect');
              final saved = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(l, canvasSize: aspect.canvas),
                canvasSize: aspect.canvas,
              );
              expect(saved.text, l.text);
              expect(saved.imageBackground, l.imageBackground);
              expect(saved.type, l.type);
              if (l.imageUrl?.startsWith('asset:') ?? false)
                expect(File(l.imageUrl!.substring(6)).existsSync(), true);
              if (l.type == LayerType.image) {
                expect(cleared[entry.$1].imageUrl, isNull);
                expect(
                  cleared[entry.$1]
                      .copyWith(
                        imageUrl: 'asset:assets/snapfit_home_square.jpg',
                      )
                      .imageBackground,
                  l.imageBackground,
                );
                if (index > 0 &&
                    (index.isOdd
                        ? rect.right > aspect.canvas.width * .88 + .1
                        : rect.left < aspect.canvas.width * .12 - .1))
                  issues.add('${l.id} binding inset');
              }
              if (l.type == LayerType.sticker)
                expect(cleared[entry.$1].imageUrl, l.imageUrl);
              if (l.type != LayerType.text) continue;
              final painter = TextPainter(
                text: TextSpan(text: l.text, style: l.textStyle),
                textDirection: TextDirection.ltr,
                strutStyle: StrutStyle.fromTextStyle(
                  l.textStyle!,
                  forceStrutHeight: true,
                ),
              )..layout(maxWidth: l.width);
              if (painter.height > l.height + .5)
                issues.add(
                  '${cover.name}/${l.id}: ${painter.height.toStringAsFixed(1)} > ${l.height.toStringAsFixed(1)} (${l.text})',
                );
              painter.dispose();
              for (final other in page.where(
                (o) => o.type == LayerType.text || o.type == LayerType.image,
              )) {
                if (other.id != l.id &&
                    rect
                        .deflate(.1)
                        .overlaps(
                          (other.position & Size(other.width, other.height))
                              .deflate(.1),
                        ))
                  issues.add('${l.id} overlaps ${other.id}');
              }
            }
          }
        }
        expect(issues.toSet(), isEmpty);
      },
    );
    testWidgets('${aspect.name}: render all 32 pages and 3 covers', (
      tester,
    ) async {
      final pages = windAtlasPreviewPages(aspect);
      final images = <ui.Image>[];
      for (final page in pages) {
        images.add(
          await capture(
            tester,
            TemplatePageRenderer(
              layers: page,
              width: 420,
              height: 420 / aspect.canvas.aspectRatio,
              designCanvasSize: aspect.canvas,
              preserveTypography: true,
              showCanvasChrome: false,
            ),
          ),
        );
        for (final raw in tester.widgetList<RawImage>(find.byType(RawImage)))
          expect(raw.image, isNotNull);
      }
      if (exporting)
        await tester.runAsync(() async {
          final dir = Directory(
            'output/template-preview/wind-atlas/${aspect.name}',
          );
          await dir.create(recursive: true);
          for (final item in images.indexed)
            await File('${dir.path}/page-${item.$1}.png').writeAsBytes(
              (await item.$2.toByteData(
                format: ui.ImageByteFormat.png,
              ))!.buffer.asUint8List(),
            );
          final w = images.first.width.toDouble(),
              h = images.first.height.toDouble();
          final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
          canvas.drawColor(const Color(0xFFE2E7E5), BlendMode.src);
          for (var i = 0; i < images.length; i++) {
            final x = i == 0 ? 0.0 : ((i - 1) % 4) * w;
            final y = i == 0 ? 0.0 : (((i - 1) ~/ 4) + 1) * (h + 20);
            canvas.drawImage(images[i], Offset(x, y), Paint());
          }
          final picture = recorder.endRecording();
          final contact = await picture.toImage(
            (w * 4).ceil(),
            ((h + 20) * 9).ceil(),
          );
          await File('${dir.path}/contact.png').writeAsBytes(
            (await contact.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          );
          contact.dispose();
          picture.dispose();
          await File('${dir.path}/document.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert(buildWindAtlas(aspect)),
          );
        });
      for (final im in images) im.dispose();
      for (final cover in WindAtlasCover.values.skip(1)) {
        final layers = windAtlasPreviewPages(aspect, cover: cover).first;
        final image = await capture(
          tester,
          TemplatePageRenderer(
            layers: layers,
            width: 600,
            height: 600 / aspect.canvas.aspectRatio,
            designCanvasSize: aspect.canvas,
            preserveTypography: true,
            showCanvasChrome: false,
          ),
        );
        if (exporting)
          await tester.runAsync(() async {
            await File(
              'output/template-preview/wind-atlas/${aspect.name}/cover-${cover.name}.png',
            ).writeAsBytes(
              (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!.buffer.asUint8List(),
            );
            await File(
              'output/template-preview/wind-atlas/${aspect.name}/cover-${cover.name}.json',
            ).writeAsString(
              const JsonEncoder.withIndent(
                '  ',
              ).convert(buildWindAtlas(aspect, cover: cover)['cover']),
            );
          });
        image.dispose();
      }
      expect(tester.takeException(), isNull);
    });
  }
  test('editable copy validates across all covers and ratios', () {
    expect(windAtlasCopyFits(windAtlasCopy), true);
    expect(
      windAtlasCopyFits(
        const EditorialCopy(
          place: '초여름의 작은 마을에서 보낸 시간',
          period: '2026년 6월 12일 ~ 6월 18일',
          byline: '수연과 지후의 기록',
          note: '함께한 순간을 오래 기억하고 싶다.',
        ),
      ),
      true,
    );
    expect(
      windAtlasCopyFits(
        EditorialCopy(
          place: '여행',
          period: '2026',
          byline: '수연',
          note: List.filled(40, '기록').join('\n'),
        ),
      ),
      false,
    );
  });
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('$size: covers, overview, copy, photos and size controls', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrapCreation(const WindAtlasPreview()));
      await tester.pumpAndSettle();
      expect(find.text('무료 · 표지 + 내지 32쪽'), findsOneWidget);
      await tester.tap(find.byTooltip('표지 디자인'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is CheckedPopupMenuItem<WindAtlasCover> &&
              w.value == WindAtlasCover.botanical,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('전체 펼침 보기'));
      await tester.pumpAndSettle();
      expect(find.text('16 / 다음 여행을 위한 여백'), findsOneWidget);
      await tester.tap(find.byTooltip('책으로 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('문구 편집'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '우리의 여름');
      await tester.tap(find.byTooltip('문구 적용'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byTooltip('사진 교체 확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('인물 사진'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('앨범 규격'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CollectionAspect.landscape.cover.name));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

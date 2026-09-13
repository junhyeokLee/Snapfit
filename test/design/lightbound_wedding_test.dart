import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../../tool/template_studio/lightbound_preview.dart';
import '../widget/studio_decorations_test.dart' show capture;
import '../widget/ai_album_start_step_test.dart'
    show loadCreationFonts, wrapCreation;

const _out = 'output/template-preview/lightbound';
const _export = bool.fromEnvironment('EXPORT_LIGHTBOUND');
const _longCopy = LightboundWeddingCopy(
  firstName: '알렉산드라김수연',
  secondName: '크리스토퍼박지후',
  date: '2026년 5월 24일',
  letter:
      '우리의 하루를 함께 기억해 줘서 고마워요. 특별한 순간뿐 아니라 평범한 아침과 느린 저녁에도 '
      '서로의 이야기에 귀를 기울이는 사람이 되고 싶어요. 바쁜 날에도 나란히 앉아 잠깐의 안부를 나누고, '
      '새로운 계절이 오면 익숙한 길을 다시 걸어 보아요. 먼 훗날 이 책을 펼쳤을 때에도 '
      '오늘처럼 편안하게 웃을 수 있기를 바라요.',
);

String _composition(Map<String, dynamic> page) => jsonEncode([
  for (final layer in page['layers'] as List)
    [
      for (final key in ['type', 'x', 'y', 'w', 'h']) layer[key],
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

  test('free baseline is independent, honestly counted and never paid', () {
    expect(bundledCreationTemplates.length, 37);
    expect(bundledCreationTemplates.every((t) => !t.isPremium), isTrue);
    expect(authoredCollections.any((c) => c.id == 'lightbound'), isTrue);
    for (final aspect in CollectionAspect.values) {
      final data = buildLightboundWeddingDraft(aspect);
      expect(data['publicationStatus'], 'bundled');
      expect(data['accessTier'], 'free');
      expect(data['catalogPublishable'], false);
      expect(data['aiGenerated'], false);
      expect(data['innerPageCount'], 24);
      expect(data['targetInnerPageCount'], 24);
      final pages = templateDocumentPages(data);
      expect(pages.length, 25);
      expect(pages.map((p) => p['role']).toSet().length, 25);
      expect((data['chapters'] as List).length, 12);
      expect(lightboundSpreadNames.length * 2, lightboundInnerPageCount);
      for (var i = 0; i < pages.length; i++) {
        expect(
          pages[i]['side'],
          i == 0 ? 'cover' : (i.isOdd ? 'left' : 'right'),
        );
      }
      final originals = retiredAuthoredCollections
          .expand((c) => templateDocumentPages(c.document(aspect)))
          .map(_composition)
          .toSet();
      expect(pages.any((p) => originals.contains(_composition(p))), isFalse);
    }
  });

  test(
    'Korean names and long letter fit all sizes, excessive line breaks are rejected',
    () {
      expect(lightboundCopyFits(const LightboundWeddingCopy()), isTrue);
      expect(lightboundCopyFits(_longCopy), isTrue);
      expect(
        lightboundCopyFits(
          LightboundWeddingCopy(letter: List.filled(24, '우리의 하루').join('\n')),
        ),
        isFalse,
      );
    },
  );

  for (final aspect in CollectionAspect.values) {
    test(
      '${aspect.name}: complete composition, safe text and editable photo roundtrip',
      () {
        for (final copy in [const LightboundWeddingCopy(), _longCopy]) {
          final pages = lightboundPreviewPages(aspect, copy);
          final ids = <String>{};
          for (var index = 0; index < pages.length; index++) {
            final page = pages[index];
            final texts = page.where((l) => l.type == LayerType.text).toList();
            for (var a = 0; a < texts.length; a++) {
              for (var b = a + 1; b < texts.length; b++) {
                expect(
                  (texts[a].position & Size(texts[a].width, texts[a].height))
                      .deflate(.05)
                      .overlaps(
                        (texts[b].position &
                                Size(texts[b].width, texts[b].height))
                            .deflate(.05),
                      ),
                  isFalse,
                  reason: '${texts[a].id} overlaps ${texts[b].id}',
                );
              }
            }
            final photos = page
                .where((l) => l.type == LayerType.image)
                .toList();
            expect(photos.map((l) => l.imageUrl).toSet().length, photos.length);
            final cleared = AlbumCreationTemplate.preparePages(
              [page],
              sourceCanvas: aspect.canvas,
              cover: aspect.cover,
            ).single;
            for (var i = 0; i < page.length; i++) {
              final layer = page[i];
              expect(ids.add(layer.id), isTrue);
              final bounds = layer.position & Size(layer.width, layer.height);
              expect(bounds.left, greaterThanOrEqualTo(0));
              expect(bounds.top, greaterThanOrEqualTo(0));
              expect(bounds.right, lessThanOrEqualTo(aspect.canvas.width + .1));
              expect(
                bounds.bottom,
                lessThanOrEqualTo(aspect.canvas.height + .1),
              );
              final saved = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(layer, canvasSize: aspect.canvas),
                canvasSize: aspect.canvas,
              );
              expect(saved.imageBackground, layer.imageBackground);
              expect(saved.text, layer.text);
              if (layer.type == LayerType.image) {
                expect(
                  bounds.left,
                  greaterThanOrEqualTo(aspect.canvas.width * .06),
                );
                expect(
                  bounds.right,
                  lessThanOrEqualTo(aspect.canvas.width * .94),
                );
                expect(File(layer.imageUrl!.substring(6)).existsSync(), isTrue);
                expect(cleared[i].imageUrl, isNull);
                final replaced = cleared[i].copyWith(
                  imageUrl: 'asset:assets/snapfit_home_square.jpg',
                );
                expect(replaced.imageBackground, layer.imageBackground);
                if (layer.id.endsWith('family_group')) {
                  expect(
                    layer.width / layer.height,
                    closeTo(1.5, .00001),
                    reason:
                        'The group photograph must not lose faces to a portrait crop.',
                  );
                }
                final target = coverCanvasBaseSize(aspect.cover);
                expect(
                  replaced.position.dx / target.width,
                  closeTo(layer.position.dx / aspect.canvas.width, .0001),
                );
                expect(
                  replaced.position.dy / target.height,
                  closeTo(layer.position.dy / aspect.canvas.height, .0001),
                );
                expect(
                  replaced.width / replaced.height,
                  closeTo(layer.width / layer.height, .0001),
                );
                expect(
                  replaced.width / target.width,
                  closeTo(layer.width / aspect.canvas.width, .0001),
                );
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
              expect(
                painter.height,
                lessThanOrEqualTo(layer.height + .5),
                reason: '${aspect.name} ${layer.id}: ${layer.text}',
              );
              painter.dispose();
              for (final photo in photos) {
                expect(
                  bounds.overlaps(
                    photo.position & Size(photo.width, photo.height),
                  ),
                  isFalse,
                  reason: '${layer.id} overlaps ${photo.id}',
                );
              }
            }
          }
        }
      },
    );

    testWidgets('${aspect.name}: render every spread and long-copy inspection', (
      tester,
    ) async {
      final images = <ui.Image>[];
      final pages = lightboundPreviewPages(
        aspect,
        const LightboundWeddingCopy(),
      );
      for (var i = 0; i < pages.length; i++) {
        images.add(
          await capture(
            tester,
            TemplatePageRenderer(
              layers: pages[i],
              width: 420,
              height: 420 / aspect.canvas.aspectRatio,
              designCanvasSize: aspect.canvas,
              preserveTypography: true,
              showCanvasChrome: false,
            ),
          ),
        );
        for (final raw in tester.widgetList<RawImage>(find.byType(RawImage))) {
          expect(raw.image, isNotNull);
        }
      }
      if (_export) {
        await tester.runAsync(() async {
          final dir = Directory('$_out/${aspect.name}')
            ..createSync(recursive: true);
          for (var i = 0; i < images.length; i += i == 0 ? 1 : 2) {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            canvas.drawImage(images[i], Offset.zero, Paint());
            if (i > 0)
              canvas.drawImage(
                images[i + 1],
                Offset(images[i].width.toDouble(), 0),
                Paint(),
              );
            final picture = recorder.endRecording();
            final spread = await picture.toImage(
              images[i].width * (i == 0 ? 1 : 2),
              images[i].height,
            );
            await File(
              '${dir.path}/${i == 0 ? 'cover' : 'spread-${(i + 1) ~/ 2}'}.png',
            ).writeAsBytes(
              (await spread.toByteData(
                format: ui.ImageByteFormat.png,
              ))!.buffer.asUint8List(),
            );
            spread.dispose();
            picture.dispose();
          }
          await File('${dir.path}/document.json').writeAsString(
            const JsonEncoder.withIndent(
              '  ',
            ).convert(buildLightboundWeddingDraft(aspect)),
          );
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          final pageHeight = images[1].height / 2;
          final rowHeight = pageHeight + 42;
          canvas.drawColor(const Color(0xFFE7ECE9), BlendMode.src);
          for (
            var spread = 0;
            spread < lightboundSpreadNames.length;
            spread++
          ) {
            final x = 16.0 + (spread % 3) * 440;
            final y = 12.0 + (spread ~/ 3) * rowHeight;
            final label = TextPainter(
              text: TextSpan(
                text: '${spread + 1} / ${lightboundSpreadNames[spread]}',
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 12,
                  color: Colors.black,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: 420);
            label.paint(canvas, Offset(x, y));
            label.dispose();
            for (var side = 0; side < 2; side++) {
              final image = images[spread * 2 + side + 1];
              canvas.drawImageRect(
                image,
                Rect.fromLTWH(
                  0,
                  0,
                  image.width.toDouble(),
                  image.height.toDouble(),
                ),
                Rect.fromLTWH(x + side * 210, y + 22, 210, pageHeight),
                Paint()..filterQuality = FilterQuality.medium,
              );
            }
          }
          final picture = recorder.endRecording();
          final contact = await picture.toImage(
            1336,
            (rowHeight * 4 + 12).ceil(),
          );
          await File('${dir.path}/all-spreads.png').writeAsBytes(
            (await contact.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          );
          contact.dispose();
          picture.dispose();
        });
      }
      for (final image in images) {
        image.dispose();
      }
      final longPages = lightboundPreviewPages(aspect, _longCopy);
      final long = await capture(
        tester,
        TemplatePageRenderer(
          layers: longPages.last,
          width: 420,
          height: 420 / aspect.canvas.aspectRatio,
          designCanvasSize: aspect.canvas,
          preserveTypography: true,
          showCanvasChrome: false,
        ),
      );
      if (_export)
        await tester.runAsync(() async {
          await File('$_out/${aspect.name}/long-letter.png').writeAsBytes(
            (await long.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          );
        });
      long.dispose();
    });
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      '$size: document, overview, copy edit and cancellation work without payment',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(wrapCreation(const LightboundPreview()));
        await tester.pumpAndSettle();
        expect(find.text('무료 · 표지 + 내지 24쪽'), findsOneWidget);
        await tester.tap(find.byTooltip('전체 펼침 보기'));
        await tester.pumpAndSettle();
        expect(find.text('01 / 서로에게 닿은 날'), findsOneWidget);
        await tester.tap(find.byTooltip('책으로 보기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('목차'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('23–24 / 다음의 우리'));
        await tester.tap(find.text('23–24 / 다음의 우리'));
        await tester.pumpAndSettle();
        expect(
          find.text(size.width > size.height ? '23–24 / 24쪽' : '23 / 24쪽'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('문구 편집'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '김수연');
        await tester.tap(find.byTooltip('문구 적용'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNothing);
        await tester.tap(find.byTooltip('문구 편집'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          '김수연',
        );
        await tester.enterText(find.byType(TextFormField).first, '변경 취소');
        await tester.tap(find.byTooltip('문구 편집 닫기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('문구 편집'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          '김수연',
        );
        await tester.tap(find.byTooltip('문구 편집 닫기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../../tool/template_studio/editorial_preview.dart';
import '../widget/studio_decorations_test.dart' show capture;
import '../widget/ai_album_start_step_test.dart'
    show loadCreationFonts, wrapCreation;

const _export = bool.fromEnvironment('EXPORT_EDITORIAL');
const _longCopy = EditorialCopy(
  place: '초여름의 작은 마을에서 보낸 시간',
  period: '2026년 6월 12일 ~ 6월 18일',
  byline: '수연과 지후의 기록',
  note:
      '좋았던 순간들을 이렇게 한 권에 남겨 둡니다. 바쁜 날에도 잠시 멈춰 '
      '주변을 바라볼 수 있기를, 익숙한 장소에서도 새로운 장면을 발견할 수 있기를 바라요. '
      '함께 웃고 이야기를 나누던 날의 마음은 오래 기억하고 싶어요. '
      '다음 계절에도 우리만의 속도로 좋은 날들을 차곡차곡 모아 보아요.',
);

String _geometry(Map<String, dynamic> p) => jsonEncode([
  for (final l in p['layers'] as List)
    [
      for (final k in ['type', 'x', 'y', 'w', 'h']) l[k],
    ],
]);
Rect _rect(LayerModel l) => l.position & Size(l.width, l.height);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCreationFonts);

  test('two independent 24-page collections are free, never paid', () {
    expect(bundledCreationTemplates.length, 36);
    expect(bundledCreationTemplates.every((t) => !t.isPremium), isTrue);
    for (final aspect in CollectionAspect.values) {
      final old = [
        ...retiredAuthoredCollections.expand(
          (c) => templateDocumentPages(c.document(aspect)),
        ),
        ...templateDocumentPages(buildLightboundWeddingDraft(aspect)),
      ].map(_geometry).toSet();
      final betweenVolumes = <String>{};
      for (final volume in EditorialVolume.values) {
        final doc = volume.document(aspect);
        final pages = templateDocumentPages(doc);
        expect(doc['aiGenerated'], false);
        expect(doc['publicationStatus'], 'bundled');
        expect(doc['accessTier'], 'free');
        expect(doc['catalogPublishable'], false);
        expect(doc['innerPageCount'], 24);
        expect(pages.length, 25);
        expect((doc['chapters'] as List).length, 12);
        expect(pages.map((p) => p['role']).toSet().length, 25);
        for (var i = 0; i < pages.length; i++) {
          expect(old.contains(_geometry(pages[i])), isFalse);
          expect(
            betweenVolumes.add(_geometry(pages[i])),
            isTrue,
            reason:
                '${volume.route}/${aspect.name}/$i repeats an entire composition',
          );
          expect(
            pages[i]['side'],
            i == 0 ? 'cover' : (i.isOdd ? 'left' : 'right'),
          );
        }
      }
    }
  });

  for (final volume in EditorialVolume.values) {
    test('${volume.route}: copy validation rejects excessive line breaks', () {
      expect(editorialCopyFits(volume, volume.defaultCopy), isTrue);
      expect(editorialCopyFits(volume, _longCopy), isTrue);
      expect(
        editorialCopyFits(
          volume,
          EditorialCopy(
            place: '기록',
            period: '2026',
            byline: '수연',
            note: List.filled(24, '기록').join('\n'),
          ),
        ),
        isFalse,
      );
    });
    for (final aspect in CollectionAspect.values) {
      test(
        '${volume.route}/${aspect.name}: geometry, typography and editable roundtrip',
        () {
          final issues = <String>[];
          for (final copy in [volume.defaultCopy, _longCopy]) {
            final pages = editorialPreviewPages(volume, aspect, copy);
            final ids = <String>{};
            for (final page in pages) {
              final texts = page
                  .where((l) => l.type == LayerType.text)
                  .toList();
              final photos = page
                  .where((l) => l.type == LayerType.image)
                  .toList();
              expect(
                photos.map((l) => l.imageUrl).toSet().length,
                photos.length,
              );
              final cleared = AlbumCreationTemplate.preparePages(
                [page],
                sourceCanvas: aspect.canvas,
                cover: aspect.cover,
              ).single;
              for (var i = 0; i < page.length; i++) {
                final l = page[i], r = _rect(l);
                expect(ids.add(l.id), isTrue);
                expect(r.left, greaterThanOrEqualTo(0));
                expect(r.top, greaterThanOrEqualTo(0));
                expect(r.right, lessThanOrEqualTo(aspect.canvas.width + .1));
                expect(r.bottom, lessThanOrEqualTo(aspect.canvas.height + .1));
                final restored = LayerExportMapper.fromJson(
                  LayerExportMapper.toJson(l, canvasSize: aspect.canvas),
                  canvasSize: aspect.canvas,
                );
                expect(restored.imageBackground, l.imageBackground);
                expect(restored.text, l.text);
                if (l.type == LayerType.image) {
                  expect(File(l.imageUrl!.substring(6)).existsSync(), isTrue);
                  expect(
                    r.left,
                    greaterThanOrEqualTo(aspect.canvas.width * .06 - .1),
                  );
                  expect(
                    r.right,
                    lessThanOrEqualTo(aspect.canvas.width * .94 + .1),
                  );
                  expect(cleared[i].imageUrl, isNull);
                  final replaced = cleared[i].copyWith(
                    imageUrl: 'asset:assets/snapfit_home_square.jpg',
                  );
                  expect(replaced.imageBackground, l.imageBackground);
                  final target = coverCanvasBaseSize(aspect.cover);
                  expect(
                    replaced.width / target.width,
                    closeTo(l.width / aspect.canvas.width, .0001),
                  );
                  expect(
                    replaced.position.dy / target.height,
                    closeTo(l.position.dy / aspect.canvas.height, .0001),
                  );
                  if (l.id.endsWith('friends_uncropped')) {
                    expect(l.width / l.height, closeTo(1.5, .00001));
                  }
                }
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
                    '${l.id}: text ${painter.height} > ${l.height}: ${l.text}',
                  );
                painter.dispose();
                for (final other in [...texts, ...photos]) {
                  if (other.id != l.id &&
                      r.deflate(.05).overlaps(_rect(other).deflate(.05))) {
                    issues.add('${l.id} overlaps ${other.id}');
                  }
                }
              }
            }
            final empty = editorialPreviewPages(
              volume,
              aspect,
              copy,
              photos: false,
            );
            expect(
              empty
                  .expand((p) => p)
                  .where((l) => l.type == LayerType.image)
                  .every((l) => l.imageUrl == null),
              isTrue,
            );
          }
          expect(issues.toSet(), isEmpty);
        },
      );

      testWidgets('${volume.route}/${aspect.name}: render all 25 pages', (
        tester,
      ) async {
        final pages = editorialPreviewPages(volume, aspect, volume.defaultCopy);
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
          for (final raw in tester.widgetList<RawImage>(
            find.byType(RawImage),
          )) {
            expect(raw.image, isNotNull);
          }
        }
        if (_export)
          await tester.runAsync(() => _exportPages(volume, aspect, images));
        for (final image in images) {
          image.dispose();
        }
        expect(tester.takeException(), isNull);
      });
    }
    for (final viewport in [const Size(390, 844), const Size(844, 390)]) {
      testWidgets(
        '${volume.route}/$viewport: contents, overview and copy editing',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            wrapCreation(EditorialPreview(volume: volume)),
          );
          await tester.pumpAndSettle();
          expect(find.text('무료 · 표지 + 내지 24쪽'), findsOneWidget);
          await tester.tap(find.byTooltip('목차'));
          await tester.pumpAndSettle();
          final end = find.text('23–24 / ${volume.chapters.last}');
          await tester.ensureVisible(end);
          await tester.tap(end);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('creation_document_position')),
            findsOneWidget,
          );
          await tester.tap(find.byTooltip('전체 펼침 보기'));
          await tester.pumpAndSettle();
          expect(find.text('12 / ${volume.chapters.last}'), findsOneWidget);
          await tester.tap(find.byTooltip('책으로 보기'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('문구 편집'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField).first, '새로운 계절');
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
            '새로운 계절',
          );
          await tester.tap(find.byTooltip('문구 편집 닫기'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _exportPages(
  EditorialVolume volume,
  CollectionAspect aspect,
  List<ui.Image> images,
) async {
  final dir = Directory(
    'output/template-preview/${volume.route}/${aspect.name}',
  )..createSync(recursive: true);
  Future<void> save(
    ui.Picture picture,
    int width,
    int height,
    String name,
  ) async {
    final image = await picture.toImage(width, height);
    await File('${dir.path}/$name.png').writeAsBytes(
      (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List(),
    );
    image.dispose();
    picture.dispose();
  }

  for (var i = 0; i < images.length; i += i == 0 ? 1 : 2) {
    final r = ui.PictureRecorder();
    // Each export is the native page renderer, never a separate web approximation.
    final c = Canvas(r);
    c.drawImage(images[i], Offset.zero, Paint());
    if (i > 0)
      c.drawImage(
        images[i + 1],
        Offset(images[i].width.toDouble(), 0),
        Paint(),
      );
    await save(
      r.endRecording(),
      images[i].width * (i == 0 ? 1 : 2),
      images[i].height,
      i == 0 ? 'cover' : 'spread-${(i + 1) ~/ 2}',
    );
  }
  final r = ui.PictureRecorder();
  final canvas = Canvas(r);
  canvas.drawColor(const Color(0xFFE8ECEB), BlendMode.src);
  final height = images[1].height / 2, row = height + 42;
  for (var i = 0; i < 12; i++) {
    final x = 16.0 + (i % 3) * 440, y = 12.0 + (i ~/ 3) * row;
    final text = TextPainter(
      text: TextSpan(
        text: '${i + 1} / ${volume.chapters[i]}',
        style: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 12,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 420);
    text.paint(canvas, Offset(x, y));
    text.dispose();
    for (var side = 0; side < 2; side++) {
      final image = images[i * 2 + side + 1];
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(x + side * 210, y + 22, 210, height),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
  }
  await save(r.endRecording(), 1336, (row * 4 + 12).ceil(), 'all-spreads');
  await File('${dir.path}/document.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(volume.document(aspect)),
  );
}

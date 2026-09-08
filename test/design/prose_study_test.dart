import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/catalog_favorites.dart';
import 'package:snap_fit/core/templates/catalog_favorite_keys.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../../tool/template_studio/prose_study_preview.dart';
import '../../tool/template_studio/prose_comparison.dart';
import '../widget/ai_album_start_step_test.dart'
    show loadCreationFonts, wrapCreation;
import '../widget/studio_decorations_test.dart' show capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    for (final f in [
      ('Eulyoo', 'Eulyoo1945-Regular.ttf'),
      ('BookMyungjo', 'BookkMyungjo_Bold.ttf'),
      ('Cormorant Garamond', 'Cormorant-Regular.ttf'),
    ]) {
      await (FontLoader(
        f.$1,
      )..addFont(rootBundle.load('assets/fonts/${f.$2}'))).load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
  });
  tearDown(() => CatalogFavorites.instance.dispose());
  test('prose becomes the 37th free collection with a complete edition', () {
    expect(bundledCreationTemplates.length, 37);
    expect(bundledCreationTemplates.every((t) => !t.isPremium), true);
    expect(authoredCollections.any((c) => c.id == proseStudyId), true);
    final doc = buildProseStudy(CollectionAspect.square);
    expect(doc['catalogPublishable'], false);
    expect(doc['accessTier'], 'free');
    expect(doc['approvalStatus'], 'accepted-as-free');
    expect(
      templateDocumentPages(buildProseAlbum(CollectionAspect.square)).length,
      25,
    );
    expect(templateDocumentPages(doc).length, 7);
    expect(proseStudyStyles.toSet().length, 6);
  });
  for (final aspect in CollectionAspect.values) {
    test(
      '${aspect.name}: type fits, no collisions, binding and editable roundtrip',
      () {
        final pages = proseStudyPages(aspect), issues = <String>[];
        for (final page in pages.indexed) {
          final cleared = AlbumCreationTemplate.preparePages(
            [page.$2],
            sourceCanvas: aspect.canvas,
            cover: aspect.cover,
          ).single;
          for (final item in page.$2.indexed) {
            final l = item.$2, rect = l.position & Size(l.width, l.height);
            if (rect.left < 0 ||
                rect.top < 0 ||
                rect.right > aspect.canvas.width + .1 ||
                rect.bottom > aspect.canvas.height + .1)
              issues.add('${l.id} bounds $rect');
            final saved = LayerExportMapper.fromJson(
              LayerExportMapper.toJson(l, canvasSize: aspect.canvas),
              canvasSize: aspect.canvas,
            );
            expect(saved.text, l.text);
            if (l.textStyle != null) {
              expect(saved.textStyle!.fontFamily, l.textStyle!.fontFamily);
              expect(saved.textStyle!.fontWeight, l.textStyle!.fontWeight);
              expect(
                saved.textStyle!.fontStyle,
                l.textStyle!.fontStyle ?? FontStyle.normal,
              );
              expect(
                saved.textStyle!.fontSize,
                closeTo(l.textStyle!.fontSize!, 1e-8),
              );
              expect(
                saved.textStyle!.height,
                closeTo(l.textStyle!.height!, 1e-8),
              );
              expect(saved.textStyle!.letterSpacing, 0);
              expect(saved.textStyle!.color, l.textStyle!.color);
            }
            expect(saved.imageUrl, l.imageUrl);
            expect(saved.imageBackground, l.imageBackground);
            expect(saved.textFillMode, l.textFillMode);
            expect(saved.textFillImageUrl, l.textFillImageUrl);
            if (l.type == LayerType.image) {
              expect(cleared[item.$1].imageUrl, isNull);
              if (page.$1 > 0 &&
                  (page.$1.isOdd
                      ? rect.right > aspect.canvas.width * .88
                      : rect.left < aspect.canvas.width * .12))
                issues.add('${l.id} binding');
            }
            if (l.type == LayerType.sticker)
              expect(cleared[item.$1].imageUrl, l.imageUrl);
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
                '${l.id}: ${painter.height} > ${l.height} (${l.text})',
              );
            painter.dispose();
            for (final other in page.$2.where(
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
        expect(issues, isEmpty);
      },
    );
    testWidgets('${aspect.name}: actual renderer exports all seven pages', (
      tester,
    ) async {
      final pages = proseStudyPages(aspect), images = <ui.Image>[];
      (await capture(
        tester,
        Image.asset(proseStudyInk, width: 50, height: 50),
      )).dispose();
      for (final page in pages) {
        images.add(
          await capture(
            tester,
            TemplatePageRenderer(
              layers: page,
              width: 440,
              height: 440 / aspect.canvas.aspectRatio,
              designCanvasSize: aspect.canvas,
              preserveTypography: true,
              showCanvasChrome: false,
            ),
          ),
        );
        for (final raw in tester.widgetList<RawImage>(find.byType(RawImage)))
          expect(raw.image, isNotNull);
      }
      if (const bool.fromEnvironment('EXPORT_PROSE_STUDY'))
        await tester.runAsync(() async {
          final dir = Directory(
            'output/template-preview/prose-study/${aspect.name}',
          );
          await dir.create(recursive: true);
          for (final e in images.indexed)
            await File('${dir.path}/page-${e.$1}.png').writeAsBytes(
              (await e.$2.toByteData(
                format: ui.ImageByteFormat.png,
              ))!.buffer.asUint8List(),
            );
          final w = images.first.width.toDouble(),
              h = images.first.height.toDouble();
          final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
          canvas.drawColor(const Color(0xFFE1E6E5), BlendMode.src);
          for (final e in images.indexed)
            canvas.drawImage(
              e.$2,
              Offset(
                e.$1 == 0 ? 0 : (e.$1 - 1) % 2 * w,
                e.$1 == 0 ? 0 : ((e.$1 - 1) ~/ 2 + 1) * (h + 18),
              ),
              Paint(),
            );
          final picture = recorder.endRecording(),
              contact = await picture.toImage(
                (w * 2).ceil(),
                ((h + 18) * 4).ceil(),
              );
          await File('${dir.path}/contact.png').writeAsBytes(
            (await contact.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          );
          await File('${dir.path}/document.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert(buildProseStudy(aspect)),
          );
          contact.dispose();
          picture.dispose();
        });
      for (final i in images) i.dispose();
    });
  }
  test('editable copy handles names and refuses overflowing type', () {
    expect(proseStudyCopyFits(const ProseStudyCopy()), true);
    expect(
      proseStudyCopyFits(
        const ProseStudyCopy(
          heading: '함께하는',
          keyword: '계절',
          names: '민서와 도윤',
          promise: '너와 나의 속도로\n함께 걷겠습니다.',
          closing: '또 만나, 우리.',
        ),
      ),
      true,
    );
    expect(proseStudyCopyFits(const ProseStudyCopy(keyword: '')), false);
    expect(
      proseStudyCopyFits(
        const ProseStudyCopy(
          heading: '우리가함께보낸아름다운시간',
          keyword: '사랑이라는책',
          names: 'Alex와 서연',
          date: '2026. 10. 17 / 서울',
        ),
      ),
      true,
    );
    expect(
      proseStudyCopyFits(
        ProseStudyCopy(letter: List.filled(40, '긴 편지').join('\n')),
      ),
      false,
    );
  });
  test('revised copy and photo constructions are distinct and editable', () {
    expect(proseStudyTitle, '함께여서 좋은 날');
    for (final aspect in CollectionAspect.values) {
      final pages = proseStudyPages(aspect);
      final text = pages.expand((p) => p).map((l) => l.text ?? '').join('\n');
      expect(text, isNot(contains('우리라는 문장')));
      expect(text, isNot(contains('오래 읽고 싶어')));
      expect(pages[4].where((l) => l.type == LayerType.image).length, 2);
      expect(pages[4].any((l) => l.text == '나란히 앉은 오후'), true);
      expect(
        pages[6].any((l) => l.text?.replaceAll('\n', ' ') == '다음에도, 이렇게.'),
        true,
      );
      final edited = proseStudyPages(
        aspect,
        copy: const ProseStudyCopy(
          promise: '같이 걸었던 길,\n다시 함께 걷고 싶어.',
          closing: '또 만나, 우리.',
        ),
      );
      expect(edited[4].any((l) => l.text == '같이 걸었던 길,\n다시 함께 걷고 싶어.'), true);
      expect(
        edited[6].any((l) => l.text?.replaceAll('\n', ' ') == '또 만나, 우리.'),
        true,
      );
    }
  });
  test(
    'comparison uses the same photo pool and leaves both source documents untouched',
    () {
      for (final aspect in CollectionAspect.values) {
        final freeBefore = jsonEncode(buildProseAlbum(aspect));
        final studyBefore = jsonEncode(buildLuminousEdition(aspect));
        for (
          var spread = 1;
          spread <= luminousEditionInnerPageCount ~/ 2;
          spread++
        ) {
          Set<String?> photos(bool study) =>
              proseComparisonPages(aspect, spread, study: study)
                  .expand((p) => p)
                  .where((l) => l.type == LayerType.image)
                  .map((l) => l.imageUrl)
                  .toSet();
          expect(photos(false), photos(true));
          expect(
            proseComparisonPages(aspect, spread, study: true, photos: false)
                .expand((p) => p)
                .where((l) => l.type == LayerType.image)
                .every((l) => l.imageUrl == null),
            true,
          );
        }
        expect(jsonEncode(buildProseAlbum(aspect)), freeBefore);
        expect(jsonEncode(buildLuminousEdition(aspect)), studyBefore);
      }
    },
  );
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      '$size: copy, style navigation and favorites preserve editing',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(wrapCreation(const ProseStudyPreview()));
        await tester.pumpAndSettle();
        expect(find.text('무료 · 표지 + 내지 24쪽'), findsOneWidget);
        await tester.tap(find.byTooltip('문구 편집'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '함께하는');
        Finder field(String label) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        Future<void> reachField(String label) => tester.scrollUntilVisible(
          field(label),
          150,
          scrollable: find
              .descendant(
                of: find.byType(ProseCopySheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        for (final item in [
          ('4쪽 짧은 기록', '함께 걸었던 오후.'),
          ('24쪽 마무리', '또 만나, 우리.'),
        ]) {
          await reachField(item.$1);
          await tester.pumpAndSettle();
          await tester.enterText(field(item.$1), item.$2);
        }
        await tester.tap(find.byTooltip('문구 적용'));
        await tester.pumpAndSettle();
        expect(find.byType(ProseCopySheet), findsNothing);
        await tester.tap(find.byTooltip('문구 조판'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('패턴으로 쓴 표제 즐겨찾기 추가'));
        await tester.pumpAndSettle();
        expect(
          CatalogFavorites.instance.contains(
            CatalogFavoriteKeys.textStyle('prose-study:cartouche'),
          ),
          true,
        );
        await tester.drag(find.byType(GridView), const Offset(0, -350));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('장면을 여는 문장'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('장면을 여는 문장'));
        await tester.pumpAndSettle();
        expect(find.byType(ProseStyleGallery), findsNothing);
        await tester.tap(find.byTooltip('문구 편집'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '함께하는',
        );
        for (final item in [
          ('4쪽 짧은 기록', '함께 걸었던 오후.'),
          ('24쪽 마무리', '또 만나, 우리.'),
        ]) {
          await reachField(item.$1);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(field(item.$1)).controller!.text,
            item.$2,
          );
        }
        await tester.tap(find.byTooltip('문구 편집 닫기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('무료와 비교'));
        await tester.pumpAndSettle();
        expect(find.byType(ProseComparison), findsOneWidget);
        expect(find.text('무료'), findsOneWidget);
        expect(find.text('새 시안'), findsOneWidget);
        await tester.tap(find.byTooltip('같은 사진으로 비교'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('원본 사진으로 비교'), findsOneWidget);
        await tester.tap(find.text('표지'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1–2'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('비교 사진 숨기기'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('비교 사진 보이기'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('문구 편집'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '함께하는',
        );
        await tester.tap(find.byTooltip('문구 편집 닫기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

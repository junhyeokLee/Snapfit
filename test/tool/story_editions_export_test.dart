import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/shared/widgets/studio_word_art_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import '../unit/story_editions_test.dart' show loadStoryFonts;

void main() {
  testWidgets(
    'export native covers, photo compositions and matching materials',
    (tester) async {
      await loadStoryFonts();
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cache = PaintingBinding.instance.imageCache;
      final maxBytes = cache.maximumSizeBytes;
      cache.maximumSizeBytes = 24 * 1024 * 1024;
      addTearDown(() => cache.maximumSizeBytes = maxBytes);
      const exclusiveOnly = bool.fromEnvironment(
        'EXPORT_EXCLUSIVE_STORY_GALLERY',
      );
      const clubOnly = bool.fromEnvironment('EXPORT_CLUB_STORY_GALLERY');
      const activityOnly = bool.fromEnvironment(
        'EXPORT_ACTIVITY_STORY_GALLERY',
      );
      const categoryMaterials = bool.fromEnvironment(
        'EXPORT_CATEGORY_MATERIAL_GALLERY',
      );
      final selected = categoryMaterials
          ? storyEditions
                .where(
                  (e) => e.qualityRevision == categoryStoryMaterialRevision,
                )
                .toList()
          : activityOnly
          ? activityStoryEditions
          : clubOnly
          ? clubStoryEditions
          : exclusiveOnly
          ? exclusiveStoryEditions
          : storyEditions;
      final output = Directory(
        categoryMaterials
            ? 'output/category-materials-40'
            : activityOnly
            ? 'output/activity-stories-10'
            : clubOnly
            ? 'output/club-stories-10'
            : exclusiveOnly
            ? 'output/exclusive-stories-10'
            : 'output/story-editions-55',
      )..createSync(recursive: true);
      final cards = <Map<String, dynamic>>[];
      Future<void> export(String name, Widget child, Size size) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox.fromSize(size: size, child: child),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final element in find.byType(Image).evaluate().toList()) {
          await tester.runAsync(
            () => precacheImage((element.widget as Image).image, element),
          );
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        for (final image in tester.widgetList<RawImage>(
          find.byType(RawImage),
        )) {
          expect(image.image, isNotNull, reason: name);
        }
        await tester.runAsync(() async {
          final bitmap =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          try {
            final bytes = await bitmap.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '${output.path}/$name.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
          } finally {
            bitmap.dispose();
          }
        });
        expect(
          cache.currentSizeBytes,
          lessThanOrEqualTo(cache.maximumSizeBytes),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(
          cache.liveImageCount,
          0,
          reason: '$name: released image listeners',
        );
        expect(
          cache.pendingImageCount,
          0,
          reason: '$name: no orphaned decoding',
        );
        cache.clear();
      }

      for (final e in selected) {
        final aspect = CollectionAspect.square;
        final pages = templateDocumentPages(storyEditionDocument(e, aspect));
        Widget render(Map<String, dynamic> p) => TemplatePageRenderer(
          layers: DataTemplateEngine.buildLayersFromJson(p, aspect.canvas),
          width: 500,
          height: 500,
          designCanvasSize: aspect.canvas,
          preserveTypography: true,
          imageDecodeWidth: 720,
        );
        await export(
          '${e.id}-cover',
          render(pages.first),
          const Size(500, 500),
        );
        for (final a in [
          if (categoryMaterials) ...[
            CollectionAspect.landscape4x3,
            CollectionAspect.landscape5x4,
          ] else ...[
            CollectionAspect.portrait,
            CollectionAspect.landscape,
          ],
        ]) {
          await export(
            '${e.id}-cover-${a.name}',
            TemplatePageRenderer(
              layers: DataTemplateEngine.buildLayersFromJson(
                storyEditionCover(e, a),
                a.canvas,
              ),
              width: 500,
              height: 500 / a.canvas.aspectRatio,
              designCanvasSize: a.canvas,
              preserveTypography: true,
              imageDecodeWidth: 720,
            ),
            Size(500, 500 / a.canvas.aspectRatio),
          );
        }
        // Find the true stationery spread and text-assembly spread, regardless
        // of the book's narrative order. These are production layers, not CSS.
        for (final role in [
          7,
          4,
          if (clubOnly || activityOnly) ...[2, 8],
          if (activityOnly) ...[5, 6],
          if (categoryMaterials) ...[1, 6],
        ]) {
          final left = pages.indexWhere((p) => p['role'] == 'story-$role');
          await export(
            '${e.id}-spread-$role',
            Row(children: [render(pages[left]), render(pages[left + 1])]),
            const Size(1000, 500),
          );
        }
        final art = studioWordArts.singleWhere((a) => a.id == e.wordArtId);
        await export(
          '${e.id}-materials',
          ColoredBox(
            color: const Color(0xFFF7F5F2),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: StudioDecoration(
                      spec: studioDecorationById(e.paperId)!,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: StudioDecoration(
                      spec: studioDecorationById(e.motifId)!,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: StudioWordArtPreview(art: art)),
                ],
              ),
            ),
          ),
          const Size(1000, 270),
        );
        cards.add({
          'id': e.id,
          'title': e.title,
          'category': e.category,
          'subtitle': e.subtitle,
          'materials': [e.paperLabel, e.motifLabel, '${e.title} 타이틀 조합'],
          'frameMaterials': [
            for (final frame in e.photoFrames)
              pointShopKnownProducts
                  .singleWhere((p) => p.productKey == 'frame:$frame')
                  .title,
          ],
          'productKey': e.productKey,
          'proposedPoints': e.isPremium ? 1800 : 0,
          'isPremium': e.isPremium,
          'includedMaterialKeys': e.includedMaterialKeys,
          'status': e.isPremium ? 'local-design-review' : 'bundled',
          'isActive': false,
        });
      }
      File('${output.path}/manifest.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'revision': categoryMaterials
              ? categoryStoryMaterialRevision
              : activityOnly
              ? activityStoryEditionRevision
              : clubOnly
              ? clubStoryEditionRevision
              : exclusiveOnly
              ? exclusiveStoryEditionRevision
              : storyEditionRevision,
          'templates': cards,
          'templateCount': selected.length,
          'materialCount': selected.length * 3,
          'aspects': categoryMaterials
              ? ['square', 'landscape4x3', 'landscape5x4']
              : ['portrait', 'square', 'landscape'],
          'innerPages': 24,
          'remotePublished': false,
          'printProofVerified': false,
        }),
      );
      final html = File(
        categoryMaterials
            ? 'tool/template_studio/category_materials_gallery.html'
            : activityOnly
            ? 'tool/template_studio/activity_editions_gallery.html'
            : clubOnly
            ? 'tool/template_studio/club_editions_gallery.html'
            : 'tool/template_studio/story_editions_gallery.html',
      ).readAsStringSync();
      File('${output.path}/index.html').writeAsStringSync(
        html
            .replaceAll(
              '스토리 에디션 35',
              exclusiveOnly ? '전용 사진 에디션 10' : '스토리 에디션 45',
            )
            .replaceAll('서른다섯 권', exclusiveOnly ? '열 권' : '마흔다섯 권')
            .replaceAll(
              '7개 주제에 각 5종.',
              exclusiveOnly
                  ? '새로운 2개 주제에 각 5종. 각 책의 사진 5장은 다른 템플릿과 공유하지 않습니다.'
                  : '9개 주제에 각 5종.',
            )
            .replaceAll(
              '일부 미리보기 사진은 생성 샘플이며',
              exclusiveOnly
                  ? '모든 미리보기 사진은 새로 생성한 전용 샘플이며'
                  : '일부 미리보기 사진은 생성 샘플이며',
            )
            .replaceFirst('/*EDITION_DATA*/[]', jsonEncode(cards)),
      );
    },
    skip: !const bool.fromEnvironment('EXPORT_STORY_EDITION_GALLERY'),
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/catalog_preview_assets.g.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import 'package:snap_fit/features/album/presentation/widgets/cover/album_spine_image.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_cover_frame.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';

class _CountedTemplate extends PremiumTemplate {
  _CountedTemplate(PremiumTemplate original)
    : super(
        id: original.id,
        title: original.title,
        coverImageUrl: original.coverImageUrl,
        previewImages: original.previewImages,
        pageCount: original.pageCount,
        userCount: original.userCount,
        documentBuilder: original.documentBuilder,
      );
  int documentReads = 0;
  @override
  String? get templateJson {
    documentReads++;
    return super.templateJson;
  }
}

void main() {
  test('all published catalog artwork has a bounded local thumbnail', () {
    final keys = {
      for (final t in publishedCreationTemplates) 'template:${t.id}',
      for (final s in studioDecorations) 'sticker:${s.id}',
      for (final f in imageFrameStyles.where((f) => f.key.isNotEmpty))
        'frame:${f.key}',
      for (final a in studioWordArts) a.productKey,
    };
    expect(
      catalogPreviewAssets.keys.toSet(),
      keys,
      reason: 'Regenerate catalog thumbnails when publishing artwork.',
    );
    for (final entry in catalogPreviewAssets.entries) {
      final bytes = File(entry.value).readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      final dimension = entry.key.startsWith('template:') ? 660 : 384;
      expect(header.getUint32(16), dimension, reason: entry.key);
      expect(header.getUint32(20), dimension, reason: entry.key);
    }
  });
  testWidgets('paid catalog cover uses its current native layers', (
    tester,
  ) async {
    final t = publishedPremiumTemplates.first;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 180,
          child: CreationCatalogCover(template: t, useThumbnail: true),
        ),
      ),
    );
    final renderer = tester.widget<TemplatePageRenderer>(
      find.byType(TemplatePageRenderer),
    );
    expect(renderer.preserveTypography, isTrue);
    expect(renderer.imageDecodeWidth, inInclusiveRange(128, 1024));
    expect(
      renderer.layers.map((layer) => layer.id),
      ((jsonDecode(t.templateJson!) as Map)['cover']['layers'] as List).map(
        (layer) => layer['id'],
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('paid book wraps current cover and bounds image decoding', (
    tester,
  ) async {
    final template = _CountedTemplate(
      publishedCreationTemplates.firstWhere((t) => t.id == -9501),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 180,
              child: CreationCatalogCover(
                template: template,
                useThumbnail: true,
                showBookMaterial: true,
              ),
            ),
          ),
        ),
      ),
    );
    final renderers = tester.widgetList<TemplatePageRenderer>(
      find.byType(TemplatePageRenderer),
    );
    // The front and the narrow binding share the parsed cover, never a second
    // document read or a stale cached bitmap.
    expect(renderers, hasLength(2));
    for (final renderer in renderers) {
      expect(renderer.imageDecodeWidth, inInclusiveRange(128, 1024));
      expect(renderer.preserveTypography, isTrue);
    }
    expect(template.documentReads, 1);
    expect(find.byType(AlbumSpineImage), findsOneWidget);
    final frame = tester.widget<HomeCoverFrame>(find.byType(HomeCoverFrame));
    expect(frame.bindingArtwork, isNotNull);
    expect(frame.showBookDepth, isTrue);
    expect(frame.width / frame.height, 1);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final canvas in [const Size(400, 600), const Size(600, 400)]) {
    testWidgets('book preview keeps the authored canvas $canvas', (
      tester,
    ) async {
      final template = PremiumTemplate(
        id: canvas.width.toInt(),
        title: 'Canvas',
        coverImageUrl: '',
        previewImages: const [],
        pageCount: 24,
        userCount: 0,
        templateJson: jsonEncode({
          'designWidth': canvas.width,
          'designHeight': canvas.height,
          'pages': [
            {
              'layers': [
                {
                  'id': 'title',
                  'type': 'text',
                  'x': .1,
                  'y': .1,
                  'width': .8,
                  'height': .2,
                  'text': 'Canvas',
                  'fontSize': 24,
                },
              ],
            },
          ],
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 180,
                child: CreationCatalogCover(
                  template: template,
                  showBookMaterial: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final frame = tester.widget<HomeCoverFrame>(find.byType(HomeCoverFrame));
      expect(
        frame.width / frame.height,
        closeTo(canvas.width / canvas.height, .001),
      );
      for (final renderer in tester.widgetList<TemplatePageRenderer>(
        find.byType(TemplatePageRenderer),
      )) {
        expect(renderer.designCanvasSize, canvas);
        expect(renderer.showCanvasChrome, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

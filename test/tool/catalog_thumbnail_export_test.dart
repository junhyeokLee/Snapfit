import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/data/catalog_preview.dart';
import 'package:snap_fit/core/templates/frame_preview_photos.dart';
import 'package:snap_fit/core/templates/catalog_preview_assets.g.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_original_preview.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/shared/widgets/studio_word_art_preview.dart';

// flutter test --dart-define=EXPORT_CATALOG=true test/tool/catalog_thumbnail_export_test.dart
void main() {
  testWidgets(
    'export native catalog artwork without rebuilding it on scroll',
    (tester) async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final font in manifest) {
        final loader = FontLoader(font['family'] as String);
        for (final asset in font['fonts'] as List) {
          loader.addFont(rootBundle.load(asset['asset'] as String));
        }
        await loader.load();
      }
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final imageCache = PaintingBinding.instance.imageCache;
      final previousSize = imageCache.maximumSize;
      final previousBytes = imageCache.maximumSizeBytes;
      imageCache.maximumSize = 8;
      imageCache.maximumSizeBytes = 24 * 1024 * 1024;
      addTearDown(() {
        imageCache.clear();
        imageCache.clearLiveImages();
        imageCache.maximumSize = previousSize;
        imageCache.maximumSizeBytes = previousBytes;
        CatalogPreviews.clearCache();
      });
      const materialsOnly = bool.fromEnvironment('EXPORT_MATERIALS_ONLY');
      final selectedIds = const String.fromEnvironment(
        'EXPORT_TEMPLATE_IDS',
      ).split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
      final selectedMaterials = const String.fromEnvironment(
        'EXPORT_MATERIAL_KEYS',
      ).split(',').where((s) => s.isNotEmpty).toSet();
      final partial = selectedIds.isNotEmpty || selectedMaterials.isNotEmpty;
      expect(
        selectedMaterials.difference({
          ...studioDecorations.map((s) => 'sticker:${s.id}'),
          ...imageFrameStyles
              .where((f) => f.key.isNotEmpty)
              .map((f) => 'frame:${f.key}'),
          ...studioWordArts.map((art) => art.productKey),
        }),
        isEmpty,
      );
      expect(
        selectedIds.difference(
          publishedCreationTemplates.map((t) => t.id).toSet(),
        ),
        isEmpty,
      );
      expect(materialsOnly && partial, false);
      final entries = <String, Widget Function()>{
        for (final t in publishedCreationTemplates.where(
          (t) => !materialsOnly && (!partial || selectedIds.contains(t.id)),
        ))
          'template:${t.id}': () =>
              CreationCatalogCover(template: t, useThumbnail: false),
        for (final spec in studioDecorations.where(
          (s) => !partial || selectedMaterials.contains('sticker:${s.id}'),
        ))
          'sticker:${spec.id}': () => MaterialOriginalPreview(
            productKey: 'sticker:${spec.id}',
            child: StudioDecoration(spec: spec, imageDecodeWidth: 768),
          ),
        for (final frame in imageFrameStyles.where(
          (f) =>
              !materialsOnly &&
              f.key.isNotEmpty &&
              (!partial || selectedMaterials.contains('frame:${f.key}')),
        ))
          'frame:${frame.key}': () => ImageFramePreview(
            style: frame,
            child: Image.asset(
              framePreviewPhotos[frame.key]!,
              fit: BoxFit.cover,
              cacheWidth: 768,
            ),
          ),
        for (final art in studioWordArts.where(
          (art) =>
              !materialsOnly &&
              (!partial || selectedMaterials.contains(art.productKey)),
        ))
          art.productKey: () => StudioWordArtPreview(art: art),
      };
      final assets = <String, String>{if (partial) ...catalogPreviewAssets};
      Directory('assets/catalog_thumbnails').createSync(recursive: true);
      for (final entry in entries.entries) {
        final cover = entry.key.startsWith('template:');
        if (cover) {
          final id = int.parse(entry.key.substring('template:'.length));
          final template = publishedCreationTemplateById(id)!;
          // The worker runs outside the widget-test clock. pumpAndSettle can
          // finish while its static loading skeleton is still being shown.
          await tester.runAsync(() async {
            final preview = await CatalogPreviews.request(template);
            expect(preview, isNotNull, reason: entry.key);
            preview!.prepareParts(cover: true);
            expect(preview.cover, isNotEmpty, reason: entry.key);
          });
        }
        final size = cover ? 220.0 : 96.0;
        final boundary = GlobalKey();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, __) => MaterialApp(
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: boundary,
                    child: SizedBox.square(
                      dimension: size,
                      child: entry.value(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (cover) {
          expect(
            find.byKey(
              ValueKey('catalog-cover-skeleton-${entry.key.substring(9)}'),
            ),
            findsNothing,
            reason: 'Never publish a loading placeholder as a book cover.',
          );
        }
        final imageWidgets = tester
            .widgetList<Image>(find.byType(Image))
            .toList();
        await tester.runAsync(() async {
          for (final image in imageWidgets) {
            Object? error;
            await precacheImage(
              image.image,
              boundary.currentContext!,
              onError: (e, _) => error = e,
            );
            if (error != null) throw StateError('${entry.key}: $error');
          }
        });
        await tester.pumpAndSettle();
        for (final raw in tester.widgetList<RawImage>(find.byType(RawImage))) {
          expect(raw.image, isNotNull, reason: entry.key);
        }
        expect(tester.takeException(), isNull, reason: entry.key);
        final stem = entry.key.replaceAll(':', '_');
        var path = 'assets/catalog_thumbnails/$stem.png';
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: cover ? 3 : 4);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final png = bytes!.buffer.asUint8List();
          // These revised originals need a new URL: hosting caches images for
          // an hour, while the editable source ships in the new app entrypoint.
          // Other catalog paths and the stable commerce keys remain untouched.
          if ((cover &&
                  const bool.fromEnvironment(
                    'FINGERPRINT_TEMPLATE_THUMBNAILS',
                  )) ||
              const {
                'phrase:collage-bold-cut',
                'phrase:collage-ticket-label',
                'phrase:collage-hand-note',
                'phrase:collage-diecut',
              }.contains(entry.key)) {
            final fingerprint = sha256.convert(png).toString().substring(0, 12);
            path = 'assets/catalog_thumbnails/$stem.$fingerprint.png';
          }
          File(path).writeAsBytesSync(png);
          image.dispose();
        });
        assets[entry.key] = path;
        await tester.pumpWidget(const SizedBox.shrink());
        imageCache.clear();
        imageCache.clearLiveImages();
        // Progress is useful when regenerating the full catalog.
        debugPrint('Exported: ${entry.key}');
      }
      if (!materialsOnly)
        File(
          'lib/core/templates/catalog_preview_assets.g.dart',
        ).writeAsStringSync(
          '// Generated by test/tool/catalog_thumbnail_export_test.dart. Do not edit.\n'
          'const catalogPreviewAssets = <String, String>{\n'
          '${assets.entries.map((e) => "  '${e.key}': '${e.value}',").join('\n')}\n};\n',
        );
    },
    skip: !const bool.fromEnvironment('EXPORT_CATALOG'),
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

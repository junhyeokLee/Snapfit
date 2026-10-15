import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
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
      const materialsOnly = bool.fromEnvironment('EXPORT_MATERIALS_ONLY');
      final selectedIds = const String.fromEnvironment(
        'EXPORT_TEMPLATE_IDS',
      ).split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
      final partial = selectedIds.isNotEmpty;
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
        for (final spec in partial ? [] : studioDecorations)
          'sticker:${spec.id}': () => MaterialOriginalPreview(
            productKey: 'sticker:${spec.id}',
            child: StudioDecoration(spec: spec, imageDecodeWidth: 768),
          ),
        for (final frame in imageFrameStyles.where(
          (f) => !partial && !materialsOnly && f.key.isNotEmpty,
        ))
          'frame:${frame.key}': () => ImageFramePreview(
            style: frame,
            child: Image.asset(
              framePreviewPhotos[frame.key]!,
              fit: BoxFit.cover,
              cacheWidth: 768,
            ),
          ),
        for (final art in materialsOnly || partial ? [] : studioWordArts)
          art.productKey: () => StudioWordArtPreview(art: art),
      };
      final assets = <String, String>{if (partial) ...catalogPreviewAssets};
      Directory('assets/catalog_thumbnails').createSync(recursive: true);
      for (final entry in entries.entries) {
        final cover = entry.key.startsWith('template:');
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
        final path =
            'assets/catalog_thumbnails/${entry.key.replaceAll(':', '_')}.png';
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: cover ? 3 : 4);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        assets[entry.key] = path;
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

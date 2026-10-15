import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/catalog_preview_assets.g.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../widget/ai_album_start_step_test.dart' show loadCreationFonts;
import '../widget/studio_decorations_test.dart' show capture;

const _export = bool.fromEnvironment('EXPORT_COVER_REVIEW');

Future<void> _sheet(
  String path,
  List<(String, ui.Image)> entries, {
  int columns = 6,
}) async {
  const tile = 240.0;
  const row = 285.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawColor(const Color(0xFFE9EEEB), BlendMode.src);
  for (final entry in entries.indexed) {
    final x = 16.0 + entry.$1 % columns * (tile + 16);
    final y = 16.0 + entry.$1 ~/ columns * row;
    final image = entry.$2.$2;
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dest = Rect.fromLTWH(x, y, tile, tile);
    final fitted = applyBoxFit(BoxFit.contain, source.size, dest.size);
    canvas.drawImageRect(
      image,
      source,
      Alignment.center.inscribe(fitted.destination, dest),
      Paint(),
    );
    final label = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: entry.$2.$1,
        style: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 12,
          color: Color(0xFF26382F),
        ),
      ),
    )..layout(maxWidth: tile);
    label.paint(canvas, Offset(x, y + tile + 8));
    label.dispose();
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (16 + columns * (tile + 16)).round(),
    (32 + (entries.length / columns).ceil() * row).round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void main() {
  testWidgets(
    'review every published cover with the native renderer',
    (tester) async {
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
      final covers = {
        for (final aspect in CollectionAspect.values)
          aspect: <(String, ui.Image)>[],
      };
      final audit = <Map<String, dynamic>>[];
      for (final template in publishedCreationTemplates) {
        final doc = jsonDecode(template.templateJson!) as Map<String, dynamic>;
        final cover = doc['cover'] as Map<String, dynamic>;
        final photos = [
          for (final layer in cover['layers'] as List)
            if (layer['type'] == 'image') layer['imageUrl'],
        ];
        audit.add({
          'id': template.id,
          'title': template.title,
          'category': template.category,
          'paid': template.isPremium,
          'photos': photos,
        });
        for (final aspect in CollectionAspect.values) {
          final variant = doc['variants'][aspect.name] as Map<String, dynamic>;
          final image = await capture(
            tester,
            TemplatePageRenderer(
              layers: DataTemplateEngine.buildLayersFromJson(
                variant['cover'],
                aspect.canvas,
              ),
              width: 240,
              height: 240 / aspect.canvas.aspectRatio,
              designCanvasSize: aspect.canvas,
              preserveTypography: true,
              showCanvasChrome: false,
            ),
          );
          covers[aspect]!.add((
            '${template.id} ${template.isPremium ? '유료' : '무료'} / ${template.title}',
            image,
          ));
          if (_export) {
            await tester.runAsync(() async {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                  'output/settings-template-qa/covers/template_${template.id}-${aspect.name}.png',
                )
                ..parent.createSync(recursive: true)
                ..writeAsBytesSync(bytes!.buffer.asUint8List());
            });
          }
        }
      }
      expect(audit, hasLength(51));
      if (_export) {
        await tester.runAsync(() async {
          for (final aspect in CollectionAspect.values) {
            await _sheet(
              'output/settings-template-qa/cover-diversity-${aspect.name}.png',
              covers[aspect]!,
            );
          }
          await _sheet(
            'output/settings-template-qa/cover-diversity.png',
            covers[CollectionAspect.square]!,
          );
          const refinedIds = {-9301, -9302, -9303, -9403, -9414};
          await _sheet('output/settings-template-qa/refined-free-covers.png', [
            for (final entry in covers[CollectionAspect.square]!.indexed)
              if (refinedIds.contains(publishedCreationTemplates[entry.$1].id))
                entry.$2,
          ], columns: 5);
          final cached = <(String, ui.Image)>[];
          for (final template in publishedCreationTemplates) {
            final path = catalogPreviewAssets['template:${template.id}']!;
            final codec = await ui.instantiateImageCodec(
              File(path).readAsBytesSync(),
              targetWidth: 240,
            );
            cached.add((
              '${template.id} / ${template.title}',
              (await codec.getNextFrame()).image,
            ));
            codec.dispose();
          }
          await _sheet(
            'output/settings-template-qa/catalog-list-covers.png',
            cached,
          );
          for (final entry in cached) entry.$2.dispose();
          File(
            'output/settings-template-qa/cover-inventory.json',
          ).writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(audit),
          );
          final paths = [
            for (final dir in [
              'assets/templates/original_editorial/images',
              'assets/frame_preview',
              'assets/templates/soft_babybook/images/approved_stock',
              'assets/templates/jeju_travel/images/approved_stock',
            ])
              ...Directory(dir)
                  .listSync()
                  .whereType<File>()
                  .where((f) => RegExp(r'\.(png|jpg)$').hasMatch(f.path))
                  .map((f) => f.path),
          ]..sort();
          final photos = <(String, ui.Image)>[];
          for (final path in paths) {
            final codec = await ui.instantiateImageCodec(
              File(path).readAsBytesSync(),
              targetWidth: 240,
            );
            final image = (await codec.getNextFrame()).image;
            photos.add((path.split('/').last, image));
            codec.dispose();
          }
          await _sheet(
            'output/settings-template-qa/photo-inventory.png',
            photos,
          );
          for (final photo in photos) photo.$2.dispose();
        });
      }
      for (final cover in covers.values.expand((v) => v)) cover.$2.dispose();
    },
    skip: !_export,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

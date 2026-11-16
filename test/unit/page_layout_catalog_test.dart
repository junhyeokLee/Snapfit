import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/page_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

const _legacyIds = {
  'basic',
  'collage',
  'focus',
  'journey',
  'grid_mosaic',
  'cinematic',
  'full_single',
  'full_duo_vertical',
  'full_duo_horizontal',
  'full_triple_strip',
  'full_triple_columns',
  'full_four_grid',
};

Rect _rect(PageTemplateSlot slot) =>
    Rect.fromLTWH(slot.left, slot.top, slot.width, slot.height);

// Frozen original arrangements: adding choices must not change an existing
// favorite's photo order, crop frames, spacing or background.
Map<String, List<Rect>> _legacyGeometry() {
  const m = .016;
  const half = (1 - m * 3) / 2;
  const third = (1 - m * 4) / 3;
  final four = [
    for (var row = 0; row < 2; row++)
      for (var col = 0; col < 2; col++)
        Rect.fromLTWH(m + (m + half) * col, m + (m + half) * row, half, half),
  ];
  return {
    'basic': [
      const Rect.fromLTWH(m, m, 1 - m * 2, 2 / 3 - m * 1.5),
      const Rect.fromLTWH(m, 2 / 3 + m * .5, half, 1 / 3 - m * 1.5),
      const Rect.fromLTWH(m * 2 + half, 2 / 3 + m * .5, half, 1 / 3 - m * 1.5),
    ],
    'collage': four,
    'focus': [
      const Rect.fromLTWH(m, m, 1 - m * 2, 2 / 3 - m * 1.5),
      for (var col = 0; col < 3; col++)
        Rect.fromLTWH(
          m + (m + third) * col,
          2 / 3 + m * .5,
          third,
          1 / 3 - m * 1.5,
        ),
    ],
    'journey': [
      const Rect.fromLTWH(m, m, 1 - m * 2, .38 - m * 1.5),
      for (var col = 0; col < 5; col++)
        Rect.fromLTWH(
          m + (m + (1 - m * 6) / 5) * col,
          .38 + m * .5,
          (1 - m * 6) / 5,
          .62 - m * 1.5,
        ),
    ],
    'grid_mosaic': [
      for (var row = 0; row < 3; row++)
        for (var col = 0; col < 3; col++)
          Rect.fromLTWH(
            m + (m + third) * col,
            m + (m + third) * row,
            third,
            third,
          ),
    ],
    'cinematic': [
      const Rect.fromLTWH(m, m, 1 - m * 2, .55 - m * 1.5),
      const Rect.fromLTWH(m, .55 + m * .5, half, .45 - m * 1.5),
      const Rect.fromLTWH(m * 2 + half, .55 + m * .5, half, .45 - m * 1.5),
    ],
    'full_single': [const Rect.fromLTWH(m, m, 1 - m * 2, 1 - m * 2)],
    'full_duo_vertical': [
      const Rect.fromLTWH(m, m, half, 1 - m * 2),
      const Rect.fromLTWH(m * 2 + half, m, half, 1 - m * 2),
    ],
    'full_duo_horizontal': [
      const Rect.fromLTWH(m, m, 1 - m * 2, half),
      const Rect.fromLTWH(m, m * 2 + half, 1 - m * 2, half),
    ],
    'full_triple_strip': [
      for (var row = 0; row < 3; row++)
        Rect.fromLTWH(m, m + (m + third) * row, 1 - m * 2, third),
    ],
    'full_triple_columns': [
      for (var col = 0; col < 3; col++)
        Rect.fromLTWH(m + (m + third) * col, m, third, 1 - m * 2),
    ],
    'full_four_grid': four,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))).load();
  });

  test(
    'all 36 choices have stable unique IDs and useful photo-count coverage',
    () {
      final templates = pageTemplates;
      expect(templates, hasLength(36));
      expect(templates.map((template) => template.id).toSet(), hasLength(36));
      expect(templates.map((template) => template.name).toSet(), hasLength(36));
      expect(
        templates.where((template) => !_legacyIds.contains(template.id)),
        hasLength(24),
      );
      for (var count = 1; count <= 9; count++) {
        expect(
          templates.where((template) => template.photoCount == count),
          isNotEmpty,
          reason: '$count photos',
        );
      }
      for (final category in PageLayoutCategory.values) {
        expect(
          templates.where((template) => template.category == category).length,
          greaterThanOrEqualTo(5),
        );
        expect(category.label.trim(), isNotEmpty);
      }
      for (final template in templates) {
        expect(pageTemplateById(template.id)?.name, template.name);
        expect(template.description.trim(), isNotEmpty, reason: template.id);
        expect(template.photoCount + template.textCount, template.slots.length);
      }
      expect(pageTemplateById('not-a-layout'), isNull);
    },
  );

  test('legacy IDs retain exact photo geometry and backgrounds', () {
    const backgrounds = {
      'basic': 0xFFFFFBF5,
      'collage': 0xFFF8F5EF,
      'focus': 0xFFFFF8F0,
      'journey': 0xFFF7FBFF,
      'grid_mosaic': 0xFFFAF8FF,
      'cinematic': 0xFFF4F5F7,
      'full_single': 0xFFFFFFFF,
      'full_duo_vertical': 0xFFF7FBF7,
      'full_duo_horizontal': 0xFFFFFAF4,
      'full_triple_strip': 0xFFF7FBFF,
      'full_triple_columns': 0xFFFAF7FF,
      'full_four_grid': 0xFFF8F8F8,
    };
    for (final entry in _legacyGeometry().entries) {
      final template = pageTemplateById(entry.key)!;
      expect(template.backgroundColor.toARGB32(), backgrounds[entry.key]);
      expect(template.slots, hasLength(entry.value.length));
      for (var i = 0; i < entry.value.length; i++) {
        final slot = template.slots[i];
        final expected = entry.value[i];
        expect(slot.type, 'image');
        expect(slot.rotation, 0);
        expect(slot.left, closeTo(expected.left, 1e-9));
        expect(slot.top, closeTo(expected.top, 1e-9));
        expect(slot.width, closeTo(expected.width, 1e-9));
        expect(slot.height, closeTo(expected.height, 1e-9));
      }
    }
    expect(pageTemplateById('full_duo_vertical')!.name, contains('나란히'));
    expect(pageTemplateById('full_duo_horizontal')!.name, contains('위아래'));
  });

  test(
    'every frame stays on the page without obscuring another photo or note',
    () {
      for (final template in pageTemplates) {
        for (var i = 0; i < template.slots.length; i++) {
          final slot = template.slots[i];
          final rect = _rect(slot);
          expect(slot.type, isIn(['image', 'text']), reason: template.id);
          expect(slot.rotation, 0, reason: template.id);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(1 + 1e-9), reason: template.id);
          expect(rect.bottom, lessThanOrEqualTo(1 + 1e-9), reason: template.id);
          expect(rect.width, greaterThan(.1), reason: template.id);
          expect(
            rect.height,
            greaterThan(slot.type == 'text' ? .065 : .1),
            reason: template.id,
          );
          for (var j = i + 1; j < template.slots.length; j++) {
            final overlap = rect.intersect(_rect(template.slots[j]));
            expect(
              overlap.width > 1e-9 && overlap.height > 1e-9,
              isFalse,
              reason: '${template.id} slots $i/$j',
            );
          }
          if (!_legacyIds.contains(template.id)) {
            expect(
              slot.imageBackground,
              isNull,
              reason: 'A layout must not require a material entitlement',
            );
            expect(slot.textBackground, isNull);
            expect(slot.imageTemplate, isNull);
          }
        }
      }
    },
  );

  test(
    'the 24 new arrangements are different geometries, not recolored duplicates',
    () {
      final seen = <String>{};
      for (final template in pageTemplates.where(
        (t) => !_legacyIds.contains(t.id),
      )) {
        final fingerprint = template.slots
            .map(
              (slot) => [
                slot.type,
                ...[
                  slot.left,
                  slot.top,
                  slot.width,
                  slot.height,
                ].map((value) => value.toStringAsFixed(6)),
              ].join(','),
            )
            .join(';');
        expect(seen.add(fingerprint), isTrue, reason: template.id);
      }
    },
  );

  for (final canvas in [
    const Size(500, 375),
    const Size(500, 500),
    const Size(500, 500 / .75),
  ]) {
    test(
      'all arrangements preserve frames, text and provenance through save at $canvas',
      () {
        for (final isCover in [false, true]) {
          for (final template in pageTemplates) {
            final page = const AlbumEditorService().createPageFromTemplate(
              template: template,
              index: isCover ? 0 : 1,
              canvasSize: canvas,
              isCover: isCover,
            );
            expect(page.layers, hasLength(template.slots.length));
            expect(page.backgroundColor, template.backgroundColor.toARGB32());
            for (final layer in page.layers) {
              expect(layer.isTemplateContent, isTrue);
              expect(layer.hasImageSource, isFalse);
              expect(layer.position.dx, greaterThanOrEqualTo(0));
              expect(layer.position.dy, greaterThanOrEqualTo(0));
              expect(
                layer.position.dx + layer.width,
                lessThanOrEqualTo(canvas.width + 1e-7),
              );
              expect(
                layer.position.dy + layer.height,
                lessThanOrEqualTo(canvas.height + 1e-7),
              );
              final restored = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(
                  layer,
                  canvasSize: canvas,
                  isCover: isCover,
                ),
                canvasSize: canvas,
                isCover: isCover,
              );
              expect(restored.position.dx, closeTo(layer.position.dx, 1e-7));
              expect(restored.position.dy, closeTo(layer.position.dy, 1e-7));
              expect(restored.width, closeTo(layer.width, 1e-7));
              expect(restored.height, closeTo(layer.height, 1e-7));
              expect(restored.text, layer.text);
              expect(
                restored.textStyle?.fontSize,
                layer.textStyle?.fontSize == null
                    ? isNull
                    : closeTo(layer.textStyle!.fontSize!, 1e-7),
              );
              expect(restored.isTemplateContent, isTrue);
            }
          }
        }
      },
    );

    test(
      'Korean layout prompts fit their frames with the actual album body font at $canvas',
      () {
        for (final template in pageTemplates) {
          final page = const AlbumEditorService().createPageFromTemplate(
            template: template,
            index: 1,
            canvasSize: canvas,
          );
          for (final layer in page.layers.where(
            (layer) => layer.type == LayerType.text,
          )) {
            final painter = TextPainter(
              text: TextSpan(
                text: layer.text,
                style: layer.textStyle!.copyWith(fontFamily: 'NotoSans'),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: layer.width);
            expect(layer.text!.trim(), isNotEmpty);
            expect(
              painter.height,
              lessThanOrEqualTo(layer.height + .01),
              reason: '${template.id}: ${layer.text}',
            );
            for (final line in painter.computeLineMetrics()) {
              expect(
                line.width,
                lessThanOrEqualTo(layer.width + .01),
                reason: template.id,
              );
            }
            painter.dispose();
          }
        }
      },
    );
  }
}

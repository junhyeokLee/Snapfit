import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export native spread contact sheet and material inventory', () async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    const size = Size(1400, 1640);
    final recorder = ui.PictureRecorder();
    // The proof is assembled from native output, not a separate HTML recreation.
    final c = Canvas(recorder);
    c.drawColor(const Color(0xFFF1F5F3), BlendMode.src);
    void text(String value, Offset at, double fontSize, Color color) {
      final p = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontSize: fontSize,
            color: color,
          ),
        ),
      )..layout(maxWidth: 1300);
      p.paint(c, at);
      p.dispose();
    }

    text(
      'SNAPFIT / LAYERED ATELIER',
      const Offset(40, 28),
      17,
      const Color(0xFF557568),
    );
    text(
      '주제마다 다르게 편집한 일곱 권',
      const Offset(40, 61),
      29,
      const Color(0xFF203A2F),
    );
    final books = <Map<String, dynamic>>[];
    for (final entry in AtelierEdition.values.indexed) {
      final e = entry.$2, column = entry.$1 % 2, row = entry.$1 ~/ 2;
      final offset = Offset(40 + column * 680, 130 + row * 365);
      final bytes = File(
        'output/premium-atelier-qa/${e.id}-square-1.png',
      ).readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      c.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        offset & const Size(640, 320),
        Paint()..filterQuality = FilterQuality.high,
      );
      image.dispose();
      codec.dispose();
      text(
        '${e.category} / ${e.title}',
        offset + const Offset(0, 326),
        18,
        const Color(0xFF203A2F),
      );
      final materials = templateVisualMaterialKeys(e.catalogDocument()).toList()
        ..sort();
      books.add({
        'id': e.id,
        'title': e.title,
        'innerPages': 32,
        'materialKeys': materials,
        'newKit': atelierLayeredMaterialKits[e.id],
        'allThreeRatios': true,
      });
    }
    text(
      '종이 · 절개 매트 · 겹침 바인딩',
      const Offset(720, 1280),
      23,
      const Color(0xFF203A2F),
    );
    text(
      '새 구조 소재 21종 / 기본 종이 7종 무료',
      const Offset(720, 1330),
      17,
      const Color(0xFF557568),
    );
    text(
      '장식 띠 100P · 포토 매트 200P 제안',
      const Offset(720, 1370),
      17,
      const Color(0xFF557568),
    );
    text(
      '기존 투명 오브젝트 7종 / 300P 제안',
      const Offset(720, 1410),
      17,
      const Color(0xFF557568),
    );
    text(
      '디자인 검수 중 · 실제 유료 판매 비활성',
      const Offset(720, 1470),
      16,
      const Color(0xFF855D56),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      'output/premium-atelier-qa/layered-overview.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    File('output/premium-atelier-qa/layered-review.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'revision': '2026-10-16-layered-atelier',
        'nativeRenderer': true,
        'approvedByOwner': false,
        'competitorSuperiorityValidated': false,
        'newStructuralMaterials': 21,
        'freeStructuralMaterials': 7,
        'proposedMaterialPrices': atelierEditionMaterialPrices,
        'books': books,
      }),
    );
  }, skip: !const bool.fromEnvironment('EXPORT_ATELIER_COMPOSITIONS'));
}

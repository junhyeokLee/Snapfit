import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../features/album/domain/entities/layer.dart';

part 'atelier_word_art_catalog.dart';

/// Text and stationery remain separate editable layers, not a flattened image.
class StudioWordArt {
  const StudioWordArt(
    this.id,
    this.label,
    this.text, {
    this.square = false,
    this.canvasSize,
  });

  final String id, label, text;
  final bool square;
  final Size? canvasSize;
  Size get sourceSize =>
      canvasSize ?? (square ? const Size(300, 300) : const Size(500, 192));
  String get insertionValue => 'wordart:$id';
  String get productKey => 'phrase:collage-$id';
  String get favoriteKey => 'textStyle:luminous-edition:$id';

  List<LayerModel> buildLayers(Size canvas) {
    final source = sourceSize;
    final scale = math.min(
      canvas.width * .72 / source.width,
      canvas.height * .52 / source.height,
    );
    final origin = Offset(
      (canvas.width - source.width * scale) / 2,
      (canvas.height - source.height * scale) / 2,
    );
    return _sourceLayers().map((layer) {
      var result = layer.copyWith(
        position: origin + layer.position * scale,
        width: layer.width * scale,
        height: layer.height * scale,
        textStyle: layer.textStyle?.copyWith(
          fontSize: layer.textStyle!.fontSize! * scale,
        ),
      );
      if (id.startsWith('atelier-') && layer.type == LayerType.text) {
        // Font hinting rounds line metrics at the inserted size, not the source size.
        final measure = TextPainter(
          text: TextSpan(text: result.text, style: result.textStyle),
          textDirection: TextDirection.ltr,
          textAlign: result.textAlign ?? TextAlign.center,
        )..layout(maxWidth: result.width);
        final height = measure.height;
        measure.dispose();
        result = result.copyWith(
          position: result.position + Offset(0, (result.height - height) / 2),
          height: height,
        );
      }
      return result;
    }).toList();
  }

  List<LayerModel> previewLayers() => _sourceLayers();

  List<LayerModel> _sourceLayers() {
    if (id.startsWith('atelier-')) return _atelierWordArtLayers(this);
    LayerModel paper(String key, Rect rect) => LayerModel(
      id: '$id-paper',
      type: LayerType.decoration,
      position: rect.topLeft,
      width: rect.width,
      height: rect.height,
      imageBackground: key,
      zIndex: 0,
    );
    LayerModel lettering(
      Rect rect,
      String font,
      double size,
      Color color, {
      String? fill,
    }) {
      final style = TextStyle(
        fontFamily: font,
        fontSize: size,
        height: 1.2,
        color: color,
        letterSpacing: 0,
      );
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width);
      final height = painter.height;
      painter.dispose();
      // A tight text frame aligns the editor's top-aligned text with previews.
      return LayerModel(
        id: '$id-text',
        type: LayerType.text,
        position: Offset(rect.left, rect.center.dy - height / 2),
        width: rect.width,
        height: height,
        text: text,
        textStyle: style,
        textStyleType: TextStyleType.none,
        textFillMode: fill,
        textAlign: TextAlign.center,
        zIndex: 1,
      );
    }

    const ink = Color(0xFF202020);
    const blue = Color(0xFF2451E6);
    const rose = Color(0xFFA42E4A);
    return switch (id) {
      'bold-cut' => [
        lettering(
          const Rect.fromLTWH(28, 54, 444, 84),
          'RiaSans',
          60,
          blue,
          fill: 'papercut',
        ),
      ],
      'ticket-label' => [
        paper('zineTicket', const Rect.fromLTWH(10, 12, 480, 168)),
        lettering(const Rect.fromLTWH(40, 66, 324, 60), 'NotoSans', 24, ink),
      ],
      'hand-note' => [
        paper('zineUnderline', const Rect.fromLTWH(45, 131, 410, 30)),
        lettering(const Rect.fromLTWH(25, 38, 450, 94), 'Yeongwol', 57, ink),
      ],
      'diecut' => [
        lettering(
          const Rect.fromLTWH(30, 50, 440, 92),
          'Samlip',
          42,
          rose,
          fill: 'sticker',
        ),
      ],
      'ribbon' => [
        paper('luminousRibbon', const Rect.fromLTWH(10, 28, 480, 136)),
        lettering(
          const Rect.fromLTWH(64, 66, 372, 60),
          'BookMyungjo',
          40,
          Colors.white,
        ),
      ],
      'seal' => [
        paper('luminousRosette', const Rect.fromLTWH(8, 8, 284, 284)),
        lettering(
          const Rect.fromLTWH(70, 92, 160, 116),
          'BookMyungjo',
          34,
          rose,
        ),
      ],
      _ => [
        lettering(
          const Rect.fromLTWH(26, 50, 448, 92),
          'BookMyungjo',
          64,
          blue,
          fill: 'outline',
        ),
      ],
    };
  }
}

const studioWordArts = [
  StudioWordArt('bold-cut', '볼드 컷아웃', '같이 찍자!'),
  StudioWordArt('ticket-label', '티켓 라벨', '오늘의 기분 : 맑음'),
  StudioWordArt('hand-note', '손글씨 밑줄', '다음 장도 함께'),
  StudioWordArt('diecut', '겹인쇄 스티커', '반짝반짝'),
  StudioWordArt('ribbon', '리본 문구', '오늘도, 네 편!'),
  StudioWordArt('seal', '레이스 메달 문구', '소중한\n우리', square: true),
  StudioWordArt('outline', '아웃라인 명조', '우리의 순간'),
  ...atelierWordArts,
];

StudioWordArt? studioWordArtById(String id) =>
    studioWordArts.where((art) => art.id == id).firstOrNull;

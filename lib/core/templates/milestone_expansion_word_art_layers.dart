part of 'studio_word_art_catalog.dart';

List<LayerModel> _milestoneExpansionWordArtLayers(StudioWordArt art) {
  final e = storyEditionsById[art.id]!;
  final k = e.catalogId.abs() - 9781;
  Color color(String raw) =>
      Color(int.parse('FF${raw.substring(1)}', radix: 16));
  final ink = color(e.ink), accent = color(e.accent);
  final layers = <LayerModel>[];
  void text(
    String value,
    Rect rect,
    double size,
    String font, {
    Color? fill,
    TextAlign align = TextAlign.left,
  }) {
    var fontSize = size;
    late TextPainter painter;
    for (var n = 0; n < 16; n++) {
      final style = TextStyle(
        fontFamily: font,
        fontSize: fontSize,
        height: 1.25,
        color: fill ?? ink,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
      );
      painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout(maxWidth: rect.width);
      if (painter.height <= rect.height + .1 || n == 15) {
        break;
      }
      painter.dispose();
      fontSize *= .94;
    }
    final height = painter.height;
    final style = (painter.text as TextSpan).style!;
    painter.dispose();
    layers.add(
      LayerModel(
        id: '${art.id}-${layers.length}',
        type: LayerType.text,
        position: Offset(rect.left, rect.top + (rect.height - height) / 2),
        width: rect.width,
        height: height,
        zIndex: layers.length,
        text: value,
        textStyle: style,
        textAlign: align,
        isTemplateContent: true,
        textStyleType: TextStyleType.none,
      ),
    );
  }

  void rule(Rect rect, Color fill) => layers.add(
    LayerModel(
      id: '${art.id}-${layers.length}',
      type: LayerType.decoration,
      position: rect.topLeft,
      width: rect.width,
      height: rect.height,
      zIndex: layers.length,
      decorationFillColor: '#${fill.toARGB32().toRadixString(16).substring(2)}',
      isTemplateContent: true,
    ),
  );
  switch (k) {
    case 0:
      text(
        'LITTLE STEPS / BIG APPLAUSE',
        const Rect.fromLTWH(30, 19, 440, 28),
        12,
        'Poppins',
        fill: accent,
        align: TextAlign.center,
      );
      text(
        art.text,
        const Rect.fromLTWH(28, 78, 444, 151),
        54,
        'Samlip',
        align: TextAlign.center,
      );
      rule(const Rect.fromLTWH(172, 248, 156, 7), accent);
      text(
        '이만큼 자란 우리에게',
        const Rect.fromLTWH(30, 276, 440, 29),
        20,
        'NanumPen',
        align: TextAlign.center,
      );
    case 1:
      rule(const Rect.fromLTWH(24, 27, 3, 263), accent);
      text(
        'A HOME JOURNAL',
        const Rect.fromLTWH(48, 20, 422, 30),
        13,
        'Poppins',
        fill: accent,
      );
      text(art.text, const Rect.fromLTWH(48, 75, 422, 152), 51, 'Arita');
      text(
        '열쇠를 돌리며 새 생활을 시작하다',
        const Rect.fromLTWH(48, 272, 422, 30),
        16,
        'BookMyungjo',
      );
    case 2:
      text(
        'BEGIN AGAIN / WORK IN PROGRESS',
        const Rect.fromLTWH(30, 19, 440, 29),
        12,
        'Poppins',
        fill: accent,
      );
      text(art.text, const Rect.fromLTWH(28, 79, 444, 150), 54, 'Tenada');
      for (var n = 0; n < 5; n++)
        rule(
          Rect.fromLTWH(30 + n * 30.0, 251, 21, 5),
          n < 3 ? accent : color(e.tint),
        );
      text(
        '지나온 경험에서 다음의 나로',
        const Rect.fromLTWH(30, 277, 440, 27),
        16,
        'BookMyungjo',
      );
    case 3:
      text(
        'a long chapter, a new morning',
        const Rect.fromLTWH(30, 27, 440, 61),
        29,
        'Cormorant Garamond',
        fill: accent,
      );
      text(art.text, const Rect.fromLTWH(28, 121, 444, 132), 49, 'Eulyoo');
      rule(const Rect.fromLTWH(30, 278, 66, 1), accent);
      text(
        '오래 함께한 날에 보내는 마음',
        const Rect.fromLTWH(113, 267, 357, 29),
        15,
        'BookMyungjo',
      );
    default:
      text(
        'FIRST EXHIBITION / ARCHIVE',
        const Rect.fromLTWH(30, 25, 440, 29),
        12,
        'Raleway',
        fill: accent,
      );
      rule(const Rect.fromLTWH(30, 68, 440, 1), ink.withValues(alpha: .35));
      text(art.text, const Rect.fromLTWH(28, 95, 444, 143), 50, 'BookMyungjo');
      text(
        '처음의 전시를 기록하다',
        const Rect.fromLTWH(30, 278, 440, 27),
        15,
        'BookMyungjo',
      );
  }
  return layers;
}

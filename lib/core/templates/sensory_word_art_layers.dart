part of 'studio_word_art_catalog.dart';

List<LayerModel> _sensoryWordArtLayers(StudioWordArt art) {
  final night = art.id.contains('night');
  final caption = art.id.startsWith('sensory-');
  final ink = night ? const Color(0xFF17243B) : const Color(0xFF493A2D);
  final accent = night ? const Color(0xFF3559D8) : const Color(0xFF936044);
  final result = <LayerModel>[];
  void rule(String id, Rect rect, Color color) => result.add(
    LayerModel(
      id: '${art.id}-$id',
      type: LayerType.decoration,
      position: rect.topLeft,
      width: rect.width,
      height: rect.height,
      zIndex: result.length,
      decorationFillColor:
          '#${color.toARGB32().toRadixString(16).substring(2)}',
    ),
  );
  void text(
    String id,
    String value,
    Rect rect,
    String font,
    double size,
    Color color, {
    TextAlign align = TextAlign.left,
  }) {
    final style = TextStyle(
      fontFamily: font,
      fontSize: size,
      height: 1.20,
      color: color,
      letterSpacing: 0,
    );
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: rect.width);
    final h = painter.height;
    painter.dispose();
    result.add(
      LayerModel(
        id: '${art.id}-$id',
        type: LayerType.text,
        position: Offset(rect.left, rect.center.dy - h / 2),
        width: rect.width,
        height: h,
        text: value,
        textStyle: style,
        textAlign: align,
        textStyleType: TextStyleType.none,
        zIndex: result.length,
        isTemplateContent: true,
      ),
    );
  }

  if (caption) {
    rule('rail', const Rect.fromLTWH(25, 22, 4, 145), accent);
    text(
      'label',
      night ? 'ROUTE / DATE / AFTER HOURS' : 'CAFE NOTES / A SMALL PAUSE',
      const Rect.fromLTWH(48, 20, 420, 25),
      'Poppins',
      12,
      accent,
    );
    text(
      'detail',
      night ? '출발점  —  환승  —  도착점' : '장소 · 날짜 · 다시 찾을 이유',
      const Rect.fromLTWH(48, 140, 420, 28),
      'BookMyungjo',
      15,
      ink,
    );
    text(
      'main',
      art.text,
      const Rect.fromLTWH(46, 60, 420, 65),
      night ? 'Tenada' : 'NanumPen',
      night ? 42 : 57,
      ink,
    );
  } else {
    text(
      'label',
      night ? 'AFTER HOURS / CITY ARCHIVE' : 'A CUP, A LITTLE PAUSE',
      const Rect.fromLTWH(28, 20, 442, 26),
      'Poppins',
      12,
      accent,
    );
    rule('underline', const Rect.fromLTWH(30, 256, 105, 2), accent);
    text(
      'date',
      night ? 'DATE  /  PLACE  /  WALK' : '나의 오후를 천천히 모으다',
      const Rect.fromLTWH(28, 276, 440, 26),
      night ? 'Poppins' : 'BookMyungjo',
      13,
      ink,
    );
    text(
      'main',
      art.text,
      const Rect.fromLTWH(25, 65, 450, 171),
      night ? 'Arirang2' : 'BookMyungjo',
      night ? 65 : 62,
      ink,
    );
  }
  return result;
}

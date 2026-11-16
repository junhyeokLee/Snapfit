part of 'studio_word_art_catalog.dart';

List<LayerModel> _premiumQuartetWordArtLayers(StudioWordArt art) {
  final s = premiumQuartetSpecForMaterial(art.id)!;
  final caption = art.id.endsWith('-caption');
  final h = art.sourceSize.height;
  Color color(String value) =>
      Color(int.parse('FF${value.substring(1)}', radix: 16));
  final layers = <LayerModel>[];
  void rule(Rect rect, String fill) => layers.add(
    LayerModel(
      id: '${art.id}-${layers.length}',
      type: LayerType.decoration,
      position: rect.topLeft,
      width: rect.width,
      height: rect.height,
      zIndex: layers.length,
      decorationFillColor: fill,
      isTemplateContent: true,
    ),
  );
  void text(
    String value,
    Rect rect,
    String font,
    double size,
    String fill,
    TextAlign align,
  ) {
    final maxLines = value.split('\n').length;
    TextStyle style;
    double height;
    for (var n = 0; ; n++) {
      style = TextStyle(
        fontFamily: font,
        fontSize: size,
        color: color(fill),
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.3,
      );
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout(maxWidth: rect.width - 1);
      height = painter.height + 1;
      final fits =
          height <= rect.height &&
          painter.computeLineMetrics().length <= maxLines;
      painter.dispose();
      if (fits || n == 60) break;
      size *= .95;
    }
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
        textStyleType: TextStyleType.none,
        isTemplateContent: true,
      ),
    );
  }

  final mode = s.style % 8;
  final align = mode == 0 || mode == 3 || mode == 6
      ? TextAlign.center
      : TextAlign.left;
  if (mode == 1 || mode == 5) rule(Rect.fromLTWH(22, 30, 5, h - 60), s.accent);
  if (mode == 2 || mode == 6) {
    rule(const Rect.fromLTWH(32, 24, 64, 3), s.accent);
    rule(Rect.fromLTWH(404, h - 28, 64, 3), s.accent);
  }
  if (mode == 3 || mode == 7) {
    rule(Rect.fromLTWH(32, h - 22, 436, 1.2), s.accent);
    rule(const Rect.fromLTWH(32, 20, 436, 1.2), s.accent);
  }
  text(
    caption ? s.phrase2 : s.headline,
    Rect.fromLTWH(42, caption ? 25 : 52, 416, caption ? 140 : 192),
    caption ? (s.style.isEven ? s.font : 'BookMyungjo') : s.font,
    caption ? 48 : 66,
    s.ink,
    align,
  );
  text(
    caption
        ? s.category
        : storyEditionsById[s.id]!.englishTitle.replaceAll('\n', ' '),
    Rect.fromLTWH(42, h - 47, 416, 25),
    caption ? 'BookMyungjo' : s.secondaryFont,
    caption ? 15 : 17,
    s.accent,
    align,
  );
  return layers;
}

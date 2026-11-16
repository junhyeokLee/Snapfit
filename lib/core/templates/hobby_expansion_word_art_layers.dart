part of 'studio_word_art_catalog.dart';

/// Distinct native lettering assemblies: every word remains independently editable.
List<LayerModel> _hobbyExpansionWordArtLayers(StudioWordArt art) {
  final e = storyEditionsById[art.id]!;
  final spec = hobbyExpansionSpecs[e.id]!;
  final mode = e.coverStyle - 40;
  Color color(String hex) =>
      Color(int.parse('FF${hex.substring(1)}', radix: 16));
  final ink = color(e.ink);
  final accent = color(e.accent);
  final layers = <LayerModel>[];
  void text(
    String value,
    Rect region,
    double fontSize,
    String font, {
    TextAlign align = TextAlign.left,
    Color? fill,
  }) {
    TextStyle style() => TextStyle(
      fontFamily: font,
      fontSize: fontSize,
      height: 1.22,
      fontWeight: FontWeight.w400,
      color: fill ?? ink,
      letterSpacing: 0,
    );
    var size = Size.zero;
    for (var pass = 0; pass < 36; pass++) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style()),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: region.width);
      size = painter.size;
      final fits =
          size.height <= region.height - 1 &&
          painter.computeLineMetrics().every(
            (line) => line.width <= region.width + .1,
          );
      painter.dispose();
      if (fits) break;
      fontSize *= .94;
    }
    layers.add(
      LayerModel(
        id: '${e.id}-lettering-${layers.length}',
        type: LayerType.text,
        position: Offset(
          region.left,
          region.top + (region.height - size.height) / 2,
        ),
        width: region.width,
        height: size.height + .5,
        zIndex: layers.length,
        text: value,
        textStyle: style(),
        textAlign: align,
        isTemplateContent: true,
        textStyleType: TextStyleType.none,
      ),
    );
  }

  void rule(Rect region, {Color? fill}) => layers.add(
    LayerModel(
      id: '${e.id}-lettering-${layers.length}',
      type: LayerType.decoration,
      position: region.topLeft,
      width: region.width,
      height: region.height,
      zIndex: layers.length,
      decorationFillColor:
          '#${(fill ?? accent).toARGB32().toRadixString(16).substring(2)}',
      isTemplateContent: true,
    ),
  );
  switch (mode) {
    case 0: // Potter's broad title and a narrow specimen index.
      text(art.text, const Rect.fromLTWH(28, 55, 340, 177), 61, spec.font);
      text(
        e.englishTitle.toUpperCase(),
        const Rect.fromLTWH(378, 72, 95, 130),
        18,
        'Poppins',
        fill: accent,
      );
      rule(const Rect.fromLTWH(375, 65, 1.4, 157));
      text(
        spec.phrase,
        const Rect.fromLTWH(30, 266, 440, 30),
        15,
        'BookMyungjo',
      );
    case 1: // A centered herbarium label with room around each line.
      text(
        e.englishTitle.replaceAll('\n', ' '),
        const Rect.fromLTWH(30, 18, 440, 36),
        25,
        'Cormorant Garamond',
        align: TextAlign.center,
        fill: accent,
      );
      text(
        art.text,
        const Rect.fromLTWH(35, 76, 430, 164),
        62,
        spec.font,
        align: TextAlign.center,
      );
      rule(const Rect.fromLTWH(215, 259, 70, 1.1));
      text(
        spec.phrase,
        const Rect.fromLTWH(30, 276, 440, 28),
        14,
        'BookMyungjo',
        align: TextAlign.center,
      );
    case 2: // Camera contact-sheet index, dense type only in the top third.
      rule(const Rect.fromLTWH(27, 22, 17, 15));
      text(
        '35 MM / PERSONAL CONTACTS',
        const Rect.fromLTWH(58, 17, 410, 30),
        16,
        'Poppins',
        fill: accent,
      );
      text(art.text, const Rect.fromLTWH(28, 72, 444, 153), 62, spec.font);
      rule(const Rect.fromLTWH(29, 244, 442, 1.3));
      text(
        spec.phrase,
        const Rect.fromLTWH(29, 268, 442, 31),
        16,
        'BookMyungjo',
      );
    case 3: // Friendly bakery lettering with a recipe-style lower label.
      text(
        e.englishTitle.replaceAll('\n', ' '),
        const Rect.fromLTWH(30, 18, 440, 40),
        27,
        'Cormorant Garamond',
        align: TextAlign.center,
        fill: accent,
      );
      text(
        art.text,
        const Rect.fromLTWH(28, 69, 444, 172),
        62,
        spec.font,
        align: TextAlign.center,
      );
      rule(const Rect.fromLTWH(150, 260, 200, 1.3));
      text(
        spec.phrase,
        const Rect.fromLTWH(30, 278, 440, 26),
        14,
        'BookMyungjo',
        align: TextAlign.center,
      );
    case 4: // Handwritten knitting title, a small woven line below.
      text(
        art.text,
        const Rect.fromLTWH(25, 39, 450, 196),
        86,
        spec.font,
        align: TextAlign.center,
      );
      for (var n = 0; n < 12; n++)
        rule(Rect.fromLTWH(88 + n * 28, 254 + n % 2 * 4, 18, 1.3));
      text(
        spec.phrase,
        const Rect.fromLTWH(30, 281, 440, 25),
        14,
        'BookMyungjo',
        align: TextAlign.center,
      );
    case 5: // Performance programme: title, separate tempo and final note.
      text(
        'PRACTICE / REPEAT / LISTEN',
        const Rect.fromLTWH(28, 19, 444, 28),
        15,
        'Poppins',
        fill: accent,
      );
      text(art.text, const Rect.fromLTWH(28, 65, 444, 162), 60, spec.font);
      for (var n = 0; n < 3; n++)
        rule(Rect.fromLTWH(29, 248 + n * 4, 80 + n * 23, 1));
      text(
        spec.phrase,
        const Rect.fromLTWH(29, 276, 442, 29),
        15,
        'BookMyungjo',
      );
    case 6: // Asymmetric collected-paper assembly, each strip still native.
      rule(const Rect.fromLTWH(29, 25, 84, 9));
      text(
        'COLLECTED ON PAPER',
        const Rect.fromLTWH(144, 14, 327, 32),
        17,
        'Poppins',
        fill: accent,
      );
      text(art.text, const Rect.fromLTWH(43, 78, 411, 161), 64, spec.font);
      rule(const Rect.fromLTWH(28, 268, 1.4, 35));
      text(
        spec.phrase,
        const Rect.fromLTWH(45, 271, 427, 28),
        14,
        'BookMyungjo',
      );
    case 7: // Quiet gallery colophon: restrained display with registration rules.
      rule(const Rect.fromLTWH(27, 25, 43, 1));
      rule(const Rect.fromLTWH(27, 25, 1, 30));
      text(
        e.englishTitle.replaceAll('\n', ' / '),
        const Rect.fromLTWH(88, 14, 385, 38),
        22,
        'Cormorant Garamond',
        align: TextAlign.right,
        fill: accent,
      );
      text(art.text, const Rect.fromLTWH(28, 83, 444, 149), 60, spec.font);
      text(
        spec.phrase,
        const Rect.fromLTWH(28, 273, 444, 28),
        14,
        'BookMyungjo',
      );
      rule(const Rect.fromLTWH(429, 306, 43, 1));
    default: // Field notebook: outdoor title and a route-like side mark.
      text(
        'FIELD NOTES / A SLOWER WEEKEND',
        const Rect.fromLTWH(28, 18, 444, 31),
        15,
        'Poppins',
        fill: accent,
      );
      text(art.text, const Rect.fromLTWH(28, 76, 444, 156), 63, spec.font);
      rule(const Rect.fromLTWH(29, 252, 98, 2));
      rule(const Rect.fromLTWH(126, 252, 2, 20));
      text(
        spec.phrase,
        const Rect.fromLTWH(29, 279, 442, 27),
        14,
        'BookMyungjo',
      );
  }
  return layers;
}

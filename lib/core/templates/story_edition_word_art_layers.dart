part of 'studio_word_art_catalog.dart';

/// Independent text, ruling and stationery, shared by insertion and print.
List<LayerModel> _storyEditionWordArtLayers(StudioWordArt art) {
  final e = storyEditionsById[art.id]!;
  Color color(String hex) =>
      Color(int.parse('FF${hex.substring(1)}', radix: 16));
  final result = <LayerModel>[];
  void text(
    String value,
    Rect r,
    double size,
    String font,
    Color ink, {
    TextAlign align = TextAlign.left,
  }) {
    final style = TextStyle(
      fontFamily: font,
      fontSize: size,
      height: 1.25,
      fontWeight: FontWeight.w400,
      color: ink,
      letterSpacing: 0,
    );
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    )..layout(maxWidth: r.width);
    final height = painter.height;
    painter.dispose();
    result.add(
      LayerModel(
        id: '${art.id}-${result.length}',
        type: LayerType.text,
        position: Offset(r.left, r.top + (r.height - height) / 2),
        width: r.width,
        height: height,
        zIndex: result.length,
        text: value,
        textStyle: style,
        textAlign: align,
        isTemplateContent: true,
        textStyleType: TextStyleType.none,
      ),
    );
  }

  void line(Rect rect) => result.add(
    LayerModel(
      id: '${art.id}-${result.length}',
      type: LayerType.decoration,
      position: rect.topLeft,
      width: rect.width,
      height: rect.height,
      decorationFillColor: e.accent,
      zIndex: result.length,
    ),
  );
  final ink = color(e.ink);
  if (e.activity != null) {
    final club = e.category == '동아리';
    text(
      club ? 'OUR CIRCLE / SHARED DAYS' : 'PERSONAL / TRAINING NOTES',
      const Rect.fromLTWH(30, 18, 440, 28),
      12,
      'Poppins',
      color(e.accent),
    );
    if (e.coverStyle == 22 || e.coverStyle == 27) {
      text(
        e.englishTitle,
        const Rect.fromLTWH(30, 64, 440, 157),
        58,
        'Cormorant Garamond',
        ink,
        align: TextAlign.center,
      );
      line(const Rect.fromLTWH(220, 242, 60, 1.5));
      text(
        art.text,
        const Rect.fromLTWH(30, 267, 440, 37),
        23,
        'NotoSans',
        ink,
        align: TextAlign.center,
      );
    } else if (e.coverStyle == 23 || e.coverStyle == 28) {
      line(const Rect.fromLTWH(29, 66, 3, 155));
      text(
        e.englishTitle,
        const Rect.fromLTWH(55, 61, 415, 162),
        56,
        club ? 'Cormorant Garamond' : 'Raleway',
        ink,
      );
      text(
        art.text,
        const Rect.fromLTWH(55, 264, 415, 38),
        23,
        'NotoSans',
        ink,
      );
    } else {
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 61, 444, 166),
        58,
        club ? 'Cormorant Garamond' : 'Raleway',
        ink,
      );
      line(Rect.fromLTWH(30, 245, club ? 115 : 70, 2));
      text(
        art.text,
        const Rect.fromLTWH(30, 268, 440, 37),
        23,
        'NotoSans',
        ink,
      );
    }
    return result;
  }
  switch (e.coverStyle) {
    case 10 || 15:
      text(
        'OUR CLUB / COLLECTED DAYS',
        const Rect.fromLTWH(30, 20, 440, 28),
        13,
        'Poppins',
        color(e.accent),
      );
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 66, 444, 162),
        61,
        'Cormorant Garamond',
        ink,
      );
      line(const Rect.fromLTWH(30, 246, 88, 2));
      text(
        art.text,
        const Rect.fromLTWH(30, 269, 440, 36),
        23,
        'BookMyungjo',
        ink,
      );
    case 11 || 16:
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 22, 444, 172),
        62,
        'Cormorant Garamond',
        ink,
        align: TextAlign.center,
      );
      line(const Rect.fromLTWH(220, 226, 60, 1));
      text(
        art.text,
        const Rect.fromLTWH(28, 264, 444, 36),
        23,
        'BookMyungjo',
        ink,
        align: TextAlign.center,
      );
    case 12 || 17:
      line(const Rect.fromLTWH(28, 29, 3, 258));
      text(
        e.englishTitle,
        const Rect.fromLTWH(57, 26, 413, 172),
        60,
        'Cormorant Garamond',
        ink,
      );
      text(
        art.text,
        const Rect.fromLTWH(58, 254, 412, 39),
        23,
        'NotoSans',
        ink,
      );
    case 13 || 18:
      text(
        art.text,
        const Rect.fromLTWH(28, 23, 444, 44),
        25,
        'BookMyungjo',
        ink,
      );
      line(const Rect.fromLTWH(30, 93, 440, 1));
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 122, 444, 166),
        61,
        'Cormorant Garamond',
        ink,
      );
    case 14 || 19:
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 25, 444, 172),
        58,
        'Cormorant Garamond',
        ink,
      );
      line(const Rect.fromLTWH(30, 226, 110, 2));
      text(
        art.text,
        const Rect.fromLTWH(30, 263, 440, 39),
        23,
        'NotoSans',
        ink,
      );
    case 5:
      text(
        'A PERSONAL RECORD',
        const Rect.fromLTWH(30, 20, 440, 28),
        13,
        'Poppins',
        color(e.accent),
      );
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 69, 444, 152),
        64,
        'Cormorant Garamond',
        ink,
      );
      line(const Rect.fromLTWH(30, 245, 58, 2));
      text(
        art.text,
        const Rect.fromLTWH(30, 270, 440, 34),
        21,
        'NotoSans',
        ink,
      );
    case 6:
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 24, 444, 165),
        63,
        'Cormorant Garamond',
        ink,
        align: TextAlign.center,
      );
      line(const Rect.fromLTWH(219, 224, 62, 1));
      text(
        art.text,
        const Rect.fromLTWH(28, 263, 444, 36),
        23,
        'BookMyungjo',
        ink,
        align: TextAlign.center,
      );
    case 7:
      line(const Rect.fromLTWH(30, 30, 4, 255));
      text(
        e.englishTitle,
        const Rect.fromLTWH(57, 29, 413, 172),
        62,
        'Cormorant Garamond',
        ink,
      );
      text(
        art.text,
        const Rect.fromLTWH(58, 251, 412, 41),
        23,
        'BookMyungjo',
        ink,
      );
    case 8:
      text(
        art.text,
        const Rect.fromLTWH(28, 23, 444, 44),
        24,
        'BookMyungjo',
        ink,
      );
      line(const Rect.fromLTWH(30, 91, 440, 1));
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 121, 444, 170),
        63,
        'Cormorant Garamond',
        ink,
      );
    case 9:
      text(
        e.englishTitle.replaceAll('\n', ' '),
        const Rect.fromLTWH(30, 42, 440, 146),
        58,
        'Cormorant Garamond',
        ink,
      );
      line(const Rect.fromLTWH(30, 222, 440, 1));
      text(
        art.text,
        const Rect.fromLTWH(30, 260, 440, 39),
        23,
        'NotoSans',
        ink,
      );
    case 0:
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 24, 444, 178),
        69,
        'Cormorant Garamond',
        ink,
      );
      line(const Rect.fromLTWH(30, 235, 65, 2));
      text(
        art.text,
        const Rect.fromLTWH(28, 259, 444, 36),
        21,
        'NotoSans',
        ink,
      );
    case 1:
      text(
        art.text,
        const Rect.fromLTWH(28, 24, 444, 65),
        32,
        'BookMyungjo',
        ink,
      );
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 108, 444, 147),
        58,
        'Cormorant Garamond',
        ink,
      );
      line(const Rect.fromLTWH(30, 286, 440, 1));
    case 2:
      text(
        '01 / ${e.category}',
        const Rect.fromLTWH(28, 23, 444, 30),
        14,
        'NotoSans',
        color(e.accent),
      );
      text(
        e.englishTitle.replaceAll('\n', ' '),
        const Rect.fromLTWH(28, 90, 444, 124),
        50,
        'Cormorant Garamond',
        ink,
      );
      text(
        art.text,
        const Rect.fromLTWH(28, 256, 444, 36),
        22,
        'NotoSans',
        ink,
      );
      line(const Rect.fromLTWH(30, 231, 440, 1));
    case 3:
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 30, 444, 165),
        59,
        'Cormorant Garamond',
        ink,
        align: TextAlign.center,
      );
      text(
        art.text,
        const Rect.fromLTWH(28, 255, 444, 38),
        23,
        'BookMyungjo',
        ink,
        align: TextAlign.center,
      );
      line(const Rect.fromLTWH(212, 220, 76, 1));
    default:
      text(
        e.englishTitle,
        const Rect.fromLTWH(28, 25, 444, 176),
        63,
        'Cormorant Garamond',
        ink,
      );
      text(
        art.text,
        const Rect.fromLTWH(28, 252, 444, 40),
        23,
        'BookMyungjo',
        ink,
      );
      line(const Rect.fromLTWH(30, 226, 110, 2));
  }
  return result;
}

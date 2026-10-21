part of 'authored_collections.dart';

const paidImmersiveCoverRevision = 'paid-unframed-photography-2026-10-21';

enum _PaidJacketAnchor {
  upperLeft,
  upperCenter,
  upperRight,
  lowerLeft,
  lowerCenter,
}

class _PaidJacketDirection {
  const _PaidJacketDirection(
    this.ink,
    this.paper,
    this.anchor, {
    this.wideAnchor,
    this.titles = const [1],
    this.eyebrows = const [0],
    this.authors = const [2],
    this.dates = const [3],
    this.subtitles = const [],
    this.width = .88,
    this.wideWidth = .80,
    this.titlePixels = 47,
    this.wideTitlePixels = 38,
    this.secondaryPixels = 34,
    this.wideSecondaryPixels = 28,
    this.titleColor,
    this.eyebrowColor,
    this.footerColor,
    this.dateColor,
    this.wideTitleColor,
    this.wideEyebrowColor,
    this.wideFooterColor,
    this.secondaryColor,
    this.titleTop,
    this.wideTitleTop,
    this.titleX,
  });
  final String ink, paper;
  final _PaidJacketAnchor anchor;
  final _PaidJacketAnchor? wideAnchor;
  final List<int> titles, eyebrows, authors, dates, subtitles;
  final double width, wideWidth, titlePixels, wideTitlePixels;
  final double secondaryPixels, wideSecondaryPixels;
  final String? titleColor, eyebrowColor, footerColor, dateColor;
  final String? wideTitleColor, wideEyebrowColor, wideFooterColor;
  final String? secondaryColor;
  final double? titleTop, wideTitleTop, titleX;
}

// Each placement follows the existing photograph: wall, sky, tabletop or lower
// foreground. The 26 original font families and exact editable strings remain.
const _paidJacketDirections = <String, _PaidJacketDirection>{
  'vow-keepsake': _PaidJacketDirection(
    '#242C2D',
    '#F7F3E9',
    _PaidJacketAnchor.upperLeft,
    width: .49,
    wideWidth: .48,
  ),
  'luminous-edition': _PaidJacketDirection(
    '#294C4C',
    '#F2F1E7',
    _PaidJacketAnchor.upperCenter,
    titlePixels: 52,
    wideTitlePixels: 43,
    titleColor: '#183335',
    footerColor: '#FFFDF5',
  ),
  'daily-cabinet': _PaidJacketDirection(
    '#273E43',
    '#F3EDE3',
    _PaidJacketAnchor.lowerLeft,
    eyebrowColor: '#FFFDF5',
  ),
  'first-year-keepsake': _PaidJacketDirection(
    '#345368',
    '#F4EDE2',
    _PaidJacketAnchor.upperRight,
    titles: [0],
    eyebrows: [1],
    width: .52,
    wideWidth: .48,
  ),
  'table-stories': _PaidJacketDirection(
    '#493A2E',
    '#F7EDDC',
    _PaidJacketAnchor.upperCenter,
    titleColor: '#FFF8EA',
    footerColor: '#FFF8EA',
    dateColor: '#211C17',
  ),
  'two-tickets': _PaidJacketDirection(
    '#3D333B',
    '#F3ECE4',
    _PaidJacketAnchor.lowerLeft,
    titles: [0],
    eyebrows: [1],
    titleColor: '#1C1C1E',
  ),
  'walk-and-nap': _PaidJacketDirection(
    '#562B32',
    '#FAEFE7',
    _PaidJacketAnchor.upperLeft,
    wideAnchor: _PaidJacketAnchor.lowerLeft,
    titles: [0],
    eyebrows: [1],
    width: .43,
    wideWidth: .49,
    titlePixels: 44,
    wideTitlePixels: 36,
    titleColor: '#321D20',
    footerColor: '#FFF8ED',
    wideFooterColor: '#311D22',
  ),
  'silk-vows': _PaidJacketDirection(
    '#404A47',
    '#F5F1E8',
    _PaidJacketAnchor.upperCenter,
    titleColor: '#29332D',
  ),
  'shore-days': _PaidJacketDirection(
    '#24545D',
    '#F1F1E7',
    _PaidJacketAnchor.upperRight,
    titles: [1, 2],
    eyebrows: [],
    authors: [3],
    dates: [0],
    titlePixels: 62,
    wideTitlePixels: 49,
    secondaryPixels: 34,
    wideSecondaryPixels: 28,
    titleColor: '#102C35',
    secondaryColor: '#FFFDF4',
    footerColor: '#FFFDF4',
  ),
  'reading-room': _PaidJacketDirection(
    '#244993',
    '#F2F0E7',
    _PaidJacketAnchor.lowerLeft,
    titleColor: '#10202B',
    eyebrowColor: '#FFFDF5',
    footerColor: '#101D29',
    titlePixels: 32,
    wideTitlePixels: 28,
    titleTop: .58,
    wideTitleTop: .48,
    titleX: .18,
    width: .68,
    wideWidth: .68,
  ),
  'first-wardrobe': _PaidJacketDirection(
    '#3A5145',
    '#F3F0E4',
    _PaidJacketAnchor.upperLeft,
    width: .50,
    wideWidth: .51,
    titlePixels: 44,
    wideTitlePixels: 36,
    titleColor: '#18251C',
    footerColor: '#FFF8EB',
  ),
  'sunday-picnic': _PaidJacketDirection(
    '#70443E',
    '#F8F0DD',
    _PaidJacketAnchor.upperCenter,
    titles: [0, 2],
    eyebrows: [1],
    authors: [],
    dates: [],
    titlePixels: 67,
    wideTitlePixels: 51,
    secondaryPixels: 35,
    wideSecondaryPixels: 28,
    titleColor: '#542C27',
    secondaryColor: '#FFFDF6',
  ),
  'shared-seasons': _PaidJacketDirection(
    '#314A42',
    '#F4EEE3',
    _PaidJacketAnchor.upperLeft,
    width: .53,
    wideWidth: .50,
    titleColor: '#FFF9EB',
    footerColor: '#FFF9EB',
  ),
  'little-companion': _PaidJacketDirection(
    '#153D70',
    '#F4EFE6',
    _PaidJacketAnchor.upperLeft,
    titles: [1],
    subtitles: [2],
    authors: [3],
    dates: [4],
    width: .40,
    wideWidth: .41,
    titlePixels: 44,
    wideTitlePixels: 36,
    footerColor: '#FFFDF7',
  ),
  'night-vows': _PaidJacketDirection(
    '#202C40',
    '#F4F0E8',
    _PaidJacketAnchor.upperLeft,
    authors: [3],
    dates: [2],
    titleColor: '#FFF8ED',
    footerColor: '#FFF8ED',
  ),
  'slow-rail': _PaidJacketDirection(
    '#693A35',
    '#F2EEE6',
    _PaidJacketAnchor.upperLeft,
    authors: [3],
    dates: [2],
    width: .39,
    wideWidth: .34,
    titlePixels: 38,
    wideTitlePixels: 32,
    titleColor: '#2E211B',
    footerColor: '#FFF9EA',
  ),
  'green-hours': _PaidJacketDirection(
    '#294C38',
    '#F4F1E5',
    _PaidJacketAnchor.upperLeft,
    authors: [3],
    dates: [2],
    width: .56,
    wideWidth: .52,
    titleColor: '#111D13',
    footerColor: '#151E14',
  ),
  'first-orbit': _PaidJacketDirection(
    '#34536B',
    '#F6F1E5',
    _PaidJacketAnchor.upperLeft,
    authors: [3],
    dates: [2],
    wideTitlePixels: 35,
    titleColor: '#17313F',
  ),
  'family-recipe-book': _PaidJacketDirection(
    '#79332E',
    '#F7F1E6',
    _PaidJacketAnchor.lowerLeft,
    authors: [3],
    dates: [2],
    titleColor: '#FFF9ED',
    eyebrowColor: '#2D211A',
    footerColor: '#251B14',
  ),
  'private-cinema': _PaidJacketDirection(
    '#592C36',
    '#F1E9DF',
    _PaidJacketAnchor.upperLeft,
    wideAnchor: _PaidJacketAnchor.lowerLeft,
    authors: [3],
    dates: [2],
    width: .64,
    wideWidth: .55,
    titleColor: '#32221C',
    footerColor: '#FFF5E6',
    wideTitleColor: '#FFF5E6',
    wideEyebrowColor: '#32221C',
    titlePixels: 36,
  ),
  'walk-map': _PaidJacketDirection(
    '#345C4F',
    '#F0F2E7',
    _PaidJacketAnchor.upperLeft,
    authors: [3],
    dates: [2],
    width: .60,
    wideWidth: .55,
    titleColor: '#203B30',
    footerColor: '#172920',
  ),
  'city-afterglow': _PaidJacketDirection(
    '#182C32',
    '#EFEBDD',
    _PaidJacketAnchor.upperLeft,
    authors: [],
    dates: [2],
    titlePixels: 49,
    wideTitlePixels: 41,
    titleColor: '#FFF8E8',
    footerColor: '#FFF8E8',
  ),
  'summer-keepsake-box': _PaidJacketDirection(
    '#163E40',
    '#F5EEDD',
    _PaidJacketAnchor.upperLeft,
    titles: [1, 2],
    authors: [],
    dates: [],
    titlePixels: 40,
    wideTitlePixels: 29,
    secondaryPixels: 50,
    wideSecondaryPixels: 38,
    titleColor: '#16373A',
    footerColor: '#173332',
  ),
  'companion-journal': _PaidJacketDirection(
    '#29282D',
    '#F3E8E3',
    _PaidJacketAnchor.upperLeft,
    wideAnchor: _PaidJacketAnchor.upperLeft,
    wideWidth: .34,
    authors: [],
    dates: [],
    titlePixels: 43,
    wideTitlePixels: 38,
    titleColor: '#222129',
    footerColor: '#24202A',
  ),
  'velvet-vow-archive': _PaidJacketDirection(
    '#4C2939',
    '#F3EDE3',
    _PaidJacketAnchor.upperLeft,
    width: .88,
    wideWidth: .88,
    authors: [],
    dates: [],
    titlePixels: 47,
    wideTitlePixels: 37,
    titleColor: '#482737',
    footerColor: '#482737',
  ),
  'little-explorer-book': _PaidJacketDirection(
    '#173B50',
    '#F5EFDE',
    _PaidJacketAnchor.upperLeft,
    width: .38,
    wideWidth: .32,
    authors: [],
    dates: [],
    titlePixels: 40,
    wideTitlePixels: 32,
    titleColor: '#132C37',
    footerColor: '#FFF9EB',
  ),
};

Map<String, dynamic> _refinePaidImmersiveCover(
  String id,
  CollectionAspect aspect,
  Map<String, dynamic> document,
) {
  final direction = _paidJacketDirections[id];
  if (direction == null) return document;
  final before = Map<String, dynamic>.from(document['cover'] as Map);
  final painter = _PaidPhotographicJacket(id, aspect, before, direction);
  painter.paint();
  return {
    ...document,
    'coverRevision': paidImmersiveCoverRevision,
    'cover': {
      ...before,
      'layers': painter.p.layers,
      'coverRevision': paidImmersiveCoverRevision,
      'heroCoverageFraction': 1.0,
      'typographyPanelCoverageFraction': 0.0,
      'coverTypographyTreatment': 'direct-on-photograph',
      'jacketArtDirection': id,
    },
  };
}

class _PaidPhotographicJacket {
  _PaidPhotographicJacket(this.id, this.aspect, this.before, this.direction)
    : p = _Sheet('paid_jacket_$id', aspect, 0, direction.ink) {
    original = (before['layers'] as List)
        .map((l) => Map<String, dynamic>.from(l as Map))
        .toList();
    texts = original.where((l) => l['type'] == 'text').toList();
    photo = original.firstWhere((l) => l['type'] == 'image');
  }
  final String id;
  final CollectionAspect aspect;
  final Map<String, dynamic> before;
  final _PaidJacketDirection direction;
  final _Sheet p;
  late final List<Map<String, dynamic>> original, texts;
  late final Map<String, dynamic> photo;
  double get w => aspect.canvas.width;
  double get h => aspect.canvas.height;
  bool get wide => aspect == CollectionAspect.landscape;
  double get margin => wide ? 25 : 31;
  double get inner => w - margin * 2;
  _PaidJacketAnchor get anchor =>
      wide ? direction.wideAnchor ?? direction.anchor : direction.anchor;
  bool get lower =>
      anchor == _PaidJacketAnchor.lowerLeft ||
      anchor == _PaidJacketAnchor.lowerCenter;
  bool get centered =>
      anchor == _PaidJacketAnchor.upperCenter ||
      anchor == _PaidJacketAnchor.lowerCenter;
  bool get right => anchor == _PaidJacketAnchor.upperRight;
  static Color _color(String hex) =>
      Color(int.parse(hex.replaceFirst('#', '').padLeft(8, 'F'), radix: 16));
  String get titleInk =>
      (wide ? direction.wideTitleColor : null) ??
      direction.titleColor ??
      direction.ink;
  String get eyebrowInk =>
      (wide ? direction.wideEyebrowColor : null) ??
      direction.eyebrowColor ??
      titleInk;
  String get footerInk =>
      (wide ? direction.wideFooterColor : null) ??
      direction.footerColor ??
      titleInk;

  String _value(Map<String, dynamic> layer) {
    final text = layer['text'] as String? ?? '';
    if (id == 'slow-rail' && identical(layer, texts[direction.titles.first])) {
      return text.replaceFirst('느린 열차의', '느린\n열차의');
    }
    return text;
  }

  TextPainter _measure(
    Map<String, dynamic> source,
    double pixels,
    double width,
    double leading,
  ) {
    final style = Map<String, dynamic>.from(source['style'] as Map? ?? {});
    final weight = (style['fontWeight'] as num?)?.toInt() ?? 400;
    final textStyle = TextStyle(
      fontFamily: style['fontFamily'] as String? ?? 'NotoSans',
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      fontSize: pixels,
      height: leading,
      letterSpacing: 0,
    );
    return TextPainter(
      text: TextSpan(text: _value(source), style: textStyle),
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(textStyle, forceStrutHeight: true),
    )..layout(maxWidth: math.max(1, width - 2));
  }

  (double, double, double) _fit(
    Map<String, dynamic> source,
    double width,
    double height,
    double initial,
    double minimum, {
    double leading = 1.18,
  }) {
    var pixels = initial;
    while (true) {
      final painter = _measure(source, pixels, width, leading);
      final actualHeight = painter.height + 2;
      final actualWidth = math.min(
        width,
        math.max(
          2.0,
          painter.computeLineMetrics().fold(
                0.0,
                (maxWidth, line) => math.max(maxWidth, line.width),
              ) +
              3,
        ),
      );
      final fits = actualHeight <= height;
      painter.dispose();
      if (fits || pixels <= minimum) return (pixels, actualWidth, actualHeight);
      pixels = math.max(minimum, pixels * .96);
    }
  }

  void _place(
    Map<String, dynamic> source,
    Rect rect,
    double pixels, {
    String role = 'caption',
    double minimum = 8.5,
    String align = 'left',
    String? color,
    double leading = 1.18,
  }) {
    final style = Map<String, dynamic>.from(source['style'] as Map? ?? {});
    final ink = color ?? titleInk;
    final lightInk = _color(ink).computeLuminance() > .5;
    p.layers.add({
      ...source,
      'text': _value(source),
      if (_value(source) != source['text'])
        'editorialSourceText': source['editorialSourceText'] ?? source['text'],
      'x': rect.left / w,
      'y': rect.top / h,
      'w': rect.width / w,
      'h': rect.height / h,
      'z': p.layers.length,
      'rotation': 0,
      'align': align,
      'typographyRole': role,
      'typographyMinFontSize': minimum,
      'style': {
        ...style,
        'fontSize': pixels,
        'height': leading,
        'color': ink,
        'letterSpacing': 0,
        'shadows': [
          if (lightInk)
            {
              'color': '#66000000',
              'blurRadius': 2.0,
              'offset': {'dx': 0.0, 'dy': .7},
            },
        ],
      },
    });
  }

  void paint() {
    final cropException =
        id == 'summer-keepsake-box' && aspect == CollectionAspect.portrait;
    p.layers.add({
      ...photo,
      'x': 0.0,
      'y': 0.0,
      'w': 1.0,
      'h': 1.0,
      'frame': 'none',
      'rotation': 0,
      'z': p.layers.length,
      if (cropException) ...{
        'sourcePhotoTransform': {
          'imageOffsetRatio': photo['imageOffsetRatio'],
          'imageOffset': photo['imageOffset'],
          'imageZoom': photo['imageZoom'] ?? 1.0,
        },
        'imageOffsetRatio': {'x': .16, 'y': 0.0},
      },
    });
    for (final other in original.where(
      (l) => l['type'] == 'image' && l['id'] != photo['id'],
    )) {
      p.layers.add({...other, 'z': p.layers.length});
    }

    final titleSet = {...direction.titles, ...direction.subtitles};
    final eyeSet = direction.eyebrows.toSet();
    final authorSet = direction.authors.toSet();
    final dateSet = direction.dates.toSet();
    final used = {...titleSet, ...eyeSet, ...authorSet, ...dateSet};
    final bodies = <int>[
      for (var i = 0; i < texts.length; i++)
        if (!used.contains(i)) i,
    ];
    final footer = _footer(bodies, direction.authors, direction.dates);

    final eyes = <(Map<String, dynamic>, double, double, double)>[];
    var eyeHeight = 0.0;
    for (final index in direction.eyebrows) {
      final fit = _fit(texts[index], inner, h * .14, 9.5, 8.5);
      eyes.add((texts[index], fit.$1, fit.$2, fit.$3));
      eyeHeight += fit.$3 + 9;
    }
    final headlines = <(Map<String, dynamic>, double, double, double, bool)>[];
    var headingHeight = 0.0, headingWidth = 0.0;
    final maxWidth = inner * (wide ? direction.wideWidth : direction.width);
    for (final entry in direction.titles.indexed) {
      final index = entry.$2;
      final initial = entry.$1 == 0
          ? (wide ? direction.wideTitlePixels : direction.titlePixels)
          : (wide ? direction.wideSecondaryPixels : direction.secondaryPixels);
      final minimum = wide
          ? 28.0
          : entry.$1 == 0
          ? 32.0
          : 28.0;
      final fit = _fit(
        texts[index],
        maxWidth,
        h * .43,
        initial,
        minimum,
        leading: 1.12,
      );
      headlines.add((texts[index], fit.$1, fit.$2, fit.$3, true));
      headingHeight += fit.$3 + 6;
      headingWidth = math.max(headingWidth, fit.$2);
    }
    for (final index in direction.subtitles) {
      final fit = _fit(
        texts[index],
        maxWidth,
        h * .16,
        wide ? 27 : 30,
        24,
        leading: 1.12,
      );
      headlines.add((texts[index], fit.$1, fit.$2, fit.$3, false));
      headingHeight += fit.$3 + 6;
      headingWidth = math.max(headingWidth, fit.$2);
    }
    final top = wide
        ? direction.wideTitleTop ?? direction.titleTop
        : direction.titleTop;
    var y = top != null
        ? h * top
        : lower
        ? math.max(margin + eyeHeight + 18, footer - headingHeight - 17)
        : margin + eyeHeight + 4;
    final x = direction.titleX != null
        ? w * direction.titleX!
        : centered
        ? (w - headingWidth) / 2
        : right
        ? w - margin - headingWidth
        : margin;
    for (final line in headlines) {
      final offset = centered
          ? (headingWidth - line.$3) / 2
          : right
          ? headingWidth - line.$3
          : 0.0;
      _place(
        line.$1,
        Rect.fromLTWH(x + offset, y, line.$3, line.$4),
        line.$2,
        color:
            direction.titles
                .skip(1)
                .any((index) => identical(texts[index], line.$1))
            ? id == 'sunday-picnic' && aspect == CollectionAspect.portrait
                  ? titleInk
                  : direction.secondaryColor ?? titleInk
            : titleInk,
        role: line.$5 ? 'signature-title' : 'signature-subtitle',
        minimum: line.$5 ? (wide ? 28 : 28) : 24,
        align: centered
            ? 'center'
            : right
            ? 'right'
            : 'left',
        leading: 1.12,
      );
      y += line.$4 + 6;
    }
    var eyeY = margin;
    for (final eye in eyes) {
      final eyeX = centered
          ? (w - eye.$3) / 2
          : right
          ? w - margin - eye.$3
          : margin;
      _place(
        eye.$1,
        Rect.fromLTWH(eyeX, eyeY, eye.$3, eye.$4),
        eye.$2,
        color: eyebrowInk,
        align: centered
            ? 'center'
            : right
            ? 'right'
            : 'left',
      );
      eyeY += eye.$4 + 9;
    }
  }

  double _footer(List<int> bodies, List<int> authors, List<int> dates) {
    final details = <(Map<String, dynamic>, double, double, double)>[];
    var detailHeight = 0.0;
    for (final index in bodies) {
      final fit = _fit(texts[index], inner, h * .25, 11, 11);
      details.add((texts[index], fit.$1, fit.$2, fit.$3));
      detailHeight += fit.$3 + 7;
    }
    final row = <(Map<String, dynamic>, double, double, double, bool)>[];
    var rowHeight = 0.0;
    for (final index in [...authors, ...dates]) {
      final date = dates.contains(index);
      final fit = _fit(
        texts[index],
        inner * .46,
        h * .20,
        date ? 9.5 : 10.5,
        8.5,
      );
      row.add((texts[index], fit.$1, fit.$2, fit.$3, date));
      rowHeight = math.max(rowHeight, fit.$3 + 2);
    }
    var y = h - margin - detailHeight - rowHeight;
    final top = y;
    for (final detail in details) {
      _place(
        detail.$1,
        Rect.fromLTWH(margin, y, detail.$3, detail.$4),
        detail.$2,
        role: 'body',
        minimum: 11,
        color: footerInk,
      );
      y += detail.$4 + 7;
    }
    for (final field in row) {
      _place(
        field.$1,
        Rect.fromLTWH(
          field.$5 ? w - margin - field.$3 : margin,
          y,
          field.$3,
          field.$4,
        ),
        field.$2,
        color: field.$5 ? direction.dateColor ?? footerInk : footerInk,
        align: field.$5 ? 'right' : 'left',
      );
    }
    return top;
  }
}

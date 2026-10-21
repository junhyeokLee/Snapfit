part of 'authored_collections.dart';

const _immersiveFreeCoverRevision = 'open-photographic-type-2026-10-21';

/// A current-catalog jacket only: source documents, saved albums, personal
/// strings and product identities are never rewritten by this presentation.
Map<String, dynamic> _refineFreeImmersiveCover(
  String id,
  CollectionAspect aspect,
  Map<String, dynamic> document,
) {
  if (FreeCollectionVolume.byId(id) == null &&
      !const {
        'lightbound',
        'journey',
        'small-days',
        windAtlasId,
        proseStudyId,
        'alley-afternoon',
        'saturday-together',
        'daily-paw-walk',
        'our-first-promise',
        'little-day-discoveries',
      }.contains(id))
    return document;
  final before = document['cover'] as Map<String, dynamic>;
  final painter = _ImmersiveFreeJacket(id, aspect, before);
  painter.paint();
  return {
    ...document,
    'coverRevision': _immersiveFreeCoverRevision,
    'cover': {
      ...before,
      'layers': painter.p.layers,
      'coverRevision': _immersiveFreeCoverRevision,
      'heroCoverageFraction': 1.0,
      'coverTextTreatment': 'open-photographic-type',
      'typographyPanelCoverageFraction': 0.0,
    },
  };
}

class _ImmersiveFreeJacket {
  _ImmersiveFreeJacket(this.id, this.aspect, this.before) {
    original = (before['layers'] as List)
        .map((l) => Map<String, dynamic>.from(l as Map))
        .toList();
    texts = original.where((l) => l['type'] == 'text').toList();
    hero = original.firstWhere((l) => l['type'] == 'image');
    final title =
        texts
            .where((l) => l['typographyRole'] == 'signature-title')
            .firstOrNull ??
        texts.reduce((a, b) => _font(a) >= _font(b) ? a : b);
    final paper =
        original.where((l) => l['fillColor'] != null).firstOrNull?['fillColor']
            as String? ??
        '#F6F1E7';
    final titleInk = (title['style'] as Map)['color'] as String? ?? '#233A35';
    final candidate = _color(titleInk);
    ink = candidate.computeLuminance() < .16
        ? candidate
        : const Color(0xFF20362F);
    p = _Sheet('immersive_$id', aspect, 0, paper);
  }

  final String id;
  final CollectionAspect aspect;
  final Map<String, dynamic> before;
  late final List<Map<String, dynamic>> original, texts;
  late final Map<String, dynamic> hero;
  late final _Sheet p;
  late final Color ink;
  double get w => aspect.canvas.width;
  double get h => aspect.canvas.height;
  bool get wide => aspect == CollectionAspect.landscape;
  double get margin => wide ? 23 : 27;
  double get inner => w - margin * 2;

  // Portraits with a quiet upper background use it; faces in the upper half of
  // family and baby photographs get a lower, compact title instead.
  bool get upperTitle =>
      !(wide && const {'a-day-with-you', 'our-walking-promise'}.contains(id)) &&
      const {
        'one-fine-film',
        'garden-promise',
        'love-letters',
        'across-the-sea',
        'city-collector',
        'slow-paths',
        'travel-postbox',
        'seasonal-table',
        'taste-archive',
        'better-together',
        'weekend-temperature',
        'across-generations',
        'a-day-with-you',
        'shapes-of-naps',
        'our-walking-promise',
        'our-little-companion',
        'the-kindest-face',
        'journey',
        windAtlasId,
        proseStudyId,
        'alley-afternoon',
        'saturday-together',
        'daily-paw-walk',
        'our-first-promise',
        'seasons-of-love',
        'you-are-spring',
        'our-family-year',
        'our-good-company',
      }.contains(id);
  bool get rightTitle => const {
    'garden-promise',
    'slow-paths',
    'travel-postbox',
    'seasonal-table',
    'weekend-temperature',
    'shapes-of-naps',
    'the-kindest-face',
    windAtlasId,
  }.contains(id);

  static Color _color(String value) =>
      Color(int.parse(value.replaceFirst('#', '').padLeft(8, 'F'), radix: 16));
  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  // Ink follows the photograph's quiet areas, rather than changing its colors
  // with a plate or a scrim. Upper sky/walls and lower furnishings often need
  // different ink on the very same cover.
  Color _inkAt(Rect rect, {bool headline = false}) {
    final upper = rect.center.dy < h * .52;
    final lightOnTop = const {
      'one-fine-film',
      'better-together',
      'collected-by-two',
      'our-walking-promise',
      'saturday-together',
      'daily-paw-walk',
      'taste-archive',
      proseStudyId,
    }.contains(id);
    final lightOnBottom = const {
      'one-fine-film',
      'city-collector',
      'slow-paths',
      'better-together',
      'dates-of-us',
      'collected-by-two',
      proseStudyId,
      windAtlasId,
    }.contains(id);
    final lightFooter = id == 'still-us' && rect.top > h * .79;
    final groomSide =
        id == 'our-vows' && rect.top > h * .79 && rect.center.dx > w * .55;
    final headlineOnDarkSubject =
        headline &&
        (const {'little-footsteps', 'still-us'}.contains(id) ||
            (wide &&
                const {'a-day-with-you', 'our-walking-promise'}.contains(id)));
    final denimFooter =
        !headline &&
        id == 'small-days' &&
        rect.top > h * .7 &&
        rect.center.dx < w * .6;
    return (upper ? lightOnTop : lightOnBottom) ||
            lightFooter ||
            groomSide ||
            headlineOnDarkSubject ||
            denimFooter
        ? const Color(0xFFFFFAF2)
        : ink;
  }

  static double _font(Map<String, dynamic> layer) =>
      ((layer['style'] as Map?)?['fontSize'] as num?)?.toDouble() ?? 11;
  String _text(Map<String, dynamic> layer) => layer['text'] as String? ?? '';
  String _id(Map<String, dynamic> layer) => layer['id'] as String;
  bool _suffix(Map<String, dynamic> l, String value) =>
      _id(l).endsWith('_$value');

  TextPainter _measure(
    Map<String, dynamic> layer,
    double pixels,
    double available, {
    double? leading,
  }) {
    final old = Map<String, dynamic>.from(layer['style'] as Map? ?? {});
    final weight = (old['fontWeight'] as num?)?.toInt() ?? 400;
    final style = TextStyle(
      fontFamily: old['fontFamily'] as String? ?? 'NotoSans',
      fontSize: pixels,
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      height: leading ?? 1.22,
      letterSpacing: 0,
    );
    return TextPainter(
      text: TextSpan(text: _text(layer), style: style),
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    )..layout(maxWidth: math.max(1, available - 1));
  }

  (double, double, double) _fit(
    Map<String, dynamic> layer,
    double maximumWidth,
    double maximumHeight,
    double initial,
    double minimum, {
    double leading = 1.22,
  }) {
    var size = initial;
    while (true) {
      final measure = _measure(layer, size, maximumWidth, leading: leading);
      final height = measure.height + 2;
      final width = math.min(
        maximumWidth,
        math.max(
          1.0,
          measure.computeLineMetrics().fold<double>(
                0,
                (maxWidth, line) => math.max(maxWidth, line.width),
              ) +
              2,
        ),
      );
      final fits = height <= maximumHeight;
      measure.dispose();
      if (fits || size <= minimum) return (size, width, height);
      size = math.max(minimum, size * .96);
    }
  }

  void _place(
    Map<String, dynamic> source,
    Rect rect,
    double pixels, {
    String align = 'left',
    double leading = 1.22,
    double minimum = 8.5,
    bool headline = false,
  }) {
    final old = Map<String, dynamic>.from(source['style'] as Map? ?? {});
    final foreground = _inkAt(rect, headline: headline);
    final light = foreground.computeLuminance() > .5;
    p.layers.add({
      ...source,
      'x': rect.left / w,
      'y': rect.top / h,
      'w': rect.width / w,
      'h': rect.height / h,
      'z': p.layers.length,
      'align': align,
      'rotation': 0,
      'textFillMode': 'solid',
      'typographyMinFontSize': minimum,
      'style': {
        ...old,
        'fontSize': pixels,
        'color': _hex(foreground),
        'letterSpacing': 0,
        'height': leading,
        'shadows': [
          {
            'color': light ? '#66000000' : '#18000000',
            'blurRadius': light ? 2.4 : 1.2,
            'offset': {'dx': 0.0, 'dy': light ? .7 : .25},
          },
        ],
      },
    });
  }

  void paint() {
    final source = hero['imageUrl'] as String;
    final isSquare =
        source.contains('cover_cinema_dance') ||
        source.contains('cover_friends_evening') ||
        source.contains('cover_generations_home') ||
        source.contains('/atelier_editions_2026/');
    final xFocus = switch (id) {
      'first-birthday' => -.25,
      'love-letters' => -.08,
      'taste-archive' => -.10,
      'your-first-year' => 0.0,
      'our-little-companion' => .05,
      _ => 0.0,
    };
    // Square portraits in a wide jacket keep their headroom. All crop offsets
    // use the existing editable crop schema shared by editor and print export.
    p.layers.add({
      ...hero,
      'x': 0.0,
      'y': 0.0,
      'w': 1.0,
      'h': 1.0,
      'z': p.layers.length,
      'frame': 'none',
      'rotation': 0,
      'imageZoom': 1.0,
      'imageOffsetRatio': {
        'x': aspect == CollectionAspect.portrait ? xFocus : 0.0,
        'y': wide && isSquare ? .5 : 0.0,
      },
    });

    final titles = texts
        .where((l) => l['typographyRole'] == 'signature-title')
        .toList();
    if (titles.isEmpty) {
      titles.add(texts.reduce((a, b) => _font(a) >= _font(b) ? a : b));
    }
    final decks = texts
        .where((l) => _suffix(l, 'cover_heading') && !titles.contains(l))
        .toList();
    final eyebrows = texts
        .where(
          (l) =>
              !titles.contains(l) &&
              !decks.contains(l) &&
              (_suffix(l, 'edition') ||
                  _suffix(l, 'cover_edition') ||
                  _suffix(l, 'signature_eyebrow')),
        )
        .toList();
    // Studio keeps its original opaque text ID, not an invented metadata name.
    if (eyebrows.isEmpty && StudioEdition.byId(id) != null) {
      final first = texts.first;
      if (!titles.contains(first)) eyebrows.add(first);
    }
    final infos = texts
        .where(
          (l) =>
              !titles.contains(l) &&
              !decks.contains(l) &&
              !eyebrows.contains(l),
        )
        .toList();
    final footerTop = _footer(infos);
    _companions(footerTop);

    final titleLayers = [...decks, ...titles].map((layer) {
      final reflowed = switch (id) {
        'daily-paw-walk' => '오늘도\n산책!',
        'still-us' => _text(layer).replaceAll(RegExp(r'\s+'), ' '),
        _ => null,
      };
      if (reflowed == null || !titles.contains(layer)) return layer;
      return {
        ...layer,
        'text': reflowed,
        'editorialSourceText': layer['editorialSourceText'] ?? layer['text'],
      };
    }).toList();
    final fitted = <(Map<String, dynamic>, double, double, double)>[];
    var totalHeight = 0.0;
    final titleMaxWidth =
        inner *
        (id == 'daily-paw-walk'
            ? .36
            : id == 'still-us'
            ? .55
            : id == 'our-family-year'
            ? (wide ? .35 : .5)
            : wide
            ? .83
            : .94);
    for (final layer in titleLayers) {
      final deck = decks.contains(layer);
      final initial = deck
          ? (wide ? 24.0 : 27.0)
          : id == 'still-us'
          ? (wide ? 32.0 : 34.0)
          : id == 'our-family-year'
          ? (wide ? 28.0 : 36.0)
          : id == proseStudyId
          ? (wide ? 53.0 : 63.0)
          : id == windAtlasId && wide
          ? 35.0
          : wide
          ? 38.0
          : 46.0;
      final fit = _fit(
        layer,
        titleMaxWidth,
        h * (deck ? .15 : .36),
        initial,
        deck
            ? 18
            : wide
            ? 28
            : 32,
        leading: 1.12,
      );
      fitted.add((layer, fit.$1, fit.$2, fit.$3));
      totalHeight += fit.$3 + 7;
    }
    var eyebrowHeight = 0.0;
    final eyeFits = <(Map<String, dynamic>, double, double, double)>[];
    for (final layer in eyebrows) {
      final fit = _fit(layer, inner, h * .13, 9.5, 8.5);
      eyeFits.add((layer, fit.$1, fit.$2, fit.$3));
      eyebrowHeight += fit.$3 + 8;
    }
    var y = upperTitle
        ? margin + eyebrowHeight
        : math.max(margin + eyebrowHeight + 14, footerTop - totalHeight - 16);
    if (upperTitle && wide && id == 'daily-paw-walk')
      y = margin + eyebrowHeight;
    final titleWidth = fitted.map((f) => f.$3).fold(0.0, math.max);
    final centeredTitle = id == 'our-family-year';
    final x = centeredTitle
        ? (w - titleWidth) / 2
        : rightTitle
        ? w - margin - titleWidth
        : margin;
    for (final fit in fitted) {
      final offset = centeredTitle
          ? (titleWidth - fit.$3) / 2
          : rightTitle
          ? titleWidth - fit.$3
          : 0.0;
      _place(
        fit.$1,
        Rect.fromLTWH(x + offset, y, fit.$3, fit.$4),
        fit.$2,
        align: centeredTitle
            ? 'center'
            : rightTitle
            ? 'right'
            : 'left',
        leading: 1.12,
        minimum: decks.contains(fit.$1)
            ? 18
            : wide
            ? 28
            : 32,
        headline: true,
      );
      y += fit.$4 + 7;
    }
    var eyeY = margin;
    for (final fit in eyeFits) {
      _place(
        fit.$1,
        Rect.fromLTWH(
          rightTitle ? w - margin - fit.$3 : margin,
          eyeY,
          fit.$3,
          fit.$4,
        ),
        fit.$2,
        align: rightTitle ? 'right' : 'left',
        minimum: 8.5,
      );
      eyeY += fit.$4 + 8;
    }
  }

  void _companions(double footerTop) {
    final companions = original
        .where((l) => l['type'] == 'image' && _id(l) != _id(hero))
        .toList();
    for (final entry in companions.indexed) {
      final image = entry.$2;
      final oldWidth = (image['w'] as num).toDouble() * w;
      final oldHeight = (image['h'] as num).toDouble() * h;
      final ratio = oldWidth / oldHeight;
      final imageWidth = 85.0;
      final imageHeight = imageWidth / ratio;
      final x = w - margin - imageWidth - entry.$1 * (imageWidth + 9);
      final y = math.max(margin, footerTop - 17 - imageHeight);
      p.layers.add({
        ...image,
        'x': x / w,
        'y': y / h,
        'w': imageWidth / w,
        'h': imageHeight / h,
        'frame': 'none',
        'rotation': 0,
        'z': p.layers.length,
      });
    }
  }

  double _footer(List<Map<String, dynamic>> infos) {
    final dateField = RegExp(r'_(?:cover_|signature_)?(?:period|date)$');
    final authorField = RegExp(
      r'_(?:cover_|signature_)?(?:byline|names|author)$',
    );
    final dates = infos.where((l) => dateField.hasMatch(_id(l))).toList();
    final authors = infos
        .where((l) => !dates.contains(l) && authorField.hasMatch(_id(l)))
        .toList();
    final bodies = infos
        .where((l) => !dates.contains(l) && !authors.contains(l))
        .toList();
    final fittedBodies = <(Map<String, dynamic>, double, double, double)>[];
    var bodyHeight = 0.0;
    for (final layer in bodies) {
      final minimum = layer['typographyRole'] == 'body' ? 11.0 : 9.5;
      final fit = _fit(layer, inner, h * .25, minimum, minimum);
      fittedBodies.add((layer, fit.$1, fit.$2, fit.$3));
      bodyHeight += fit.$3 + 7;
    }
    final row = <(Map<String, dynamic>, double, double, double, bool)>[];
    var rowHeight = 0.0;
    for (final layer in [...authors, ...dates]) {
      final isDate = dates.contains(layer);
      final minimum = layer['typographyRole'] == 'body' ? 11.0 : 8.5;
      final fit = _fit(
        layer,
        inner * .47,
        h * .20,
        math.max(minimum, isDate ? 9.5 : 10),
        minimum,
      );
      row.add((layer, fit.$1, fit.$2, fit.$3, isDate));
      rowHeight = math.max(rowHeight, fit.$3 + 4);
    }
    var y = h - margin - bodyHeight - rowHeight;
    final top = y;
    for (final fit in fittedBodies) {
      _place(
        fit.$1,
        Rect.fromLTWH(margin, y, fit.$3, fit.$4),
        fit.$2,
        minimum: fit.$1['typographyRole'] == 'body' ? 11 : 9.5,
      );
      y += fit.$4 + 7;
    }
    for (final fit in row) {
      _place(
        fit.$1,
        Rect.fromLTWH(fit.$5 ? w - margin - fit.$3 : margin, y, fit.$3, fit.$4),
        fit.$2,
        align: fit.$5 ? 'right' : 'left',
        minimum: fit.$1['typographyRole'] == 'body' ? 11 : 8.5,
      );
    }
    return top;
  }
}

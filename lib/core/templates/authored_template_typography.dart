part of 'authored_collections.dart';

/// Measure the actual editable text, rather than relying on the sample's length.
double _fittedEditorialType(
  _Sheet p,
  String id,
  String value,
  Rect rect, {
  required String font,
  required double size,
  required String color,
  int weight = 400,
  double leading = 1.16,
  String align = 'left',
  String? direction,
  int? maxLines,
  bool tight = false,
}) {
  final canvas = p.aspect.canvas;
  final available = Size(
    rect.width * canvas.width,
    rect.height * canvas.height,
  );
  var pixels = math.min(p.unit * size, available.height * .80);
  var measuredHeight = 0.0;
  for (var attempt = 0; attempt < 50; attempt++) {
    final style = TextStyle(
      fontFamily: font,
      fontSize: pixels,
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      height: leading,
      letterSpacing: 0,
    );
    final measure = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    )..layout(maxWidth: math.max(1, available.width - 1));
    final fits =
        measure.height <= available.height - .5 &&
        (maxLines == null || measure.computeLineMetrics().length <= maxLines) &&
        measure.computeLineMetrics().every(
          (line) => line.width <= available.width,
        );
    measuredHeight = measure.height;
    measure.dispose();
    if (fits || pixels <= 6) break;
    pixels *= .94;
  }
  final paintedHeight = tight
      ? math.min(available.height, math.max(measuredHeight + 1, pixels * 1.25))
      : available.height;
  p.text(
    id,
    value,
    rect.left,
    rect.top,
    rect.width,
    paintedHeight / canvas.height,
    size: pixels / p.unit,
    font: font,
    weight: weight,
    color: color,
    align: align,
    lineHeight: leading,
  );
  if (direction != null) {
    p.layers.last['typographyRole'] = 'signature-title';
    p.layers.last['typographyStyle'] = direction;
    p.layers.last['typographyMaxLines'] = maxLines;
  }
  return (tight ? paintedHeight : measuredHeight) / canvas.height;
}

extension _AtelierSignatureTypography on _AtelierPage {
  void headline(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .06,
    String? color,
    String align = 'left',
  }) {
    final (firstFont, lastFont, weight) = switch (edition) {
      AtelierEdition.nightVows => ('Eulyoo', 'BookMyungjo', 400),
      AtelierEdition.slowRail => ('RiaSans', 'NotoSans', 800),
      AtelierEdition.greenHours => ('BookMyungjo', 'Eulyoo', 800),
      AtelierEdition.firstOrbit => ('Arita', 'Yeongwol', 800),
      AtelierEdition.tableStories => ('SeoulNamsan', 'RiaSans', 800),
      AtelierEdition.privateCinema => ('Eulyoo', 'NotoSans', 800),
      AtelierEdition.walkMap => ('Arita', 'NotoSans', 800),
    };
    final words = value.split(' ');
    final split = words.length >= 2 && h >= .145 && w >= .50;
    var breakAt = 1;
    var difference = value.length;
    for (var i = 1; i < words.length; i++) {
      final d =
          (words.take(i).join(' ').length - words.skip(i).join(' ').length)
              .abs();
      if (d < difference) {
        difference = d;
        breakAt = i;
      }
    }
    final inkColor = color ?? ink;
    final accent = inkColor == edition.paper ? edition.accent : inkColor;
    var markY = y + h * .965;
    if (!split) {
      final narrow = words.length >= 2 && w < .50 && h >= .18;
      final copy = narrow
          ? '${words.take(breakAt).join(' ')}\n${words.skip(breakAt).join(' ')}'
          : value;
      final usedHeight = _fittedEditorialType(
        this,
        uid,
        copy,
        Rect.fromLTWH(x, y, w, h * .86),
        font: firstFont,
        size: size,
        color: inkColor,
        weight: weight,
        align: align,
        direction: edition.id,
        maxLines: copy.split('\n').length,
        tight: true,
      );
      markY = math.min(markY, y + usedHeight + h * .08);
    } else {
      final indent = switch (edition) {
        AtelierEdition.nightVows => .06,
        AtelierEdition.slowRail => .035,
        AtelierEdition.privateCinema => .025,
        _ => 0.0,
      };
      _fittedEditorialType(
        this,
        uid,
        words.take(breakAt).join(' '),
        Rect.fromLTWH(x, y, w, h * .42),
        font: firstFont,
        size: size * .90,
        color: inkColor,
        weight: weight,
        align: align,
        direction: edition.id,
        maxLines: 1,
        tight: true,
      );
      final usedHeight = _fittedEditorialType(
        this,
        uid,
        words.skip(breakAt).join(' '),
        Rect.fromLTWH(x + w * indent, y + h * .43, w * (1 - indent), h * .46),
        font: lastFont,
        size: size * 1.08,
        color: inkColor,
        weight: lastFont == 'Eulyoo' ? 400 : 800,
        align: align,
        direction: edition.id,
        maxLines: 1,
        tight: true,
      );
      markY = math.min(markY, y + h * .43 + usedHeight + h * .07);
    }
    // Fine rules and editorial marks stay inside the reserved title region.
    final bottom = markY;
    switch (edition) {
      case AtelierEdition.nightVows:
        rule(x + w * .06, bottom, w * .27, color: edition.accent);
      case AtelierEdition.slowRail:
        box(uid, x, bottom, w * .10, .004 * ratio, accent);
        rule(x + w * .14, bottom, w * .32, color: accent);
      case AtelierEdition.greenHours:
        rule(x, bottom, w * .13, color: accent);
        rule(x + w * .18, bottom, w * .035, color: accent);
      case AtelierEdition.firstOrbit:
        rule(x, bottom, w * .08, color: accent);
        rule(x + w * .10, bottom, w * .025, color: accent);
      case AtelierEdition.tableStories:
        rule(x, bottom, w * .29, color: accent);
        rule(x, bottom + .004 * ratio, w * .29, color: edition.accent);
      case AtelierEdition.privateCinema:
        box(uid, x, bottom, w * .045, .004 * ratio, accent);
        rule(x + w * .07, bottom, w * .52, color: accent);
      case AtelierEdition.walkMap:
        for (var i = 0; i < 3; i++) {
          rule(x + w * i * .055, bottom, w * .03, color: accent);
        }
    }
  }
}

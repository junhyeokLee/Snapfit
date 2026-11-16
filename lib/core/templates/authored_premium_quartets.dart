part of 'authored_collections.dart';

/// Natural glyph metrics at final size, with explicit semantic headline breaks.
/// This authoring path never changes the geometry of an older saved edition.
void _pqType(
  _StoryPage p,
  String value,
  Rect region, {
  double size = .028,
  String? font,
  String? color,
  String align = 'left',
  String role = 'body',
  int? maxLines,
}) {
  final s = premiumQuartetSpecsById[p.edition.id]!;
  final family = font ?? (role == 'headline' ? s.font : 'BookMyungjo');
  final available = Size(
    region.width * p.aspect.canvas.width,
    region.height * p.aspect.canvas.height,
  );
  var pixels = p.unit * size;
  var height = 0.0;
  final lines =
      maxLines ?? (role == 'headline' ? value.split('\n').length : null);
  for (var n = 0; n < 64; n++) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: family,
          fontSize: pixels,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          height: 1.35,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align == 'center' ? TextAlign.center : TextAlign.left,
    )..layout(maxWidth: math.max(1, available.width - 1));
    height = painter.height + 1;
    final metrics = painter.computeLineMetrics();
    painter.layout(maxWidth: math.max(1, available.width));
    final rendered = painter.computeLineMetrics();
    final orphan =
        role == 'body' &&
        lines == null &&
        !value.contains('\n') &&
        rendered.length > 1 &&
        rendered.last.width < pixels * 2;
    final fits =
        height <= available.height &&
        (lines == null || metrics.length <= lines) &&
        metrics.every((line) => line.width <= available.width - 1) &&
        !orphan;
    painter.dispose();
    if (fits) break;
    pixels *= .95;
  }
  p.text(
    p.uid,
    value,
    region.left,
    region.top +
        math.max(0, available.height - height) / 2 / p.aspect.canvas.height,
    region.width,
    height / p.aspect.canvas.height,
    size: pixels / p.unit,
    color: color ?? p.edition.ink,
    font: family,
    align: align,
    lineHeight: 1.35,
  );
  p.layers.last.addAll({
    'editorialTextRole': role,
    'templateContent': true,
    'premiumTextRegion': [region.left, region.top, region.width, region.height],
    if (lines != null) 'premiumMaxLines': lines,
  });
}

Rect _pqPhoto(_StoryPage p, int n, Rect region, {int? frame}) {
  final r = frame == null
      ? _readingPhoto(p, n, region)
      : _storyMountedPhoto(p, n, region, mount: frame);
  // The mounted window is exactly3:2, including each frame's asymmetric insets.
  p.layers.last.remove('imageOffsetRatio');
  p.layers.last['premiumFullSourcePhoto'] = true;
  return r;
}

Rect _pqMaterial(_StoryPage p, String suffix, Rect region) {
  final ratio = suffix == 'paper' || suffix == 'vellum' ? 1.25 : 1.0;
  final width = math.min(region.width, region.height * ratio / p.ratio);
  final r = Rect.fromCenter(
    center: region.center,
    width: width,
    height: width * p.ratio / ratio,
  );
  p.piece('${p.edition.id}-$suffix', r);
  return r;
}

void _pqPhrase(_StoryPage p, Rect region, {bool caption = false}) {
  final key = '${p.edition.id}${caption ? '-caption' : ''}';
  final art = studioWordArtById(key)!;
  final source = art.sourceSize, canvas = p.aspect.canvas;
  final scale = math.min(
    region.width * canvas.width / source.width,
    region.height * canvas.height / source.height,
  );
  final origin = Offset(
    region.center.dx * canvas.width - source.width * scale / 2,
    region.center.dy * canvas.height - source.height * scale / 2,
  );
  for (final layer in art.previewLayers()) {
    var scaled = layer.copyWith(
      position: origin + layer.position * scale,
      width: layer.width * scale,
      height: layer.height * scale,
      textStyle: layer.textStyle?.copyWith(
        fontSize: layer.textStyle!.fontSize! * scale,
      ),
    );
    if (layer.type.name == 'text') {
      final painter = TextPainter(
        text: TextSpan(text: scaled.text, style: scaled.textStyle),
        textDirection: TextDirection.ltr,
        textAlign: scaled.textAlign ?? TextAlign.left,
      )..layout(maxWidth: scaled.width);
      final height = painter.height + 1;
      painter.dispose();
      scaled = scaled.copyWith(
        position: scaled.position + Offset(0, (scaled.height - height) / 2),
        height: height,
      );
    }
    final raw = LayerExportMapper.toJson(scaled, canvasSize: canvas);
    raw.addAll({
      'type': layer.type.name,
      'id': '${p.edition.id}_${p.index}_phrase_${p.layers.length}',
      'z': p.layers.length,
      'wordArtId': key,
      'templateContent': true,
    });
    p.layers.add(raw);
  }
}

void _premiumQuartetCover(_StoryPage p) {
  final e = p.edition, s = premiumQuartetSpecsById[p.edition.id]!;
  final dark = e.coverStyle == 4 || e.coverStyle == 12;
  p.box(p.uid, 0, 0, 1, 1, dark ? e.ink : e.tint);
  void title(Rect r, {double size = .092, String align = 'left'}) => _pqType(
    p,
    s.headline,
    r,
    size: size,
    role: 'headline',
    align: align,
    color: dark ? '#FFF9EF' : e.ink,
  );
  void english(Rect r, {String align = 'left'}) => _pqType(
    p,
    e.englishTitle.replaceAll('\n', ' '),
    r,
    font: s.secondaryFont,
    size: .025,
    align: align,
    color: dark ? '#F0D5B4' : e.accent,
    maxLines: 1,
  );
  void tagline(Rect r) =>
      _pqType(p, s.tagline, r, size: .024, color: dark ? '#FFF9EF' : e.ink);
  switch (e.coverStyle % 16) {
    case 0:
      english(const Rect.fromLTWH(.07, .055, .86, .04));
      title(const Rect.fromLTWH(.07, .12, .67, .25));
      _pqMaterial(p, 'motif', const Rect.fromLTWH(.78, .16, .15, .19));
      _pqPhoto(p, 0, const Rect.fromLTWH(.06, .40, .88, .43), frame: 0);
      tagline(const Rect.fromLTWH(.08, .87, .84, .07));
    case 1:
      p.line(const Rect.fromLTWH(.045, .05, .012, .89));
      english(const Rect.fromLTWH(.10, .065, .80, .04));
      title(const Rect.fromLTWH(.10, .13, .80, .24));
      _pqPhoto(p, 0, const Rect.fromLTWH(.10, .42, .78, .40), frame: 1);
      tagline(const Rect.fromLTWH(.10, .87, .78, .07));
    case 2:
      title(const Rect.fromLTWH(.07, .08, .86, .24), align: 'center');
      english(const Rect.fromLTWH(.08, .33, .84, .035), align: 'center');
      _pqPhoto(p, 0, const Rect.fromLTWH(.06, .41, .55, .42), frame: 0);
      _pqPhoto(p, 2, const Rect.fromLTWH(.65, .47, .29, .23), frame: 1);
      _pqMaterial(p, 'motif', const Rect.fromLTWH(.72, .73, .14, .15));
      tagline(const Rect.fromLTWH(.08, .89, .84, .05));
    case 3:
      english(const Rect.fromLTWH(.08, .055, .84, .04), align: 'center');
      _pqPhoto(p, 0, const Rect.fromLTWH(.06, .12, .88, .44), frame: 1);
      title(const Rect.fromLTWH(.08, .59, .84, .24), align: 'center');
      tagline(const Rect.fromLTWH(.08, .88, .84, .06));
    case 4:
      title(const Rect.fromLTWH(.075, .09, .85, .25));
      english(const Rect.fromLTWH(.08, .35, .84, .04));
      _pqPhoto(p, 0, const Rect.fromLTWH(.055, .43, .89, .43));
      tagline(const Rect.fromLTWH(.08, .89, .84, .05));
    case 5:
      title(const Rect.fromLTWH(.08, .10, .63, .29));
      _pqMaterial(p, 'keepsake', const Rect.fromLTWH(.74, .12, .20, .24));
      english(const Rect.fromLTWH(.08, .40, .84, .04));
      _pqPhoto(p, 0, const Rect.fromLTWH(.06, .49, .57, .35), frame: 0);
      _pqPhoto(p, 4, const Rect.fromLTWH(.67, .59, .27, .22), frame: 1);
      tagline(const Rect.fromLTWH(.08, .89, .84, .05));
    case 6:
      _pqPhoto(p, 0, const Rect.fromLTWH(.055, .08, .89, .43));
      p.box(p.uid, .055, .55, .89, .31, s.paperAccent);
      title(const Rect.fromLTWH(.085, .57, .83, .26), align: 'center');
      english(const Rect.fromLTWH(.08, .89, .84, .04), align: 'center');
    case 7:
      title(const Rect.fromLTWH(.07, .08, .86, .25));
      english(const Rect.fromLTWH(.08, .35, .84, .04));
      _pqPhoto(p, 0, const Rect.fromLTWH(.07, .43, .66, .44), frame: 1);
      _pqMaterial(p, 'keepsake', const Rect.fromLTWH(.76, .47, .18, .25));
      _pqType(
        p,
        'VOL. ${s.style + 1}',
        const Rect.fromLTWH(.76, .76, .18, .08),
        font: 'Poppins',
        size: .019,
      );
      tagline(const Rect.fromLTWH(.08, .9, .84, .05));
    case 8:
      english(const Rect.fromLTWH(.07, .055, .86, .04));
      _pqPhoto(p, 0, const Rect.fromLTWH(.055, .13, .89, .43), frame: 0);
      title(const Rect.fromLTWH(.07, .60, .70, .24));
      _pqMaterial(p, 'motif', const Rect.fromLTWH(.79, .65, .15, .18));
      tagline(const Rect.fromLTWH(.08, .89, .84, .05));
    case 9:
      final stock = _pqMaterial(
        p,
        'vellum',
        const Rect.fromLTWH(.04, .05, .92, .42),
      );
      title(
        Rect.fromLTWH(
          stock.left + stock.width * .16,
          stock.top + stock.height * .24,
          stock.width * .68,
          stock.height * .50,
        ),
        align: 'center',
      );
      _pqPhoto(p, 0, const Rect.fromLTWH(.075, .49, .85, .40), frame: 1);
      english(const Rect.fromLTWH(.08, .91, .84, .035), align: 'center');
    case 10:
      title(const Rect.fromLTWH(.08, .07, .84, .25));
      english(const Rect.fromLTWH(.08, .34, .84, .04));
      _pqPhoto(p, 0, const Rect.fromLTWH(.06, .43, .55, .41), frame: 0);
      _pqPhoto(p, 2, const Rect.fromLTWH(.65, .44, .29, .19), frame: 1);
      _pqPhoto(p, 4, const Rect.fromLTWH(.65, .67, .29, .19));
      tagline(const Rect.fromLTWH(.08, .91, .84, .04));
    case 11:
      for (final r in const [
        Rect.fromLTWH(.045, .045, .91, .004),
        Rect.fromLTWH(.045, .95, .91, .004),
        Rect.fromLTWH(.045, .045, .004, .91),
        Rect.fromLTWH(.95, .045, .004, .91),
      ])
        p.line(r);
      english(const Rect.fromLTWH(.09, .08, .82, .04), align: 'center');
      title(const Rect.fromLTWH(.09, .15, .82, .24), align: 'center');
      _pqPhoto(p, 0, const Rect.fromLTWH(.09, .44, .82, .37), frame: 0);
      tagline(const Rect.fromLTWH(.10, .86, .80, .06));
    case 12:
      p.box(p.uid, .065, .065, .87, .017, e.accent);
      title(const Rect.fromLTWH(.08, .12, .84, .25));
      _pqPhoto(p, 0, const Rect.fromLTWH(.065, .42, .87, .42), frame: 1);
      english(const Rect.fromLTWH(.08, .89, .84, .05));
    case 13:
      title(const Rect.fromLTWH(.07, .07, .86, .26));
      english(const Rect.fromLTWH(.08, .35, .84, .04));
      _pqPhoto(p, 0, const Rect.fromLTWH(.06, .43, .52, .41), frame: 0);
      _pqPhoto(p, 3, const Rect.fromLTWH(.62, .51, .32, .27), frame: 1);
      tagline(const Rect.fromLTWH(.08, .89, .84, .05));
    case 14:
      english(const Rect.fromLTWH(.08, .055, .84, .04), align: 'center');
      title(const Rect.fromLTWH(.08, .13, .84, .25), align: 'center');
      _pqPhoto(p, 0, const Rect.fromLTWH(.16, .43, .68, .34));
      p.line(const Rect.fromLTWH(.16, .81, .68, .004));
      tagline(const Rect.fromLTWH(.16, .86, .68, .07));
    default:
      _pqPhoto(p, 0, const Rect.fromLTWH(.055, .07, .89, .43), frame: 0);
      title(const Rect.fromLTWH(.08, .56, .68, .26));
      _pqMaterial(p, 'motif', const Rect.fromLTWH(.79, .61, .15, .18));
      english(const Rect.fromLTWH(.08, .87, .84, .055));
  }
}

List<_StoryPage> _premiumQuartetSpread(
  StoryEdition e,
  CollectionAspect aspect,
  int i,
) {
  final s = premiumQuartetSpecsById[e.id]!, role = e.spreadOrder[i];
  final l = _StoryPage(
    e,
    aspect,
    i * 2 + 1,
    role % 3 == 0 ? e.tint : '#FAF8F2',
  );
  final r = _StoryPage(
    e,
    aspect,
    i * 2 + 2,
    role % 4 == 0 ? s.paperAccent : '#FCFAF5',
  );
  void title(_StoryPage p, Rect area, {double size = .052}) =>
      _pqType(p, e.chapters[i], area, size: size, role: 'headline');
  void note(_StoryPage p, Rect area) =>
      _pqType(p, e.notes[i], area, size: .028);
  void label(_StoryPage p, {String? text}) => _pqType(
    p,
    text ??
        '${(i + 1).toString().padLeft(2, '0')} / ${e.englishTitle.replaceAll('\n', ' ')}',
    const Rect.fromLTWH(.08, .055, .84, .045),
    font: s.secondaryFont,
    size: .017,
    color: e.accent,
    maxLines: 1,
  );
  void photo(_StoryPage p, int n, Rect a, {int? mount}) =>
      _pqPhoto(p, n, a, frame: mount);
  void grid(_StoryPage p, int count, Rect area, {int start = 0}) {
    final columns = count == 3 ? 3 : 2,
        rows = (count / (count == 3 ? 3 : 2)).ceil();
    final w = (area.width - (columns - 1) * .025) / columns,
        h = (area.height - (rows - 1) * .03) / rows;
    for (var j = 0; j < count; j++)
      photo(
        p,
        start + j,
        Rect.fromLTWH(
          area.left + (j % columns) * (w + .025),
          area.top + (j ~/ columns) * (h + .03),
          w,
          h,
        ),
        mount: j.isEven ? 0 : 1,
      );
  }

  if (const [3, 9, 19, 29].contains(role)) {
    final cardIndex = const [3, 9, 19, 29].indexOf(role),
        card = s.cards[const [3, 9, 19, 29].indexOf(role)];
    label(l);
    title(l, const Rect.fromLTWH(.08, .15, .84, .15));
    note(l, const Rect.fromLTWH(.08, .32, .84, .15));
    if (cardIndex == 0)
      _pqMaterial(l, 'keepsake', const Rect.fromLTWH(.13, .51, .68, .37));
    else
      photo(
        l,
        const [0, 2, 3, 4][cardIndex],
        const Rect.fromLTWH(.08, .53, .84, .34),
        mount: 1,
      );
    final paper = _pqMaterial(
      r,
      cardIndex.isEven ? 'paper' : 'vellum',
      const Rect.fromLTWH(.055, .15, .89, .69),
    );
    Rect field(double y, double h) => Rect.fromLTWH(
      paper.left + paper.width * .16,
      paper.top + paper.height * y,
      paper.width * .68,
      paper.height * h,
    );
    _pqType(r, card[0], field(.21, .11), size: .035, role: 'headline');
    _pqType(r, card[1], field(.39, .23), size: .026);
    r.line(field(.66, .002), color: e.accent);
    _pqType(
      r,
      card[2],
      field(.69, .08),
      size: .020,
      color: e.accent,
      maxLines: 2,
    );
    r.layers.last['premiumCardRole'] = const [
      'observation',
      'conditions',
      'reflection',
      'next-plan',
    ][cardIndex];
    return [l, r];
  }
  switch (role) {
    case 0:
      label(l);
      _pqPhrase(l, const Rect.fromLTWH(.055, .16, .89, .37));
      note(l, const Rect.fromLTWH(.09, .59, .82, .15));
      _pqMaterial(l, 'motif', const Rect.fromLTWH(.72, .77, .18, .14));
      photo(r, 0, const Rect.fromLTWH(.055, .13, .89, .50), mount: 0);
      title(r, const Rect.fromLTWH(.08, .76, .47, .12), size: .033);
      photo(r, 1, const Rect.fromLTWH(.62, .73, .29, .17), mount: 1);
    case 1:
      label(l);
      title(l, const Rect.fromLTWH(.08, .15, .84, .13));
      for (var j = 0; j < 3; j++) {
        l.line(Rect.fromLTWH(.09, .35 + j * .16, .007, .12));
        _pqType(
          l,
          '0${j + 1}',
          Rect.fromLTWH(.13, .36 + j * .16, .13, .05),
          font: 'Poppins',
          size: .024,
          color: e.accent,
        );
        photo(r, j, Rect.fromLTWH(.09, .13 + j * .24, .82, .21), mount: j % 2);
      }
      note(l, const Rect.fromLTWH(.30, .34, .60, .43));
    case 2:
      label(l);
      photo(l, i, const Rect.fromLTWH(.065, .14, .87, .56), mount: 0);
      title(l, const Rect.fromLTWH(.08, .75, .84, .09), size: .04);
      photo(r, i + 1, const Rect.fromLTWH(.12, .15, .74, .35), mount: 1);
      note(r, const Rect.fromLTWH(.12, .61, .74, .20));
    case 4:
      label(l);
      title(l, const Rect.fromLTWH(.08, .15, .84, .15));
      _pqMaterial(l, 'keepsake', const Rect.fromLTWH(.075, .34, .85, .53));
      grid(r, 2, const Rect.fromLTWH(.075, .16, .85, .36), start: 2);
      final stock = _pqMaterial(
        r,
        'vellum',
        const Rect.fromLTWH(.09, .57, .82, .30),
      );
      note(
        r,
        Rect.fromLTWH(
          stock.left + stock.width * .16,
          stock.top + stock.height * .30,
          stock.width * .68,
          stock.height * .36,
        ),
      );
    case 5:
      _pqPhrase(l, const Rect.fromLTWH(.06, .15, .88, .43), caption: true);
      _pqMaterial(l, 'motif', const Rect.fromLTWH(.12, .67, .29, .22));
      photo(r, 2, const Rect.fromLTWH(.08, .13, .84, .48));
      title(r, const Rect.fromLTWH(.09, .68, .82, .09), size: .04);
      note(r, const Rect.fromLTWH(.09, .80, .82, .09));
    case 6:
      label(l);
      title(l, const Rect.fromLTWH(.08, .16, .84, .13));
      grid(l, 4, const Rect.fromLTWH(.07, .38, .86, .44), start: 1);
      photo(r, 0, const Rect.fromLTWH(.08, .17, .84, .43), mount: 1);
      note(r, const Rect.fromLTWH(.09, .68, .82, .15));
    case 7:
      photo(l, i, const Rect.fromLTWH(.055, .13, .89, .58));
      title(l, const Rect.fromLTWH(.08, .76, .84, .10), size: .039);
      _pqMaterial(r, 'motif', const Rect.fromLTWH(.09, .13, .82, .46));
      note(r, const Rect.fromLTWH(.13, .68, .74, .17));
    case 8:
      label(l);
      title(l, const Rect.fromLTWH(.08, .15, .84, .16));
      final card = _pqMaterial(
        l,
        'paper',
        const Rect.fromLTWH(.07, .39, .86, .43),
      );
      note(
        l,
        Rect.fromLTWH(
          card.left + card.width * .16,
          card.top + card.height * .30,
          card.width * .68,
          card.height * .36,
        ),
      );
      photo(r, 4, const Rect.fromLTWH(.055, .17, .89, .57), mount: 0);
      _pqType(
        r,
        s.tagline,
        const Rect.fromLTWH(.08, .81, .84, .07),
        size: .025,
      );
    case 10:
      label(l);
      title(l, const Rect.fromLTWH(.08, .15, .84, .13));
      photo(l, 1, const Rect.fromLTWH(.08, .37, .84, .36), mount: 0);
      _pqType(
        l,
        '01 / ${e.category}',
        const Rect.fromLTWH(.09, .78, .82, .05),
        size: .021,
      );
      photo(r, 3, const Rect.fromLTWH(.08, .17, .84, .40), mount: 1);
      note(r, const Rect.fromLTWH(.09, .66, .82, .18));
    case 11:
      label(l);
      title(l, const Rect.fromLTWH(.08, .16, .84, .16));
      _pqMaterial(l, 'keepsake', const Rect.fromLTWH(.14, .40, .72, .43));
      final card = _pqMaterial(
        r,
        'vellum',
        const Rect.fromLTWH(.07, .18, .86, .67),
      );
      _pqType(
        r,
        'COLLECTED / ${(i + 1).toString().padLeft(2, '0')}',
        Rect.fromLTWH(
          card.left + card.width * .16,
          card.top + card.height * .23,
          card.width * .68,
          card.height * .12,
        ),
        font: 'Poppins',
        size: .022,
        color: e.accent,
      );
      note(
        r,
        Rect.fromLTWH(
          card.left + card.width * .16,
          card.top + card.height * .42,
          card.width * .68,
          card.height * .27,
        ),
      );
    case 12:
      label(l);
      photo(l, i, const Rect.fromLTWH(.065, .16, .87, .56), mount: 1);
      title(l, const Rect.fromLTWH(.08, .78, .84, .09), size: .039);
      grid(r, 2, const Rect.fromLTWH(.08, .17, .84, .37), start: i + 1);
      note(r, const Rect.fromLTWH(.09, .64, .82, .21));
    case 13:
      label(l, text: 'DATE / WEATHER / PLACE');
      title(l, const Rect.fromLTWH(.08, .19, .84, .16));
      _pqMaterial(l, 'motif', const Rect.fromLTWH(.12, .44, .32, .27));
      note(l, const Rect.fromLTWH(.09, .75, .82, .12));
      photo(r, i, const Rect.fromLTWH(.055, .16, .89, .57), mount: 0);
      _pqType(
        r,
        '날짜 __________  날씨 __________',
        const Rect.fromLTWH(.10, .81, .80, .06),
        size: .022,
      );
    case 14:
      _pqPhrase(l, const Rect.fromLTWH(.065, .20, .87, .47));
      note(l, const Rect.fromLTWH(.12, .76, .76, .10));
      photo(r, i + 1, const Rect.fromLTWH(.07, .17, .86, .57), mount: 1);
      title(r, const Rect.fromLTWH(.09, .80, .82, .08), size: .036);
    case 15:
      label(l);
      title(l, const Rect.fromLTWH(.08, .16, .84, .16));
      for (var j = 0; j < 3; j++) {
        l.line(Rect.fromLTWH(.14 + j * .30, .47, .13, .004));
        _pqType(
          l,
          '0${j + 1}',
          Rect.fromLTWH(.10 + j * .30, .54, .20, .06),
          font: 'Poppins',
          size: .026,
        );
        photo(r, j, Rect.fromLTWH(.09, .12 + j * .25, .82, .22), mount: j % 2);
      }
      note(l, const Rect.fromLTWH(.09, .70, .82, .16));
    case 16:
      title(l, const Rect.fromLTWH(.09, .18, .82, .22), size: .064);
      label(l, text: 'CHAPTER ${(i + 1).toString().padLeft(2, '0')}');
      note(l, const Rect.fromLTWH(.10, .58, .80, .18));
      photo(r, 0, const Rect.fromLTWH(.045, .13, .91, .64));
    case 17:
      _pqPhrase(l, const Rect.fromLTWH(.06, .22, .88, .45));
      title(l, const Rect.fromLTWH(.09, .78, .82, .09), size: .034);
      photo(r, i, const Rect.fromLTWH(.08, .14, .84, .31), mount: 0);
      photo(r, i + 2, const Rect.fromLTWH(.08, .51, .84, .31), mount: 1);
    case 18:
      label(l);
      title(l, const Rect.fromLTWH(.08, .16, .84, .12));
      photo(l, 1, const Rect.fromLTWH(.08, .36, .84, .37), mount: 0);
      _pqType(
        l,
        '첫 번째 시선',
        const Rect.fromLTWH(.09, .79, .82, .05),
        size: .022,
        color: e.accent,
      );
      photo(r, 4, const Rect.fromLTWH(.08, .17, .84, .39), mount: 1);
      note(r, const Rect.fromLTWH(.09, .65, .82, .19));
    case 20:
      label(l);
      title(l, const Rect.fromLTWH(.08, .15, .84, .14));
      _pqMaterial(l, 'keepsake', const Rect.fromLTWH(.12, .40, .76, .46));
      photo(r, 3, const Rect.fromLTWH(.08, .15, .84, .39), mount: 0);
      final paper = _pqMaterial(
        r,
        'vellum',
        const Rect.fromLTWH(.08, .60, .84, .27),
      );
      note(
        r,
        Rect.fromLTWH(
          paper.left + paper.width * .16,
          paper.top + paper.height * .30,
          paper.width * .68,
          paper.height * .40,
        ),
      );
    case 21:
      label(l);
      photo(l, i, const Rect.fromLTWH(.08, .16, .84, .40), mount: 0);
      title(l, const Rect.fromLTWH(.09, .64, .82, .10), size: .040);
      _pqType(
        l,
        '처음의 날짜 __________',
        const Rect.fromLTWH(.09, .81, .82, .055),
        size: .022,
      );
      photo(r, i + 2, const Rect.fromLTWH(.08, .16, .84, .40), mount: 1);
      note(r, const Rect.fromLTWH(.09, .65, .82, .16));
    case 22:
      label(l);
      title(l, const Rect.fromLTWH(.08, .15, .84, .15));
      grid(l, 3, const Rect.fromLTWH(.07, .40, .86, .24), start: 1);
      note(l, const Rect.fromLTWH(.09, .72, .82, .14));
      photo(r, 4, const Rect.fromLTWH(.055, .18, .89, .56), mount: 1);
      _pqType(
        r,
        '작은 변화가 쌓이는 순서',
        const Rect.fromLTWH(.09, .81, .82, .06),
        size: .023,
      );
    case 23:
      label(l);
      title(l, const Rect.fromLTWH(.08, .16, .84, .14));
      note(l, const Rect.fromLTWH(.09, .39, .82, .20));
      _pqMaterial(l, 'motif', const Rect.fromLTWH(.16, .66, .33, .23));
      photo(r, 2, const Rect.fromLTWH(.08, .14, .84, .31), mount: 0);
      photo(r, 5, const Rect.fromLTWH(.08, .51, .84, .31), mount: 1);
    case 24:
      photo(l, 0, const Rect.fromLTWH(.055, .15, .89, .59));
      title(l, const Rect.fromLTWH(.09, .80, .82, .09), size: .037);
      label(r);
      final paper = _pqMaterial(
        r,
        'vellum',
        const Rect.fromLTWH(.055, .21, .89, .58),
      );
      note(
        r,
        Rect.fromLTWH(
          paper.left + paper.width * .16,
          paper.top + paper.height * .30,
          paper.width * .68,
          paper.height * .34,
        ),
      );
    case 25:
      label(l);
      title(l, const Rect.fromLTWH(.08, .17, .84, .15));
      _pqMaterial(l, 'keepsake', const Rect.fromLTWH(.10, .41, .80, .44));
      _pqType(
        r,
        '나의 수집 목록',
        const Rect.fromLTWH(.09, .18, .82, .11),
        role: 'headline',
        size: .044,
      );
      note(r, const Rect.fromLTWH(.10, .38, .80, .22));
      for (var j = 0; j < 3; j++)
        r.line(
          Rect.fromLTWH(.10, .68 + j * .075, .80, .002),
          color: s.paperAccent,
        );
    case 26:
      _pqPhrase(l, const Rect.fromLTWH(.065, .23, .87, .40), caption: true);
      title(l, const Rect.fromLTWH(.09, .76, .82, .10), size: .034);
      photo(r, 3, const Rect.fromLTWH(.06, .15, .88, .56), mount: 0);
      note(r, const Rect.fromLTWH(.10, .78, .80, .11));
    case 27:
      label(l);
      title(l, const Rect.fromLTWH(.08, .16, .84, .14));
      grid(l, 3, const Rect.fromLTWH(.07, .42, .86, .25), start: 2);
      note(l, const Rect.fromLTWH(.09, .74, .82, .13));
      photo(r, 0, const Rect.fromLTWH(.045, .14, .91, .63));
    case 28:
      label(l);
      title(l, const Rect.fromLTWH(.08, .18, .84, .16), size: .060);
      note(l, const Rect.fromLTWH(.10, .43, .80, .22));
      _pqMaterial(l, 'motif', const Rect.fromLTWH(.66, .72, .22, .17));
      photo(r, 5, const Rect.fromLTWH(.07, .16, .86, .57), mount: 1);
      _pqType(
        r,
        s.tagline,
        const Rect.fromLTWH(.10, .80, .80, .07),
        size: .025,
      );
    case 30:
      label(l);
      title(l, const Rect.fromLTWH(.08, .18, .84, .16));
      final card = _pqMaterial(
        l,
        'paper',
        const Rect.fromLTWH(.065, .42, .87, .42),
      );
      note(
        l,
        Rect.fromLTWH(
          card.left + card.width * .16,
          card.top + card.height * .29,
          card.width * .68,
          card.height * .39,
        ),
      );
      photo(r, 5, const Rect.fromLTWH(.055, .16, .89, .60));
    case 31:
      photo(l, 5, const Rect.fromLTWH(.055, .13, .89, .59), mount: 1);
      title(l, const Rect.fromLTWH(.08, .79, .84, .09), size: .037);
      _pqPhrase(r, const Rect.fromLTWH(.07, .17, .86, .39), caption: true);
      note(r, const Rect.fromLTWH(.10, .64, .80, .16));
      _pqType(
        r,
        '다음 장은 우리의 시간으로.',
        const Rect.fromLTWH(.10, .85, .80, .055),
        size: .024,
        color: e.accent,
      );
    default:
      throw StateError('premium_quartet_unknown_role:$role');
  }
  return [l, r];
}

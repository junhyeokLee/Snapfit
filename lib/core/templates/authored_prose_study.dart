part of 'authored_collections.dart';

const proseStudyId = 'our-prose';
const proseStudyTitle = '함께여서 좋은 날';
const proseStudyArt = 'assets/templates/prose_study/botanical_cartouche.png';
const proseStudyPattern = 'assets/templates/prose_study/woodcut_endpaper.png';
const proseStudyInk = 'assets/templates/prose_study/woodcut_ink.png';
const proseStudySpreads = ['웃음이 먼저 남은 날', '나란히 앉은 오후', '다음에도, 이렇게'];
const proseStudyStyles = [
  '패턴으로 쓴 표제',
  '장면을 여는 문장',
  '사진을 모은 기록',
  '사진 곁의 짧은 기록',
  '편지의 한 페이지',
  '사진으로 마무리한 인사',
];

class ProseStudyCopy {
  const ProseStudyCopy({
    this.heading = '함께여서',
    this.keyword = '좋은 날',
    this.names = '서연과 지우',
    this.date = '2026. 10. 17',
    this.promise = '나란히 앉아,\n별것 아닌 이야기로\n오래 웃었던 오후.',
    this.closing = '다음에도, 이렇게.',
    this.letter =
        '사진을 찍던 네가 먼저 웃어서, 나는 준비한 표정을 잊었어. 그때부터 이 사진이 좋아졌어.\n\n'
        '서로의 말이 길어지는 날에는 조금 더 들어 주고, 말이 없는 날에는 곁에 앉아 있자.\n\n'
        '오늘 같은 날이 앞으로도 많았으면 좋겠어.',
  });
  final String heading, keyword, names, date, promise, letter, closing;
}

/// Six-page source study retained for comparison and saved-document continuity.
Map<String, dynamic> buildProseStudy(
  CollectionAspect aspect, {
  ProseStudyCopy copy = const ProseStudyCopy(),
}) {
  const paper = '#FAFAF6', red = '#842B3D', blue = '#DCE9ED';
  const ink = '#233D35', muted = '#586A64';
  final wide = aspect == CollectionAspect.landscape;
  final pages = <Map<String, dynamic>>[];
  _Sheet sheet([String bg = paper, String color = ink]) =>
      _Sheet(proseStudyId, aspect, pages.length, bg, ink: color);
  void t(
    _Sheet p,
    String id,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .025,
    String? color,
    String font = 'NotoSans',
    int weight = 400,
    String align = 'left',
    double leading = 1.45,
  }) => p.text(
    id,
    value,
    x,
    y,
    w,
    h,
    size: size,
    color: color ?? p.ink,
    font: font,
    weight: weight,
    align: align,
    lineHeight: leading,
  );
  void display(
    _Sheet p,
    String id,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .12,
    String? color,
    String font = 'BookMyungjo',
    String align = 'left',
    bool pattern = false,
  }) {
    t(
      p,
      id,
      value,
      x,
      y,
      w,
      h,
      size: size,
      color: color,
      font: font,
      weight: font == 'BookMyungjo' ? 800 : 400,
      align: align,
      leading: 1.14,
    );
    if (pattern)
      p.layers.last.addAll({
        'textFillMode': 'imageClip',
        'textFillImageUrl': 'asset:$proseStudyInk',
      });
  }

  void rule(
    _Sheet p,
    String id,
    double x,
    double y,
    double w, [
    String? color,
  ]) => p.box(id, x, y, w, .0015, color ?? p.ink);
  void art(_Sheet p, String id, double x, double y, double w, double h) =>
      p._add(id, 'sticker', x, y, w, h, {
        'imageUrl': 'asset:$proseStudyPattern',
        'frame': 'rasterCover',
      });
  void finish(_Sheet p, String name, String role) {
    if (pages.isNotEmpty) {
      final left = pages.length.isOdd;
      t(
        p,
        'folio',
        '${pages.length}'.padLeft(2, '0'),
        left ? .07 : .84,
        .955,
        .09,
        .029,
        size: .017,
        align: left ? 'left' : 'right',
      );
      t(
        p,
        'running_title',
        proseStudyTitle,
        left ? .60 : .12,
        .957,
        .27,
        .027,
        size: .015,
        align: left ? 'right' : 'left',
      );
    }
    pages.add({
      ...p.json,
      'name': name,
      'role': role,
      'side': pages.isEmpty
          ? 'cover'
          : pages.length.isOdd
          ? 'left'
          : 'right',
      'spreadIndex': pages.isEmpty ? 0 : (pages.length + 1) ~/ 2,
    });
  }

  // The jacket and its editable display type share an original endpaper.
  var p = sheet(paper, red);
  art(p, 'jacket', 0, 0, 1, 1);
  p.box('title_stock', .055, .055, .89, .89, paper);
  rule(p, 'top_rule', .12, .14, .76, red);
  t(
    p,
    'cover_edition',
    '우리 둘의 사진 기록',
    .12,
    .083,
    .76,
    .042,
    size: .023,
    align: 'center',
  );
  display(
    p,
    'cover_heading',
    copy.heading,
    .12,
    .205,
    .76,
    .12,
    size: math.min(.086, .72 / math.max(1, copy.heading.runes.length)),
    font: 'Eulyoo',
    align: 'center',
  );
  display(
    p,
    'cover_keyword',
    copy.keyword,
    .10,
    .355,
    .80,
    .30,
    size: math.min(.29, .76 / math.max(2, copy.keyword.runes.length)),
    pattern: true,
    align: 'center',
  );
  t(
    p,
    'cover_preline',
    '평범한 하루까지, 오래 남기고 싶어서.',
    .12,
    .693,
    .76,
    .05,
    size: .027,
    align: 'center',
  );
  rule(p, 'imprint_rule', .12, .79, .76, red);
  t(
    p,
    'cover_names',
    copy.names,
    .12,
    .83,
    .76,
    .044,
    size: .026,
    align: 'center',
  );
  t(
    p,
    'cover_date',
    copy.date,
    .12,
    .89,
    .76,
    .031,
    size: .019,
    align: 'center',
  );
  finish(p, proseStudyStyles[0], 'pattern-lettered-jacket');

  // A detail, chapter numeral and arranged phrase oppose a patterned arch.
  p = sheet();
  t(p, 'chapter', '함께 웃던 날', .08, .06, .32, .04, size: .022, color: red);
  display(
    p,
    'chapter_number',
    '01',
    .07,
    .13,
    .29,
    .18,
    size: .18,
    font: 'Cormorant Garamond',
    color: red,
  );
  t(
    p,
    'opening_note',
    '준비한 표정 밖에\n우리가 있었다.',
    .08,
    .335,
    .30,
    .09,
    size: .024,
    color: muted,
  );
  p.photo(
    'opening_detail',
    '${_editorial}petal_veil.png',
    .47,
    .07,
    .40,
    .35,
    shape: 'studyArchWindow',
  );
  rule(p, 'chapter_rule', .08, .46, .79, red);
  display(p, 'cascade_a', '너에게', .08, .505, .79, .16, size: .155, color: red);
  display(
    p,
    'cascade_b',
    '기울어진',
    .28,
    .68,
    .59,
    .10,
    size: .084,
    font: 'Eulyoo',
    color: red,
  );
  display(p, 'cascade_c', '하루', .08, .79, .47, .15, size: .147, pattern: true);
  t(
    p,
    'cascade_note',
    '사진을 찍던 네가 웃어서,\n나는 포즈를 잊었다.',
    .58,
    .836,
    .29,
    .08,
    size: .020,
    color: muted,
  );
  finish(p, proseStudyStyles[1], 'scene-opening-diptych');
  p = sheet(blue);
  art(p, 'portrait_endpaper', .075, .045, .86, .82);
  p.box('portrait_mat', .105, .075, .81, .76, paper);
  p.photo(
    'portrait',
    '${_editorial}petal_couple.png',
    .13,
    .10,
    .76,
    .71,
    shape: 'studyArchWindow',
  );
  t(
    p,
    'portrait_caption',
    '정해 둔 표정보다, 함께 웃던 순간을 골랐다.',
    .12,
    .89,
    .79,
    .042,
    size: .023,
  );
  finish(p, '준비하지 않은 표정', 'patterned-arch-portrait');

  // The archive uses independently editable prints with bounded rotations.
  p = sheet(blue);
  t(p, 'archive_kicker', '둘이 모은 작은 장면들', .08, .055, .79, .04, size: .023);
  rule(p, 'archive_rule', .08, .125, .79);
  p.photo(
    'together',
    '${_editorial}couple_walk.png',
    .095,
    .185,
    wide ? .43 : .55,
    wide ? .55 : .51,
    shape: 'studyFloatMount',
    rotation: -3,
  );
  p.photo(
    'collected_light',
    '${_editorial}petal_bouquet.png',
    wide ? .59 : .66,
    wide ? .19 : .23,
    wide ? .27 : .19,
    wide ? .29 : .20,
    shape: 'studyNotchedMat',
    rotation: 3,
  );
  t(
    p,
    'archive_no',
    '장면 01\n속도를 맞추는 일',
    wide ? .59 : .67,
    wide ? .53 : .49,
    wide ? .27 : .19,
    .12,
    size: .021,
    color: red,
  );
  t(
    p,
    'archive_caption',
    '서로의 걸음에 맞추다 보니\n지나쳤을 풍경들이 보였다.',
    .10,
    .745,
    .77,
    .08,
    size: .025,
  );
  display(p, 'bold_word', '나란히', .08, .84, .55, .10, size: .096, color: red);
  t(
    p,
    'archive_date',
    copy.date,
    .65,
    .864,
    .22,
    .045,
    size: .019,
    align: 'right',
  );
  finish(p, proseStudyStyles[2], 'collected-photo-archive');

  // A paired still-life mount holds the memory; type is no longer a poster.
  p = sheet(ink, paper);
  t(
    p,
    'memory_heading',
    '나란히 앉은 오후',
    .12,
    .055,
    .79,
    .05,
    size: .031,
    font: 'Eulyoo',
  );
  p.photo(
    'evening_scene',
    '${_editorial}petal_evening.png',
    .12,
    .14,
    .50,
    .40,
    shape: 'studyFloatMount',
  );
  p.photo(
    'evening_detail',
    '${_editorial}petal_details.png',
    .65,
    .14,
    .26,
    .40,
    shape: 'studyNotchedMat',
  );
  t(p, 'memory_label', '사진 밖에 남아 있는 기억', .12, .585, .79, .042, size: .020);
  display(
    p,
    'promise',
    copy.promise,
    .12,
    .65,
    .79,
    .205,
    size: .057,
    font: 'Eulyoo',
  );
  rule(p, 'memory_rule', .12, .88, .79, '#788E83');
  t(p, 'promise_date', copy.date, .12, .902, .35, .035, size: .021);
  t(
    p,
    'promise_names',
    copy.names,
    .52,
    .898,
    .39,
    .039,
    size: .024,
    font: 'Eulyoo',
    align: 'right',
  );
  finish(p, proseStudyStyles[3], 'paired-still-life-memory');

  // Rules follow the actual physical leading and remain below editable text.
  p = sheet(blue);
  p.box('letter_stock', .045, .045, .86, .885, paper);
  p.box('letter_margin', .105, .12, .0015, .75, '#C9A3AB');
  t(
    p,
    'letter_kicker',
    '말로 다 하지 못한 마음',
    .15,
    .09,
    .69,
    .04,
    size: .021,
    color: red,
  );
  display(
    p,
    'letter_title',
    '당신에게,',
    .15,
    .185,
    .68,
    .14,
    size: .10,
    color: red,
  );
  final leading =
      math.min(aspect.canvas.width, aspect.canvas.height) * .028 * 1.75;
  for (var i = 1; i <= (aspect.canvas.height * .42 / leading).floor(); i++) {
    rule(
      p,
      'letter_rule_$i',
      .15,
      .39 + i * leading / aspect.canvas.height,
      .68,
      '#DFE4DE',
    );
  }
  t(
    p,
    'letter_body',
    copy.letter,
    .15,
    .39,
    .68,
    .43,
    size: .028,
    font: 'Eulyoo',
    leading: 1.75,
  );
  t(
    p,
    'letter_signature',
    copy.names,
    .40,
    .86,
    .43,
    .046,
    size: .026,
    font: 'Eulyoo',
    align: 'right',
    color: red,
  );
  finish(p, proseStudyStyles[4], 'ruled-correspondence');

  // The photograph closes the book; the sign-off remains short and editable.
  p = sheet();
  p.photo(
    'keepsake',
    '${_editorial}couple_anniversary.png',
    .13,
    .09,
    wide ? .45 : .78,
    wide ? .78 : .61,
    shape: 'studyFloatMount',
  );
  t(
    p,
    'closing_preline',
    wide ? '함께한 날을\n오래 남기며' : '함께한 날을 오래 남기며',
    wide ? .65 : .12,
    wide ? .20 : .757,
    wide ? .27 : .79,
    wide ? .11 : .05,
    size: .025,
    font: 'Eulyoo',
    color: red,
  );
  display(
    p,
    'closing_line',
    wide ? copy.closing.replaceFirst(', ', ',\n') : copy.closing,
    wide ? .65 : .12,
    wide ? .40 : .82,
    wide ? .27 : .79,
    wide ? .25 : .095,
    size: wide
        ? .064
        : math.min(.078, .76 / math.max(8, copy.closing.runes.length)),
    color: red,
    font: 'Eulyoo',
  );
  t(
    p,
    'closing_names',
    copy.names,
    wide ? .65 : .52,
    wide ? .75 : .921,
    wide ? .27 : .39,
    .03,
    size: .019,
    align: wide ? 'left' : 'right',
  );
  finish(p, proseStudyStyles[5], 'photographic-sign-off');

  return {
    'id': 'snapfit_prose_study_${aspect.name}',
    'collectionId': proseStudyId,
    'title': proseStudyTitle,
    'source': 'snapfit-authored-study',
    'aiGenerated': false,
    'artworkAuthorship': 'imagegen-original',
    'version': 3,
    'accessTier': 'free',
    'publicationStatus': 'design-study',
    'catalogPublishable': false,
    'approvalStatus': 'accepted-as-free',
    'innerPageCount': 6,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'letteringStyles': proseStudyStyles,
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
    'chapters': [
      for (final e in proseStudySpreads.indexed)
        {'title': e.$2, 'from': e.$1 * 2 + 1, 'to': e.$1 * 2 + 2},
    ],
  };
}

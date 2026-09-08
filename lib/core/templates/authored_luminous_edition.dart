part of 'authored_collections.dart';

const luminousEditionId = 'luminous-edition';
const luminousEditionTitle = '겹쳐진 순간';
const luminousEditionSpreads = ['가장 가까운 장면들'];
const luminousEditionInnerPageCount = 2;

class LuminousCopy {
  const LuminousCopy({
    this.first = '겹쳐진',
    this.second = '순',
    this.third = '간',
    this.names = '서연과 지우',
    this.date = '2026. 10. 17',
  });
  final String first, second, third, names, date;
}

/// Three art-direction proofs; archived materials remain independent of this study.
Map<String, dynamic> buildLuminousEdition(
  CollectionAspect aspect, {
  LuminousCopy copy = const LuminousCopy(),
}) {
  const ink = '#191C1B', paper = '#F1F2EE';
  final pages = <Map<String, dynamic>>[];
  _Sheet sheet(String color) =>
      _Sheet(luminousEditionId, aspect, pages.length, color, ink: ink);

  void photo(
    _Sheet p,
    String id,
    String file,
    Rect r, {
    String frame = 'none',
    double angle = 0,
  }) => p.photo(
    id,
    '$_editorial$file.png',
    r.left,
    r.top,
    r.width,
    r.height,
    shape: frame,
    rotation: angle,
  );

  void print(
    _Sheet p,
    String id,
    String file,
    Rect r, {
    double angle = 0,
    String mount = paper,
  }) {
    // Rotate the mount and photograph about the same physical center.
    p.box('${id}_mount', r.left, r.top, r.width, r.height, mount);
    p.layers.last['rotation'] = angle;
    const inset = .006;
    final dy = inset * aspect.canvas.aspectRatio;
    photo(
      p,
      id,
      file,
      Rect.fromLTWH(
        r.left + inset,
        r.top + dy,
        r.width - 2 * inset,
        r.height - 2 * dy,
      ),
      angle: angle,
    );
  }

  void type(
    _Sheet p,
    String id,
    String text,
    Rect r, {
    double size = .023,
    String font = 'NotoSans',
    String color = ink,
    int weight = 400,
  }) {
    p.text(
      id,
      text,
      r.left,
      r.top,
      r.width,
      r.height,
      size: size,
      font: font,
      color: color,
      weight: weight,
      lineHeight: 1.08,
    );
  }

  void rule(_Sheet p, String id, Rect r, [String color = ink]) =>
      p.box(id, r.left, r.top, r.width, r.height, color);

  void finish(_Sheet p, String role) => pages.add({
    ...p.json,
    'name': p.index == 0 ? luminousEditionTitle : '가장 가까운 장면들 ${p.index}',
    'role': role,
    'side': p.index == 0 ? 'cover' : (p.index.isOdd ? 'left' : 'right'),
    'spreadIndex': p.index == 0 ? 0 : 1,
  });

  // A single photograph carries the cover; only the personal title and credits remain.
  var p = sheet(paper);
  photo(
    p,
    'cover_people',
    'couple_walk',
    const Rect.fromLTWH(.032, .028, .936, .714),
  );
  type(
    p,
    'cover_first',
    copy.first,
    const Rect.fromLTWH(.047, .777, .85, .058),
    size: .041,
    font: 'Eulyoo',
  );
  type(
    p,
    'cover_title',
    '${copy.second}${copy.third}',
    const Rect.fromLTWH(.043, .834, .90, .113),
    size: math.min(.10, .76 / (copy.second + copy.third).runes.length),
    font: 'RiaSans',
  );
  type(
    p,
    'cover_names',
    copy.names,
    const Rect.fromLTWH(.048, .960, .54, .027),
    size: .0155,
  );
  type(
    p,
    'cover_date',
    copy.date,
    const Rect.fromLTWH(.696, .960, .275, .027),
    size: .0155,
  );
  finish(p, 'single-photo-editorial-cover');

  // Left: photographs fill the space previously occupied by decorative copy.
  p = sheet(ink);
  type(
    p,
    'chapter',
    copy.names,
    const Rect.fromLTWH(.038, .027, .79, .05),
    size: .029,
    font: 'Eulyoo',
    color: paper,
  );
  type(
    p,
    'index',
    '01',
    const Rect.fromLTWH(.885, .033, .077, .036),
    size: .018,
    font: 'Poppins',
    color: paper,
  );
  rule(p, 'title_rule', const Rect.fromLTWH(.039, .09, .93, .0015), '#68716B');
  photo(
    p,
    'cafe_scene',
    'couple_cafe',
    const Rect.fromLTWH(.04, .113, .682, .716),
  );
  photo(
    p,
    'street_scene',
    'travel_street',
    const Rect.fromLTWH(.741, .112, .22, .391),
  );
  print(
    p,
    'table_scene',
    'small_days_breakfast',
    const Rect.fromLTWH(.568, .513, .395, .32),
    angle: 3,
    mount: '#DEE1D4',
  );
  rule(p, 'contact_paper', const Rect.fromLTWH(.022, .707, .79, .235), paper);
  final contactFiles = [
    'couple_anniversary',
    'daily_book',
    'couple_keepsakes',
    'journey_train',
  ];
  for (final shot in contactFiles.indexed) {
    photo(
      p,
      'contact_${shot.$1}',
      shot.$2,
      Rect.fromLTWH(.032 + shot.$1 * .194, .717, .18, .21),
    );
  }
  type(
    p,
    'folio',
    copy.date,
    const Rect.fromLTWH(.041, .964, .80, .026),
    size: .016,
    color: '#BFC8C1',
  );
  finish(p, 'dark-contact-sheet');

  // Right: retain the offset photo structure without slogans or colored labels.
  p = sheet('#E3E7DF');
  type(
    p,
    'folio_top',
    copy.names,
    const Rect.fromLTWH(.039, .026, .80, .043),
    size: .019,
  );
  type(
    p,
    'index',
    '02',
    const Rect.fromLTWH(.90, .026, .062, .036),
    size: .018,
    font: 'Poppins',
  );
  rule(p, 'top_rule', const Rect.fromLTWH(.04, .081, .926, .0015), '#87938A');
  photo(
    p,
    'cafe_field',
    'travel_cafe',
    const Rect.fromLTWH(.334, .103, .636, .807),
  );
  print(
    p,
    'cafe_print',
    'couple_anniversary',
    const Rect.fromLTWH(.045, .12, .544, .388),
    angle: -2,
  );
  photo(
    p,
    'book_fragment',
    'daily_book',
    const Rect.fromLTWH(.046, .524, .25, .33),
    frame: 'studioTorn',
  );
  print(
    p,
    'sea_fragment',
    'travel_coast',
    const Rect.fromLTWH(.584, .412, .365, .264),
    angle: 2,
  );
  print(
    p,
    'table_fragment',
    'small_days_breakfast',
    const Rect.fromLTWH(.32, .659, .379, .255),
    angle: -3,
  );
  photo(
    p,
    'small_detail',
    'daily_fruit',
    const Rect.fromLTWH(.758, .753, .173, .138),
  );
  type(
    p,
    'closing_detail',
    copy.date,
    const Rect.fromLTWH(.041, .964, .90, .026),
    size: .016,
  );
  finish(p, 'offset-photo-fragments');

  return {
    'id': 'snapfit_luminous_study_${aspect.name}',
    'collectionId': luminousEditionId,
    'title': luminousEditionTitle,
    'source': 'snapfit-authored-study',
    'aiGenerated': false,
    'assetProvenance': 'generated-ornaments-human-authored-layout',
    'version': 5,
    'accessTier': 'unassigned',
    'publicationStatus': 'design-study',
    'catalogPublishable': false,
    'approvalStatus': 'awaiting-user-review',
    'innerPageCount': luminousEditionInnerPageCount,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
    'chapters': [
      {'title': luminousEditionSpreads.single, 'from': 1, 'to': 2},
    ],
  };
}

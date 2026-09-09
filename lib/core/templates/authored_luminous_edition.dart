part of 'authored_collections.dart';

const luminousEditionId = 'luminous-edition';
const luminousEditionTitle = '둘만의 여행';
const luminousEditionSpreads = [
  '도착한 곳, 챙겨 온 것',
  '골목의 장면과 카페',
  '해변과 짧은 편지',
  '사진 한 장, 엽서 한 장',
];
const luminousEditionInnerPageCount = 8;

class LuminousCopy {
  const LuminousCopy({
    this.first = '둘만의',
    this.second = '여',
    this.third = '행',
    this.names = '서연과 지우',
    this.date = '2026. 10. 17',
  });
  final String first, second, third, names, date;
}

/// Four contrasting spread studies; the approved 20-page edition is archived.
Map<String, dynamic> buildLuminousEdition(
  CollectionAspect aspect, {
  LuminousCopy copy = const LuminousCopy(),
}) {
  const ink = '#294C4C', paper = '#F1F2EE';
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
    file.startsWith('assets/') ? file : '$_editorial$file.png',
    r.left,
    r.top,
    r.width,
    r.height,
    shape: frame,
    rotation: angle,
  );

  void print(_Sheet p, String id, String file, Rect r, {double angle = 0}) {
    // The photograph and mount share a center when rotated as separate layers.
    p.box('${id}_mount', r.left, r.top, r.width, r.height, '#F8F9F4');
    p.layers.last['rotation'] = angle;
    const inset = .009;
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

  Rect material(
    _Sheet p,
    String id,
    String key,
    Rect bounds, {
    double angle = 0,
  }) {
    final ratio = studioDecorationById(key)!.aspectRatio;
    final w = math.min(
      bounds.width,
      bounds.height * ratio / aspect.canvas.aspectRatio,
    );
    final h = w * aspect.canvas.aspectRatio / ratio;
    final r = Rect.fromLTWH(bounds.left, bounds.top, w, h);
    p.material(id, key, r.left, r.top, r.width, h: r.height, rotation: angle);
    return r;
  }

  void type(
    _Sheet p,
    String id,
    String text,
    Rect r, {
    double size = .023,
    String font = 'NotoSans',
    String color = ink,
    String? overlayImageId,
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
      lineHeight: 1.08,
    );
    if (overlayImageId != null)
      p.layers.last['overlayImageId'] = overlayImageId;
  }

  void finish(_Sheet p, String role) => pages.add({
    ...p.json,
    'name': p.index == 0
        ? luminousEditionTitle
        : '${luminousEditionSpreads[(p.index - 1) ~/ 2]} ${p.index}',
    'role': role,
    'side': p.index == 0 ? 'cover' : (p.index.isOdd ? 'left' : 'right'),
    'spreadIndex': p.index == 0 ? 0 : (p.index + 1) ~/ 2,
  });

  // Keep the sky free for editable type; no montage, frame or label on the cover.
  var p = sheet(paper);
  photo(p, 'cover_people', 'couple_walk', const Rect.fromLTWH(0, 0, 1, 1));
  final coverImageId = p.layers.last['id'] as String;
  type(
    p,
    'cover_first',
    copy.first,
    const Rect.fromLTWH(.078, .053, .84, .057),
    size: .037,
    font: 'Eulyoo',
    overlayImageId: coverImageId,
  );
  type(
    p,
    'cover_title',
    '${copy.second}${copy.third}',
    const Rect.fromLTWH(.074, .117, .84, .13),
    size: math.min(.105, .72 / (copy.second + copy.third).runes.length),
    font: 'Eulyoo',
    overlayImageId: coverImageId,
  );
  type(
    p,
    'cover_names',
    copy.names,
    const Rect.fromLTWH(.078, .918, .52, .041),
    size: .020,
    color: '#243A38',
    overlayImageId: coverImageId,
  );
  type(
    p,
    'cover_date',
    copy.date,
    const Rect.fromLTWH(.660, .925, .27, .028),
    size: .016,
    color: '#243A38',
    overlayImageId: coverImageId,
  );
  finish(p, 'full-bleed-travel-cover');

  // A continuous image field paired with a document pocket, not two collages.
  p = sheet('#EFF1EC');
  photo(p, 'arrival_sea', 'travel_coast', const Rect.fromLTWH(0, 0, 1, .87));
  material(
    p,
    'coastal_note',
    'travelContourSlip',
    const Rect.fromLTWH(.72, .71, .24, .17),
    angle: 4,
  );
  material(
    p,
    'arrival_ticket',
    'studioTravelTicket',
    const Rect.fromLTWH(.07, .77, .44, .12),
    angle: -3,
  );
  p.box('caption_stock', 0, .89, 1, .11, '#EFF1EC');
  type(
    p,
    'arrival_caption',
    '기차에서 내려 처음 마주한 바다',
    const Rect.fromLTWH(.07, .929, .77, .039),
    size: .026,
    font: 'Eulyoo',
  );
  finish(p, 'immersive-landscape');

  p = sheet('#DAE5DF');
  type(
    p,
    'folio_heading',
    '도착한 날의 기록',
    const Rect.fromLTWH(.08, .055, .79, .08),
    size: .043,
    font: 'Eulyoo',
  );
  material(
    p,
    'map_insert',
    'studioTravelMap',
    const Rect.fromLTWH(.36, .15, .55, .40),
    angle: 3,
  );
  p.box('itinerary_shadow', .112, .184, .43, .478, '#BECAC0');
  p.box('itinerary', .1, .175, .43, .478, '#F5F5ED');
  type(
    p,
    'itinerary_label',
    '여행 수첩',
    const Rect.fromLTWH(.14, .222, .34, .045),
    size: .027,
    font: 'Eulyoo',
  );
  p.box('itinerary_rule', .14, .294, .33, .0015, '#AEBEB3');
  for (final row in [
    ('01', '바다가 보이는 기차', .335),
    ('02', '짐을 내려놓은 숙소', .429),
    ('03', '걸어서 한 바퀴', .523),
  ]) {
    type(
      p,
      'route_number_${row.$1}',
      row.$1,
      Rect.fromLTWH(.14, row.$3, .06, .038),
      size: .018,
    );
    type(
      p,
      'route_text_${row.$1}',
      row.$2,
      Rect.fromLTWH(.215, row.$3, .28, .064),
      size: .020,
    );
  }
  print(
    p,
    'arrival_print',
    'journey_train',
    const Rect.fromLTWH(.565, .344, .32, .335),
    angle: 0,
  );
  material(
    p,
    'print_tape',
    'studioWashiIndigo',
    const Rect.fromLTWH(.625, .329, .21, .047),
    angle: 3,
  );
  material(
    p,
    'pocket',
    'travelDocumentPocket',
    const Rect.fromLTWH(.08, .625, .84, .35),
  );
  material(
    p,
    'luggage',
    'travelLuggageLabel',
    const Rect.fromLTWH(.19, .705, .45, .145),
    angle: -4,
  );
  material(
    p,
    'room_key',
    'travelStayTag',
    const Rect.fromLTWH(.72, .692, .16, .225),
    angle: 5,
  );
  type(
    p,
    'folio_date',
    copy.date,
    const Rect.fromLTWH(.10, .944, .5, .028),
    size: .017,
  );
  finish(p, 'itinerary-pocket');

  // Narrow proof strips are aligned to one rail; notes occupy a separate margin.
  p = sheet('#ECEDE8');
  type(
    p,
    'contact_heading',
    '골목에서 고른 장면',
    const Rect.fromLTWH(.08, .055, .84, .09),
    size: .043,
    font: 'Eulyoo',
  );
  p.box('contact_rail', .075, .186, .62, .689, '#263F3C');
  for (final shot in [
    ('01', 'travel_street', '숙소 앞\n자전거', .208),
    ('02', 'journey_market', '모퉁이\n작은 가게', .432),
    ('03', 'daily_fruit', '종이봉투에\n담아 온 과일', .656),
  ]) {
    photo(
      p,
      'contact_${shot.$1}',
      shot.$2,
      Rect.fromLTWH(.105, shot.$4, .56, .195),
    );
    type(
      p,
      'contact_index_${shot.$1}',
      shot.$1,
      Rect.fromLTWH(.744, shot.$4 + .006, .18, .044),
      size: .030,
      font: 'Eulyoo',
    );
    type(
      p,
      'contact_note_${shot.$1}',
      shot.$3,
      Rect.fromLTWH(.744, shot.$4 + .064, .20, .111),
      size: .021,
    );
    for (var hole = 0; hole < 4; hole++) {
      p.box(
        'perforation_${shot.$1}_$hole',
        .080,
        shot.$4 + .025 + hole * .044,
        .012,
        .017,
        '#E7EAE1',
      );
    }
  }
  material(
    p,
    'contact_tape',
    'studioWashiSage',
    const Rect.fromLTWH(.27, .159, .25, .046),
  );
  type(
    p,
    'contact_date',
    copy.date,
    const Rect.fromLTWH(.08, .932, .70, .03),
    size: .017,
  );
  finish(p, 'annotated-contact-strips');

  // A circular table vignette balances the rigid contact sheet opposite it.
  p = sheet('#E3E7DD');
  material(
    p,
    'cafe_mat',
    'studioCottonRag',
    const Rect.fromLTWH(.035, .12, .90, .69),
    angle: -4,
  );
  material(
    p,
    'cafe_ledger',
    'studioLedger',
    const Rect.fromLTWH(.40, .08, .46, .50),
    angle: 5,
  );
  material(
    p,
    'cafe_receipt',
    'travelCafeReceipt',
    const Rect.fromLTWH(.73, .20, .20, .60),
    angle: 4,
  );
  final circleWidth = math.min(.66, .57 / aspect.canvas.aspectRatio);
  final circleHeight = circleWidth * aspect.canvas.aspectRatio;
  final circleRect = Rect.fromLTWH(
    .415 - circleWidth / 2,
    .49 - circleHeight / 2,
    circleWidth,
    circleHeight,
  );
  material(
    p,
    'coaster',
    'travelCafeCoaster',
    Rect.fromCenter(
      center: Offset(.415, .49),
      width: circleWidth + .04,
      height: circleHeight + .04 * aspect.canvas.aspectRatio,
    ),
  );
  photo(
    p,
    'cafe_table',
    'small_days_breakfast',
    circleRect,
    frame: 'studioOval',
  );
  material(
    p,
    'cafe_stub',
    'studioTravelTicket',
    const Rect.fromLTWH(.35, .747, .50, .14),
    angle: -3,
  );
  material(
    p,
    'cafe_cancel',
    'studioPostalMark',
    const Rect.fromLTWH(.075, .752, .30, .115),
    angle: -5,
  );
  type(
    p,
    'cafe_caption',
    '시장 뒤 작은 카페',
    const Rect.fromLTWH(.095, .906, .81, .07),
    size: .037,
    font: 'Eulyoo',
  );
  finish(p, 'circular-table-still-life');

  // The photograph crosses the entire page; the facing page carries no photo.
  p = sheet('#E8EEF0');
  type(
    p,
    'coast_heading',
    '해변에서 보낸 하루',
    const Rect.fromLTWH(.065, .08, .85, .09),
    size: .047,
    font: 'Eulyoo',
  );
  type(
    p,
    'coast_day',
    copy.date,
    const Rect.fromLTWH(.069, .191, .80, .033),
    size: .017,
  );
  photo(
    p,
    'wide_shore',
    'travel_harbor',
    const Rect.fromLTWH(0, .278, 1, .458),
  );
  material(
    p,
    'coast_sheet',
    'travelContourSlip',
    const Rect.fromLTWH(.057, .689, .43, .245),
    angle: -3,
  );
  material(
    p,
    'coast_postage',
    'studioCoastStamp',
    const Rect.fromLTWH(.805, .705, .12, .145),
    angle: 4,
  );
  material(
    p,
    'coast_cancel',
    'studioPostalMark',
    const Rect.fromLTWH(.65, .797, .28, .13),
    angle: -2,
  );
  type(
    p,
    'coast_note',
    '항구를 지나, 해변까지 걸었다.',
    const Rect.fromLTWH(.32, .935, .62, .032),
    size: .021,
  );
  finish(p, 'edge-to-edge-panorama');

  p = sheet('#DEE7E9');
  material(
    p,
    'letter_underlay',
    'studioBlueFibre',
    const Rect.fromLTWH(.065, .055, .88, .85),
    angle: 2,
  );
  p.box('letter_shadow', .120, .129, .767, .704, '#C5D3D2');
  p.box('letter_stock', .104, .113, .767, .704, '#F7F7F0');
  p.box('letter_fold', .105, .59, .765, .0013, '#E2E5DB');
  type(
    p,
    'letter_date',
    copy.date,
    const Rect.fromLTWH(.165, .161, .43, .031),
    size: .017,
  );
  type(
    p,
    'letter_heading',
    '여기서 보낸 하루',
    const Rect.fromLTWH(.165, .246, .64, .070),
    size: .037,
    font: 'Eulyoo',
  );
  p.text(
    'letter_body',
    '신발을 벗고 물가까지 걸었다.\n사진을 찍고는 한참을 그냥 앉아 있었다.\n돌아가는 길에 엽서를 한 장 골랐다.',
    .165,
    .371,
    .63,
    .205,
    size: .024,
    font: 'Eulyoo',
    lineHeight: 1.65,
  );
  type(
    p,
    'letter_sign',
    copy.names,
    const Rect.fromLTWH(.165, .680, .64, .055),
    size: .029,
    font: 'Eulyoo',
  );
  material(
    p,
    'letter_corner',
    'studioWashiSage',
    const Rect.fromLTWH(.665, .094, .225, .043),
    angle: 14,
  );
  material(
    p,
    'letter_envelope',
    'studioGlassineEnvelope',
    const Rect.fromLTWH(.335, .785, .58, .175),
    angle: -3,
  );
  material(
    p,
    'letter_stamp',
    'studioCoastStamp',
    const Rect.fromLTWH(.175, .782, .125, .137),
    angle: -4,
  );
  finish(p, 'folded-personal-letter');

  // A tall print and a horizontal postcard deliberately use different mounts.
  p = sheet('#CCDADB');
  material(
    p,
    'portrait_fiber',
    'studioBlueFibre',
    const Rect.fromLTWH(.07, .08, .87, .78),
    angle: -2,
  );
  p.box('portrait_mount', .203, .072, .584, .77, '#F7F7F0');
  p.box('portrait_border', .221, .089, .548, .714, '#526E6A');
  photo(
    p,
    'last_portrait',
    'couple_walk',
    const Rect.fromLTWH(.232, .100, .526, .691),
    frame: 'studioTorn',
  );
  material(
    p,
    'portrait_tape',
    'studioWashiIndigo',
    const Rect.fromLTWH(.374, .061, .247, .045),
    angle: -2,
  );
  material(
    p,
    'portrait_tag',
    'travelLuggageLabel',
    const Rect.fromLTWH(.565, .804, .38, .097),
    angle: 3,
  );
  type(
    p,
    'portrait_caption',
    '여행 끝에 남긴 우리 사진',
    const Rect.fromLTWH(.08, .926, .79, .061),
    size: .032,
    font: 'Eulyoo',
  );
  finish(p, 'archival-portrait-mat');

  p = sheet('#E5EBE5');
  material(
    p,
    'postcard_back',
    'travelPostcard',
    const Rect.fromLTWH(.126, .115, .754, .49),
    angle: -5,
  );
  material(
    p,
    'postcard_vellum',
    'studioVellum',
    const Rect.fromLTWH(.055, .275, .87, .65),
    angle: 2,
  );
  print(
    p,
    'posted_sea',
    'travel_coast',
    const Rect.fromLTWH(.09, .242, .82, .433),
  );
  p.box('postcard_label', .09, .675, .82, .12, '#F8F9F4');
  type(
    p,
    'postcard_message',
    '다음에는 조금 더 오래 머물자.',
    const Rect.fromLTWH(.14, .709, .72, .06),
    size: .030,
    font: 'Eulyoo',
  );
  material(
    p,
    'postcard_tape',
    'studioWashiSage',
    const Rect.fromLTWH(.13, .220, .24, .05),
    angle: -9,
  );
  material(
    p,
    'postcard_postage',
    'studioCoastStamp',
    const Rect.fromLTWH(.791, .12, .125, .14),
    angle: 4,
  );
  material(
    p,
    'postcard_cancel',
    'studioPostalMark',
    const Rect.fromLTWH(.625, .137, .25, .115),
    angle: -2,
  );
  type(
    p,
    'postcard_names',
    copy.names,
    const Rect.fromLTWH(.12, .904, .49, .035),
    size: .018,
  );
  type(
    p,
    'postcard_date',
    copy.date,
    const Rect.fromLTWH(.64, .905, .30, .035),
    size: .017,
  );
  finish(p, 'mounted-postcard');

  return {
    'id': 'snapfit_luminous_study_${aspect.name}',
    'collectionId': luminousEditionId,
    'title': luminousEditionTitle,
    'source': 'snapfit-authored-study',
    'aiGenerated': false,
    'assetProvenance': 'generated-ornaments-human-authored-layout',
    'version': 8,
    'studyScope': 'four-contrasting-spreads',
    'archivedEdition': 'travel-keepsake-20',
    'accessTier': 'unassigned',
    'publicationStatus': 'design-study',
    'catalogPublishable': false,
    'approvalStatus': 'approved-design-study',
    'approvedAt': '2026-09-09',
    'approvalScope': 'cover-and-eight-inner-pages',
    'innerPageCount': luminousEditionInnerPageCount,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
    'chapters': [
      for (final chapter in luminousEditionSpreads.indexed)
        {
          'title': chapter.$2,
          'from': chapter.$1 * 2 + 1,
          'to': chapter.$1 * 2 + 2,
        },
    ],
  };
}

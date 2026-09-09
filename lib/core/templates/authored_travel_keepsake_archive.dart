part of 'authored_collections.dart';

const travelKeepsakeArchiveId = 'luminous-edition';
const travelKeepsakeArchiveTitle = '둘만의 여행';
const travelKeepsakeArchiveSpreads = [
  '여행에서 모은 것들',
  '짐을 내려놓고',
  '골목과 시장',
  '카페에 머문 시간',
  '해변을 따라',
  '작은 발견들',
  '둘이 남긴 사진',
  '해가 지는 시간',
  '돌아오는 길',
  '여행을 꺼내 보는 날',
];
const travelKeepsakeArchiveInnerPageCount = 20;

class TravelKeepsakeCopy {
  const TravelKeepsakeCopy({
    this.first = '둘만의',
    this.second = '여',
    this.third = '행',
    this.names = '서연과 지우',
    this.date = '2026. 10. 17',
  });
  final String first, second, third, names, date;
}

/// An authored travel album; the approved cover and opening spread stay intact.
Map<String, dynamic> buildTravelKeepsakeArchive(
  CollectionAspect aspect, {
  TravelKeepsakeCopy copy = const TravelKeepsakeCopy(),
}) {
  const ink = '#294C4C', paper = '#F1F2EE';
  final pages = <Map<String, dynamic>>[];
  _Sheet sheet(String color) =>
      _Sheet(travelKeepsakeArchiveId, aspect, pages.length, color, ink: ink);

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
        ? travelKeepsakeArchiveTitle
        : '${travelKeepsakeArchiveSpreads[(p.index - 1) ~/ 2]} ${p.index}',
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

  // Left: a route, two photographs and travel ephemera, collected on one sheet.
  p = sheet('#E9EDE9');
  material(
    p,
    'rag_underlay',
    'studioCottonRag',
    const Rect.fromLTWH(.035, .11, .89, .78),
    angle: -2,
  );
  material(
    p,
    'folded_map',
    'studioTravelMap',
    const Rect.fromLTWH(.19, .13, .75, .72),
    angle: 3,
  );
  material(
    p,
    'translucent_leaf',
    'studioVellum',
    const Rect.fromLTWH(.055, .25, .51, .56),
    angle: -3,
  );
  print(
    p,
    'window_scene',
    'journey_train',
    const Rect.fromLTWH(.092, .22, .65, .395),
    angle: -2,
  );
  material(
    p,
    'window_tape',
    'studioWashiSage',
    const Rect.fromLTWH(.30, .198, .22, .065),
    angle: 3,
  );
  photo(
    p,
    'street_fragment',
    'travel_street',
    const Rect.fromLTWH(.624, .51, .285, .31),
    frame: 'studioTorn',
    angle: 3,
  );
  material(
    p,
    'street_tape',
    'studioWashiIndigo',
    const Rect.fromLTWH(.77, .79, .14, .05),
    angle: -4,
  );
  final ticket = material(
    p,
    'travel_pass',
    'studioTravelTicket',
    const Rect.fromLTWH(.075, .672, .50, .235),
    angle: 0,
  );
  type(
    p,
    'ticket_date',
    copy.date,
    Rect.fromLTWH(
      ticket.left + ticket.width * .09,
      ticket.top + ticket.height * .70,
      ticket.width * .64,
      ticket.height * .15,
    ),
    size: .0105,
  );
  material(
    p,
    'coast_stamp',
    'studioCoastStamp',
    const Rect.fromLTWH(.793, .09, .12, .145),
    angle: 4,
  );
  material(
    p,
    'stamp_cancel',
    'studioPostalMark',
    const Rect.fromLTWH(.737, .169, .20, .105),
    angle: -8,
  );
  type(
    p,
    'chapter',
    '바다로 가는 길',
    const Rect.fromLTWH(.065, .055, .73, .049),
    size: .027,
    font: 'Eulyoo',
  );
  type(
    p,
    'index',
    '01',
    const Rect.fromLTWH(.879, .052, .065, .041),
    size: .016,
    font: 'Poppins',
  );
  type(
    p,
    'folio',
    copy.names,
    const Rect.fromLTWH(.068, .945, .84, .034),
    size: .016,
    color: '#607773',
  );
  finish(p, 'map-and-travel-keepsakes');

  // Right: an envelope and a notebook leaf provide a quieter counterweight.
  p = sheet('#E3E9E7');
  material(
    p,
    'fibre_underlay',
    'studioBlueFibre',
    const Rect.fromLTWH(.10, .107, .85, .67),
    angle: 2,
  );
  material(
    p,
    'notebook_leaf',
    'studioLedger',
    const Rect.fromLTWH(.048, .26, .46, .56),
    angle: -3,
  );
  print(
    p,
    'cafe_scene',
    'couple_cafe',
    const Rect.fromLTWH(.275, .168, .637, .408),
    angle: 2,
  );
  material(
    p,
    'cafe_tape',
    'studioWashiIndigo',
    const Rect.fromLTWH(.52, .143, .24, .067),
    angle: -4,
  );
  material(
    p,
    'envelope',
    'studioGlassineEnvelope',
    const Rect.fromLTWH(.477, .592, .43, .326),
    angle: 2,
  );
  material(
    p,
    'kept_ticket',
    'studioTravelTicket',
    const Rect.fromLTWH(.57, .646, .35, .19),
    angle: -4,
  );
  print(
    p,
    'coast_print',
    'travel_coast',
    const Rect.fromLTWH(.072, .505, .405, .315),
    angle: -3,
  );
  material(
    p,
    'coast_tape',
    'studioWashiSage',
    const Rect.fromLTWH(.09, .486, .19, .06),
    angle: -8,
  );
  material(
    p,
    'vellum_corner',
    'studioVellum',
    const Rect.fromLTWH(.382, .718, .17, .18),
    angle: 4,
  );
  material(
    p,
    'envelope_cancel',
    'studioPostalMark',
    const Rect.fromLTWH(.62, .80, .28, .15),
    angle: 5,
  );
  type(
    p,
    'chapter',
    '함께 머문 곳',
    const Rect.fromLTWH(.065, .055, .73, .049),
    size: .027,
    font: 'Eulyoo',
  );
  type(
    p,
    'index',
    '02',
    const Rect.fromLTWH(.879, .052, .065, .041),
    size: .016,
    font: 'Poppins',
  );
  type(
    p,
    'folio',
    copy.date,
    const Rect.fromLTWH(.068, .945, .84, .034),
    size: .016,
    color: '#607773',
  );
  finish(p, 'envelope-and-coastal-prints');

  void item(String key, Rect r, {double angle = 0}) =>
      material(p, '${key}_${p.layers.length}', key, r, angle: angle);
  void closePage(String title, String role) {
    type(
      p,
      'chapter',
      title,
      const Rect.fromLTWH(.065, .055, .73, .049),
      size: .027,
      font: 'Eulyoo',
    );
    type(
      p,
      'index',
      p.index.toString().padLeft(2, '0'),
      const Rect.fromLTWH(.879, .052, .065, .041),
      size: .016,
      font: 'Poppins',
    );
    type(
      p,
      'folio',
      p.index.isOdd ? copy.names : copy.date,
      const Rect.fromLTWH(.068, .945, .84, .034),
      size: .016,
      color: '#607773',
    );
    finish(p, role);
  }

  // 3-4: a key tag and a notebook replace the route and postage of the opening.
  p = sheet('#E8EDE7');
  item('studioCottonRag', const Rect.fromLTWH(.035, .135, .88, .72), angle: -2);
  item('travelNotebook', const Rect.fromLTWH(.33, .17, .56, .64), angle: 2);
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.063, .39, .74, .44),
    angle: -3,
  );
  item('travelStayTag', const Rect.fromLTWH(.766, .145, .14, .25), angle: 5);
  print(
    p,
    'room_book',
    'assets/templates/jeju_travel/images/approved_stock/guesthouse_detail.jpg',
    const Rect.fromLTWH(.10, .22, .60, .465),
    angle: -2,
  );
  print(
    p,
    'breakfast',
    'small_days_breakfast',
    const Rect.fromLTWH(.552, .60, .35, .263),
    angle: 3,
  );
  item('studioWashiSage', const Rect.fromLTWH(.255, .20, .24, .065), angle: 3);
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.723, .827, .13, .04),
    angle: -3,
  );
  item(
    'travelLuggageLabel',
    const Rect.fromLTWH(.073, .763, .43, .142),
    angle: -3,
  );
  item('travelPostcard', const Rect.fromLTWH(.704, .413, .20, .145), angle: 2);
  closePage('짐을 내려놓은 방', 'room-key-and-book');

  p = sheet('#E9ECE5');
  item('studioCottonRag', const Rect.fromLTWH(.047, .16, .88, .69), angle: 2);
  item('travelPostcard', const Rect.fromLTWH(.08, .135, .43, .235), angle: -3);
  item('travelNotebook', const Rect.fromLTWH(.105, .41, .69, .48), angle: -2);
  item('travelStayTag', const Rect.fromLTWH(.16, .335, .125, .20), angle: -4);
  photo(
    p,
    'quiet_book',
    'daily_book',
    const Rect.fromLTWH(.427, .175, .485, .421),
    frame: 'studioPhotoCorners',
    angle: 2,
  );
  print(
    p,
    'window_table',
    'travel_cafe',
    const Rect.fromLTWH(.085, .535, .565, .299),
    angle: -2,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.582, .147, .20, .055),
    angle: 4,
  );
  item('studioWashiSage', const Rect.fromLTWH(.123, .51, .17, .053), angle: -4);
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.50, .732, .40, .166),
    angle: 3,
  );
  item('studioPostalMark', const Rect.fromLTWH(.697, .771, .20, .10), angle: 5);
  closePage('창가에 두고 온 책', 'window-table-and-key');

  // 5-6: tall street prints face a low, wide market print and a collected receipt.
  p = sheet('#E6ECE8');
  item(
    'travelContourSlip',
    const Rect.fromLTWH(.425, .133, .48, .73),
    angle: 3,
  );
  item('studioCottonRag', const Rect.fromLTWH(.055, .162, .78, .72), angle: -3);
  item('studioTravelMap', const Rect.fromLTWH(.23, .285, .67, .53), angle: -3);
  item('travelPostcard', const Rect.fromLTWH(.473, .696, .435, .204), angle: 2);
  print(
    p,
    'street',
    'travel_street',
    const Rect.fromLTWH(.088, .155, .459, .664),
    angle: -2,
  );
  photo(
    p,
    'market',
    'journey_market',
    const Rect.fromLTWH(.499, .535, .399, .292),
    frame: 'studioTorn',
    angle: 3,
  );
  item('studioWashiSage', const Rect.fromLTWH(.186, .136, .23, .061), angle: 3);
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.718, .803, .15, .046),
    angle: -4,
  );
  item(
    'studioCoastStamp',
    const Rect.fromLTWH(.768, .169, .11, .137),
    angle: 2,
  );
  item(
    'studioPostalMark',
    const Rect.fromLTWH(.68, .234, .23, .108),
    angle: -7,
  );
  closePage('지도 밖의 골목', 'street-print-on-route');

  p = sheet('#E8ECE3');
  item('studioCottonRag', const Rect.fromLTWH(.025, .135, .91, .744), angle: 2);
  item('studioTravelMap', const Rect.fromLTWH(.16, .315, .73, .515), angle: -2);
  item('travelNotebook', const Rect.fromLTWH(.067, .421, .433, .437), angle: 3);
  item('travelPostcard', const Rect.fromLTWH(.435, .461, .473, .36), angle: -3);
  print(
    p,
    'market_table',
    'journey_market',
    const Rect.fromLTWH(.227, .164, .672, .367),
    angle: 2,
  );
  print(
    p,
    'fruit',
    'daily_fruit',
    const Rect.fromLTWH(.075, .552, .477, .288),
    angle: -3,
  );
  item(
    'travelMarketReceipt',
    const Rect.fromLTWH(.719, .581, .164, .314),
    angle: 4,
  );
  item(
    'studioWashiSage',
    const Rect.fromLTWH(.426, .145, .243, .067),
    angle: -2,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.157, .53, .176, .047),
    angle: 4,
  );
  item(
    'travelLuggageLabel',
    const Rect.fromLTWH(.127, .844, .371, .064),
    angle: 0,
  );
  closePage('시장에서 고른 것들', 'market-receipt-and-fruit');

  // 7-8: coffee paper, rounded coasters and long receipts keep a different rhythm.
  p = sheet('#EFF0E7');
  item('studioCottonRag', const Rect.fromLTWH(.033, .165, .88, .71), angle: -2);
  item('travelNotebook', const Rect.fromLTWH(.084, .148, .67, .66), angle: 2);
  item(
    'travelCafeCoaster',
    const Rect.fromLTWH(.672, .146, .25, .25),
    angle: 2,
  );
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.372, .443, .548, .39),
    angle: -3,
  );
  print(
    p,
    'breakfast',
    'small_days_breakfast',
    const Rect.fromLTWH(.084, .191, .605, .392),
    angle: -2,
  );
  photo(
    p,
    'cafe_corner',
    'travel_cafe',
    const Rect.fromLTWH(.541, .528, .363, .29),
    frame: 'studioPhotoCorners',
    angle: 3,
  );
  item(
    'travelCafeReceipt',
    const Rect.fromLTWH(.114, .589, .242, .31),
    angle: -3,
  );
  item('studioWashiSage', const Rect.fromLTWH(.252, .17, .22, .065), angle: 3);
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.749, .799, .128, .045),
    angle: -2,
  );
  item('studioVellum', const Rect.fromLTWH(.324, .723, .19, .16), angle: 4);
  closePage('커피 두 잔과 아침', 'breakfast-coaster-and-receipt');

  p = sheet('#E9EEE8');
  item('studioBlueFibre', const Rect.fromLTWH(.086, .145, .831, .71), angle: 2);
  item(
    'travelCafeCoaster',
    const Rect.fromLTWH(.053, .15, .32, .31),
    angle: -3,
  );
  item('travelPostcard', const Rect.fromLTWH(.42, .638, .49, .255), angle: 3);
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.061, .506, .49, .357),
    angle: -3,
  );
  print(
    p,
    'cafe_conversation',
    'couple_cafe',
    const Rect.fromLTWH(.303, .183, .606, .402),
    angle: 2,
  );
  photo(
    p,
    'reading',
    'daily_book',
    const Rect.fromLTWH(.077, .577, .364, .26),
    frame: 'studioTorn',
    angle: -3,
  );
  item(
    'travelCafeReceipt',
    const Rect.fromLTWH(.754, .529, .14, .24),
    angle: 3,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.475, .157, .23, .062),
    angle: -3,
  );
  item('studioWashiSage', const Rect.fromLTWH(.114, .55, .18, .054), angle: 3);
  item(
    'studioPostalMark',
    const Rect.fromLTWH(.556, .792, .25, .108),
    angle: 3,
  );
  closePage('시간을 잊은 테이블', 'conversation-and-postcard');

  // 9-10: a panoramic coastal print opens the spread; the facing portrait is tall.
  p = sheet('#DFE9E6');
  item(
    'travelContourSlip',
    const Rect.fromLTWH(.075, .137, .801, .715),
    angle: -2,
  );
  item('studioCottonRag', const Rect.fromLTWH(.03, .212, .914, .62), angle: 2);
  item(
    'studioTravelMap',
    const Rect.fromLTWH(.522, .556, .394, .312),
    angle: -3,
  );
  item('studioVellum', const Rect.fromLTWH(.068, .483, .562, .348), angle: 2);
  print(
    p,
    'coastal_panorama',
    'travel_coast',
    const Rect.fromLTWH(.06, .218, .873, .372),
    angle: -1,
  );
  print(
    p,
    'harbor_note',
    'travel_harbor',
    const Rect.fromLTWH(.117, .637, .341, .225),
    angle: 3,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.322, .19, .23, .063),
    angle: -3,
  );
  item('studioWashiSage', const Rect.fromLTWH(.159, .617, .173, .05), angle: 3);
  item(
    'studioCoastStamp',
    const Rect.fromLTWH(.794, .639, .112, .151),
    angle: 4,
  );
  item(
    'studioPostalMark',
    const Rect.fromLTWH(.651, .744, .245, .115),
    angle: -5,
  );
  closePage('해변을 따라 걷기', 'coastal-panorama-and-stamp');

  p = sheet('#E3EAE6');
  item('studioBlueFibre', const Rect.fromLTWH(.076, .131, .846, .70), angle: 2);
  item(
    'travelNotebook',
    const Rect.fromLTWH(.051, .316, .505, .513),
    angle: -3,
  );
  item(
    'travelContourSlip',
    const Rect.fromLTWH(.647, .247, .259, .604),
    angle: 3,
  );
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.077, .544, .523, .347),
    angle: -2,
  );
  print(
    p,
    'couple_by_the_sea',
    'couple_walk',
    const Rect.fromLTWH(.392, .149, .516, .603),
    angle: 2,
  );
  photo(
    p,
    'sea_fragment',
    'travel_coast',
    const Rect.fromLTWH(.075, .573, .397, .264),
    frame: 'studioTorn',
    angle: -3,
  );
  item(
    'studioWashiSage',
    const Rect.fromLTWH(.523, .123, .245, .067),
    angle: -3,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.112, .551, .18, .049),
    angle: 3,
  );
  item(
    'travelPostcard',
    const Rect.fromLTWH(.515, .794, .385, .122),
    angle: -2,
  );
  item(
    'studioPostalMark',
    const Rect.fromLTWH(.665, .818, .234, .091),
    angle: 3,
  );
  closePage('같은 바다 앞에서', 'sea-portrait-and-notebook');

  // 11-12: little purchases and a picnic keep the quieter green paper family.
  p = sheet('#E9EEE3');
  item('studioCottonRag', const Rect.fromLTWH(.043, .161, .872, .72), angle: 2);
  item(
    'travelNotebook',
    const Rect.fromLTWH(.314, .143, .555, .686),
    angle: -3,
  );
  item(
    'travelMarketReceipt',
    const Rect.fromLTWH(.097, .513, .24, .348),
    angle: -2,
  );
  item(
    'studioArchiveTag',
    const Rect.fromLTWH(.68, .159, .238, .245),
    angle: 3,
  );
  print(
    p,
    'fruit_selection',
    'daily_fruit',
    const Rect.fromLTWH(.098, .18, .579, .371),
    angle: -2,
  );
  print(
    p,
    'market_detail',
    'journey_market',
    const Rect.fromLTWH(.513, .548, .386, .283),
    angle: 3,
  );
  item('studioWashiSage', const Rect.fromLTWH(.261, .156, .217, .06), angle: 2);
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.721, .809, .135, .044),
    angle: -3,
  );
  item(
    'travelPostcard',
    const Rect.fromLTWH(.325, .738, .225, .158),
    angle: -3,
  );
  item('studioVellum', const Rect.fromLTWH(.293, .599, .17, .208), angle: 3);
  closePage('가방에 넣어 온 것', 'small-purchases-and-paper');

  p = sheet('#E5EBE2');
  item(
    'studioCottonRag',
    const Rect.fromLTWH(.048, .14, .872, .736),
    angle: -2,
  );
  item(
    'studioBlueFibre',
    const Rect.fromLTWH(.245, .201, .663, .598),
    angle: 3,
  );
  item(
    'travelNotebook',
    const Rect.fromLTWH(.063, .353, .538, .515),
    angle: -2,
  );
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.343, .584, .553, .275),
    angle: 3,
  );
  print(
    p,
    'picnic',
    'daily_picnic',
    const Rect.fromLTWH(.311, .196, .587, .375),
    angle: 2,
  );
  photo(
    p,
    'park_walk',
    'small_days_walk',
    const Rect.fromLTWH(.081, .523, .423, .31),
    frame: 'studioTorn',
    angle: -3,
  );
  item(
    'travelCafeCoaster',
    const Rect.fromLTWH(.657, .704, .219, .19),
    angle: 0,
  );
  item(
    'studioWashiSage',
    const Rect.fromLTWH(.464, .173, .218, .06),
    angle: -3,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.129, .503, .178, .05),
    angle: 4,
  );
  item(
    'travelPostcard',
    const Rect.fromLTWH(.085, .173, .196, .156),
    angle: -3,
  );
  closePage('꽃을 들고 나선 날', 'picnic-and-park-fragments');

  // 13-14: paired memories use photo corners and storage paper instead of big labels.
  p = sheet('#ECEEE7');
  item('studioCottonRag', const Rect.fromLTWH(.031, .16, .885, .728), angle: 2);
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.056, .233, .805, .542),
    angle: -3,
  );
  item(
    'travelPostcard',
    const Rect.fromLTWH(.072, .655, .524, .245),
    angle: -2,
  );
  item('travelNotebook', const Rect.fromLTWH(.57, .231, .338, .614), angle: 2);
  photo(
    p,
    'evening_together',
    'couple_anniversary',
    const Rect.fromLTWH(.104, .186, .591, .427),
    frame: 'studioPhotoCorners',
    angle: -2,
  );
  print(
    p,
    'sea_portrait',
    'couple_walk',
    const Rect.fromLTWH(.597, .551, .287, .302),
    angle: 3,
  );
  item('studioWashiSage', const Rect.fromLTWH(.262, .161, .22, .062), angle: 3);
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.668, .831, .158, .041),
    angle: -3,
  );
  item(
    'studioCoastStamp',
    const Rect.fromLTWH(.784, .145, .113, .153),
    angle: 2,
  );
  item(
    'studioPostalMark',
    const Rect.fromLTWH(.721, .232, .197, .10),
    angle: -5,
  );
  closePage('나란히 앉은 날', 'portrait-keepsakes-in-sleeve');

  p = sheet('#E5ECE8');
  item(
    'studioBlueFibre',
    const Rect.fromLTWH(.061, .153, .852, .696),
    angle: -2,
  );
  item(
    'travelContourSlip',
    const Rect.fromLTWH(.085, .184, .521, .64),
    angle: 3,
  );
  item('travelPostcard', const Rect.fromLTWH(.473, .643, .429, .25), angle: 2);
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.068, .494, .556, .387),
    angle: -3,
  );
  print(
    p,
    'sea_walk',
    'couple_walk',
    const Rect.fromLTWH(.324, .154, .576, .49),
    angle: 2,
  );
  print(
    p,
    'cafe_print',
    'couple_cafe',
    const Rect.fromLTWH(.088, .599, .434, .264),
    angle: -3,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.507, .127, .226, .065),
    angle: -3,
  );
  item(
    'studioWashiSage',
    const Rect.fromLTWH(.133, .578, .187, .048),
    angle: 2,
  );
  item(
    'studioArchiveTag',
    const Rect.fromLTWH(.10, .132, .174, .187),
    angle: -3,
  );
  item(
    'studioPostalMark',
    const Rect.fromLTWH(.645, .801, .246, .105),
    angle: 2,
  );
  closePage('함께 나온 한 장', 'two-portraits-and-postcard');

  // 15-16: dusk comes from the photographs, not glitter or saturated decorations.
  p = sheet('#D5DFDD');
  item(
    'travelContourSlip',
    const Rect.fromLTWH(.113, .13, .758, .752),
    angle: -2,
  );
  item('studioCottonRag', const Rect.fromLTWH(.04, .215, .898, .61), angle: 2);
  item(
    'travelPostcard',
    const Rect.fromLTWH(.084, .662, .481, .241),
    angle: -3,
  );
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.476, .536, .422, .353),
    angle: 3,
  );
  print(
    p,
    'sunset_panorama',
    'assets/templates/jeju_travel/images/resized/jeju_sunset.jpg',
    const Rect.fromLTWH(.062, .208, .868, .398),
    angle: 1,
  );
  photo(
    p,
    'harbor_evening',
    'travel_harbor',
    const Rect.fromLTWH(.598, .671, .293, .197),
    frame: 'studioTorn',
    angle: -3,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.325, .184, .235, .066),
    angle: -2,
  );
  item(
    'studioWashiSage',
    const Rect.fromLTWH(.658, .653, .158, .044),
    angle: 2,
  );
  item(
    'studioCoastStamp',
    const Rect.fromLTWH(.147, .725, .098, .13),
    angle: -3,
  );
  item('studioPostalMark', const Rect.fromLTWH(.208, .77, .235, .10), angle: 4);
  closePage('해가 내려앉는 바다', 'sunset-panorama-and-mail');

  p = sheet('#DBE2DE');
  item(
    'studioCottonRag',
    const Rect.fromLTWH(.045, .135, .87, .737),
    angle: -2,
  );
  item('travelNotebook', const Rect.fromLTWH(.072, .256, .496, .62), angle: -3);
  item('travelPostcard', const Rect.fromLTWH(.081, .129, .247, .25), angle: 3);
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.322, .52, .567, .35),
    angle: 2,
  );
  // Preserve both the sun and silhouettes, including the mount's equal inset.
  final sunsetWidth = math.min(
    .613,
    (.50 / aspect.canvas.aspectRatio - .018) * 7 / 6 + .018,
  );
  final sunsetHeight =
      ((sunsetWidth - .018) * 6 / 7 + .018) * aspect.canvas.aspectRatio;
  print(
    p,
    'sunset_together',
    'assets/templates/scrapbook/images/sources/sunset_pair.png',
    Rect.fromLTWH(.90 - sunsetWidth, .165, sunsetWidth, sunsetHeight),
    angle: 2,
  );
  photo(
    p,
    'harbor_light',
    'travel_harbor',
    const Rect.fromLTWH(.083, .601, .423, .25),
    frame: 'studioTorn',
    angle: -3,
  );
  item(
    'studioWashiSage',
    const Rect.fromLTWH(.449, .151, .229, .063),
    angle: -2,
  );
  item('studioWashiIndigo', const Rect.fromLTWH(.13, .58, .18, .048), angle: 3);
  item(
    'studioArchiveTag',
    const Rect.fromLTWH(.746, .619, .148, .247),
    angle: -3,
  );
  item('studioVellum', const Rect.fromLTWH(.538, .69, .15, .177), angle: 3);
  closePage('해질녘을 함께 보며', 'last-sunset-and-keepsakes');

  // 17-18: transport labels return once, linking the ending to the opening.
  p = sheet('#E3EAE5');
  item(
    'studioCottonRag',
    const Rect.fromLTWH(.037, .148, .881, .73),
    angle: -2,
  );
  item(
    'studioTravelMap',
    const Rect.fromLTWH(.308, .126, .593, .718),
    angle: 3,
  );
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.059, .432, .739, .425),
    angle: -2,
  );
  item('travelPostcard', const Rect.fromLTWH(.423, .56, .475, .314), angle: 3);
  print(
    p,
    'return_train',
    'journey_train',
    const Rect.fromLTWH(.087, .172, .619, .434),
    angle: -2,
  );
  print(
    p,
    'last_street',
    'travel_street',
    const Rect.fromLTWH(.607, .559, .286, .292),
    angle: 3,
  );
  item(
    'studioWashiSage',
    const Rect.fromLTWH(.252, .149, .218, .061),
    angle: 3,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.693, .831, .154, .041),
    angle: -3,
  );
  item(
    'travelLuggageLabel',
    const Rect.fromLTWH(.092, .711, .457, .159),
    angle: -2,
  );
  item(
    'studioPostalMark',
    const Rect.fromLTWH(.74, .255, .163, .108),
    angle: 5,
  );
  closePage('돌아오는 기차에서', 'return-train-and-baggage');

  p = sheet('#E6EBE5');
  item('studioBlueFibre', const Rect.fromLTWH(.062, .145, .856, .70), angle: 2);
  item('travelNotebook', const Rect.fromLTWH(.078, .242, .54, .615), angle: -3);
  item('travelPostcard', const Rect.fromLTWH(.479, .643, .433, .25), angle: 3);
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.06, .468, .582, .414),
    angle: -2,
  );
  print(
    p,
    'familiar_walk',
    'small_days_walk',
    const Rect.fromLTWH(.328, .17, .575, .438),
    angle: 2,
  );
  print(
    p,
    'book_again',
    'daily_book',
    const Rect.fromLTWH(.081, .548, .431, .293),
    angle: -3,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.495, .145, .225, .064),
    angle: -3,
  );
  item(
    'studioWashiSage',
    const Rect.fromLTWH(.147, .527, .173, .046),
    angle: 3,
  );
  item(
    'travelLuggageLabel',
    const Rect.fromLTWH(.095, .162, .215, .089),
    angle: -4,
  );
  item(
    'studioPostalMark',
    const Rect.fromLTWH(.62, .791, .265, .114),
    angle: 4,
  );
  closePage('집으로 가져온 꽃', 'homeward-flowers-and-note');

  // 19-20: collected pages and a final large photo close the album without a slogan.
  p = sheet('#EBEEE7');
  item('studioCottonRag', const Rect.fromLTWH(.04, .132, .87, .744), angle: -2);
  item('travelNotebook', const Rect.fromLTWH(.327, .143, .538, .676), angle: 3);
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.054, .282, .755, .537),
    angle: -2,
  );
  item('travelPostcard', const Rect.fromLTWH(.072, .666, .49, .229), angle: -3);
  print(
    p,
    'desk',
    'daily_desk',
    const Rect.fromLTWH(.095, .183, .613, .419),
    angle: -2,
  );
  photo(
    p,
    'open_book',
    'daily_book',
    const Rect.fromLTWH(.604, .576, .279, .266),
    frame: 'studioTorn',
    angle: 3,
  );
  item('studioWashiSage', const Rect.fromLTWH(.265, .16, .227, .064), angle: 3);
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.671, .819, .156, .046),
    angle: -3,
  );
  item(
    'studioCoastStamp',
    const Rect.fromLTWH(.786, .147, .105, .14),
    angle: -2,
  );
  item(
    'studioPostalMark',
    const Rect.fromLTWH(.147, .761, .246, .115),
    angle: 4,
  );
  closePage('책상 위에 펼친 여행', 'collected-pages-on-desk');

  p = sheet('#E8EDE8');
  item(
    'studioBlueFibre',
    const Rect.fromLTWH(.089, .136, .798, .70),
    angle: -2,
  );
  item(
    'studioCottonRag',
    const Rect.fromLTWH(.053, .242, .873, .615),
    angle: 2,
  );
  item(
    'travelPhotoSleeve',
    const Rect.fromLTWH(.085, .473, .713, .393),
    angle: -2,
  );
  item('travelPostcard', const Rect.fromLTWH(.504, .655, .385, .248), angle: 3);
  print(
    p,
    'last_photo',
    'couple_walk',
    const Rect.fromLTWH(.112, .179, .756, .433),
    angle: 0,
  );
  print(
    p,
    'last_sea',
    'travel_coast',
    const Rect.fromLTWH(.627, .67, .249, .207),
    angle: 3,
  );
  item(
    'studioGlassineEnvelope',
    const Rect.fromLTWH(.102, .621, .414, .273),
    angle: -3,
  );
  item(
    'studioWashiSage',
    const Rect.fromLTWH(.349, .156, .238, .065),
    angle: 0,
  );
  item(
    'studioWashiIndigo',
    const Rect.fromLTWH(.679, .651, .141, .044),
    angle: -2,
  );
  item(
    'studioPostalMark',
    const Rect.fromLTWH(.232, .762, .265, .121),
    angle: 4,
  );
  closePage('꺼내 보고 싶은 사진', 'closing-photo-and-envelope');

  return {
    'id': 'snapfit_luminous_study_${aspect.name}',
    'collectionId': travelKeepsakeArchiveId,
    'title': travelKeepsakeArchiveTitle,
    'source': 'snapfit-authored-study',
    'aiGenerated': false,
    'assetProvenance': 'generated-ornaments-human-authored-layout',
    'version': 7,
    'accessTier': 'unassigned',
    'publicationStatus': 'design-study',
    'catalogPublishable': false,
    'approvalStatus': 'awaiting-user-review',
    'innerPageCount': travelKeepsakeArchiveInnerPageCount,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
    'chapters': [
      for (final chapter in travelKeepsakeArchiveSpreads.indexed)
        {
          'title': chapter.$2,
          'from': chapter.$1 * 2 + 1,
          'to': chapter.$1 * 2 + 2,
        },
    ],
  };
}

part of 'authored_collections.dart';

const windAtlasTitle = '바람을 수집한 여행';
const windAtlasId = 'wind-atlas';
const windAtlasBundledId = -9304;
const windAtlasArt = 'assets/templates/premium_wind_atlas/';
const windAtlasCopy = EditorialCopy(
  place: '지중해의 작은 마을들',
  period: '2026. 06. 12 ~ 06. 18',
  byline: '수연과 지후',
  note:
      '우리는 바다를 보러 갔지만, 돌아올 때는 더 많은 것을 가지고 있었다.\n\n'
      '이름 모를 골목의 빛, 작은 식탁에서 나눈 이야기, 길을 잃고도 웃던 얼굴. '
      '사진에 다 담기지 않은 순간까지 이 책 사이에 오래 두고 싶다.\n\n'
      '다음 여행에도 빈 페이지 몇 장을 남겨 두기로.',
);

enum WindAtlasCover {
  illustrated('해안 화보'),
  botanical('보태니컬 에디션'),
  photographic('수집가의 표지');

  const WindAtlasCover(this.label);
  final String label;
}

const windAtlasSpreads = [
  '여행을 여는 문장',
  '도착의 감각',
  '골목의 표정',
  '바다의 두 가지 온도',
  '햇빛을 모은 식탁',
  '시장 산책',
  '주머니 속 수집품',
  '창문 너머의 세계',
  '우리의 느린 오후',
  '길 위의 작은 장면',
  '보내지 않은 엽서',
  '빛이 머무는 시간',
  '마음에 남은 주소',
  '여행의 색 사전',
  '돌아오는 길의 편지',
  '다음 여행을 위한 여백',
];

/// Authored free collection. Historical document IDs and asset paths are kept
/// stable; tier metadata, not those names, determines its free classification.
Map<String, dynamic> buildWindAtlas(
  CollectionAspect aspect, {
  WindAtlasCover cover = WindAtlasCover.illustrated,
  EditorialCopy copy = windAtlasCopy,
}) {
  const paper = '#F7F8F2', ink = '#173E38', red = '#B93C32';
  const blue = '#D6E9ED', pale = '#E8EDD9', butter = '#F5EABC';
  const harbor = '${_editorial}travel_harbor.png';
  const street = '${_editorial}travel_street.png';
  const coast = '${_editorial}travel_coast.png';
  const cafe = '${_editorial}travel_cafe.png';
  const market = '${_editorial}journey_market.png';
  const train = '${_editorial}journey_train.png';
  const people = '${_editorial}couple_walk.png';
  const fruit = '${_editorial}daily_fruit.png';
  final wide = aspect == CollectionAspect.landscape;
  final pages = <Map<String, dynamic>>[];
  final ids = <String>[];

  _Sheet sheet([String background = paper, String color = ink]) =>
      _Sheet(windAtlasId, aspect, pages.length, background, ink: color);
  void text(
    _Sheet p,
    String id,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .027,
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
  void title(
    _Sheet p,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .09,
    String? color,
    String align = 'left',
  }) => text(
    p,
    'heading',
    value,
    x,
    y,
    w,
    h,
    size: size,
    color: color,
    font: 'Eulyoo',
    align: align,
    leading: 1.25,
  );
  void art(
    _Sheet p,
    String id,
    String file,
    double x,
    double y,
    double w,
    double h,
  ) => p._add(id, 'sticker', x, y, w, h, {
    'imageUrl': 'asset:$windAtlasArt$file.png',
  });
  void line(
    _Sheet p,
    String id,
    double x,
    double y,
    double w, [
    String? color,
  ]) => p.box(id, x, y, w, .0015, color ?? p.ink);
  void caption(
    _Sheet p,
    String value,
    double x,
    double y,
    double w, {
    String? color,
  }) => text(
    p,
    'caption_${p.layers.length}',
    value,
    x,
    y,
    w,
    .065,
    size: .022,
    color: color,
    leading: 1.35,
  );
  void chapter(_Sheet p, String number, String name) {
    text(
      p,
      'chapter_number',
      number,
      .08,
      .06,
      .12,
      .07,
      size: .042,
      font: 'Cormorant Garamond',
      color: red,
    );
    text(
      p,
      'chapter_name',
      name,
      .25,
      .074,
      .64,
      .045,
      size: .022,
      color: p.ink,
    );
    line(p, 'chapter_rule', .08, .139, .8);
  }

  void add(_Sheet p, String name, String role) {
    if (pages.isNotEmpty) {
      final left = pages.length.isOdd;
      text(
        p,
        'folio',
        pages.length.toString().padLeft(2, '0'),
        left ? .07 : .82,
        .95,
        .1,
        .027,
        size: .018,
        color: p.ink,
        align: left ? 'left' : 'right',
      );
      text(
        p,
        'running_head',
        '바람의 기록',
        left ? .57 : .12,
        .953,
        .3,
        .025,
        size: .015,
        color: p.ink,
        align: left ? 'right' : 'left',
      );
    }
    ids.add(role);
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

  // Three genuinely different cover compositions, not three palette variants.
  var p = sheet();
  switch (cover) {
    case WindAtlasCover.illustrated:
      p.box('bookcloth_spine', 0, 0, .034, 1, ink);
      text(
        p,
        'edition',
        '여행 수집실 · 첫 번째 기록',
        .10,
        .065,
        .8,
        .05,
        size: .022,
        color: red,
      );
      title(
        p,
        wide ? '바람을\n수집한\n여행' : '바람을\n수집한 여행',
        .1,
        wide ? .23 : .17,
        wide ? .32 : .8,
        wide ? .45 : .32,
        size: wide ? .105 : .123,
      );
      art(
        p,
        'coast_frontispiece',
        'coast_watercolor',
        wide ? .43 : .04,
        wide ? .16 : .44,
        wide ? .53 : .91,
        wide ? .63 : .38,
      );
      line(p, 'imprint_rule', .1, .86, .8);
      text(p, 'cover_place', copy.place, .1, .89, .52, .065, size: .024);
      text(
        p,
        'cover_byline',
        copy.byline,
        .64,
        .89,
        .26,
        .065,
        size: .024,
        align: 'right',
      );
    case WindAtlasCover.botanical:
      p.box('cloth', 0, 0, 1, 1, ink);
      p.box('paper_label', .095, .075, .81, .85, paper);
      text(
        p,
        'edition',
        '여행 수집실 / 식물과 풍경',
        .15,
        .12,
        .7,
        .05,
        size: .021,
        color: red,
        align: 'center',
      );
      art(
        p,
        'botanical_cover',
        'lemon_botanical',
        wide ? .28 : .25,
        .22,
        wide ? .44 : .49,
        .43,
      );
      title(p, '바람을 수집한 여행', .15, .70, .7, .08, size: .059, align: 'center');
      text(
        p,
        'cover_place',
        copy.place,
        .15,
        .815,
        .7,
        .06,
        size: .024,
        align: 'center',
      );
    case WindAtlasCover.photographic:
      text(
        p,
        'edition',
        '여행 수집실 · 사진과 문장',
        .09,
        .065,
        .82,
        .05,
        size: .021,
        color: red,
      );
      title(p, '바람을 수집한 여행', .09, .15, .82, .12, size: .075);
      p.photo(
        'cover_photo',
        harbor,
        .09,
        .32,
        .82,
        .45,
        shape: 'studioPhotoCorners',
      );
      line(p, 'photo_cover_rule', .09, .825, .82);
      text(p, 'cover_place', copy.place, .09, .85, .82, .05, size: .024);
      text(p, 'cover_byline', copy.byline, .09, .91, .82, .04, size: .021);
  }
  add(p, cover.label, 'atlas-cover-${cover.name}');

  // 01: illustrated frontispiece and a typographic table of contents.
  p = sheet();
  text(
    p,
    'opening_imprint',
    '여행 수집실',
    .08,
    .075,
    .8,
    .06,
    size: .029,
    color: red,
  );
  title(p, '낯선 곳에서\n나에게로.', .08, .20, .78, .29, size: .112);
  art(p, 'opening_coast', 'coast_watercolor', .04, .49, .88, .30);
  text(
    p,
    'dedication',
    '떠난 날의 마음과\n돌아온 날의 우리가 머무는 곳.',
    .08,
    .82,
    .8,
    .1,
    size: .026,
  );
  add(p, '낯선 곳에서 나에게로', 'illustrated-frontispiece');
  p = sheet(blue);
  title(p, '여행의 목차', .12, .075, .76, .13, size: .082);
  for (final entry in [
    ('01', '도착과 산책', '01 — 08'),
    ('02', '맛과 수집', '09 — 16'),
    ('03', '우리와 풍경', '17 — 24'),
    ('04', '기록과 여운', '25 — 32'),
  ].indexed) {
    final y = .28 + entry.$1 * .137;
    text(
      p,
      'contents_no_${entry.$1}',
      entry.$2.$1,
      .12,
      y,
      .1,
      .05,
      size: .032,
      font: 'Cormorant Garamond',
      color: red,
    );
    text(
      p,
      'contents_title_${entry.$1}',
      entry.$2.$2,
      .29,
      y,
      .43,
      .06,
      size: .032,
    );
    text(
      p,
      'contents_pages_${entry.$1}',
      entry.$2.$3,
      .74,
      y + .012,
      .14,
      .04,
      size: .017,
      align: 'right',
    );
    line(p, 'contents_rule_${entry.$1}', .12, y + .086, .76);
  }
  caption(p, '${copy.period}\n${copy.byline}의 여행', .12, .84, .76);
  add(p, '한 권의 여행 지도', 'contents-ledger');

  // 02: a ticket-like departure note, opposite a generous arrival photograph.
  p = sheet(ink, paper);
  text(
    p,
    'arrival_section',
    '첫 번째 장 / 도착의 감각',
    .09,
    .075,
    .78,
    .05,
    size: .023,
    color: butter,
  );
  title(p, '마침내,\n여기.', .09, .23, .8, .39, size: .15);
  p.box('ticket_stock', .09, .66, .79, .19, paper);
  text(p, 'ticket_label', '도착한 곳', .13, .69, .68, .04, size: .021, color: red);
  text(
    p,
    'ticket_place',
    copy.place,
    .13,
    .76,
    .68,
    .07,
    size: .031,
    color: ink,
  );
  add(p, '마침내 여기', 'arrival-chapter');
  p = sheet();
  p.photo('arrival_full', harbor, .12, .07, .81, .69);
  text(
    p,
    'arrival_word',
    '첫인상',
    .12,
    .79,
    .28,
    .08,
    size: .049,
    font: 'Eulyoo',
  );
  text(
    p,
    'arrival_note',
    '우리는 잠깐 말을 멈추고\n오래 바다를 바라보았다.',
    .49,
    .80,
    .44,
    .10,
    size: .026,
  );
  add(p, '바다부터 만난 날', 'arrival-photo-essay');

  // 03: a tall doorway aperture; the opposite page collects different scales.
  p = sheet(pale);
  chapter(p, '01', '골목의 표정');
  p.photo(
    'doorway',
    street,
    wide ? .18 : .18,
    .21,
    wide ? .50 : .64,
    .56,
    shape: 'studioArch',
  );
  caption(p, '모퉁이를 돌면, 또 다른 빛.', .12, .83, .74);
  add(p, '골목이라는 작은 세계', 'doorway-aperture');
  p = sheet();
  title(p, '길을 잃는\n즐거움에 대하여', .12, .07, .76, .19, size: .069);
  p.photo('lane_detail', harbor, .12, .35, .42, .44, shape: 'studioGallery');
  p.photo('lane_small', street, .60, .35, .32, .245);
  text(
    p,
    'lane_note',
    '계획에서 벗어나\n발견한 장면들.\n\n느린 걸음으로\n한 장씩 모았다.',
    .60,
    .64,
    .32,
    .25,
    size: .026,
  );
  caption(p, '기억하고 싶은 모퉁이', .12, .83, .43);
  add(p, '발견의 크기', 'asymmetric-discovery');

  // 04: photo diptych with complementary calm/light and dark/detailed pages.
  p = sheet(blue);
  title(p, '바다의\n두 가지 온도', .08, .075, .81, .24, size: .088);
  p.photo('sea_horizon', coast, .08, .41, .79, .36);
  caption(p, '멀리서 보면 고요하고,', .08, .825, .79);
  add(p, '멀리서 바라본 바다', 'sea-horizon');
  p = sheet(ink, paper);
  p.photo('sea_close', harbor, .12, .10, .81, .57, shape: 'studioWave');
  title(p, '가까이서는\n반짝이던.', .12, .72, .81, .19, size: .069);
  add(p, '가까이에서 발견한 바다', 'sea-wave-window');

  // 05: a botanical still-life opposite a generous cafe table.
  p = sheet(butter);
  chapter(p, '02', '햇빛을 모은 식탁');
  art(p, 'lemon_plate', 'lemon_botanical', .13, .22, .53, .47);
  title(p, '그 계절의 맛', .09, .735, .79, .1, size: .073);
  caption(p, '신맛 한 입, 웃음 한 모금.', .09, .866, .79);
  add(p, '레몬 향의 오후', 'botanical-still-life');
  p = sheet();
  p.photo('table', cafe, .12, .11, .80, .56, shape: 'studioDoubleMat');
  text(p, 'menu_label', '우리의 주문', .12, .735, .29, .06, size: .023, color: red);
  line(p, 'menu_rule', .12, .885, .80);
  text(
    p,
    'menu',
    '커피 두 잔\n이야기는 넉넉히',
    .47,
    .727,
    .45,
    .13,
    size: .033,
    font: 'Eulyoo',
  );
  add(p, '오래 앉아 있던 자리', 'cafe-menu');

  // 06: an illustrated market register and a three-image harvest sequence.
  p = sheet();
  title(p, '시장 산책', .08, .08, .79, .12, size: .095);
  p.photo('market_scene', market, .08, .29, .79, .40);
  for (final entry in [
    ('01', '처음 보는 과일'),
    ('02', '이름을 배운 꽃'),
    ('03', '다정한 인사'),
  ].indexed) {
    final y = .744 + entry.$1 * .057;
    text(
      p,
      'market_n_${entry.$1}',
      entry.$2.$1,
      .08,
      y,
      .10,
      .04,
      size: .02,
      color: red,
    );
    text(p, 'market_t_${entry.$1}', entry.$2.$2, .25, y, .60, .04, size: .024);
  }
  add(p, '골라 담은 즐거움', 'market-register');
  p = sheet(pale);
  p.photo('harvest_one', fruit, .12, .09, .47, .40, shape: 'studioOval');
  art(p, 'harvest_lemon', 'lemon_botanical', .66, .12, .24, .30);
  p.photo('harvest_two', market, .12, .59, .37, .22);
  p.photo('harvest_three', cafe, .55, .59, .37, .22, shape: 'studioRounded');
  caption(p, '손에 남은 것보다 마음에 남은 것들.', .12, .854, .8);
  add(p, '초여름의 수확', 'harvest-triptych');

  // 07: ephemera are separate editable shapes and type, never baked into art.
  p = sheet(blue);
  chapter(p, '03', '주머니 속 수집품');
  p.box('ticket_red', .08, .22, .78, .18, red);
  text(
    p,
    'ticket_title',
    '오늘의 목적지',
    .12,
    .249,
    .68,
    .05,
    size: .022,
    color: paper,
  );
  text(
    p,
    'ticket_destination',
    copy.place,
    .12,
    .318,
    .68,
    .065,
    size: .029,
    color: paper,
  );
  p.photo('saved_postcard', coast, .08, .49, .52, .30, shape: 'studioPostage');
  text(
    p,
    'kept_note',
    '종이 한 장에도\n하루가\n접혀 있었다.',
    .65,
    .53,
    .23,
    .20,
    size: .029,
    font: 'Eulyoo',
  );
  caption(p, '버리지 못한 작은 것들의 목록', .08, .86, .78);
  add(p, '주머니에서 꺼낸 하루', 'ephemera-pocket');
  p = sheet();
  title(p, '수집품 목록', .12, .075, .80, .12, size: .081);
  for (final entry in [
    ('01', '돌아오는 기차표', '차창 밖 바다까지 함께'),
    ('02', '카페의 작은 영수증', '오래 앉아 있던 오후'),
    ('03', '보내지 못한 엽서', '쓸 말이 너무 많아서'),
  ].indexed) {
    final y = .30 + entry.$1 * .20;
    text(
      p,
      'archive_n_${entry.$1}',
      entry.$2.$1,
      .12,
      y,
      .12,
      .065,
      size: .04,
      font: 'Cormorant Garamond',
      color: red,
    );
    text(
      p,
      'archive_title_${entry.$1}',
      entry.$2.$2,
      .31,
      y,
      .59,
      .055,
      size: .030,
    );
    text(
      p,
      'archive_note_${entry.$1}',
      entry.$2.$3,
      .31,
      y + .075,
      .59,
      .07,
      size: .022,
    );
    line(p, 'archive_rule_${entry.$1}', .12, y + .15, .80);
  }
  add(p, '작은 물건의 긴 기억', 'ephemera-index');

  // 08: negative-space window compositions reflow in landscape, not stretched.
  p = sheet();
  text(
    p,
    'window_kicker',
    '창문 너머의 세계',
    .08,
    .08,
    .79,
    .06,
    size: .025,
    color: red,
  );
  p.photo(
    'train_window',
    train,
    .08,
    wide ? .22 : .23,
    wide ? .50 : .79,
    wide ? .60 : .43,
    shape: 'studioRounded',
  );
  text(
    p,
    'train_note',
    '가는 길에도\n도착하는 중이었다.',
    wide ? .64 : .08,
    wide ? .36 : .75,
    wide ? .23 : .79,
    wide ? .28 : .15,
    size: wide ? .039 : .045,
    font: 'Eulyoo',
  );
  add(p, '움직이는 창가', 'window-reflow');
  p = sheet(ink, paper);
  title(p, '잠깐,\n멈춰 선 풍경.', .12, .09, .79, .22, size: .078);
  p.photo('still_window', street, .12, .42, .38, .40, shape: 'studioArch');
  p.photo('still_scene', harbor, .57, .54, .35, .28);
  caption(p, '다시 지나가도 알아볼 수 있을까.', .12, .87, .80);
  add(p, '오래 보고 싶은 창', 'stationary-windows');

  // 09: a quiet portrait spread keeps faces away from the inner binding zone.
  p = sheet(pale);
  title(p, '우리의\n느린 오후', .08, .075, .79, .25, size: .094);
  text(
    p,
    'afternoon_note',
    '특별한 일은 없었지만\n함께여서 충분했던 시간.\n\n서로를 찍어 주다 보니\n사진보다 웃음이 많아졌다.',
    .08,
    .41,
    .46,
    .28,
    size: .029,
  );
  art(p, 'afternoon_branch', 'lemon_botanical', .59, .48, .29, .29);
  line(p, 'afternoon_rule', .08, .81, .79);
  caption(p, '함께 걷는 속도를 배웠다.', .08, .85, .79);
  add(p, '기억의 주인공', 'companions-dedication');
  p = sheet();
  const portraitH = .72;
  final portraitW = portraitH / aspect.canvas.aspectRatio * (2 / 3);
  p.photo(
    'companions_portrait',
    people,
    .52 - portraitW / 2,
    .10,
    portraitW,
    portraitH,
    shape: 'studioPhotoCorners',
  );
  caption(p, '같은 풍경 속에 우리가 있었다.', .12, .87, .80);
  add(p, '사진 속의 우리', 'companions-portrait');

  // 10: a six-frame contact sheet, balanced by one very large photo.
  p = sheet();
  chapter(p, '04', '길 위의 작은 장면');
  final contactPhotos = [street, cafe, market, train, fruit, people];
  for (var i = 0; i < 6; i++) {
    final col = wide ? i % 3 : i % 2, row = wide ? i ~/ 3 : i ~/ 2;
    final x = .08 + col * (wide ? .272 : .414),
        y = .225 + row * (wide ? .293 : .214);
    p.photo(
      'contact_$i',
      contactPhotos[i],
      x,
      y,
      wide ? .24 : .365,
      wide ? .205 : .15,
    );
    text(
      p,
      'contact_no_$i',
      (i + 1).toString().padLeft(2, '0'),
      x,
      y + (wide ? .216 : .159),
      .15,
      .03,
      size: .016,
      color: red,
    );
  }
  caption(p, '한 장씩은 작지만, 함께 두면 하루가 된다.', .08, .86, .8);
  add(p, '여섯 개의 작은 기억', 'contact-sheet-six');
  p = sheet(blue);
  p.photo('contact_anchor', coast, .12, .09, .80, .64, shape: 'studioDeckle');
  title(p, '그중에서도,\n이 장면.', .12, .775, .80, .15, size: .053);
  add(p, '오래 남을 한 장', 'contact-anchor');

  // 11: a postcard and its writable reverse form a meaningful matched pair.
  p = sheet(pale);
  text(
    p,
    'postcard_label',
    '보내지 않은 엽서 / 앞면',
    .08,
    .085,
    .79,
    .045,
    size: .023,
    color: red,
  );
  p.photo(
    'postcard_front',
    harbor,
    .08,
    .255,
    .79,
    .47,
    shape: 'studioPostcard',
  );
  title(p, '여기서 너를 생각했어.', .08, .805, .79, .09, size: .046);
  add(p, '사진으로 쓰는 안부', 'postcard-front');
  p = sheet();
  text(
    p,
    'postcard_reverse',
    '마음으로 쓰는 엽서',
    .12,
    .08,
    .80,
    .05,
    size: .025,
    color: red,
  );
  art(p, 'postcard_stamp', 'lemon_botanical', .75, .19, .16, .16);
  title(p, '잘 지내고 있지?', .12, .235, .58, .10, size: .055);
  text(
    p,
    'postcard_message',
    '나는 여기서 조금 느리게 지내고 있어.\n\n아침에는 바다를 보고, 오후에는 골목을 걸어.\n맛있는 것을 만나면 네 생각이 나더라.\n\n돌아가면 사진보다 긴 이야기를 들려줄게.',
    .12,
    .43,
    .80,
    .32,
    size: .028,
    leading: 1.6,
  );
  line(p, 'postcard_signature_rule', .59, .83, .33);
  text(
    p,
    'postcard_signature',
    copy.byline,
    .59,
    .854,
    .33,
    .06,
    size: .023,
    align: 'right',
  );
  add(p, '보내지 못한 말들', 'postcard-letter');

  // 12: a full-color interlude, not another rectangular photo-and-title page.
  p = sheet(red, paper);
  text(
    p,
    'light_interlude',
    '빛의 기록 / 시간이 머무는 곳',
    .08,
    .075,
    .79,
    .05,
    size: .022,
  );
  title(p, '오늘이\n조금 더\n길었으면.', .08, .22, .79, .48, size: .123);
  text(
    p,
    'light_note',
    '해가 기울자\n여행은 다른 색이 되었다.',
    .08,
    .76,
    .79,
    .12,
    size: .032,
  );
  add(p, '오늘이 조금 더 길었으면', 'coral-interlude');
  p = sheet();
  p.photo('light_scene', coast, .12, .12, .80, .56, shape: 'studioOvalMat');
  text(
    p,
    'light_time',
    '오후의 끝에서',
    .12,
    .76,
    .80,
    .09,
    size: .043,
    font: 'Eulyoo',
  );
  caption(p, '사진 밖의 바람까지 기억하기.', .12, .88, .8);
  add(p, '빛으로 남은 풍경', 'oval-light-study');

  // 13: addresses combine photos with usable travel notes, not filler copy.
  p = sheet();
  chapter(p, '05', '마음에 남은 주소');
  p.photo('address_cafe', cafe, .08, .23, .46, .40);
  text(
    p,
    'address_cafe_title',
    '다시 갈 곳',
    .60,
    .25,
    .27,
    .12,
    size: .045,
    font: 'Eulyoo',
  );
  text(
    p,
    'address_cafe_note',
    '바다가 보이는\n작은 카페.\n\n창가 자리와\n따뜻한 인사.',
    .60,
    .45,
    .27,
    .26,
    size: .027,
  );
  line(p, 'address_cafe_rule', .08, .77, .79);
  caption(p, '이름보다 먼저 떠오르는 분위기.', .08, .82, .79);
  add(p, '다시 앉고 싶은 자리', 'address-cafe');
  p = sheet(blue);
  p.photo(
    'address_street',
    street,
    .12,
    .10,
    .35,
    .58,
    shape: 'studioPhotoCorners',
  );
  p.photo('address_market', market, .53, .10, .39, .27, shape: 'studioRounded');
  title(p, '좋았던 곳은\n잊지 않도록.', .53, .44, .39, .17, size: .048);
  text(
    p,
    'address_memory',
    '길의 이름을 적는 대신,\n그곳에서의 기분을 적었다.',
    .12,
    .775,
    .80,
    .13,
    size: .032,
  );
  add(p, '마음으로 적은 주소', 'address-memory');

  // 14: a color specimen page works with, rather than over, user photos.
  p = sheet();
  title(p, '여행의 색 사전', .08, .075, .8, .12, size: .074);
  final specimens = [
    (ink, '깊은 물빛', harbor),
    (red, '지붕의 오후', street),
    ('#DDBA49', '레몬의 계절', fruit),
  ];
  for (final entry in specimens.indexed) {
    final y = .28 + entry.$1 * .20;
    p.box('specimen_color_${entry.$1}', .08, y, .13, .137, entry.$2.$1);
    p.photo('specimen_image_${entry.$1}', entry.$2.$3, .26, y, .26, .137);
    text(
      p,
      'specimen_name_${entry.$1}',
      entry.$2.$2,
      .59,
      y + .039,
      .29,
      .07,
      size: .029,
    );
  }
  caption(p, '이 계절을 다시 꺼내 보는 방법.', .08, .87, .8);
  add(p, '사진에서 건져 올린 색', 'color-specimens');
  p = sheet(butter);
  art(p, 'color_botanical', 'lemon_botanical', .13, .07, .70, .62);
  title(p, '기억에도\n색이 있다면.', .12, .72, .80, .195, size: .073);
  add(p, '노란 기억', 'botanical-colophon');

  // 15: the full editable letter balances the last large departure image.
  p = sheet(ink, paper);
  p.photo('return_window', train, .08, .11, .79, .44, shape: 'studioRounded');
  title(p, '돌아오는 길에\n남긴 문장', .08, .66, .79, .205, size: .078);
  caption(p, '여행은 끝나도 이야기는 계속된다.', .08, .88, .79);
  add(p, '돌아오는 창가', 'return-window');
  p = sheet();
  text(
    p,
    'letter_kicker',
    '여행을 마치며',
    .12,
    .08,
    .80,
    .055,
    size: .024,
    color: red,
  );
  title(p, '우리에게 남은 것', .12, .18, .80, .11, size: .066);
  text(
    p,
    'closing_letter',
    copy.note,
    .12,
    .365,
    .80,
    .43,
    size: wide ? .026 : .029,
    leading: 1.65,
  );
  line(p, 'closing_signature_rule', .62, .846, .30);
  text(
    p,
    'closing_signature',
    copy.byline,
    .49,
    .867,
    .43,
    .052,
    size: .024,
    align: 'right',
  );
  add(p, '우리에게 보내는 편지', 'closing-letter');

  // 16: a future-facing notebook page and a true illustrated colophon.
  p = sheet(blue);
  title(p, '다음에는,', .08, .085, .79, .15, size: .108);
  for (final entry in ['다시 걷고 싶은 길', '함께 가고 싶은 사람', '이번에는 하지 못한 일'].indexed) {
    final y = .34 + entry.$1 * .16;
    text(
      p,
      'future_prompt_${entry.$1}',
      entry.$2,
      .08,
      y,
      .79,
      .045,
      size: .025,
    );
    line(p, 'future_rule_${entry.$1}', .08, y + .102, .79, '#86A7A9');
  }
  caption(p, '다음 여행을 위한 빈 문장.', .08, .875, .79);
  add(p, '다음 여행의 첫 페이지', 'future-notebook');
  p = sheet();
  text(
    p,
    'colophon_edition',
    '여행 수집실 / 첫 번째 기록',
    .12,
    .09,
    .80,
    .05,
    size: .022,
    color: red,
    align: 'center',
  );
  art(p, 'closing_coast', 'coast_watercolor', .09, .23, .85, .40);
  title(p, '다녀온 마음은\n여기에 두고.', .12, .70, .80, .20, size: .073, align: 'center');
  add(p, '다녀온 마음을 두는 곳', 'illustrated-colophon');

  return {
    'id': 'snapfit_premium_wind_atlas_${aspect.name}',
    'collectionId': windAtlasId,
    'title': windAtlasTitle,
    'category': '여행',
    'version': 1,
    'source': 'snapfit-authored',
    'aiGenerated': false,
    'layoutAuthorship': 'independently-authored',
    'artworkAuthorship': 'imagegen-originals',
    'artworkProvenance': '${windAtlasArt}provenance.json',
    'accessTier': 'free',
    'publicationStatus': 'bundled',
    'catalogPublishable': false,
    'innerPageCount': 32,
    'coverVariant': cover.name,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'layoutSafety': {
      'insetFraction': .07,
      'bindingInsetFraction': .12,
      'printVerified': false,
    },
    'releaseChecks': {
      'deviceEditing': 'pending',
      'physicalProof': 'pending',
      'rightsReview': 'pending',
      'billing': 'pending',
      'blindComparison': 'pending',
    },
    'chapters': [
      for (final e in windAtlasSpreads.indexed)
        {'title': e.$2, 'from': e.$1 * 2 + 1, 'to': e.$1 * 2 + 2},
    ],
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
    'pageRoles': ids,
  };
}

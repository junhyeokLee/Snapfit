part of 'authored_collections.dart';

Map<String, dynamic> _journeyDraft(
  CollectionAspect aspect,
  EditorialCopy copy,
) {
  const paper = '#FBFCFA', ink = '#174D50', coral = '#CC513E';
  const sky = '#DFEEF1', mist = '#E7EFEB', yellow = '#F2F0D8';
  const harbor = '${_editorial}travel_harbor.png';
  const street = '${_editorial}travel_street.png';
  const coast = '${_editorial}travel_coast.png';
  const cafe = '${_editorial}travel_cafe.png';
  const train = '${_editorial}journey_train.png';
  const market = '${_editorial}journey_market.png';
  final book = _EditorialBook(EditorialVolume.journey, aspect, paper, ink);
  final wide = aspect == CollectionAspect.landscape;
  final tall = aspect == CollectionAspect.portrait;
  void label(
    _Sheet p,
    String id,
    String text,
    double x,
    double y,
    double w, {
    String? color,
    double h = .045,
  }) => p.text(
    id,
    text,
    x,
    y,
    w,
    h,
    size: .024,
    color: color ?? p.ink,
    weight: 500,
  );
  void body(
    _Sheet p,
    String id,
    String text,
    double x,
    double y,
    double w,
    double h, {
    double size = .031,
  }) => p.text(id, text, x, y, w, h, size: size, color: p.ink, lineHeight: 1.6);

  var p = book.sheet();
  p.box('spine_mark', .07, .076, .014, .125, coral);
  p.title('여행의 결', x: .12, y: .065, w: .78, h: .15, size: .112);
  label(p, 'cover_place', copy.place, .12, .221, .78);
  p.photo('cover_harbor', harbor, .07, .305, .86, .455);
  p.box('cover_rule', .07, .805, .86, .002, ink);
  label(p, 'cover_period', copy.period, .07, .827, .86);
  label(p, 'cover_byline', '${copy.byline}의 여행 기록', .07, .893, .86);
  book.add(p, '여행의 결 / 표지', 'journey-cover');

  // Departure: a small window opposite an expansive arrival photograph.
  p = book.sheet();
  label(p, 'opening', '출발 / 낯선 곳을 향해', .09, .085, .82, color: coral);
  p.title('조금 멀리,\n조금 느리게.', x: .09, y: .25, w: .82, h: .22, size: .08);
  body(
    p,
    'opening_note',
    '짐은 가볍게.\n마음은 넓게.\n\n이번에는 길 위에서\n시간을 잊어 보기로.',
    .09,
    .54,
    .38,
    .32,
  );
  p.photo(
    'departure_window',
    train,
    .57,
    .555,
    .34,
    .265,
    shape: 'studioRounded',
  );
  book.add(p, '출발 전의 마음', 'departure-note');
  p = book.sheet(sky);
  p.photo('arrival', harbor, .07, .07, .86, .785);
  label(p, 'arrival_caption', '도착하자마자, 바다부터.', .09, .882, .82);
  book.add(p, '처음 만난 항구', 'arrival-landscape');

  p = book.sheet();
  label(p, 'train_header', '01 / 창밖의 시간', .08, .08, .84, color: coral);
  p.photo('train_view', train, .08, .177, .84, .565);
  p.title('가는 길도 여행이니까.', x: .08, y: .79, w: .84, h: .095, size: .055);
  book.add(p, '차창에 남은 장면', 'train-observation');
  p = book.sheet();
  p.box('route_rule', .08, .175, .39, .003, coral);
  label(p, 'route_header', '그날의 작은 경로', .08, .085, .84);
  for (final entry in [
    ('01', '작은 역에서', '창문 너머 바다를 보고'),
    ('02', '골목을 지나', '지도는 잠깐 접어 두고'),
    ('03', '항구에 닿아', '낮은 돌담에 앉았다'),
  ].indexed) {
    final y = .235 + entry.$1 * .21;
    label(
      p,
      'stop_${entry.$1}',
      '${entry.$2.$1} / ${entry.$2.$2}',
      .08,
      y,
      .43,
    );
    body(
      p,
      'stop_note_${entry.$1}',
      entry.$2.$3,
      .08,
      y + .064,
      .43,
      .078,
      size: .025,
    );
  }
  p.photo('route_lane', street, .58, .22, .34, .58);
  book.add(p, '발걸음의 순서', 'route-register');

  p = book.sheet(mist);
  p.photo('lane_portrait', street, .09, .075, .68, .735);
  p.box('lane_tab', .82, .075, .09, .08, coral);
  label(p, 'lane_caption', '길을 잃어도 좋았던 골목.', .09, .857, .82);
  book.add(p, '이름 모를 골목', 'lane-asymmetry');
  p = book.sheet();
  p.photo('lane_harbor', harbor, .08, .14, .43, .64);
  body(p, 'lane_note', '모퉁이를 돌 때마다\n다른 빛이 기다렸다.', .59, .155, .33, .18);
  p.photo('lane_market', market, .59, .47, .33, .31, shape: 'studioGallery');
  label(p, 'lane_pair_caption', '눈길이 머문 것들을 한 장씩.', .08, .837, .84);
  book.add(p, '골목에서 주운 풍경', 'lane-pair');

  p = book.sheet(sky);
  p.title('아무것도\n서두르지 않는 곳.', x: .09, y: .09, w: .82, h: .205, size: .073);
  p.photo('sea_pause', coast, .09, .39, .82, .425);
  label(p, 'sea_caption', '소리까지 기억하고 싶은 오후.', .09, .853, .82);
  book.add(p, '바다 앞의 여백', 'sea-pause');
  p = book.sheet(ink, paper);
  p.photo('water_window', harbor, .1, .13, .8, .60, shape: 'studioArch');
  body(p, 'water_note', '한참을 보고 있어도\n같은 파도는 없었다.', .1, .79, .8, .105);
  book.add(p, '물빛을 오래 바라보기', 'arched-harbor');

  p = book.sheet();
  label(p, 'cafe_header', '02 / 오래 앉은 자리', .09, .085, .82, color: coral);
  p.photo('cafe_table', cafe, .09, .24, .82, .55);
  label(p, 'cafe_caption', '커피 두 잔. 이야기 몇 시간.', .09, .853, .82);
  book.add(p, '느린 카페', 'cafe-table');
  p = book.sheet(yellow);
  p.title('오늘의 메뉴', x: .09, y: .13, w: .82, h: .12, size: .067);
  p.box('menu_rule', .09, .3, .82, .002, ink);
  body(
    p,
    'menu_note',
    '따뜻한 커피\n갓 구운 빵\n그리고 끝나지 않는 이야기',
    .09,
    .355,
    wide ? .44 : .82,
    .24,
    size: .036,
  );
  p.circle('cafe_detail', cafe, .66, wide ? .43 : .60, wide ? .27 : .23);
  label(p, 'menu_footer', '평점 대신, 다시 오고 싶은 마음.', .09, .862, .82);
  book.add(p, '맛으로 남은 기억', 'cafe-menu');

  p = book.sheet();
  p.photo('market_still', market, .07, .12, .86, .645, shape: 'studioDeckle');
  p.title('그 동네의 색을 고르다.', x: .09, y: .81, w: .82, h: .1, size: .052);
  book.add(p, '시장의 아침', 'market-still-life');
  p = book.sheet();
  label(p, 'market_header', '작은 장보기 기록', .09, .085, .82, color: coral);
  p.circle('market_round', market, .09, .215, .41);
  body(
    p,
    'market_note',
    '종이봉투의 감촉,\n막 씻은 과일의 향.\n\n사진에 담기지 않는 것도\n함께 가져왔다.',
    .57,
    .255,
    .34,
    .33,
    size: wide ? .029 : .031,
  );
  p.box('market_rule', .09, .76, .82, .002, ink);
  label(p, 'market_foot', '가장 작은 기념품은 오늘의 감각.', .09, .816, .82);
  book.add(p, '종이봉투 속 여행', 'market-inventory');

  p = book.sheet(mist);
  label(p, 'pocket_header', '03 / 주머니 속 조각', .09, .08, .82);
  p.photo('pocket_cafe', cafe, .09, .2, .49, .42, shape: 'studioInstant');
  p.photo('pocket_street', street, .66, .39, .25, .31, shape: 'studioTicket');
  p.material('pocket_tape', 'studioWashiSage', .20, .18, .23);
  body(
    p,
    'pocket_note',
    '티켓 대신 남겨 둔 사진.\n작은 조각마다 하루가 들어 있다.',
    .09,
    .782,
    .82,
    .105,
  );
  book.add(p, '꺼내 보는 조각들', 'pocket-archive');
  p = book.sheet();
  p.title('남겨 둔 것', x: .09, y: .1, w: .82, h: .11, size: .072);
  for (final entry in [
    ('빛', '돌계단에 내려앉은 오후'),
    ('향', '봉투를 열 때의 레몬'),
    ('소리', '정박한 배가 흔들리는 소리'),
    ('마음', '다음에 또 오자는 약속'),
  ].indexed) {
    final y = .29 + entry.$1 * .14;
    p.box('memory_rule_${entry.$1}', .09, y, .82, .0015, '#B8CFCA');
    label(p, 'memory_key_${entry.$1}', entry.$2.$1, .09, y + .035, .13);
    body(
      p,
      'memory_value_${entry.$1}',
      entry.$2.$2,
      .28,
      y + .025,
      .63,
      .08,
      size: .029,
    );
  }
  book.add(p, '감각의 목록', 'sensory-register');

  p = book.sheet();
  label(p, 'color_header', '길 위에서 모은 색', .09, .08, .82, color: coral);
  p.photo('color_street', street, .09, .185, .82, .555);
  for (final color in [ink, '#A9C9D1', '#EFCAC0', '#E6E7CE'].indexed) {
    p.box(
      'swatch_${color.$1}',
      .09 + color.$1 * .205,
      .785,
      .19,
      .035,
      color.$2,
    );
  }
  label(p, 'color_caption', '물빛 / 그늘 / 꽃 / 햇살', .09, .853, .82);
  book.add(p, '그곳의 팔레트', 'travel-palette');
  p = book.sheet();
  p.photo('color_market', market, .09, .105, .49, .365);
  p.photo('color_sea', coast, .38, .55, .53, .30);
  body(
    p,
    'color_note',
    '여행의 색은\n서로 다른 시간에\n천천히 모였다.',
    .09,
    .575,
    .23,
    .23,
    size: .027,
  );
  book.add(p, '다른 시간의 두 장면', 'offset-color-study');

  p = book.sheet(sky);
  p.photo('return_coast', coast, .07, .07, .86, .77);
  label(p, 'return_coast_note', '다시 걷는다면, 같은 속도로.', .09, .878, .82);
  book.add(p, '다시 걷고 싶은 길', 'return-path');
  p = book.sheet();
  p.title('한 번 더,\n이 골목으로.', x: .09, y: .115, w: .82, h: .23, size: .077);
  p.photo('return_lane', street, .09, .435, .37, .35, shape: 'studioRounded');
  body(
    p,
    'return_lane_note',
    '길을 외운 뒤에도\n새로 보이는 것들.\n\n익숙해질 즈음\n떠나야 했다.',
    .55,
    .47,
    .36,
    .31,
  );
  book.add(p, '다음 여행의 첫 번째 장소', 'return-intention');

  p = book.sheet(yellow);
  p.photo('postcard_front', harbor, .09, .15, .82, .55, shape: 'studioGallery');
  body(p, 'postcard_caption', '이 풍경을 당신에게도\n보여 주고 싶었다.', .09, .76, .82, .12);
  book.add(p, '보내지 않은 엽서 앞면', 'postcard-front');
  p = book.sheet();
  label(p, 'postcard_to', '멀리 있는 당신에게', .1, .11, .8, color: coral);
  p.box('postcard_rule', .1, .205, .8, .002, ink);
  body(
    p,
    'postcard_letter',
    '여기는 하루가 조금 길어.\n\n'
        '아침에는 바다를 보고, 점심에는 골목을 걷고,\n저녁에는 오늘 좋았던 일을 하나씩 말해.\n\n'
        '돌아가면 사진보다 긴 이야기를 들려줄게.',
    .1,
    .285,
    .8,
    .40,
    size: .031,
  );
  label(p, 'postcard_from', copy.byline, .1, .79, .8);
  book.add(p, '보내지 않은 엽서 뒷면', 'postcard-letter');

  p = book.sheet();
  p.photo('home_train', train, .09, .095, .82, tall ? .66 : .63);
  p.title('돌아가는 길의 빛', x: .09, y: .81, w: .82, h: .1, size: .059);
  book.add(p, '돌아오는 창가', 'homebound-window');
  p = book.sheet(mist);
  label(p, 'end_place', copy.place, .09, .095, .82);
  p.title('여행은 끝나도\n장면은 남는다.', x: .09, y: .26, w: .82, h: .23, size: .075);
  p.photo('end_market', market, .09, .585, .32, .23, shape: 'studioTicket');
  body(p, 'end_note', '마지막 날에도\n작은 기념 하나.', .5, .625, .41, .14);
  book.add(p, '가방에 넣지 못한 풍경', 'homebound-keepsake');

  p = book.sheet();
  p.photo('last_coast', coast, .12, .14, .76, .52);
  body(
    p,
    'last_photo_note',
    '여행을 다녀온 뒤,\n평범한 길도 조금 다르게 보였다.',
    .12,
    .755,
    .76,
    .13,
  );
  book.add(p, '여행 다음의 날', 'after-journey');
  p = book.sheet();
  label(p, 'closing_header', '돌아와서 쓰는 문장', .1, .095, .8, color: coral);
  p.title('오래 남을 여행.', x: .1, y: .21, w: .8, h: .115, size: .067);
  body(p, 'closing_note', copy.note, .1, .365, .8, .40, size: .03);
  p.box('closing_rule', .1, .809, .8, .002, ink);
  label(p, 'closing_period', copy.period, .1, .846, .8);
  book.add(p, '여행의 마지막 기록', 'journey-closing-letter');
  return book.document;
}

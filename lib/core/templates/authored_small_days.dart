part of 'authored_collections.dart';

Map<String, dynamic> _smallDaysDraft(
  CollectionAspect aspect,
  EditorialCopy copy,
) {
  const paper = '#FEFEFB', ink = '#413440', plum = '#755270';
  const lime = '#E9EDBD', pink = '#F4E3E7', blue = '#E6EEF2';
  const breakfast = '${_editorial}small_days_breakfast.png';
  const walk = '${_editorial}small_days_walk.png';
  const desk = '${_editorial}daily_desk.png';
  const picnic = '${_editorial}daily_picnic.png';
  const friends = '${_editorial}daily_friends.png';
  const fruit = '${_editorial}daily_fruit.png';
  const reading = '${_editorial}daily_book.png';
  final book = _EditorialBook(EditorialVolume.smallDays, aspect, paper, ink);
  final wide = aspect == CollectionAspect.landscape;
  final tall = aspect == CollectionAspect.portrait;
  void label(
    _Sheet p,
    String id,
    String value,
    double x,
    double y,
    double w, {
    String? color,
  }) => p.text(
    id,
    value,
    x,
    y,
    w,
    .045,
    size: .024,
    color: color ?? p.ink,
    weight: 500,
  );
  void body(
    _Sheet p,
    String id,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .031,
  }) =>
      p.text(id, value, x, y, w, h, size: size, color: p.ink, lineHeight: 1.6);

  var p = book.sheet(lime);
  p.title('작은 날의\n기록', x: .085, y: .065, w: .83, h: .27, size: .105);
  p.photo('cover_walk', walk, .355, .365, .56, .42, shape: 'studioOval');
  body(p, 'cover_volume', '좋아하는\n순간을\n모아서.', .085, .46, .22, .22, size: .032);
  label(p, 'cover_season', copy.place, .085, .837, .83);
  label(p, 'cover_author', '${copy.byline}의 생활 기록', .085, .9, .83);
  book.add(p, '작은 날의 기록 / 표지', 'small-days-cover');

  // A playful opening, then one generous still life; no wedding-style dedication.
  p = book.sheet();
  label(p, 'mood_header', '오늘의 기분을 한 장에', .09, .09, .82, color: plum);
  p.circle(
    'mood_fruit',
    fruit,
    wide ? .64 : .57,
    wide ? .17 : .215,
    wide ? .26 : .33,
  );
  p.title('별일 없던 날도\n좋은 날이었다.', x: .09, y: .57, w: .82, h: .20, size: .072);
  label(p, 'mood_season', copy.place, .09, .845, .82);
  book.add(p, '기록을 시작하는 마음', 'mood-opening');
  p = book.sheet(pink);
  p.photo('mood_desk', desk, .09, .105, .82, .675, shape: 'studioRounded');
  body(p, 'mood_caption', '오늘 가장 먼저 마음에 들어온 장면.', .09, .833, .82, .065);
  book.add(p, '오늘의 첫 장면', 'mood-still-life');

  p = book.sheet();
  p.title('아침을\n차리는 일', x: .09, y: .10, w: .82, h: .21, size: .079);
  p.photo('morning_breakfast', breakfast, .09, .41, .82, .395);
  label(p, 'morning_caption', '서두르지 않는 날의 첫 번째 식사.', .09, .851, .82);
  book.add(p, '느린 아침 식탁', 'breakfast-table');
  p = book.sheet(lime);
  label(p, 'morning_header', '아침의 작은 순서', .1, .09, .8);
  body(
    p,
    'morning_list',
    '창문을 열고\n물을 한 잔 마시고\n오늘 쓸 접시를 고른다.',
    .1,
    .24,
    .8,
    .245,
    size: .043,
  );
  p.photo('morning_fruit', fruit, .1, .57, .36, .255, shape: 'studioCapsule');
  body(
    p,
    'morning_note',
    '사소한 선택들이\n하루의 기분을 만든다.',
    .55,
    .635,
    .35,
    .14,
    size: .029,
  );
  book.add(p, '하루를 여는 순서', 'morning-ritual');

  p = book.sheet();
  p.photo('desk_main', desk, .085, .1, .54, .69);
  body(p, 'desk_side', '책상 위에\n좋아하는 것을\n하나씩.', .705, .32, .21, .23, size: .027);
  label(p, 'desk_caption', '일하는 자리에도 작은 취향.', .085, .847, .83, color: plum);
  book.add(p, '책상이라는 작은 세계', 'desk-portrait');
  p = book.sheet(blue);
  label(p, 'objects_header', '마음에 드는 물건들', .09, .09, .82);
  p.photo(
    'objects_reading',
    reading,
    .09,
    .195,
    .39,
    .39,
    shape: 'studioGallery',
  );
  p.photo(
    'objects_breakfast',
    breakfast,
    .56,
    .34,
    .35,
    .35,
    shape: 'studioRounded',
  );
  body(
    p,
    'objects_note',
    '오래 읽은 책과 손에 익은 그릇.\n새것이 아니어도, 충분히 좋다.',
    .09,
    .77,
    .82,
    .12,
  );
  book.add(p, '손에 익은 취향', 'objects-pair');

  p = book.sheet();
  label(p, 'pause_header', '잠깐 쉬어 가는 페이지', .1, .09, .8, color: plum);
  p.photo('pause_reading', reading, .18, .2, .64, .51, shape: 'studioArch');
  p.title('쉬는 것도, 하루의 일.', x: .1, y: .795, w: .8, h: .11, size: .055);
  book.add(p, '책을 덮어 둔 시간', 'reading-pause');
  p = book.sheet(pink);
  p.title('아무것도 하지 않은\n시간도 남겨 두기.', x: .1, y: .16, w: .8, h: .24, size: .064);
  p.box('pause_rule', .1, .49, .8, .002, plum);
  body(
    p,
    'pause_note',
    '창가에 앉아 빛이 옮겨 가는 걸 봤다.\n\n'
        '대답하지 않은 메시지도, 덜 읽은 책도\n조금쯤 기다려 줄 것 같았다.',
    .1,
    .565,
    .8,
    .25,
    size: .033,
  );
  book.add(p, '아무 일 없는 오후', 'quiet-paragraph');

  p = book.sheet();
  p.photo('flower_walk', walk, .09, .075, .82, .73, shape: 'studioOval');
  label(p, 'flower_caption', '오는 길에 꽃을 샀다.', .09, .849, .82);
  book.add(p, '꽃을 사는 산책', 'flower-walk');
  p = book.sheet();
  label(p, 'flower_header', '오늘 들고 온 색', .09, .085, .82, color: plum);
  p.photo('flower_desk', desk, .09, .22, .48, .46, shape: 'studioDeckle');
  p.material('flower_pressed', 'studioPressedCosmos', .70, .28, .16);
  body(
    p,
    'flower_note',
    '어제와 같은 방에\n오늘의 꽃 하나.',
    .09,
    .77,
    .82,
    .12,
    size: .036,
  );
  book.add(p, '방 안에 도착한 계절', 'flower-keepsake');

  p = book.sheet(lime);
  p.title('같이 먹으면\n더 좋은 것들.', x: .09, y: .095, w: .82, h: .21, size: .074);
  p.photo('picnic_cloth', picnic, .09, .385, .82, .435);
  label(p, 'picnic_caption', '조금씩 가져와, 넉넉해진 식탁.', .09, .86, .82);
  book.add(p, '밖에서 먹는 점심', 'picnic-table');
  p = book.sheet();
  p.photo('picnic_fruit', fruit, .09, .14, .43, .39, shape: 'studioRounded');
  p.photo(
    'picnic_breakfast',
    breakfast,
    .60,
    .4,
    .31,
    .37,
    shape: 'studioTicket',
  );
  body(
    p,
    'picnic_note',
    '어떤 메뉴였는지보다\n누구와 웃었는지가\n더 오래 남는다.',
    .09,
    .635,
    .43,
    .20,
    size: .031,
  );
  book.add(p, '나누어 먹는 마음', 'shared-meal');

  p = book.sheet();
  label(p, 'friends_header', '우리의 얼굴', .09, .08, .82, color: plum);
  // Preserve the group photo's full 3:2 frame in every physical album format.
  final groupW = wide ? .74 : .84;
  final groupH = groupW * aspect.canvas.aspectRatio / 1.5;
  final groupX = (1 - groupW) / 2;
  p.photo(
    'friends_uncropped',
    friends,
    groupX,
    .49 - groupH / 2,
    groupW,
    groupH,
  );
  label(p, 'friends_caption', '한 장에 다 담기지 않는 웃음.', .09, .872, .82);
  book.add(p, '함께 웃은 사람들', 'friends-full-frame');
  p = book.sheet(pink);
  p.title('자주 만나지 못해도\n늘 편한 사이.', x: .09, y: .105, w: .82, h: .22, size: .069);
  p.photo(
    'friends_afternoon',
    picnic,
    .42,
    .43,
    .49,
    .36,
    shape: 'studioScallop',
  );
  body(p, 'friends_note', '다음 약속은\n헤어지기 전에.', .09, .56, .26, .18, size: .031);
  label(p, 'friends_footer', '오늘도 만나서 좋았어.', .09, .867, .82);
  book.add(p, '다음 약속', 'friendship-note');

  p = book.sheet();
  p.photo('season_fruit', fruit, .09, .11, .82, .635);
  p.title('계절은 맛으로 온다.', x: .09, y: .798, w: .82, h: .108, size: .059);
  book.add(p, '계절의 한 접시', 'seasonal-still');
  p = book.sheet(lime);
  label(p, 'season_header', '이번 계절의 취향', .09, .095, .82);
  for (final item in [
    ('먹은 것', '차갑게 씻은 딸기'),
    ('본 것', '하루 더 피어난 꽃'),
    ('들은 것', '창문 밖의 가벼운 바람'),
  ].indexed) {
    final y = .24 + item.$1 * .16;
    p.box('season_rule_${item.$1}', .09, y, .82, .0015, '#BFC59D');
    label(p, 'season_label_${item.$1}', item.$2.$1, .09, y + .045, .21);
    body(p, 'season_value_${item.$1}', item.$2.$2, .36, y + .03, .55, .083);
  }
  label(p, 'season_period', copy.period, .09, .838, .82, color: plum);
  book.add(p, '감각으로 쓴 계절', 'season-register');

  p = book.sheet();
  label(p, 'habit_header', '나를 돌보는 작은 습관', .09, .08, .82, color: plum);
  p.photo('habit_breakfast', breakfast, .09, .19, .50, .39);
  body(p, 'habit_a', '밥을 천천히\n먹는 일.', .68, .31, .23, .18, size: .03);
  p.photo('habit_book', reading, .56, .65, .35, .22, shape: 'studioRounded');
  body(p, 'habit_b', '잠들기 전에\n몇 장 읽는 일.', .09, .70, .39, .13);
  book.add(p, '다정한 습관 두 가지', 'daily-ritual-pair');
  p = book.sheet(blue);
  p.photo('habit_walk', walk, .14, .105, .72, .665, shape: 'studioCapsule');
  label(p, 'habit_caption', '나에게 주는, 별것 아닌 선물.', .10, .837, .8);
  book.add(p, '나를 위한 산책', 'self-care-portrait');

  p = book.sheet();
  p.title('이번 달의\n작은 기록', x: .09, y: .085, w: .82, h: .205, size: .075);
  p.photo('month_desk', desk, .09, .39, .35, .28, shape: 'studioGallery');
  p.photo('month_picnic', picnic, .52, .39, .39, .28, shape: 'studioGallery');
  label(p, 'month_a', '집에서 보낸 날', .09, .715, .35);
  label(p, 'month_b', '밖에서 보낸 날', .52, .715, .39);
  label(p, 'month_period', copy.period, .09, .853, .82, color: plum);
  book.add(p, '두 장으로 남긴 한 달', 'month-diptych');
  p = book.sheet();
  label(p, 'month_note_header', '잊기 전에, 세 문장', .1, .09, .8, color: plum);
  for (final entry in [
    ('기분 좋았던 일', '별다른 이유 없이 친구에게 전화를 걸었다.'),
    ('처음 해 본 일', '늘 지나치던 꽃집에서 내 취향을 골랐다.'),
    ('다음 달에도', '하루 한 장. 좋은 장면을 놓치지 않기.'),
  ].indexed) {
    final y = .245 + entry.$1 * .205;
    label(p, 'month_key_${entry.$1}', entry.$2.$1, .1, y, .8);
    body(p, 'month_value_${entry.$1}', entry.$2.$2, .1, y + .062, .8, .115);
  }
  book.add(p, '한 달의 문장', 'monthly-journal');

  p = book.sheet(pink);
  label(p, 'favorites_header', '좋아하는 것은 가까이에', .09, .085, .82);
  p.circle('favorites_fruit', fruit, .10, .22, .34);
  p.photo('favorites_walk', walk, .57, .3, .33, .36, shape: 'studioSticker');
  body(
    p,
    'favorites_note',
    '취향이 조금씩 모여\n지금의 내가 된다.',
    .1,
    .775,
    .8,
    .12,
    size: .036,
  );
  book.add(p, '좋아하는 것의 모음', 'favorites-collection');
  p = book.sheet();
  p.photo('favorites_reading', reading, .09, .1, .82, .61);
  body(
    p,
    'favorites_caption',
    '오래 머물고 싶은 자리 하나면\n충분한 날이 있다.',
    .09,
    .77,
    .82,
    .13,
  );
  book.add(p, '오래 머무는 자리', 'favorite-corner');

  p = book.sheet(lime);
  p.title('내일도,\n이만큼 좋기를.', x: .1, y: .1, w: .8, h: .22, size: .081);
  p.photo(
    'tomorrow_breakfast',
    breakfast,
    .1,
    .43,
    .8,
    tall ? .32 : .38,
    shape: 'studioRounded',
  );
  label(p, 'tomorrow_caption', '또 한 번의 평범하고 다정한 하루.', .1, .862, .8);
  book.add(p, '다음 하루의 인사', 'tomorrow-table');
  p = book.sheet();
  label(
    p,
    'closing_header',
    '${copy.byline}의 마지막 메모',
    .1,
    .085,
    .8,
    color: plum,
  );
  p.title('작아서 더 오래.', x: .1, y: .205, w: .8, h: .115, size: .069);
  body(p, 'closing_note', copy.note, .1, .37, .8, .40, size: .03);
  p.box('closing_rule', .1, .815, .8, .002, plum);
  label(p, 'closing_season', copy.place, .1, .853, .8);
  book.add(p, '작은 날을 묶는 문장', 'small-days-closing');
  return book.document;
}

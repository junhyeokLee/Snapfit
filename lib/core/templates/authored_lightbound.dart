part of 'authored_collections.dart';

const lightboundWeddingTitle = '빛으로 엮은 우리';
const lightboundWeddingDraftId = 'lightbound_wedding_draft';
const lightboundSpreadNames = [
  '서로에게 닿은 날',
  '시간의 결',
  '작은 약속',
  '둘의 초상',
  '작은 보관함',
  '함께한 얼굴들',
  '축하의 자리',
  '저녁의 온도',
  '기억의 기록',
  '우리의 평범한 날',
  '오래 지킬 마음',
  '다음의 우리',
];
const lightboundInnerPageCount = 24;

class LightboundWeddingCopy {
  const LightboundWeddingCopy({
    this.firstName = '수연',
    this.secondName = '지후',
    this.date = '2026. 05. 24',
    this.letter =
        '우리가 함께 보낸 첫날을\n이렇게 한 권에 묶어 둡니다.\n\n'
        '특별한 날보다 평범한 날에\n더 자주 서로의 편이 되어 주기를.\n\n'
        '시간이 지나 이 책을 다시 펼치면,\n오늘의 마음부터 떠올려 주세요.',
  });
  final String firstName, secondName, date, letter;
  String get names => '$firstName · $secondName';
}

/// Free baseline collection. Stable draft-era IDs preserve existing documents.
Map<String, dynamic> buildLightboundWeddingDraft(
  CollectionAspect aspect, {
  LightboundWeddingCopy copy = const LightboundWeddingCopy(),
}) {
  const paper = '#FCFDFB', ink = '#293B36', sage = '#E7EDE9', lilac = '#EEE7EC';
  const couple = '${_editorial}petal_couple.png';
  const veil = '${_editorial}petal_veil.png';
  const bouquet = '${_editorial}petal_bouquet.png';
  const rings = '${_editorial}petal_details.png';
  const table = '${_editorial}petal_table.png';
  const evening = '${_editorial}petal_evening.png';
  const ceremony = '${_editorial}lightbound_ceremony.png';
  const guests = '${_editorial}lightbound_guests.png';
  const twilight = '${_editorial}lightbound_twilight.png';
  const cake = '${_editorial}lightbound_cake.png';
  const desk = '${_editorial}daily_desk.png';
  const book = '${_editorial}daily_book.png';
  const fruit = '${_editorial}daily_fruit.png';
  final pages = <Map<String, dynamic>>[];
  final portrait = aspect == CollectionAspect.portrait;
  final wide = aspect == CollectionAspect.landscape;
  _Sheet sheet([String background = paper, String textInk = ink]) =>
      _Sheet('lightbound', aspect, pages.length, background, ink: textInk);
  void finish(_Sheet page, String name, String role) {
    if (page.index > 0) {
      final left = page.index.isOdd;
      page.text(
        'folio',
        page.index.toString().padLeft(2, '0'),
        left ? .07 : .83,
        .94,
        .10,
        .03,
        size: .019,
        color: page.ink,
        align: left ? 'left' : 'right',
      );
    }
    pages.add({
      ...page.json,
      'name': name,
      'role': role,
      'spreadIndex': page.index == 0 ? 0 : (page.index + 1) ~/ 2,
      'side': page.index == 0 ? 'cover' : (page.index.isOdd ? 'left' : 'right'),
    });
  }

  void label(
    _Sheet p,
    String id,
    String value,
    double x,
    double y,
    double w, {
    String color = ink,
  }) => p.text(id, value, x, y, w, .045, size: .024, color: color, weight: 500);

  var p = sheet();
  if (wide) {
    p.photo('cover_photo', couple, .07, .075, .55, .77);
    p.text(
      'edition',
      '우리의 첫 번째 책',
      .68,
      .17,
      .25,
      .045,
      size: .025,
      color: ink,
    );
    p.title('빛으로\n엮은 우리', x: .68, y: .36, w: .25, h: .26, size: .072);
    p.text('cover_date', copy.date, .68, .73, .25, .05, size: .026, color: ink);
  } else {
    p.photo('cover_photo', couple, .08, .07, .84, portrait ? .66 : .64);
    p.title(
      lightboundWeddingTitle,
      x: .08,
      y: portrait ? .785 : .765,
      w: .84,
      h: .09,
      size: .069,
      align: 'center',
    );
    p.text(
      'cover_date',
      copy.date,
      .08,
      portrait ? .875 : .865,
      .84,
      .04,
      size: .025,
      color: ink,
      align: 'center',
    );
  }
  p.text(
    'cover_names',
    copy.names,
    .08,
    .925,
    .84,
    .04,
    size: .027,
    color: ink,
    align: wide ? 'right' : 'center',
  );
  finish(p, '빛으로 엮은 우리 / 표지', 'photographic-cover');

  // 01-02: the quiet dedication gives the facing portrait room to breathe.
  p = sheet();
  label(p, 'section', '하나 / 서로에게 닿은 날', .09, .075, .81);
  p.photo(
    'light_window',
    veil,
    wide ? .67 : .64,
    .18,
    wide ? .25 : .28,
    wide ? .30 : .25,
  );
  p.title(
    '오래도록,\n이 빛 안에.',
    x: .09,
    y: wide ? .35 : .45,
    w: wide ? .51 : .75,
    h: .22,
    size: .070,
  );
  p.text(
    'dedication',
    '서로의 이름을 부르던 날.\n그날의 빛과 마음을\n천천히 펼쳐 봅니다.',
    .09,
    wide ? .67 : .73,
    .76,
    .16,
    size: .031,
    lineHeight: 1.5,
    color: ink,
  );
  finish(p, '첫 장의 인사', 'dedication');
  p = sheet(sage);
  p.photo('first_portrait', couple, .07, .07, .86, portrait ? .79 : .78);
  label(p, 'portrait_caption', '우리, 같은 방향을 바라보기 시작한 날.', .09, .885, .82);
  finish(p, '서로를 바라보는 순간', 'full-portrait');

  // 03-04: staggered details become a calm sequence, not a uniform photo grid.
  p = sheet();
  label(p, 'section', '둘 / 시간의 결', .09, .075, .82);
  if (wide) {
    p.photo('getting_ready', bouquet, .08, .20, .43, .59);
    p.photo('waiting_light', veil, .59, .37, .33, .42);
    label(p, 'time_a', '01 / 설레던 아침', .08, .82, .43);
    label(p, 'time_b', '02 / 고요한 기다림', .59, .82, .33);
  } else {
    p.photo('getting_ready', bouquet, .08, .20, .54, portrait ? .59 : .56);
    p.photo('waiting_light', veil, .69, .45, .23, portrait ? .27 : .31);
    label(p, 'time_a', '01 / 설레던 아침', .08, .83, .45);
    p.text(
      'time_b',
      '02\n고요한 기다림',
      .69,
      .80,
      .23,
      .085,
      size: .023,
      lineHeight: 1.4,
      color: ink,
    );
  }
  finish(p, '설레는 준비', 'staggered-sequence');
  p = sheet();
  p.photo('our_table', table, .08, .085, .84, wide ? .43 : .44);
  label(p, 'table_caption', '03 / 우리가 함께 앉을 자리', .08, wide ? .54 : .555, .84);
  p.title('당신과\n나란히.', x: .08, y: wide ? .65 : .69, w: .40, h: .19, size: .054);
  p.photo(
    'afterglow_inset',
    evening,
    .56,
    wide ? .66 : .665,
    .36,
    wide ? .20 : .205,
  );
  finish(p, '함께하는 자리', 'scene-and-afterglow');

  // 05-08: the vows and close portraits have their own pace before the archive.
  p = sheet(sage);
  p.photo('vows_scene', ceremony, .08, .08, .84, portrait ? .75 : .74);
  label(p, 'vows_caption', '마주 잡은 손, 함께 시작하는 문장.', .09, .875, .82);
  finish(p, '서로에게 하는 약속', 'vow-portrait');
  p = sheet();
  label(p, 'section', '셋 / 작은 약속', .10, .075, .80);
  p.title(
    '당신의 오늘과\n내일을 함께\n걷겠습니다.',
    x: .10,
    y: .19,
    w: .80,
    h: .26,
    size: .055,
  );
  p.text('vow_names', copy.names, .10, .465, .80, .045, size: .026, color: ink);
  final ringWidth = wide ? .28 : .38;
  p.circle('vow_rings', rings, (1 - ringWidth) / 2, .54, ringWidth);
  finish(p, '함께 걷겠다는 말', 'vow-and-seal');

  p = sheet();
  label(p, 'section', '넷 / 둘의 초상', .09, .075, .82);
  p.photo('close_portrait', twilight, .15, .20, .70, .62, shape: 'studioArch');
  label(p, 'close_caption', '가장 가까이에서, 가장 편안하게.', .15, .87, .72);
  finish(p, '가까운 표정', 'arched-portrait');
  p = sheet();
  p.photo('portrait_walk', couple, .08, .12, .39, wide ? .54 : .55);
  p.photo('portrait_rest', evening, .53, .25, .39, wide ? .54 : .55);
  p.text(
    'portrait_note',
    '걷다가,\n잠시 쉬어 가다가.',
    .08,
    .73,
    .39,
    .15,
    size: .034,
    font: 'Eulyoo',
    lineHeight: 1.5,
    color: ink,
  );
  label(p, 'portrait_date', copy.date, .53, .85, .39);
  finish(p, '둘만의 걸음', 'offset-portrait-pair');

  // 09-10: retain the approved tactile spread between portraits and people.
  p = sheet(lilac);
  label(p, 'section', '다섯 / 작은 보관함', .09, .075, .82);
  p.photo(
    'bouquet_keepsake',
    bouquet,
    .10,
    .185,
    wide ? .56 : .62,
    wide ? .64 : .60,
    shape: 'studioDeckle',
  );
  p.material(
    'pressed_flower',
    'studioPressedCosmos',
    wide ? .77 : .80,
    .205,
    wide ? .10 : .08,
  );
  p.text(
    'keepsake_note',
    '오래\n간직할\n작은 것들.',
    wide ? .72 : .77,
    wide ? .50 : .53,
    wide ? .20 : .15,
    .25,
    size: .028,
    font: 'Eulyoo',
    lineHeight: 1.8,
    color: ink,
  );
  label(p, 'keepsake_caption', '손끝에 남은 감촉까지 기억하고 싶어서.', .10, .84, .81);
  finish(p, '한 송이의 기억', 'tactile-keepsake');
  p = sheet();
  p.title('그날의 작은 목록', x: .09, y: .09, w: .82, h: .09, size: .044);
  final firstY = wide ? .24 : .225;
  p.photo(
    'rings_archive',
    rings,
    .09,
    firstY,
    .34,
    wide ? .27 : .29,
    shape: 'studioGallery',
  );
  label(p, 'rings_number', '01 / 약속', .50, firstY + .035, .40);
  p.text(
    'rings_note',
    '작은 원 안에\n담아 둔 우리의 마음.',
    .50,
    firstY + .115,
    .41,
    .13,
    size: .029,
    lineHeight: 1.6,
    color: ink,
  );
  p.photo('veil_archive', veil, .57, wide ? .60 : .59, .34, wide ? .27 : .29);
  label(p, 'veil_number', '02 / 기다림', .09, .63, .41);
  p.text(
    'veil_note',
    '바람이 지나간 자리,\n가만히 빛나던 오후.',
    .09,
    .715,
    .42,
    .13,
    size: .029,
    lineHeight: 1.6,
    color: ink,
  );
  finish(p, '기억의 목록', 'annotated-archive');

  // 11-12: keep the family photo's native 3:2 shape, including on tall pages.
  p = sheet();
  p.title(
    '우리 곁의 사람들',
    x: .08,
    y: wide ? .05 : .075,
    w: .84,
    h: wide ? .08 : .10,
    size: .048,
  );
  final groupWidth = wide ? .78 : .84;
  p.photo(
    'family_group',
    guests,
    (1 - groupWidth) / 2,
    wide ? .16 : (portrait ? .30 : .24),
    groupWidth,
    groupWidth * p.ratio / 1.5,
  );
  p.text(
    'family_note',
    wide ? '함께해 준 마음 덕분에, 더 많이 웃었던 하루.' : '한자리에 모인 마음 덕분에\n이날의 우리는 더 많이 웃었습니다.',
    .09,
    wide ? .89 : (portrait ? .79 : .835),
    .82,
    wide ? .045 : .09,
    size: .026,
    lineHeight: 1.5,
    color: ink,
  );
  finish(p, '함께해 준 얼굴들', 'uncropped-family-portrait');
  p = sheet(sage);
  p.photo('thank_you_cake', cake, .08, .10, .38, .39);
  p.photo('thank_you_table', table, .55, .31, .37, .34);
  p.title('마음을 모아,\n오래 기억할게요.', x: .08, y: .725, w: .84, h: .15, size: .043);
  finish(p, '함께 만든 하루', 'gratitude-mosaic');

  // 13-14: generous celebration photographs, with no repeated ornamental frame.
  p = sheet();
  p.title('축하를 나누는 자리', x: .08, y: .075, w: .84, h: .10, size: .047);
  p.photo('celebration_table', table, .08, .235, .84, portrait ? .53 : .52);
  label(p, 'celebration_caption', '작은 건배와 끝나지 않던 이야기.', .08, .83, .84);
  finish(p, '나란히 앉은 식탁', 'reception-table');
  p = sheet(lilac);
  p.photo('celebration_cake', cake, .12, .08, .76, .66);
  p.title('둘이 나누는 달콤함', x: .09, y: .79, w: .82, h: .09, size: .043);
  label(p, 'cake_caption', '오늘의 기쁨을 한 조각씩.', .09, .89, .82);
  finish(p, '작은 축하', 'celebration-still-life');

  // 15-16: a single dark spread-side makes the evening pause intentional.
  p = sheet(ink, paper);
  p.photo('evening_close', twilight, .08, .08, .84, .78);
  label(p, 'evening_caption', '여덟 / 저녁의 온도', .09, .89, .82, color: paper);
  finish(p, '하루 끝의 표정', 'evening-portrait');
  p = sheet();
  p.title('시간이 조금\n느리게 흘렀다.', x: .09, y: .18, w: .82, h: .22, size: .057);
  p.text(
    'evening_words',
    '많은 인사가 지나간 뒤,\n다시 둘만의 목소리로.',
    .09,
    .46,
    .82,
    .13,
    size: .031,
    font: 'Eulyoo',
    lineHeight: 1.6,
    color: ink,
  );
  p.photo('evening_memory', evening, .09, .66, .38, .22);
  p.text(
    'evening_note',
    '괜찮은 하루였지.\n너와 함께여서.',
    .54,
    .70,
    .37,
    .13,
    size: .028,
    lineHeight: 1.6,
    color: ink,
  );
  finish(p, '느리게 흐르는 시간', 'quiet-evening-note');

  // 17-18: editable observations, not filler pages with another giant title.
  p = sheet();
  p.title('그날을 적어 두기', x: .08, y: .075, w: .84, h: .10, size: .046);
  p.photo('record_ring', rings, .08, .22, .39, .28, shape: 'studioGallery');
  p.photo('record_veil', veil, .53, .22, .39, .28, shape: 'studioGallery');
  p.box('record_rule', .08, .61, .84, .002, '#CCD6D1');
  label(p, 'record_date_label', '함께 시작한 날', .08, .655, .30);
  p.text('record_date', copy.date, .45, .65, .47, .055, size: .030, color: ink);
  label(p, 'record_names_label', '이 책의 두 사람', .08, .77, .30);
  p.text(
    'record_names',
    copy.names,
    .45,
    .755,
    .47,
    .10,
    size: .029,
    color: ink,
    lineHeight: 1.4,
  );
  finish(p, '날짜와 이름', 'personal-record');
  p = sheet(sage);
  p.title('기억하고 싶은 것들', x: .09, y: .09, w: .82, h: .10, size: .044);
  for (final (i, entry) in [
    ('가장 많이 웃었던 순간', '서로의 긴장을 알아보고\n같이 웃어 버렸을 때.'),
    ('오래 남은 한마디', '오늘처럼, 앞으로도\n늘 같은 편이 되어 주자.'),
    ('그날의 공기', '조용한 바람과\n손끝에 닿던 따뜻함.'),
  ].indexed) {
    final y = .27 + i * .205;
    label(p, 'memory_label_$i', '0${i + 1}', .09, y, .09);
    label(p, 'memory_title_$i', entry.$1, .23, y, .68);
    p.text(
      'memory_body_$i',
      entry.$2,
      .23,
      y + .055,
      .68,
      .13,
      size: .029,
      lineHeight: 1.6,
      color: ink,
    );
  }
  finish(p, '기억의 세 문장', 'memory-journal');

  // 19-20: everyday photographs give the wedding story a life beyond the day.
  p = sheet();
  p.title('우리의 평범한 날', x: .08, y: .085, w: .84, h: .10, size: .047);
  p.photo('ordinary_desk', desk, .08, .25, .84, .50);
  p.text(
    'ordinary_words',
    '특별한 날 다음에도\n소중한 하루는 계속되니까.',
    .08,
    .815,
    .84,
    .09,
    size: .030,
    font: 'Eulyoo',
    lineHeight: 1.4,
    color: ink,
  );
  finish(p, '일상으로 이어지는 책', 'everyday-opening');
  p = sheet();
  p.photo('ordinary_book', book, .09, .10, .56, .39, shape: 'studioRounded');
  p.photo('ordinary_fruit', fruit, .57, .59, .34, .26);
  p.text(
    'ordinary_note',
    '같은 집,\n다른 하루,\n함께인 마음.',
    .09,
    .63,
    .40,
    .22,
    size: .040,
    font: 'Eulyoo',
    lineHeight: 1.4,
    color: ink,
  );
  finish(p, '서로의 하루', 'everyday-vignettes');

  // 21-22: a soft portrait and three practical promises precede the final letter.
  p = sheet(lilac);
  p.photo(
    'promise_portrait',
    twilight,
    .15,
    .11,
    .70,
    .62,
    shape: 'studioOval',
  );
  p.title(
    '오래 지킬 마음',
    x: .10,
    y: .80,
    w: .80,
    h: .10,
    size: .049,
    align: 'center',
  );
  finish(p, '다정함을 약속하기', 'oval-promise-portrait');
  p = sheet();
  p.title('우리의 작은 약속', x: .09, y: .095, w: .66, h: .10, size: .045);
  p.material('promise_flower', 'studioPressedCosmos', .80, .08, .08);
  for (final (i, words) in [
    '하루에 한 번은\n서로의 이야기를 끝까지 듣기.',
    '함께 웃을 수 있는\n사소한 일들을 놓치지 않기.',
    '익숙해진 마음에도\n고맙다는 말은 아끼지 않기.',
  ].indexed) {
    final y = .28 + i * .18;
    label(p, 'promise_number_$i', '0${i + 1}', .09, y, .10);
    p.text(
      'promise_words_$i',
      words,
      .25,
      y - .01,
      .65,
      .12,
      size: .031,
      font: 'Eulyoo',
      lineHeight: 1.6,
      color: ink,
    );
  }
  label(p, 'promise_date', copy.date, .09, .855, .55);
  p.photo('promise_ring', rings, .72, .79, .19, .12);
  finish(p, '둘이 지켜 갈 일들', 'shared-promises');

  // 23-24: retain the approved ending with the personal letter on the right.
  p = sheet(sage);
  p.photo('last_light', evening, .08, .105, .84, portrait ? .64 : .62);
  p.title(
    '내일도, 같은 편.',
    x: .09,
    y: portrait ? .81 : .80,
    w: .82,
    h: .09,
    size: .048,
  );
  finish(p, '다음의 우리', 'closing-portrait');
  p = sheet();
  label(p, 'section', '열둘 / 다음의 우리', .10, .075, .80);
  p.title('미래의 우리에게', x: .10, y: .18, w: .80, h: .10, size: .045);
  p.text(
    'letter',
    copy.letter,
    .10,
    .325,
    .80,
    wide ? .49 : .50,
    size: wide ? .034 : .032,
    font: 'Eulyoo',
    lineHeight: 1.7,
    color: ink,
  );
  p.text(
    'signature',
    copy.names,
    .10,
    .86,
    .80,
    .045,
    size: .027,
    color: ink,
    align: 'right',
  );
  finish(p, '미래의 우리에게', 'personal-letter');

  return {
    'id': '${lightboundWeddingDraftId}_${aspect.name}',
    'title': lightboundWeddingTitle,
    'source': 'snapfit-authored-free',
    'aiGenerated': false,
    'publicationStatus': 'bundled',
    'accessTier': 'free',
    'catalogPublishable': false,
    'version': 2,
    'innerPageCount': lightboundInnerPageCount,
    'targetInnerPageCount': lightboundInnerPageCount,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'layoutSafety': {'insetFraction': .06, 'printVerified': false},
    'chapters': [
      for (var i = 0; i < lightboundSpreadNames.length; i++)
        {'title': lightboundSpreadNames[i], 'from': 1 + i * 2, 'to': 2 + i * 2},
    ],
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
  };
}

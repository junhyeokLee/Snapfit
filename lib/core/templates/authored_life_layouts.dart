part of 'authored_collections.dart';

const _lifePalettes = {
  FreeCollectionVolume.firstYear: _FreePalette(
    '#FCFDFB',
    '#304C40',
    '#667CA4',
    '#EAF0E8',
    'studioGallery',
    serif: true,
  ),
  FreeCollectionVolume.littleSteps: _FreePalette(
    '#FAFCFE',
    '#31536B',
    '#A75D45',
    '#E4EFF5',
    'studioRounded',
  ),
  FreeCollectionVolume.babyBloom: _FreePalette(
    '#FFFBFC',
    '#714953',
    '#4D725D',
    '#F6E5EB',
    'studioScallop',
    serif: true,
  ),
  FreeCollectionVolume.playroom: _FreePalette(
    '#FFFDF7',
    '#334C85',
    '#CC5247',
    '#F8EDBB',
    'studioSticker',
  ),
  FreeCollectionVolume.birthday: _FreePalette(
    '#FCFCFF',
    '#625078',
    '#8B6733',
    '#EDE8F5',
    'studioArch',
  ),
  FreeCollectionVolume.homeYear: _FreePalette(
    '#FAFCFA',
    '#2C5045',
    '#A65442',
    '#E2EDE7',
    'studioGallery',
    serif: true,
  ),
  FreeCollectionVolume.familyTable: _FreePalette(
    '#FFFCF8',
    '#6B3E36',
    '#647B4A',
    '#F3E1D9',
    'studioScallop',
  ),
  FreeCollectionVolume.friendsUs: _FreePalette(
    '#FCFCFF',
    '#514B7B',
    '#8A633B',
    '#EAEAF6',
    'studioInstant',
  ),
  FreeCollectionVolume.generations: _FreePalette(
    '#FCFCFA',
    '#353D3B',
    '#61796E',
    '#E9ECE7',
    'none',
    serif: true,
  ),
  FreeCollectionVolume.familyOuting: _FreePalette(
    '#FAFCFF',
    '#34616B',
    '#AA573C',
    '#E2EEF2',
    'studioTicket',
  ),
  FreeCollectionVolume.usDays: _FreePalette(
    '#FFFCFD',
    '#6E414F',
    '#477B76',
    '#F4E7EC',
    'studioRounded',
  ),
  FreeCollectionVolume.dateFilm: _FreePalette(
    '#F8FAFC',
    '#293F50',
    '#B05B46',
    '#E5EAEF',
    'studioFilm',
  ),
  FreeCollectionVolume.loveSeason: _FreePalette(
    '#FCFDF9',
    '#465E49',
    '#9C5770',
    '#EAF0E2',
    'studioOval',
    serif: true,
  ),
  FreeCollectionVolume.anniversary: _FreePalette(
    '#FFFCFC',
    '#703D4E',
    '#707747',
    '#F3E6E9',
    'studioGallery',
    serif: true,
  ),
  FreeCollectionVolume.twoTickets: _FreePalette(
    '#FAFDFD',
    '#2C6267',
    '#B25353',
    '#DFF0EE',
    'studioDeckle',
  ),
  FreeCollectionVolume.pawDiary: _FreePalette(
    '#FAFCFB',
    '#3F6555',
    '#866336',
    '#E4EFE5',
    'studioRounded',
  ),
  FreeCollectionVolume.catNap: _FreePalette(
    '#FCFCFF',
    '#535574',
    '#527C71',
    '#EAEAF4',
    'studioCapsule',
    serif: true,
  ),
  FreeCollectionVolume.walkClub: _FreePalette(
    '#FBFDF9',
    '#3E6446',
    '#496C92',
    '#E9F0DD',
    'studioTicket',
  ),
  FreeCollectionVolume.petHome: _FreePalette(
    '#FFFDFC',
    '#835340',
    '#476C85',
    '#F4E5DE',
    'studioScallop',
  ),
  FreeCollectionVolume.petPortrait: _FreePalette(
    '#FAFCFC',
    '#304C54',
    '#9A6249',
    '#E3ECEB',
    'studioGallery',
    serif: true,
  ),
};

EditorialCopy? _lifeDefaultCopy(String category) => switch (category) {
  '성장·육아' => const EditorialCopy(
    place: '너와 함께 자라는 집',
    period: '2025. 06 ~ 2026. 06',
    byline: '하온의 기록',
    note:
        '너의 첫 순간을 곁에서 지켜볼 수 있어 기뻐.\n\n작은 변화에도 함께 웃고, 서두르지 않고 기다릴게. 어떤 모습으로 자라든 너의 속도를 응원한다.',
  ),
  '가족·친구' => const EditorialCopy(
    place: '우리의 일상이 모이는 곳',
    period: '2026년의 우리',
    byline: '함께한 사람들의 기록',
    note:
        '자주 만나는 얼굴에도 매번 새로운 이야기가 있다.\n\n같이 먹고 걷고 웃었던 시간을 모았다. 서로의 하루에 귀 기울이며, 다음에도 다정하게 만나자.',
  ),
  '커플·기념일' => const EditorialCopy(
    place: '둘이 함께 걷던 곳',
    period: '2025. 06 ~ 2026. 06',
    byline: '수연과 지후의 기록',
    note:
        '특별한 날 사이에 평범하고 좋은 날이 더 많았다.\n\n그 모든 날에 네가 있어서 기뻤다. 작은 마음도 놓치지 않고, 우리의 다음 페이지를 함께 써 나가자.',
  ),
  '반려동물' => const EditorialCopy(
    place: '함께 사는 우리 집',
    period: '2026년의 기록',
    byline: '소중한 동행의 기록',
    note:
        '말은 달라도 함께하는 마음은 전해진다.\n\n좋아하는 자리와 편안한 시간을 기억할게. 너의 속도에 맞춰 걷고, 매일의 작은 표정을 소중히 간직한다.',
  ),
  _ => null,
};

List<String>? _lifePhotos(FreeCollectionVolume v) {
  if (v == FreeCollectionVolume.friendsUs) {
    return const [
      'daily_picnic.png',
      'travel_cafe.png',
      'family_friends.png',
      'daily_book.png',
      'travel_coast.png',
      'daily_friends.png',
    ];
  }
  if (v == FreeCollectionVolume.catNap || v == FreeCollectionVolume.petHome) {
    return const [
      'pet_cat.png',
      'pet_nap.png',
      'pet_keepsakes.png',
      'daily_book.png',
    ];
  }
  return switch (v.category) {
    '성장·육아' => const [
      'growth_play.png',
      'growth_walk.png',
      'growth_sleep.png',
      'growth_keepsakes.png',
      'growth_birthday.png',
      'growth_hand.png',
    ],
    '가족·친구' => const [
      'family_picnic.png',
      'family_kitchen.png',
      'family_friends.png',
      'family_table.png',
      'daily_picnic.png',
      'daily_friends.png',
    ],
    '커플·기념일' => const [
      'couple_walk.png',
      'couple_cafe.png',
      'couple_anniversary.png',
      'couple_keepsakes.png',
      'travel_coast.png',
      'travel_cafe.png',
    ],
    '반려동물' => const [
      'pet_dog.png',
      'pet_walk.png',
      'pet_keepsakes.png',
      'pet_rest.png',
    ],
    _ => null,
  };
}

void _lifeMotif(_FreeBook b, _Sheet p) {
  final a = b.palette;
  switch (b.volume) {
    case FreeCollectionVolume.firstYear:
    case FreeCollectionVolume.homeYear:
    case FreeCollectionVolume.usDays:
      b.rule(p, .08, .046, .84, color: a.soft);
      for (var i = 0; i < 12; i++) {
        p.box(
          'month_$i',
          .08 + i * .072,
          .042,
          .012,
          .01,
          i == (p.index - 1) ~/ 2 ? a.accent : a.soft,
        );
      }
    case FreeCollectionVolume.playroom:
    case FreeCollectionVolume.friendsUs:
    case FreeCollectionVolume.petHome:
      p.material('motif_tape', 'studioWashiIndigo', .41, .028, .18, h: .025);
    case FreeCollectionVolume.babyBloom:
    case FreeCollectionVolume.loveSeason:
      p.material('flower', 'studioPressedCosmos', .025, .916, .044, h: .040);
    case FreeCollectionVolume.birthday:
    case FreeCollectionVolume.anniversary:
      p.material('motif_ribbon', 'studioSageRibbon', .855, .027, .061, h: .042);
    case FreeCollectionVolume.dateFilm:
      for (var i = 0; i < 9; i++) {
        p.box('film_$i', .08 + i * .10, .034, .024, .01, a.accent);
      }
    case FreeCollectionVolume.twoTickets:
    case FreeCollectionVolume.familyOuting:
    case FreeCollectionVolume.walkClub:
      p.box('route_tab', .028, .1, .012, .10, a.accent);
      b.rule(p, .78, .045, .14);
    default:
      b.rule(p, .08, .043, .16);
      b.rule(p, .82, .917, .1, color: a.soft);
  }
}

void _lifeCover(_FreeBook b) {
  final p = b.sheet();
  final a = b.palette;
  void heading(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .076,
    String align = 'left',
  }) => p.title(value, x: x, y: y, w: w, h: h, size: size, align: align);
  void photo(int i, double x, double y, double w, double h, {String? frame}) =>
      b.photo(p, 'cover_photo_${p.layers.length}', i, x, y, w, h, frame: frame);
  void band(double x, double y, double w, double h) =>
      p.box('stock_${p.layers.length}', x, y, w, h, a.soft);
  // Each cover is independently composed. None is a recolored retired cover.
  switch (b.volume) {
    case FreeCollectionVolume.firstYear:
      b.rule(p, .10, .09, .80);
      heading('너의 첫해', .10, .15, .80, .12, size: .093, align: 'center');
      photo(0, .16, .335, .68, .42);
      for (var i = 0; i < 12; i++)
        p.box(
          'month_$i',
          .17 + i * .056,
          .793,
          .024,
          .007,
          i.isEven ? a.accent : a.ink,
        );
    case FreeCollectionVolume.littleSteps:
      band(.055, .055, .89, .76);
      heading('작은 걸음의\n기록', .11, .11, .78, .22, size: .078);
      photo(1, .35, .385, .53, .34);
      photo(5, .10, .565, .20, .18, frame: 'studioOval');
      for (var i = 0; i < 6; i++)
        p.box(
          'measure_$i',
          .10,
          .385 + i * .024,
          i.isEven ? .065 : .035,
          .002,
          a.accent,
        );
    case FreeCollectionVolume.babyBloom:
      heading('너라는 봄', .10, .12, .80, .13, size: .094, align: 'center');
      photo(2, .20, .315, .60, .435, frame: 'studioOval');
      p.material('flower', 'studioPressedCosmos', .79, .65, .10, h: .13);
      b.rule(p, .35, .79, .30);
    case FreeCollectionVolume.playroom:
      band(0, 0, 1, 1);
      heading('알록달록\n자라는 날', .085, .08, .83, .24, size: .087);
      photo(0, .09, .39, .55, .35, frame: 'studioSticker');
      photo(3, .695, .49, .215, .22, frame: 'studioOval');
      p.box('color_a', .08, .785, .16, .012, a.accent);
      p.box('color_b', .25, .785, .08, .012, a.ink);
    case FreeCollectionVolume.birthday:
      photo(4, .085, .085, .83, .405, frame: 'none');
      heading('처음 맞는\n생일', .10, .56, .80, .215, size: .083, align: 'center');
      p.material('ribbon', 'studioSageRibbon', .77, .72, .13, h: .072);
    case FreeCollectionVolume.homeYear:
      heading('우리 집의\n사계절', .09, .095, .82, .225, size: .084);
      photo(0, .09, .38, .82, .36, frame: 'none');
      for (var i = 0; i < 4; i++)
        p.box(
          'season_$i',
          .09 + i * .21,
          .775,
          .18,
          .01,
          i.isEven ? a.ink : a.accent,
        );
    case FreeCollectionVolume.familyTable:
      band(.035, .035, .93, .77);
      heading('한 식탁의\n이야기', .095, .09, .81, .225, size: .086, align: 'center');
      photo(3, .105, .39, .49, .32, frame: 'studioScallop');
      photo(1, .65, .49, .24, .20, frame: 'none');
      b.rule(p, .105, .75, .785);
    case FreeCollectionVolume.friendsUs:
      heading('우리의\n좋은 사이', .105, .105, .79, .21, size: .080);
      photo(2, .08, .365, .84, .29, frame: 'none');
      photo(5, .575, .69, .33, .12, frame: 'none');
      b.text(p, 'friend_note', '같이 웃던 날들', .09, .713, .43, .052, size: .027);
    case FreeCollectionVolume.generations:
      b.rule(p, .08, .10, .84);
      heading('세대를 잇는\n사진', .09, .15, .82, .205, size: .071, align: 'center');
      photo(0, .07, .445, .86, .285, frame: 'none');
      b.rule(p, .37, .79, .26);
    case FreeCollectionVolume.familyOuting:
      band(0, .045, 1, .10);
      heading('함께 떠난\n소풍', .10, .21, .80, .21, size: .080);
      photo(0, .09, .49, .60, .285, frame: 'none');
      photo(4, .73, .61, .18, .165, frame: 'studioTicket');
    case FreeCollectionVolume.usDays:
      heading('너와 나의\n날짜들', .10, .10, .80, .22, size: .082);
      photo(0, .10, .385, .53, .36, frame: 'studioRounded');
      photo(1, .69, .48, .21, .24, frame: 'none');
      b.rule(p, .10, .79, .80);
    case FreeCollectionVolume.dateFilm:
      band(.035, .035, .93, .75);
      photo(0, .08, .13, .84, .37, frame: 'studioFilm');
      heading('둘만의 장면', .095, .565, .81, .12, size: .078);
      b.text(p, 'film_note', '우리의 작은 데이트 필름', .095, .715, .81, .05, size: .023);
    case FreeCollectionVolume.loveSeason:
      heading('사랑이 머문\n계절', .105, .09, .79, .225, size: .078, align: 'center');
      photo(0, .19, .36, .62, .385, frame: 'studioOval');
      p.material('petal', 'studioPressedCosmos', .075, .705, .10, h: .10);
    case FreeCollectionVolume.anniversary:
      b.rule(p, .20, .09, .60);
      heading('오래도록\n우리', .10, .17, .80, .22, size: .088, align: 'center');
      photo(2, .16, .475, .68, .26, frame: 'none');
      p.material('ribbon', 'studioSageRibbon', .78, .755, .08, h: .05);
    case FreeCollectionVolume.twoTickets:
      heading('둘이 모은\n조각', .085, .105, .83, .205, size: .082);
      photo(0, .085, .37, .49, .355, frame: 'studioTicket');
      photo(3, .645, .435, .265, .28, frame: 'studioDeckle');
      p.material('tape', 'studioWashiRose', .18, .335, .22, h: .025);
      b.rule(p, .09, .78, .82);
    case FreeCollectionVolume.pawDiary:
      heading('너의 하루를\n따라', .10, .105, .80, .225, size: .079);
      photo(0, .235, .38, .66, .375, frame: 'studioRounded');
      p.box('index', .10, .42, .03, .22, a.soft);
      b.rule(p, .235, .79, .66);
    case FreeCollectionVolume.catNap:
      band(.04, .04, .92, .75);
      photo(1, .13, .115, .74, .40, frame: 'studioCapsule');
      heading('낮잠의 모양', .09, .595, .82, .12, size: .083, align: 'center');
    case FreeCollectionVolume.walkClub:
      heading('산책이라는\n약속', .085, .09, .83, .225, size: .077);
      photo(1, .085, .38, .83, .355, frame: 'studioTicket');
      for (var i = 0; i < 8; i++)
        p.box('trail_$i', .09 + i * .11, .78, .045, .005, a.accent);
    case FreeCollectionVolume.petHome:
      heading('우리 집\n작은 가족', .10, .105, .80, .215, size: .081, align: 'center');
      photo(0, .115, .395, .47, .345, frame: 'studioScallop');
      photo(1, .65, .535, .235, .20, frame: 'studioRounded');
      p.material('tape', 'studioWashiSage', .225, .363, .23, h: .022);
    case FreeCollectionVolume.petPortrait:
      b.rule(p, .12, .09, .76);
      photo(0, .24, .16, .52, .37, frame: 'studioGallery');
      heading('가장 다정한\n얼굴', .12, .60, .76, .185, size: .072, align: 'center');
    default:
      throw StateError('Missing life cover: ${b.volume.id}');
  }
  b.text(
    p,
    'period',
    b.copy.period,
    .09,
    .844,
    .82,
    .049,
    size: .022,
    align: 'center',
  );
  b.text(
    p,
    'byline',
    b.copy.byline,
    .09,
    .915,
    .82,
    .041,
    size: .020,
    align: 'center',
  );
  b.pages.add({
    ...p.json,
    'name': '${b.volume.title} / 표지',
    'role': '${b.volume.id}-cover',
    'side': 'cover',
    'spreadIndex': 0,
  });
}

void _lifeSpread(_FreeBook b, _FreeSpread s, _Sheet l, _Sheet r, int chapter) {
  void label(_Sheet p, String text, double x, double y, double w) => b.text(
    p,
    'label_${p.layers.length}',
    text,
    x,
    y,
    w,
    .05,
    size: .023,
    color: b.palette.accent,
  );
  void photo(
    _Sheet p,
    int source,
    double x,
    double y,
    double w,
    double h, {
    String? frame,
  }) =>
      b.photo(p, 'photo_${p.layers.length}', source, x, y, w, h, frame: frame);
  label(l, '${chapter.toString().padLeft(2, '0')} / ${s.title}', .09, .09, .82);
  switch (s.layout) {
    case _FreeLayout.milestone:
      b.title(l, s.line, .09, .215, .82, .21, size: .07);
      for (var i = 0; i < 3; i++) {
        final y = .50 + i * .125;
        label(l, ['기억할 날짜', '오늘의 발견', '남기고 싶은 말'][i], .10, y, .30);
        b.rule(l, .45, y + .045, .44, color: b.palette.accent);
      }
      photo(r, s.photo, .11, .12, .78, .44);
      photo(r, s.detail, .11, .66, .30, .20);
      b.text(r, 'caption', s.caption, .50, .68, .39, .15, size: .029);
    case _FreeLayout.ribbonPair:
      photo(l, s.photo, .10, .22, .80, .43);
      b.title(l, s.line, .10, .735, .80, .15, size: .048);
      r.material('ribbon', 'studioSageRibbon', .76, .09, .12, h: .065);
      photo(r, s.detail, .19, .24, .62, .39);
      b.text(
        r,
        'caption',
        s.caption,
        .16,
        .75,
        .68,
        .10,
        size: .031,
        align: 'center',
      );
    case _FreeLayout.pinboard:
      photo(l, s.photo, .10, .22, .80, .35, frame: 'studioInstant');
      photo(l, s.detail, .10, .68, .32, .20, frame: 'studioRounded');
      b.text(l, 'caption', s.caption, .51, .69, .39, .16, size: .029);
      b.title(r, s.line, .10, .13, .80, .215, size: .071);
      photo(r, s.detail, .12, .49, .37, .30, frame: 'studioDeckle');
      photo(r, s.photo + 2, .57, .55, .31, .25, frame: 'studioTicket');
      r.material('tape', 'studioWashiSage', .19, .455, .22, h: .028);
    case _FreeLayout.fieldNotes:
      b.title(l, s.line, .09, .215, .82, .20, size: .067);
      photo(l, s.detail, .09, .535, .38, .265);
      b.text(l, 'caption', s.caption, .56, .57, .35, .20, size: .029);
      b.rule(l, .09, .87, .82);
      photo(r, s.photo, .085, .13, .83, .51, frame: 'none');
      label(r, '장소', .10, .745, .15);
      b.text(r, 'place', b.copy.place, .30, .738, .60, .075, size: .026);
      label(r, '기록', .10, .835, .15);
      b.rule(r, .30, .875, .60);
    case _FreeLayout.portraitEssay:
      photo(l, s.photo, .14, .235, .72, .49, frame: 'none');
      b.text(l, 'caption', s.caption, .14, .805, .72, .083, size: .029);
      b.title(r, s.line, .12, .15, .76, .215, size: .073);
      b.rule(r, .12, .43, .30);
      photo(r, s.detail, .47, .55, .41, .275);
      b.text(
        r,
        'essay',
        '오래 보고 싶은\n오늘의 한 장.',
        .12,
        .625,
        .28,
        .155,
        size: .030,
      );
    default:
      throw StateError('Unsupported life spread: ${s.layout}');
  }
}

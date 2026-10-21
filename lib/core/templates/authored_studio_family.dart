part of 'authored_collections.dart';

const _saturdayStories = [
  ('같이 나서는 아침', '늦지 않아도 되는 날, 서로의 속도에 맞춰 집을 나섰다.'),
  ('돗자리를 펴고', '가장 먼저 도착한 사람이 그늘이 좋은 자리를 골랐다.'),
  ('각자 가져온 것', '같은 메뉴가 하나도 없어서 점심이 더 풍성해졌다.'),
  ('모두 모인 사진', '한 명씩 찍어 주다가, 마지막에는 다 같이 들어갔다.'),
  ('오래 앉은 자리', '할 이야기가 남아서 일어날 생각을 잊었다.'),
  ('잠깐 걸어 볼까', '짐은 그대로 두고 가까운 길을 한 바퀴 걸었다.'),
  ('웃음이 번진 순간', '무슨 말 때문이었는지보다 웃던 얼굴이 더 잘 기억난다.'),
  ('조금 다른 오후', '늘 보던 얼굴을 낯선 풍경 속에서 다시 보았다.'),
  ('같이 차린 한 끼', '한 사람은 담고, 한 사람은 나르고, 모두 함께 먹었다.'),
  ('돌아가기 아쉬워서', '사진 한 장만 더 찍자고 몇 번이나 말했다.'),
  ('오늘의 작은 기록', '함께한 사람과 오래 머문 곳을 짧게 적어 두었다.'),
  ('다음 토요일에도', '특별한 계획이 없어도 이렇게 다시 만나면 좋겠다.'),
];

const _summerStories = [
  ('여름을 꺼내는 날', '차창을 열자 먼저 도착한 바람이 우리의 여름을 알려 주었다.'),
  ('같이 온 사람들', '누가 먼저 웃었는지 모를 만큼, 금세 같은 표정이 되었다.'),
  ('한낮의 연락 인화', '고르지 못한 사진들에도 그날의 이야기가 조금씩 남아 있었다.'),
  ('돗자리의 작은 물건', '수건과 물컵과 손에 쥔 귤 하나. 챙긴 것마다 쓸모가 있었다.'),
  ('파라솔 아래서', '햇볕을 피해 모인 자리에서 가장 오래 이야기를 나눴다.'),
  ('물을 따라 걷기', '젖은 발자국이 지워지는 동안 조금 더 멀리 걸었다.'),
  ('같은 풍경의 세 장면', '넓게 한 장, 가까이 한 장, 그리고 함께 한 장.'),
  ('잠시 쉬어 가는 곳', '아무것도 하지 않는 시간이 이렇게 잘 어울릴 줄 몰랐다.'),
  ('우리만 아는 표정', '카메라를 의식하지 않을 때 가장 좋아하는 얼굴이 나왔다.'),
  ('주머니에 남은 여름', '작은 조각을 버리지 못해, 사진 옆에 자리를 내주었다.'),
  ('해가 내려간 뒤', '밖이 어두워지자 하나둘 식탁 앞으로 모여들었다.'),
  ('한 판만 더 하자', '이긴 사람도 진 사람도 자리에서 쉽게 일어나지 못했다.'),
  ('내일도 기억할 것', '오래 기억하고 싶은 장면을 각자 하나씩 골라 보았다.'),
  ('함께 보낸 시간표', '정해 둔 일정 대신 그날 실제로 머문 시간을 적었다.'),
  ('마지막까지 천천히', '돌아갈 시간이 가까워질수록 사진을 더 자주 찍었다.'),
  ('다음 여름의 약속', '나눠 가진 사진들을 한 권에 모아, 다음에 다시 펼치기로 했다.'),
];

const _familyPhotos = [
  'assets/templates/atelier_editions_2026/saturday-together.png',
  'assets/templates/original_editorial/images/family_picnic.png',
  'assets/templates/original_editorial/images/daily_picnic.png',
  'assets/templates/original_editorial/images/family_friends.png',
  'assets/templates/original_editorial/images/family_table.png',
  'assets/templates/original_editorial/images/daily_friends.png',
  'assets/templates/original_editorial/images/daily_fruit.png',
];
const _summerPhotos = [
  'assets/templates/atelier_editions_2026/summer-keepsake-box.png',
  'assets/templates/atelier_editions_2026/summer-bench.png',
  'assets/templates/atelier_editions_2026/summer-evening.png',
  'assets/templates/original_editorial/images/family_friends.png',
  'assets/templates/original_editorial/images/travel_coast.png',
  'assets/templates/original_editorial/images/family_picnic.png',
  'assets/templates/original_editorial/images/family_table.png',
  'assets/templates/original_editorial/images/daily_fruit.png',
];

void _studioFamilyCover(_StudioPage p, StudioEdition e) {
  p.photo('cover_photo', e.coverAsset, 0, 0, 1, 1);
  if (!e.premium) _coverShade(p, top: true, strength: .32);
  _coverShade(p, top: false, strength: .20);
  final ink = e.premium ? '#163E40' : '#FFFDF5';
  p.type(
    e.premium ? 'OUR SUMMER / A SHARED ARCHIVE' : 'SATURDAY, TOGETHER',
    .075,
    .055,
    .85,
    .05,
    size: .019,
    color: ink,
    font: 'Poppins',
    weight: 600,
  );
  if (e.premium) {
    p.type('한여름', .075, .145, .80, .11, size: .075, color: ink, font: 'Eulyoo');
    p.type(
      '수집함',
      .075,
      .265,
      .80,
      .15,
      size: .115,
      color: ink,
      font: 'BookMyungjo',
      weight: 800,
    );
    p.box(p.uid, .08, .435, .13, .002 * p.ratio, ink);
  } else {
    p.type(
      '같이 보낸\n토요일',
      .075,
      .15,
      .85,
      .27,
      size: .093,
      color: ink,
      font: 'NotoSans',
      weight: 600,
    );
  }
  // Both captions remain editable independently of the full-bleed photograph.
  p.type(
    '함께한 사람들, 다시 펼쳐 볼 하루',
    .075,
    .90,
    .85,
    .055,
    size: .021,
    color: e.premium ? '#FFFFFF' : ink,
    font: 'Eulyoo',
  );
}

const _summerPapers = [
  ('#E7EFE8', false, '#E9AC67', false),
  ('#F3EEE4', false, '#D7E5D1', false),
  ('#B8D8D6', false, '#F2E5CE', false),
  ('#F0E8D9', false, '#D9E4DF', false),
  ('#BD623F', true, '#F4EEE1', false),
  ('#C7DDD7', false, '#EAE6CD', false),
  ('#EEE8DA', false, '#205356', true),
  ('#D9E2C9', false, '#F0E6D6', false),
  ('#E2EEE5', false, '#D3E0DF', false),
  ('#EEE4CE', false, '#C9DBCD', false),
  ('#273C3C', true, '#E8DCBC', false),
  ('#EBE4D3', false, '#D1E3DE', false),
  ('#E7B975', false, '#E8EDE0', false),
  ('#E5E9D7', false, '#B8D0D0', false),
  ('#1D4D52', true, '#F0E4CD', false),
  ('#DBE6DB', false, '#F2EEE2', false),
];

void _familyLabel(_StudioPage p, String text, double x, double y, double w) =>
    p.type(text, x, y, w, .044, size: .018, font: 'Poppins', weight: 600);

void _summerTitle(
  _StudioPage p,
  String first,
  String last,
  double x,
  double y,
  double w, {
  double size = .072,
}) {
  p.type(first, x, y, w, .08, size: size * .55, font: 'Eulyoo');
  p.type(
    last,
    x + .025,
    y + .09,
    w - .025,
    .14,
    size: size,
    font: 'BookMyungjo',
    weight: 800,
  );
  p.rule(x + .025, y + .245, math.min(.14, w));
}

void _summerSlip(
  _StudioPage p,
  String text,
  double x,
  double y,
  double w,
  double h,
) {
  final materialRatio = studioDecorationById('lifePicnicSlip')!.aspectRatio;
  final width = math.min(w, h * materialRatio / p.ratio);
  final height = width * p.ratio / materialRatio;
  p.mat('lifePicnicSlip', x, y, w, h);
  p.type(
    text,
    x + width * .12,
    y + height * .24,
    width * .76,
    height * .46,
    size: .021,
    font: 'Eulyoo',
  );
}

List<_StudioPage> _studioFamilySpread(
  StudioEdition e,
  CollectionAspect a,
  int i,
) {
  final premium = e.premium;
  const freeStocks = [
    ('#F5F4EC', '#E6EDDD'),
    ('#E9EEE2', '#F4E4D4'),
    ('#F6EFE3', '#DEE7E8'),
    ('#E9E5D9', '#F4EFE5'),
  ];
  final paper = premium
      ? _summerPapers[i]
      : (freeStocks[i % 4].$1, false, freeStocks[i % 4].$2, false);
  final l = _StudioPage(e, a, i * 2 + 1, paper.$1, dark: paper.$2);
  final r = _StudioPage(e, a, i * 2 + 2, paper.$3, dark: paper.$4);
  final story = _studioStories[e]![i];
  void caption(_StudioPage p, double x, double y, double w, double h) {
    p.type(story.$2, x, y, w, h, size: premium ? .028 : .026);
    p.layers.last['typographyRole'] = 'family-caption';
  }

  _familyLabel(
    l,
    premium ? 'SUMMER ARCHIVE / ${i + 1}' : 'OUR SATURDAY / ${i + 1}',
    .07,
    .05,
    .86,
  );
  if (!premium) {
    String p(int n) => _familyPhotos[n];
    switch (i) {
      case 0:
        l.scene(p(1), .04, .17, .92, .57, fill: true);
        l.heading('모이면 좋은\n우리의 하루', .08, .78, .84, .13, size: .049);
        r.type(
          '별다른 계획 없이\n그냥 같이 보내는 날.',
          .10,
          .18,
          .80,
          .24,
          size: .058,
          font: 'Eulyoo',
        );
        r.scene(p(6), .46, .56, .44, .28, frame: 'studioScallop');
        caption(r, .10, .57, .30, .24);
      case 1:
        l.heading(story.$1, .09, .16, .82, .12, size: .051);
        for (var n = 0; n < 3; n++) {
          l.scene(
            p([2, 6, 1][n]),
            .075 + n * .285,
            .39 + n * .07,
            .25,
            .22,
            frame: 'studioInstant',
            turn: n == 1 ? -2 : 1,
          );
        }
        caption(l, .09, .80, .82, .09);
        r.scene(p(0), .10, .12, .80, .65, frame: 'studioDoubleMat', fill: true);
      case 2:
        l.scene(p(2), .09, .17, .82, .51, frame: 'studioOval');
        _familyLabel(l, 'ONE DISH FROM EACH OF US', .10, .79, .80);
        r.heading('나눠 먹으면\n더 맛있는 것', .09, .13, .82, .23, size: .066);
        r.scene(p(6), .10, .47, .80, .30, frame: 'studioWave');
        caption(r, .10, .83, .80, .08);
      case 3:
        l.scene(p(0), .075, .20, .85, .59, frame: 'studioPhotoCorners');
        l.mat('studioWashiSage', .34, .16, .29, .07, turn: -2);
        r.scene(p(3), .08, .10, .61, .31, frame: 'studioPostage');
        r.scene(p(5), .35, .54, .56, .28, frame: 'studioRounded');
        r.type('한 명도 빠지지 않게.', .10, .44, .80, .07, size: .032, font: 'Eulyoo');
      case 4:
        l.heading(story.$1, .08, .15, .84, .12, size: .057);
        l.scene(p(5), .08, .38, .84, .37, fill: true);
        caption(l, .10, .81, .80, .10);
        r.mat('atelierGridLeaf', .08, .12, .83, .67);
        r.type(
          '오늘의 이야기\n\n만난 곳\n\n다음에 같이 할 일',
          .16,
          .24,
          .64,
          .43,
          size: .031,
          font: 'Eulyoo',
        );
      case 5:
        l.scene(p(3), .08, .18, .52, .58, fill: true);
        l.type('같은 쪽을\n바라보며', .67, .25, .25, .30, size: .043, font: 'Eulyoo');
        r.scene(p(1), .09, .12, .82, .48, frame: 'studioPostcard', turn: -1.5);
        r.mat('studioWashiRose', .65, .10, .23, .055);
        caption(r, .10, .74, .73, .15);
      case 6:
        l.heading('웃는 얼굴이\n닮아 가는 날', .08, .14, .84, .23, size: .064);
        l.scene(p(0), .06, .50, .88, .32);
        r.scene(p(5), .06, .08, .88, .43, frame: 'studioScallop');
        r.scene(p(1), .10, .63, .36, .20, frame: 'studioPhotoCorners');
        caption(r, .55, .65, .35, .20);
      case 7:
        l.scene(p(3), .04, .12, .92, .70, fill: true);
        r.heading('조금 멀리\n나와 보니', .10, .15, .80, .22, size: .063);
        r.rule(.10, .47, .16);
        caption(r, .10, .56, .80, .17);
        r.scene(p(6), .59, .77, .31, .12, frame: 'studioPhotoCorners');
      case 8:
        l.scene(p(4), .075, .18, .85, .55, frame: 'studioGallery');
        l.type('빈자리가 없어서 더 좋았다.', .10, .81, .80, .08, size: .030);
        r.scene(p(2), .10, .13, .37, .28, frame: 'studioInstant');
        r.scene(p(6), .54, .21, .36, .27, frame: 'studioPostage');
        r.heading(story.$1, .10, .61, .80, .13, size: .050);
        caption(r, .10, .79, .80, .10);
      case 9:
        l.scene(p(0), .13, .16, .74, .64, frame: 'studioArch', fill: true);
        r.mat('studioCottonRag', .065, .16, .87, .60);
        r.type(
          '돌아가기 전에\n한 장만 더.',
          .16,
          .29,
          .68,
          .23,
          size: .061,
          font: 'Eulyoo',
        );
        caption(r, .12, .78, .76, .11);
      case 10:
        l.scene(p(1), .07, .17, .64, .38, frame: 'studioRounded');
        l.scene(p(4), .41, .63, .51, .24, frame: 'studioPhotoCorners');
        r.heading(story.$1, .10, .15, .80, .12, size: .054);
        for (var n = 0; n < 3; n++) {
          _familyLabel(
            r,
            ['함께한 사람', '가장 오래 웃은 순간', '다음에 만날 곳'][n],
            .10,
            .40 + n * .15,
            .80,
          );
          r.rule(.10, .47 + n * .15, .80, color: '#A6B5A2');
        }
      case 11:
        l.scene(p(5), .045, .15, .91, .64, fill: true);
        _familyLabel(l, 'UNTIL OUR NEXT SATURDAY', .08, .85, .84);
        r.heading('다음에도\n우리답게', .10, .13, .80, .22, size: .073);
        caption(r, .10, .46, .80, .15);
        r.scene(p(0), .30, .69, .57, .19, frame: 'studioOval');
    }
  } else {
    String p(int n) => _summerPhotos[n];
    switch (i) {
      case 0:
        l.scene(p(0), .035, .145, .93, .65, fill: true);
        _familyLabel(l, '01 / THE FIRST AFTERNOON', .08, .84, .84);
        _summerTitle(r, '같이 꺼내 보는', '우리의 여름', .09, .13, .82);
        r.scene(p(1), .08, .48, .51, .31, frame: 'atelierWeave', turn: -1.5);
        r.scene(p(4), .62, .60, .29, .23, frame: 'studioPhotoCorners');
        caption(r, .10, .85, .80, .07);
      case 1:
        l.mat('studioVellum', .08, .14, .65, .61, turn: -1.5);
        l.scene(
          p(3),
          .14,
          .23,
          .73,
          .43,
          frame: 'atelierOxford',
          turn: 1.3,
          fill: true,
        );
        l.type(
          '이름보다 먼저\n떠오르는 얼굴들',
          .10,
          .76,
          .80,
          .13,
          size: .044,
          font: 'Eulyoo',
        );
        r.scene(p(5), .09, .11, .82, .47, frame: 'atelierDeco', fill: true);
        _summerTitle(r, '함께 온 사람들', '같은 웃음', .10, .64, .80, size: .057);
      case 2:
        l.mat('atelierGridLeaf', .055, .14, .89, .69);
        l.type(
          '한낮의 연락인화',
          .09,
          .20,
          .82,
          .10,
          size: .054,
          font: 'BookMyungjo',
          weight: 800,
        );
        for (var n = 0; n < 6; n++) {
          final x = .08 + n % 3 * .295, y = .36 + n ~/ 3 * .26;
          l.scene(
            p([0, 1, 3, 4, 7, 5][n]),
            x,
            y,
            .25,
            .20,
            frame: n == 0 || n == 5
                ? 'materialNotebookMount'
                : 'studioPhotoCorners',
            fill: true,
          );
          _familyLabel(l, '0${n + 1}', x, y + .21, .25);
        }
        r.scene(p(3), .09, .10, .46, .36, frame: 'atelierWeave');
        r.scene(p(1), .45, .51, .46, .31, frame: 'studioPhotoCorners', turn: 2);
        r.type(
          '잘 나온 한 장보다\n같이 고른 여러 장.',
          .10,
          .64,
          .28,
          .22,
          size: .035,
          font: 'Eulyoo',
        );
      case 3:
        l.box(l.uid, .05, .14, .90, .66, '#D6DFD7');
        for (var n = 0; n < 5; n++) {
          l.box(l.uid, .08 + n * .17, .14, .045, .66, '#98B3B5');
        }
        l.scene(
          p(1),
          .11,
          .22,
          .77,
          .43,
          frame: 'atelierOxford',
          turn: -1,
          fill: true,
        );
        _summerSlip(l, '가방에 챙긴 것', .42, .70, .46, .15);
        r.mat('atelierWritingRecord', .08, .13, .78, .68);
        r.type(
          '챙겨 온 것\n\n젖은 수건 / 물 한 잔\n나눠 먹은 귤 / 작은 돌',
          .17,
          .26,
          .40,
          .30,
          size: .031,
          font: 'Eulyoo',
        );
        r.scene(
          p(5),
          .48,
          .48,
          .43,
          .31,
          frame: 'materialScallopMount',
          turn: 2,
          fill: true,
        );
        r.mat('waveSeaGlass', .72, .77, .17, .12);
      case 4:
        l.type(
          '그늘 아래\n모두 모이면',
          .09,
          .18,
          .82,
          .28,
          size: .082,
          font: 'BookMyungjo',
          weight: 800,
        );
        caption(l, .10, .58, .65, .17);
        l.mat('materialCrossStitchBand', .10, .82, .76, .06);
        r.scene(
          p(0),
          .10,
          .12,
          .76,
          .43,
          frame: 'materialScallopMount',
          turn: -2,
          fill: true,
        );
        r.scene(
          p(5),
          .35,
          .52,
          .55,
          .31,
          frame: 'atelierWeave',
          turn: 2,
          fill: true,
        );
        _familyLabel(r, 'A PLACE IN THE SHADE', .10, .86, .80);
      case 5:
        l.scene(
          p(4),
          .09,
          .17,
          .66,
          .65,
          frame: 'atelierCoastline',
          fill: true,
        );
        l.type('발자국을\n따라서', .79, .32, .15, .27, size: .031, font: 'Eulyoo');
        _summerTitle(r, '물이 닿는 만큼', '조금 더 멀리', .09, .12, .82, size: .060);
        r.scene(p(0), .14, .47, .72, .35, frame: 'materialLinenOval');
        caption(r, .10, .85, .80, .06);
      case 6:
        for (var n = 0; n < 3; n++) {
          _familyLabel(
            l,
            ['01 / WIDE', '02 / DETAIL', '03 / TOGETHER'][n],
            .08,
            .18 + n * .235,
            .28,
          );
          l.scene(
            p([4, 1, 3][n]),
            .41,
            .15 + n * .235,
            .49,
            .19,
            frame: n == 0 ? 'atelierOxford' : 'studioPhotoCorners',
          );
        }
        r.scene(p(3), .055, .09, .89, .63, fill: true);
        r.type(
          '같이 본 풍경은\n서로 다르게 남는다.',
          .10,
          .78,
          .80,
          .13,
          size: .044,
          font: 'Eulyoo',
        );
      case 7:
        l.scene(p(1), .10, .17, .80, .44, frame: 'materialLinenOval');
        l.heading('서두르지 않는\n우리의 오후', .10, .71, .80, .18, size: .058);
        r.mat('studioLedger', .07, .12, .57, .66, turn: -1);
        r.scene(p(5), .14, .19, .70, .35, frame: 'studioPhotoCorners', turn: 1);
        r.scene(p(7), .57, .57, .34, .22, frame: 'studioPhotoCorners');
        r.type('오늘은\n여기까지만.', .16, .61, .32, .15, size: .033, font: 'Eulyoo');
      case 8:
        _summerTitle(l, '카메라 밖의', '좋아하는 얼굴', .09, .14, .82, size: .063);
        l.scene(p(3), .07, .50, .86, .34, frame: 'atelierWeave');
        r.scene(
          p(5),
          .08,
          .11,
          .47,
          .62,
          frame: 'materialNotebookMount',
          fill: true,
        );
        r.scene(p(0), .63, .18, .28, .24, frame: 'studioPhotoCorners');
        caption(r, .63, .53, .28, .28);
      case 9:
        l.scene(p(1), .075, .15, .85, .45, frame: 'atelierCoastline');
        l.box(l.uid, .12, .69, .76, .17, '#C5794A');
        l.type(
          '주머니에 남은 작은 여름',
          .17,
          .73,
          .66,
          .09,
          size: .033,
          color: '#FFF7EB',
          font: 'Eulyoo',
        );
        r.mat('studioVellum', .075, .12, .84, .64, turn: 1);
        r.type(
          '큰 기념품 대신\n이런 것을 가져왔다.',
          .16,
          .25,
          .68,
          .22,
          size: .058,
          font: 'BookMyungjo',
        );
        r.mat('waveSeaGlass', .12, .59, .23, .18);
        r.scene(
          p(1),
          .43,
          .53,
          .47,
          .28,
          frame: 'materialNotebookMount',
          turn: 2,
          fill: true,
        );
        _summerSlip(r, '담아 온 작은 물건', .12, .79, .39, .12);
      case 10:
        l.scene(p(2), .04, .15, .92, .62, fill: true);
        l.type(
          '해가 내려가도\n끝나지 않은 이야기',
          .09,
          .80,
          .82,
          .11,
          size: .042,
          font: 'Eulyoo',
        );
        _summerTitle(r, '창밖은 파랗게', '식탁은 따뜻하게', .09, .13, .82, size: .061);
        r.scene(p(6), .09, .51, .82, .32, frame: 'atelierWeave', turn: -1);
      case 11:
        l.heading('한 판만 더,\n다 같이 한 번 더', .08, .15, .84, .22, size: .060);
        l.scene(p(2), .08, .48, .53, .33, frame: 'materialScallopMount');
        l.type(
          '이긴 사람도\n진 사람도\n같이 웃었다.',
          .68,
          .52,
          .24,
          .26,
          size: .030,
          font: 'Eulyoo',
        );
        r.scene(p(6), .08, .10, .39, .25, frame: 'studioPhotoCorners');
        r.scene(p(2), .53, .24, .39, .29, frame: 'atelierOxford');
        r.mat('atelierGridLeaf', .10, .61, .79, .23);
        r.type(
          '다음에는 누가 먼저 시작할까.',
          .17,
          .68,
          .65,
          .11,
          size: .034,
          font: 'Eulyoo',
        );
      case 12:
        _summerTitle(l, '각자 하나씩', '내일도 기억할 것', .09, .12, .82, size: .063);
        for (var n = 0; n < 3; n++) {
          l.scene(
            p([1, 4, 7][n]),
            .08 + n * .29,
            .51 + n * .045,
            .25,
            .28,
            frame: 'studioPhotoCorners',
            fill: true,
            turn: n - 1.0,
          );
        }
        r.scene(p(0), .09, .13, .82, .43, frame: 'materialNotebookMount');
        r.type(
          '한 사람의 사진이\n모두의 기억이 되는 일.',
          .12,
          .67,
          .76,
          .18,
          size: .052,
          font: 'Eulyoo',
        );
      case 13:
        l.type(
          '함께 보낸\n시간표',
          .09,
          .16,
          .82,
          .23,
          size: .079,
          font: 'BookMyungjo',
          weight: 800,
        );
        for (var n = 0; n < 3; n++) {
          _familyLabel(
            l,
            ['11:30 / 물가에서', '15:00 / 그늘 아래', '20:30 / 식탁 앞'][n],
            .10,
            .48 + n * .13,
            .80,
          );
          l.rule(.10, .55 + n * .13, .80, color: '#A2B5A6');
        }
        r.scene(p(4), .08, .10, .84, .26, frame: 'atelierAccordion');
        r.scene(p(1), .10, .54, .39, .29, frame: 'atelierCoastline');
        r.scene(
          p(2),
          .57,
          .47,
          .35,
          .26,
          frame: 'studioPhotoCorners',
          turn: 1.5,
        );
        _familyLabel(r, 'NO PLANS, ONLY GOOD COMPANY', .10, .86, .80);
      case 14:
        l.scene(p(3), .08, .17, .47, .32, frame: 'materialLinenOval');
        l.scene(
          p(0),
          .34,
          .56,
          .58,
          .29,
          frame: 'studioPhotoCorners',
          turn: -1,
        );
        _familyLabel(l, 'ONE MORE PHOTO BEFORE WE GO', .09, .86, .82);
        r.mat('materialLinen', .075, .13, .82, .63, turn: 1);
        r.scene(
          p(4),
          .14,
          .19,
          .73,
          .42,
          frame: 'atelierCoastline',
          fill: true,
        );
        _summerSlip(r, '다음 소풍 장소', .10, .67, .46, .16);
        r.type('다음에도\n같이 걷자.', .60, .68, .30, .17, size: .042, font: 'Eulyoo');
      case 15:
        l.scene(p(0), .055, .13, .89, .65, frame: 'atelierOxford');
        l.mat('materialVellumBand', .09, .75, .59, .12);
        _summerTitle(r, '다시 펼쳐 볼', '한여름 수집함', .10, .16, .80, size: .065);
        caption(r, .10, .52, .80, .17);
        r.rule(.10, .76, .80, color: '#AAB5A5');
        r.type(
          '함께한 사람들 / 사진과 글\n우리의 여름, 2026',
          .10,
          .82,
          .80,
          .08,
          size: .022,
          font: 'Eulyoo',
        );
    }
  }
  return [l, r];
}

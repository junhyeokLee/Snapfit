part of 'authored_collections.dart';

const _pawWalkStories = [
  ('현관 앞에서 준비', '목줄 소리만 나면 누구보다 먼저 문 앞으로 달려온다.'),
  ('오늘의 산책 대장', '어디로 갈지는 네가 고르고, 나는 천천히 따라간다.'),
  ('새로운 냄새의 길', '같은 골목에서도 매일 다른 것을 발견하는 너.'),
  ('잠깐 멈춰 서기', '서두르지 않고 네가 궁금한 것을 같이 기다려 본다.'),
  ('햇볕 좋은 모퉁이', '따뜻한 자리를 찾아 잠시 쉬었다 가기로 했다.'),
  ('발맞춰 걷는 동안', '몇 걸음마다 돌아보는 얼굴이 오늘도 반갑다.'),
  ('좋아하는 길로 한 번 더', '집으로 가는 길인 줄 알면서도 한 바퀴를 더 돌았다.'),
  ('물 한 모금의 휴식', '신나게 걷다가 그늘에서 숨을 고르는 시간.'),
  ('꼭 남겨 둘 표정', '자꾸 사진첩을 다시 열게 만드는 작은 얼굴들.'),
  ('집에 돌아와서', '발을 닦고 자리를 잡으면 금세 조용해지는 오후.'),
  ('산책 뒤의 기록', '오래 머문 곳과 좋아했던 것을 짧게 적어 둔다.'),
  ('내일도 같이 가자', '매일 비슷해 보여도 너와 걷는 길은 조금씩 다르다.'),
];
const _companionStories = [
  ('이번 호의 주인공', '하루의 가장 작은 사건도 너를 만나면 사진이 된다.'),
  ('같이 사는 친구 소개', '이름과 별명, 처음 만난 날부터 천천히 적어 본다.'),
  ('호기심의 세 장면', '고개를 들고, 한 걸음 다가오고, 결국 옆에 앉는 순서.'),
  ('네가 고른 자리', '햇볕이 머무는 곳을 너는 누구보다 먼저 알아본다.'),
  ('작은 발의 큰 일', '장난감을 밀고, 문을 열고, 내 손을 가만히 붙잡는다.'),
  ('낮잠에 드는 시간', '소리를 조금 낮추고 오래 바라보게 되는 장면.'),
  ('표정을 읽는 연습', '말 대신 보이는 눈빛과 몸짓을 하나씩 기억한다.'),
  ('가장 아끼는 장난감', '새것보다 오래 곁에 둔 물건에 마음이 더 간다.'),
  ('오늘의 관찰 일지', '좋아한 것과 싫어한 것, 오늘 처음 알게 된 것.'),
  ('가까이서 마주 보면', '수염 끝과 귀의 움직임까지 남기고 싶어졌다.'),
  ('생활의 작은 물건들', '네가 쓰는 그릇과 자리가 집의 풍경을 바꿨다.'),
  ('아무 일 없는 오후', '별일이 없는 날에도 함께한 장면은 충분하다.'),
  ('좋아하는 세 가지', '놀기와 쉬기, 그리고 가만히 곁에 있기.'),
  ('하루를 따라가다', '시간표대로 움직이지 않아 더 자주 웃게 되는 생활.'),
  ('오늘을 남기는 이유', '나중에 이 평범한 하루부터 다시 보고 싶을 것 같아서.'),
  ('다음 호에도 주인공은 너', '같이 사는 날들이 쌓이면 또 한 권의 이야기가 된다.'),
];

const _walkPhotos = [
  'assets/templates/atelier_editions_2026/daily-paw-walk.png',
  'assets/templates/original_editorial/images/pet_walk.png',
  'assets/templates/original_editorial/images/pet_dog.png',
  'assets/templates/original_editorial/images/pet_keepsakes.png',
  'assets/templates/original_editorial/images/pet_rest.png',
  'assets/templates/atelier_editions_2026/daily-paw-path.png',
];
const _companionPhotos = [
  'assets/templates/atelier_editions_2026/companion-journal.png',
  'assets/templates/atelier_editions_2026/companion-window.png',
  'assets/templates/atelier_editions_2026/companion-play.png',
  'assets/templates/original_editorial/images/pet_cat.png',
  'assets/templates/original_editorial/images/pet_nap.png',
  'assets/templates/original_editorial/images/pet_keepsakes.png',
];

void _studioPetCover(_StudioPage p, StudioEdition e) {
  p.photo('cover_photo', e.coverAsset, 0, 0, 1, 1);
  _coverShade(p, top: false, strength: .25);
  p.type(
    e.premium ? 'COMPANION JOURNAL / ISSUE 01' : 'OUR DAILY WALK',
    .07,
    .045,
    .86,
    .045,
    size: .018,
    color: e.premium ? '#29282D' : '#FFFFFF',
    font: 'Poppins',
    weight: 600,
  );
  if (e.premium) {
    p.type(
      p.wide ? '우리 집\n주인공' : '우리 집 주인공',
      .065,
      p.wide ? .14 : .105,
      p.wide ? .34 : .87,
      p.wide ? .33 : .14,
      size: .093,
      font: 'RiaSans',
      color: '#29282D',
      weight: 800,
    );
    p.type(
      p.wide ? '모모와 함께\n사는 날들' : '모모와 함께 사는 날들',
      .075,
      p.wide ? .53 : .27,
      p.wide ? .29 : .46,
      p.wide ? .14 : .06,
      size: .026,
      font: 'Eulyoo',
      color: '#41383F',
    );
  } else {
    p.type(
      p.wide ? '오늘도\n산책!' : '오늘도 산책!',
      .07,
      .12,
      p.wide ? .32 : .86,
      p.wide ? .32 : .16,
      size: .087,
      font: 'NotoSans',
      color: '#F5F7AF',
      weight: 800,
    );
  }
  p.type(
    e.premium ? '초상 · 몸짓 · 같이 사는 생활' : '늘 걷던 길에서 만나는 새로운 하루',
    .075,
    .91,
    .85,
    .045,
    size: .021,
    color: '#FFFFFF',
  );
}

void _petLabel(_StudioPage p, String text, double x, double y, double w) =>
    p.type(text, x, y, w, .043, size: .018, font: 'Poppins', weight: 600);

void _petTitle(
  _StudioPage p,
  String text,
  double x,
  double y,
  double w,
  double h, {
  double size = .072,
  String? color,
}) => p.type(
  text,
  x,
  y,
  w,
  h,
  size: size,
  font: p.edition.premium ? 'RiaSans' : 'NotoSans',
  weight: 800,
  color: color,
);

void _petNote(
  _StudioPage p,
  String key,
  String text,
  double x,
  double y,
  double w,
  double h,
) {
  final r = studioDecorationById(key)!.aspectRatio;
  final width = math.min(w, h * r / p.ratio), height = width * p.ratio / r;
  p.mat(key, x, y, w, h);
  p.type(
    text,
    x + width * .13,
    y + height * .23,
    width * .73,
    height * .50,
    size: .025,
    color: '#343438',
    font: 'Eulyoo',
  );
}

const _companionPapers = [
  ('#F1F2EB', false, '#D7DF70', false),
  ('#E2DDE8', false, '#28262B', true),
  ('#F4F0EC', false, '#E2E8DA', false),
  ('#D6DD72', false, '#EEEEEA', false),
  ('#343037', true, '#E6D5D9', false),
  ('#F0E4E2', false, '#242529', true),
  ('#E0E5DF', false, '#E9E8E1', false),
  ('#EEEDE6', false, '#D8D3E0', false),
  ('#D4DC6A', false, '#F1EDE8', false),
  ('#E9DADC', false, '#2C2A2F', true),
  ('#E6E8DE', false, '#E2DCE6', false),
  ('#2A2B2C', true, '#F0E9E4', false),
  ('#E5D8DF', false, '#E6EACD', false),
  ('#F2EFE8', false, '#D9DEE0', false),
  ('#AE3C4B', true, '#E8E8DF', false),
  ('#E2E5D8', false, '#F4F0ED', false),
];

List<_StudioPage> _studioPetSpread(StudioEdition e, CollectionAspect a, int i) {
  final premium = e.premium;
  const walkStocks = [
    ('#F1F4E5', '#DFE7F0'),
    ('#E9ED9C', '#F4F4ED'),
    ('#DFE7F0', '#E8EEE3'),
    ('#F5F4EB', '#EEE2D9'),
  ];
  final stocks = premium
      ? _companionPapers[i]
      : (walkStocks[i % 4].$1, false, walkStocks[i % 4].$2, false);
  final l = _StudioPage(e, a, i * 2 + 1, stocks.$1, dark: stocks.$2);
  final r = _StudioPage(e, a, i * 2 + 2, stocks.$3, dark: stocks.$4);
  final story = _studioStories[e]![i];
  _petLabel(
    l,
    premium ? 'COMPANION / ${i + 1}' : 'WALK NOTE / ${i + 1}',
    .07,
    .045,
    .86,
  );
  void caption(_StudioPage p, double x, double y, double w, double h) {
    p.type(story.$2, x, y, w, h, size: .028);
    p.layers.last['typographyRole'] = 'pet-caption';
  }

  if (!premium) {
    String p(int n) => _walkPhotos[n];
    switch (i) {
      case 0:
        _petTitle(l, '문을 열면\n오늘의 모험', .08, .16, .84, .24, size: .074);
        l.scene(p(3), .10, .50, .49, .27, frame: 'studioTicket');
        l.type('목줄 챙기고\n물 한 병도.', .65, .54, .26, .20, size: .031);
        r.scene(p(0), .075, .08, .85, .76, frame: 'studioRounded', fill: true);
        _petLabel(r, 'READY FOR ANOTHER WALK', .10, .87, .80);
      case 1:
        l.scene(p(2), .19, .17, .62, .49, frame: 'studioOval', fill: true);
        _petTitle(l, '산책 대장, 초코', .10, .75, .80, .12, size: .053);
        r.mat('materialWalkLedger', .07, .11, .86, .68);
        r.type('오늘의 코스\n\n가장 오래 멈춘 곳\n\n만난 친구', .15, .22, .68, .46, size: .032);
      case 2:
        l.scene(p(5), .06, .15, .59, .69, fill: true);
        l.type('어제와는\n다른 냄새', .71, .24, .23, .34, size: .036);
        r.scene(p(1), .08, .10, .77, .43, frame: 'studioPhotoCorners');
        r.scene(p(0), .55, .61, .34, .26, frame: 'studioCapsule');
        caption(r, .09, .65, .39, .22);
      case 3:
        l.scene(p(0), .08, .20, .39, .47, fill: true);
        l.scene(p(1), .53, .33, .39, .47, fill: true);
        r.type(
          '기다리는 것도\n산책의 한 부분.',
          .10,
          .18,
          .80,
          .28,
          size: .060,
          font: 'Eulyoo',
        );
        caption(r, .10, .60, .80, .17);
        r.rule(.10, .83, .28);
      case 4:
        l.scene(p(2), .09, .16, .82, .52, frame: 'studioCapsule', fill: true);
        _petLabel(l, 'STOP / LOOK / GO', .10, .78, .80);
        _petTitle(r, '햇볕 좋은\n모퉁이에서', .08, .14, .84, .24, size: .065);
        r.scene(p(5), .09, .50, .82, .31, frame: 'studioWave');
      case 5:
        for (var n = 0; n < 3; n++) {
          l.type(
            '0${n + 1}',
            .08,
            .24 + n * .20,
            .15,
            .09,
            size: .043,
            font: 'Poppins',
            weight: 600,
          );
          l.scene(
            p([1, 3, 0][n]),
            .32,
            .18 + n * .21,
            .59,
            .17,
            frame: 'studioPhotoCorners',
          );
        }
        r.scene(p(1), .07, .12, .86, .52, frame: 'studioPostcard');
        caption(r, .11, .74, .78, .15);
      case 6:
        l.box(l.uid, .05, .13, .90, .71, '#D9E98A');
        _petTitle(l, '한 바퀴만\n더 걷자!', .11, .23, .78, .30, size: .089);
        caption(l, .11, .66, .71, .12);
        r.scene(p(5), .04, .11, .92, .72, fill: true);
      case 7:
        l.scene(p(3), .10, .17, .80, .46, frame: 'studioDoubleMat');
        _petTitle(l, '그늘 아래\n잠깐의 휴식', .10, .72, .80, .17, size: .053);
        r.scene(p(0), .08, .10, .53, .35, frame: 'studioRounded');
        r.scene(p(2), .38, .56, .53, .31, frame: 'studioPostage');
        r.type('천천히,\n다시 출발.', .67, .23, .25, .18, size: .034, font: 'Eulyoo');
      case 8:
        _petTitle(l, '꼭 남겨 둘\n너의 표정', .08, .13, .84, .23, size: .068);
        l.scene(p(2), .09, .45, .82, .34, frame: 'studioPhotoCorners');
        r.scene(p(0), .10, .12, .59, .57, frame: 'studioArch', fill: true);
        caption(r, .10, .78, .80, .11);
      case 9:
        l.scene(p(4), .08, .17, .84, .57, frame: 'studioCapsule');
        _petLabel(l, 'HOME, PAWS CLEAN, GOOD REST', .10, .82, .80);
        r.heading('돌아와 쉬는\n모습까지', .10, .17, .80, .22, size: .065);
        r.scene(p(3), .11, .52, .78, .28, frame: 'studioRounded');
      case 10:
        l.mat('materialWalkLedger', .075, .14, .85, .68);
        l.type(
          '산책 기록\n\n함께 걸은 길\n좋아한 장소\n다음에 가 볼 곳',
          .16,
          .25,
          .67,
          .43,
          size: .031,
        );
        r.scene(p(1), .08, .09, .84, .38, frame: 'studioGallery');
        r.scene(p(4), .11, .62, .47, .23, frame: 'studioPhotoCorners');
        r.type('오늘도\n수고했어.', .65, .65, .26, .17, size: .034, font: 'Eulyoo');
      case 11:
        _petTitle(l, '내일도\n같이 가자.', .08, .15, .84, .25, size: .080);
        l.scene(p(5), .08, .56, .84, .27);
        r.scene(
          p(0),
          .09,
          .12,
          .82,
          .69,
          frame: 'studioPhotoCorners',
          fill: true,
        );
        _petLabel(r, 'OUR DAILY WALK / 2026', .10, .87, .80);
    }
  } else {
    String p(int n) => _companionPhotos[n];
    switch (i) {
      case 0:
        _petTitle(l, 'ISSUE\n001', .075, .14, .85, .31, size: .128);
        l.type(
          '이번 호의 주인공은\n우리 집에 살고 있습니다.',
          .10,
          .52,
          .80,
          .17,
          size: .047,
          font: 'Eulyoo',
        );
        _petLabel(l, 'PORTRAIT / ROUTINE / OBSERVATIONS', .10, .80, .80);
        r.scene(p(0), .07, .07, .86, .77, frame: 'atelierKeyhole', fill: true);
        _petLabel(r, 'COVER STORY / MOMO', .10, .87, .80);
      case 1:
        l.scene(
          p(1),
          .08,
          .16,
          .53,
          .65,
          frame: 'signatureTrailPocket',
          fill: true,
        );
        l.type('함께 사는\n친구의 초상', .68, .26, .23, .27, size: .035, font: 'Eulyoo');
        _petTitle(r, 'HELLO,\nMOMO.', .10, .12, .80, .23, size: .092);
        r.type(
          '이름 / 모모\n별명 / 창가의 주인\n처음 만난 날 / 2026. 04. 12.',
          .10,
          .46,
          .80,
          .22,
          size: .031,
        );
        _petNote(r, 'materialNamePatch', 'MOMO', .10, .76, .43, .13);
      case 2:
        l.scene(
          p(1),
          .07,
          .15,
          .62,
          .40,
          frame: 'atelierCornerFold',
          fill: true,
        );
        l.scene(
          p(2),
          .35,
          .58,
          .56,
          .29,
          frame: 'studioPhotoCorners',
          turn: -1.5,
        );
        _petTitle(r, '다가오는\n세 번의 순간', .08, .14, .84, .24, size: .070);
        for (var n = 0; n < 3; n++) {
          r.scene(
            p([1, 0, 3][n]),
            .08 + n * .29,
            .51,
            .25,
            .28,
            frame: 'studioRounded',
            fill: true,
          );
          _petLabel(r, ['LOOK', 'STEP', 'STAY'][n], .08 + n * .29, .82, .25);
        }
      case 3:
        _petTitle(l, '네가\n고른 자리', .09, .15, .82, .29, size: .092);
        caption(l, .10, .58, .70, .17);
        _petNote(l, 'editionWalkBand', '네가 고른 곳이 좋아', .10, .79, .70, .13);
        r.scene(p(1), .055, .08, .89, .67, fill: true);
        _petNote(r, 'lifeCompanionTab', '창가의 자리\n오후 세 시', .10, .73, .66, .17);
      case 4:
        l.scene(
          p(2),
          .08,
          .18,
          .84,
          .49,
          frame: 'materialTwinWindow',
          fill: true,
        );
        l.type(
          '작은 발이 하는\n생각보다 많은 일.',
          .10,
          .77,
          .80,
          .13,
          size: .045,
          font: 'Eulyoo',
        );
        r.scene(
          p(0),
          .08,
          .11,
          .44,
          .42,
          frame: 'atelierCrossRibbon',
          fill: true,
        );
        r.type('밀어 보고\n톡 건드리고\n가만히 붙잡기', .61, .17, .30, .26, size: .036);
        r.mat('lifeRopeBall', .63, .61, .25, .21);
        caption(r, .10, .78, .80, .12);
      case 5:
        _petTitle(l, 'DO NOT\nDISTURB.', .08, .14, .84, .25, size: .091);
        l.scene(p(4), .10, .49, .80, .35, frame: 'signatureOrbitQuilt');
        r.scene(p(4), .07, .10, .86, .59, fill: true);
        r.type(
          '소리를 낮추고\n지켜보는 시간',
          .10,
          .76,
          .80,
          .14,
          size: .047,
          font: 'Eulyoo',
        );
      case 6:
        l.scene(
          p(3),
          .08,
          .15,
          .41,
          .44,
          frame: 'signatureHerbariumSleeve',
          fill: true,
        );
        l.scene(
          p(1),
          .57,
          .39,
          .35,
          .43,
          frame: 'atelierCrossRibbon',
          fill: true,
        );
        l.type('눈빛 / 귀 / 꼬리', .10, .77, .40, .08, size: .027, font: 'Eulyoo');
        r.scene(p(0), .04, .065, .92, .81, fill: true);
        _petLabel(r, 'A FACE WE LEARN EVERY DAY', .10, .89, .80);
      case 7:
        l.scene(
          p(2),
          .08,
          .16,
          .83,
          .46,
          frame: 'atelierCornerFold',
          fill: true,
        );
        l.type(
          '새것보다\n오래 곁에 둔 것',
          .10,
          .73,
          .65,
          .15,
          size: .046,
          font: 'Eulyoo',
        );
        l.mat('lifeFeltMouse', .76, .74, .14, .14);
        _petNote(r, 'lifeCompanionTab', '가장 좋아하는 장난감', .08, .17, .82, .25);
        r.scene(p(5), .13, .46, .74, .36, frame: 'signatureTrailPocket');
      case 8:
        _petTitle(l, '관찰 일지', .08, .16, .84, .15, size: .086);
        for (var n = 0; n < 3; n++) {
          _petLabel(
            l,
            ['오늘 좋아한 것', '조금 낯설었던 것', '처음 알게 된 습관'][n],
            .10,
            .40 + n * .16,
            .80,
          );
          l.rule(.10, .47 + n * .16, .80, color: '#8F9851');
        }
        r.scene(
          p(1),
          .10,
          .12,
          .73,
          .48,
          frame: 'signatureHerbariumSleeve',
          fill: true,
        );
        r.scene(p(2), .48, .66, .42, .22, frame: 'studioPhotoCorners');
        r.type(
          '관찰자 / 나\n오늘의 주인공 / 너',
          .10,
          .72,
          .31,
          .15,
          size: .027,
          font: 'Eulyoo',
        );
      case 9:
        l.scene(p(0), .13, .18, .74, .63, frame: 'atelierKeyhole', fill: true);
        _petLabel(l, 'PORTRAIT, UP CLOSE', .10, .87, .80);
        _petTitle(r, '마주 보는\n매일의 얼굴', .09, .14, .82, .25, size: .080);
        r.scene(p(3), .08, .55, .43, .29, frame: 'atelierCrossRibbon');
        r.scene(p(1), .60, .55, .30, .29, frame: 'studioRounded', fill: true);
      case 10:
        _petTitle(l, '이 집의\n작은 물건들', .09, .15, .82, .23, size: .072);
        l.scene(p(5), .09, .48, .82, .34, frame: 'signatureTrailPocket');
        r.mat('lifeBowl', .08, .15, .32, .25);
        r.scene(
          p(2),
          .48,
          .15,
          .43,
          .30,
          frame: 'studioPhotoCorners',
          fill: true,
        );
        _petNote(r, 'materialNamePatch', '모모의 자리', .12, .54, .58, .14);
        caption(r, .12, .75, .76, .14);
      case 11:
        l.scene(p(4), .045, .12, .91, .66, fill: true);
        l.type(
          '아무 일 없는 날도\n남겨 두고 싶은 이유',
          .10,
          .82,
          .80,
          .10,
          size: .039,
          font: 'Eulyoo',
        );
        r.scene(p(1), .08, .09, .53, .35, frame: 'atelierCornerFold');
        r.scene(
          p(0),
          .48,
          .51,
          .43,
          .35,
          frame: 'signatureOrbitQuilt',
          fill: true,
        );
        r.type('같은 집,\n다른 오후.', .10, .64, .28, .18, size: .035, font: 'Eulyoo');
      case 12:
        _petTitle(l, '좋아하는\n세 가지', .09, .13, .82, .24, size: .080);
        l.scene(
          p(2),
          .10,
          .48,
          .42,
          .35,
          frame: 'materialTwinWindow',
          fill: true,
        );
        l.scene(p(4), .60, .60, .31, .24, frame: 'studioRounded', fill: true);
        r.scene(
          p(1),
          .09,
          .13,
          .82,
          .52,
          frame: 'signatureHerbariumSleeve',
          fill: true,
        );
        r.type(
          '놀기 / 쉬기 / 곁에 있기',
          .10,
          .76,
          .80,
          .10,
          size: .038,
          font: 'Eulyoo',
        );
      case 13:
        _petTitle(l, '24 HOURS\nWITH YOU', .08, .14, .84, .22, size: .085);
        l.type(
          '08:00  먼저 일어난 친구\n12:30  창가의 낮잠\n17:00  장난감 꺼내기\n22:00  다시 나란히',
          .10,
          .45,
          .80,
          .33,
          size: .032,
        );
        r.scene(p(3), .08, .11, .51, .60, frame: 'atelierKeyhole', fill: true);
        r.scene(
          p(4),
          .64,
          .38,
          .28,
          .26,
          frame: 'studioPhotoCorners',
          fill: true,
        );
        r.type(
          '일정표보다\n네 마음대로.',
          .10,
          .78,
          .80,
          .11,
          size: .038,
          font: 'Eulyoo',
        );
      case 14:
        _petTitle(l, '꼭 남겨 두고 싶은\n오늘의 너', .08, .17, .84, .27, size: .072);
        caption(l, .10, .59, .76, .17);
        l.rule(.10, .84, .20);
        r.scene(
          p(1),
          .10,
          .13,
          .71,
          .36,
          frame: 'atelierCornerFold',
          fill: true,
        );
        r.scene(p(2), .08, .62, .37, .24, frame: 'studioPhotoCorners');
        r.scene(
          p(4),
          .55,
          .57,
          .35,
          .28,
          frame: 'signatureOrbitQuilt',
          fill: true,
        );
      case 15:
        l.scene(
          p(0),
          .08,
          .14,
          .61,
          .69,
          frame: 'atelierCrossRibbon',
          fill: true,
        );
        l.type('집 안의\n작은 편집장', .75, .24, .17, .31, size: .030, font: 'Eulyoo');
        _petTitle(r, '다음 호에도\n주인공은 너.', .09, .14, .82, .25, size: .075);
        r.rule(.10, .49, .80);
        caption(r, .10, .57, .80, .17);
        r.type(
          'COMPANION JOURNAL\n사진과 기록 / 함께 사는 우리',
          .10,
          .83,
          .80,
          .07,
          size: .021,
          font: 'Poppins',
        );
    }
  }
  return [l, r];
}

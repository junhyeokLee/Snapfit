part of 'authored_collections.dart';

const _littleDayPhotos = [
  'assets/templates/atelier_editions_2026/little-day-discoveries.png',
  'assets/templates/original_editorial/images/growth_hand.png',
  'assets/templates/original_editorial/images/growth_sleep.png',
  'assets/templates/original_editorial/images/growth_play.png',
  'assets/templates/original_editorial/images/growth_walk.png',
  'assets/templates/original_editorial/images/growth_keepsakes.png',
  'assets/templates/original_editorial/images/growth_birthday.png',
];
const _explorerPhotos = [
  'assets/templates/atelier_editions_2026/little-explorer-book.png',
  'assets/templates/atelier_editions_2026/little-explorer-drawing.png',
  'assets/templates/atelier_editions_2026/little-explorer-finds.png',
  'assets/templates/atelier_editions_2026/little-explorer-walk.png',
  'assets/templates/atelier_editions_2026/little-explorer-finds.png',
  'assets/templates/atelier_editions_2026/little-explorer-walk.png',
  'assets/templates/atelier_editions_2026/little-explorer-play.png',
  'assets/templates/atelier_editions_2026/little-explorer-rest.png',
];
const _discoveryPapers = [
  ('#E9EDD9', false, '#2F4E9C', true),
  ('#F3E8D7', false, '#DBE5E8', false),
  ('#D9E6DA', false, '#F0C3B1', false),
  ('#EADDA8', false, '#E3E8E6', false),
  ('#334D64', true, '#F2E8D7', false),
  ('#E8DAD7', false, '#D6E2DE', false),
  ('#E2E5D3', false, '#CACFE2', false),
  ('#F0E9D9', false, '#C3D9DE', false),
  ('#C26752', true, '#EBE3D1', false),
  ('#DFE9E6', false, '#F0D6CB', false),
  ('#DADFF0', false, '#E6E7C4', false),
  ('#3D5D58', true, '#E8E0D5', false),
  ('#E7D0C9', false, '#DBE5D4', false),
  ('#D9E4E6', false, '#F2E6D5', false),
  ('#ECDCAE', false, '#DAD8E1', false),
  ('#E6EADD', false, '#315174', true),
];

List<_StudioPage> _studioDiscoverySpread(
  StudioEdition e,
  CollectionAspect a,
  int i,
) {
  const basics = [
    ('#EAF0E4', '#E6EDF3'),
    ('#F6EBCB', '#F0E9E7'),
    ('#E7ECEE', '#E5EDDF'),
    ('#F1E3D6', '#F3F3E9'),
  ];
  final s = e.premium
      ? _discoveryPapers[i]
      : (basics[i % 4].$1, false, basics[i % 4].$2, false);
  final l = _StudioPage(e, a, i * 2 + 1, s.$1, dark: s.$2),
      r = _StudioPage(e, a, i * 2 + 2, s.$3, dark: s.$4);
  final story = _studioStories[e]![i];
  String p(int n) => (e.premium ? _explorerPhotos : _littleDayPhotos)[n];
  void title(
    _StudioPage sheet,
    String text,
    double x,
    double y,
    double w,
    double h, {
    double size = .067,
  }) => _milestoneTitle(sheet, text, x, y, w, h, size: size);
  void caption(_StudioPage sheet, double x, double y, double w, double h) =>
      _milestoneCaption(sheet, story.$2, x, y, w, h);
  _milestoneLabel(
    l,
    e.premium ? 'DISCOVERY INDEX / ${i + 1}' : 'LITTLE DAYS / ${i + 1}',
    .07,
    .04,
    .86,
  );
  if (!e.premium) {
    switch (i) {
      case 0:
        title(l, '매일 새로운\n너를 만나', .10, .15, .80, .23);
        l.scene(p(1), .12, .51, .46, .29, frame: 'studioOvalMat');
        l.type('처음의 표정,\n처음의 마음.', .65, .58, .25, .19, size: .029);
        r.scene(p(0), .13, .10, .74, .73, frame: 'studioRounded', fill: true);
        _milestoneLabel(r, 'HELLO, LITTLE ONE', .13, .87, .74);
      case 1:
        l.scene(p(0), .08, .15, .73, .56, frame: 'studyFloatMount', fill: true);
        _milestoneNote(
          l,
          'materialScallopNote',
          '이름을 불렀더니\n고개를 돌렸어.',
          .51,
          .69,
          .40,
          .20,
        );
        title(r, '너의 이름을\n부르는 일', .12, .20, .76, .23, size: .065);
        caption(r, .13, .63, .74, .18);
      case 2:
        l.scene(p(1), .07, .19, .86, .55, frame: 'studioPhotoCorners');
        l.type('손끝으로 만나는 세상', .12, .82, .76, .07, size: .034);
        r.scene(p(3), .12, .15, .46, .36, frame: 'studioScallop', fill: true);
        r.type('천천히 만져 보고\n한 번 더 바라보고.', .23, .66, .66, .18, size: .040);
      case 3:
        title(l, '잘 자고\n잘 웃는 하루', .10, .15, .80, .22, size: .065);
        l.scene(p(2), .11, .52, .78, .33, frame: 'studioRounded');
        r.scene(p(2), .19, .15, .62, .56, frame: 'studioOval', fill: true);
        caption(r, .14, .80, .72, .11);
      case 4:
        for (var n = 0; n < 2; n++)
          l.scene(
            p(n == 0 ? 3 : 0),
            .11,
            .14 + n * .34,
            .66,
            .27,
            frame: 'studioPhotoCorners',
          );
        l.type('또 해 줘!', .50, .82, .39, .07, size: .039);
        title(r, '다시 해도\n처음처럼', .12, .16, .76, .23, size: .076);
        r.scene(p(3), .35, .54, .53, .31, frame: 'studioCapsule', fill: true);
      case 5:
        l.scene(p(0), .10, .12, .80, .61, frame: 'studioDoubleMat', fill: true);
        caption(l, .13, .81, .74, .10);
        title(r, '한 입의\n새로운 표정', .10, .15, .80, .24, size: .069);
        _milestoneNote(
          r,
          'atelierWritingRecord',
          '처음 먹어 본 것\n\n좋아했던 맛\n\n다음에 또 먹어 볼 것',
          .17,
          .46,
          .66,
          .42,
        );
      case 6:
        title(l, '밖으로\n나가는 날', .11, .14, .78, .23, size: .075);
        l.scene(p(5), .21, .54, .55, .26, frame: 'studioPhotoCorners');
        r.scene(p(4), .10, .12, .80, .67, fill: true);
        r.type('오늘도 같이 한 바퀴.', .13, .85, .74, .06, size: .028);
      case 7:
        l.scene(p(4), .14, .18, .72, .54, frame: 'studioOvalMat', fill: true);
        caption(l, .13, .80, .74, .11);
        title(r, '안아 줄 때\n닮아 가는 표정', .11, .15, .78, .23, size: .062);
        r.scene(p(1), .12, .53, .57, .31, frame: 'studyNotchedMat');
      case 8:
        l.type(
          '01\n새로운 시도',
          .12,
          .18,
          .76,
          .25,
          size: .060,
          font: 'NotoSans',
          weight: 600,
        );
        caption(l, .13, .62, .74, .17);
        r.scene(p(3), .08, .12, .84, .48, frame: 'studioPostcard');
        r.scene(p(0), .56, .67, .32, .22, frame: 'studioRounded');
      case 9:
        l.scene(p(5), .12, .17, .76, .44, frame: 'studioDoubleMat');
        title(l, '너를 닮아 가는\n집 안의 풍경', .12, .73, .76, .17, size: .048);
        r.scene(p(0), .14, .17, .48, .47, frame: 'studioArch', fill: true);
        r.type('작은 옷과\n자주 쓰는 물건들', .51, .72, .38, .16, size: .029);
      case 10:
        _milestoneNote(
          l,
          'atelierWritingRecord',
          '오늘의 새로운 모습\n\n처음 해낸 일\n\n좋아했던 순간',
          .09,
          .14,
          .82,
          .69,
        );
        r.scene(p(6), .10, .12, .80, .45, frame: 'studioPostage');
        caption(r, .12, .70, .76, .16);
      case 11:
        l.scene(p(0), .08, .13, .58, .68, frame: 'studioRounded', fill: true);
        l.type('매일\n조금씩\n달라지는 너', .72, .29, .20, .34, size: .032);
        title(r, '내일의 얼굴도\n기다릴게', .12, .20, .76, .23, size: .067);
        caption(r, .13, .63, .74, .16);
        _milestoneLabel(r, 'A NEW LITTLE DAY', .13, .86, .74);
    }
  } else {
    switch (i) {
      case 0:
        l.type(
          '발견\n도감',
          .10,
          .15,
          .58,
          .28,
          size: .110,
          font: 'BookMyungjo',
          weight: 800,
          color: '#365494',
        );
        l.scene(
          p(2),
          .44,
          .48,
          .44,
          .29,
          frame: 'storyDiscoverySlide',
          turn: 2,
        );
        l.type('탐험가 / 하준\n기록자 / 우리', .12, .68, .28, .15, size: .027);
        r.scene(
          p(0),
          .10,
          .12,
          .80,
          .70,
          frame: 'storyDiscoveryStitch',
          fill: true,
        );
        _milestoneLabel(r, 'THE WORLD IS STILL NEW', .13, .87, .74);
      case 1:
        _milestoneNote(
          l,
          'atelierWritingRecord',
          '오늘의 발견 목록\n\n01  바스락거리는 잎\n02  손에 들어오는 돌\n03  끝없이 그리는 선',
          .10,
          .13,
          .75,
          .70,
        );
        r.scene(p(2), .10, .14, .80, .39, frame: 'storyDiscoverySlide');
        r.scene(p(0), .12, .62, .36, .25, frame: 'studioPhotoCorners');
        r.scene(p(1), .56, .62, .34, .25, frame: 'materialNotebookMount');
      case 2:
        l.scene(p(2), .08, .14, .84, .52, frame: 'atelierWeave');
        l.type('만져 보고, 다시 한 번.', .13, .79, .74, .10, size: .037);
        title(r, '작은 손이\n기억하는 것', .12, .15, .76, .23, size: .069);
        r.mat('wavePencil', .13, .52, .65, .12, turn: -5);
        caption(r, .14, .75, .72, .14);
      case 3:
        l.scene(p(1), .055, .15, .89, .55, frame: 'storyDiscoveryStitch');
        _milestoneNote(
          l,
          'lifeWardrobeLabel',
          '오늘의 작품\n제목은 네 마음대로',
          .45,
          .68,
          .43,
          .20,
        );
        r.type(
          '그리는 동안\n자라난 이야기',
          .10,
          .16,
          .80,
          .23,
          size: .068,
          font: 'BookMyungjo',
          weight: 800,
        );
        r.scene(
          p(1),
          .22,
          .54,
          .68,
          .31,
          frame: 'studioPhotoCorners',
          turn: -2,
        );
      case 4:
        title(l, '바깥에서\n주워 온 보물', .10, .14, .80, .23, size: .069);
        l.scene(p(2), .10, .49, .57, .34, frame: 'materialNotebookMount');
        l.mat('materialSpecimenPocket', .71, .58, .19, .24);
        r.scene(
          p(0),
          .12,
          .12,
          .76,
          .70,
          frame: 'storyDiscoverySlide',
          fill: true,
        );
        _milestoneLabel(r, 'SPECIMEN / A SMALL LEAF', .13, .87, .74);
      case 5:
        l.scene(
          p(3),
          .12,
          .15,
          .70,
          .60,
          frame: 'atelierAccordion',
          fill: true,
        );
        l.type('한 걸음의 차이', .14, .83, .72, .07, size: .033);
        title(r, '어제보다\n조금 더 멀리', .12, .18, .76, .24, size: .070);
        r.scene(p(2), .42, .55, .47, .28, frame: 'storyDiscoveryStitch');
        r.type('먼저 가 볼래!', .12, .63, .26, .16, size: .032);
      case 6:
        l.scene(
          p(0),
          .08,
          .15,
          .52,
          .65,
          frame: 'storyDiscoverySlide',
          fill: true,
        );
        l.type('가까이\n더 가까이', .67, .24, .24, .28, size: .040, font: 'Eulyoo');
        r.scene(p(2), .12, .16, .76, .45, frame: 'atelierWeave');
        caption(r, .13, .75, .74, .14);
      case 7:
        _milestoneLabel(l, 'MY LITTLE COLLECTION', .10, .15, .80);
        l.scene(p(2), .11, .29, .41, .30, frame: 'materialScallopMount');
        l.scene(
          p(1),
          .51,
          .55,
          .37,
          .29,
          frame: 'materialNotebookMount',
          turn: 3,
        );
        title(r, '좋아해서\n모아 두었어', .12, .16, .76, .23, size: .073);
        r.scene(
          p(2),
          .16,
          .47,
          .43,
          .30,
          frame: 'studioPhotoCorners',
          fill: true,
          turn: -2,
        );
        r.mat('materialSpecimenPocket', .13, .64, .50, .26);
        r.type(
          '언제 / 오늘\n어디서 / 산책길\n왜 / 마음에 들어서',
          .65,
          .56,
          .24,
          .25,
          size: .026,
        );
      case 8:
        title(l, '표정도\n하나의 이야기', .10, .15, .80, .24, size: .070);
        caption(l, .13, .64, .74, .17);
        for (var n = 0; n < 3; n++) {
          r.scene(
            p([0, 1, 6][n]),
            .09 + n * .29,
            .27,
            .24,
            .36,
            frame: n == 1 ? 'storyDiscoveryStitch' : 'studioRounded',
            fill: true,
          );
          _milestoneLabel(
            r,
            ['CURIOUS', 'FOCUSED', 'HAPPY'][n],
            .09 + n * .29,
            .69,
            .24,
          );
        }
        r.type('말하지 않아도 보이는 마음', .13, .83, .74, .07, size: .030);
      case 9:
        _milestoneNote(
          l,
          'atelierWritingLetter',
          '네가 들려준 말\n\n“이것 봐, 내가 찾았어!”\n\n언제 / 산책하던 오후\n누구에게 / 같이 걷던 우리에게',
          .10,
          .13,
          .80,
          .72,
        );
        r.scene(p(4), .10, .17, .80, .46, frame: 'materialScallopMount');
        title(r, '짧은 말 속의\n커다란 세상', .11, .74, .48, .14, size: .041);
        r.scene(
          p(3),
          .65,
          .73,
          .25,
          .16,
          frame: 'studioPhotoCorners',
          fill: true,
        );
      case 10:
        l.scene(
          p(6),
          .12,
          .15,
          .60,
          .48,
          frame: 'atelierAccordion',
          fill: true,
        );
        l.mat('wavePencil', .13, .72, .70, .11, turn: 3);
        title(r, '네 방식으로\n재미있으면 돼', .10, .15, .80, .22, size: .066);
        r.scene(p(1), .13, .47, .74, .40, frame: 'atelierWeave', turn: -1);
      case 11:
        l.scene(p(7), .08, .18, .84, .55, frame: 'storyDiscoveryStitch');
        l.type('오늘은 여기까지.', .13, .83, .74, .07, size: .035, font: 'Eulyoo');
        title(r, '잘 쉰 다음에\n다시 만나자', .13, .18, .74, .24, size: .066);
        caption(r, .14, .61, .72, .17);
        r.mat('materialMonthDial', .67, .79, .20, .13);
      case 12:
        l.scene(
          p(5),
          .09,
          .15,
          .59,
          .66,
          frame: 'materialScallopMount',
          fill: true,
        );
        l.type('질문을\n들어 준 사람', .73, .29, .18, .29, size: .028);
        r.scene(p(4), .12, .16, .76, .42, frame: 'materialNotebookMount');
        title(r, '같이 발견한\n우리의 하루', .13, .72, .74, .17, size: .052);
      case 13:
        l.scene(p(3), .12, .22, .73, .45, frame: 'storyDiscoverySlide');
        _milestoneLabel(l, 'THEN / 그때의 너', .14, .77, .72);
        r.scene(
          p(0),
          .11,
          .14,
          .78,
          .60,
          frame: 'atelierAccordion',
          fill: true,
        );
        r.type('NOW / 어느새 이렇게', .13, .84, .74, .06, size: .025);
      case 14:
        title(l, '오늘의\n탐험 보고서', .10, .14, .80, .23, size: .074);
        l.type('걸어간 곳\n\n주워 온 것\n\n가장 재미있던 일', .12, .48, .76, .32, size: .031);
        l.mat('wavePencil', .55, .83, .34, .065);
        r.scene(p(2), .08, .11, .48, .37, frame: 'atelierWeave', fill: true);
        r.scene(p(1), .41, .51, .47, .32, frame: 'studioPhotoCorners', turn: 2);
        _milestoneNote(r, 'lifeWardrobeLabel', '오늘도 발견 완료', .09, .70, .31, .16);
      case 15:
        l.scene(
          p(0),
          .075,
          .13,
          .58,
          .71,
          frame: 'materialScallopMount',
          fill: true,
        );
        l.scene(
          p(1),
          .63,
          .64,
          .28,
          .20,
          frame: 'studioPhotoCorners',
          fill: true,
        );
        l.type('너의 다음 질문을 기다리며', .13, .86, .74, .06, size: .026);
        title(r, '다음 장도\n궁금해서', .12, .20, .76, .25, size: .078);
        caption(r, .14, .60, .72, .17);
        r.rule(.14, .84, .42, color: '#B8CCDD');
        _milestoneLabel(r, 'TO BE DISCOVERED, TOGETHER', .14, .88, .72);
    }
  }
  return [l, r];
}

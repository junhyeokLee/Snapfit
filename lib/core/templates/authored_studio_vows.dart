part of 'authored_collections.dart';

const _promisePhotos = [
  'assets/templates/atelier_editions_2026/our-first-promise.png',
  'assets/templates/original_editorial/images/petal_veil.png',
  'assets/templates/original_editorial/images/petal_bouquet.png',
  'assets/templates/original_editorial/images/petal_couple.png',
  'assets/templates/original_editorial/images/lightbound_guests.png',
  'assets/templates/original_editorial/images/petal_table.png',
  'assets/templates/original_editorial/images/petal_details.png',
  'assets/templates/original_editorial/images/petal_evening.png',
];
const _velvetPhotos = [
  'assets/templates/atelier_editions_2026/velvet-vow-archive.png',
  'assets/templates/atelier_editions_2026/velvet-vow-details.png',
  'assets/templates/atelier_editions_2026/velvet-vow-reading.png',
  'assets/templates/original_editorial/images/lightbound_ceremony.png',
  'assets/templates/original_editorial/images/lightbound_cake.png',
  'assets/templates/original_editorial/images/lightbound_twilight.png',
  'assets/templates/original_editorial/images/petal_bouquet.png',
  'assets/templates/original_editorial/images/lightbound_guests.png',
];

const _vowPapers = [
  ('#F3F0EB', false, '#673E50', true),
  ('#E9DCDD', false, '#ECEFEC', false),
  ('#DDE5E0', false, '#F4F0E6', false),
  ('#483A43', true, '#E7D7D9', false),
  ('#F2E7E2', false, '#CFD9D9', false),
  ('#E7E4DE', false, '#6A3E50', true),
  ('#E9D9D7', false, '#F1EDE6', false),
  ('#CEDAD6', false, '#E9E5E1', false),
  ('#F6F1EA', false, '#403D43', true),
  ('#D8D5DE', false, '#F0E9E3', false),
  ('#754851', true, '#E3DDD4', false),
  ('#E3E8E3', false, '#E9D6D2', false),
  ('#F1E9E4', false, '#CACFD2', false),
  ('#3B4544', true, '#EADFD9', false),
  ('#DFCFD4', false, '#E7EAE4', false),
  ('#F2EDE6', false, '#503C47', true),
];

List<_StudioPage> _studioVowSpread(StudioEdition e, CollectionAspect a, int i) {
  const basics = [
    ('#F0F3F3', '#F9F6F0'),
    ('#F1E7E6', '#E8EFF0'),
    ('#F6F3EC', '#E0E8E4'),
    ('#E2ECF0', '#F3EBE5'),
  ];
  final s = e.premium
      ? _vowPapers[i]
      : (basics[i % 4].$1, false, basics[i % 4].$2, false);
  final l = _StudioPage(e, a, i * 2 + 1, s.$1, dark: s.$2),
      r = _StudioPage(e, a, i * 2 + 2, s.$3, dark: s.$4);
  final story = _studioStories[e]![i];
  String p(int n) => (e.premium ? _velvetPhotos : _promisePhotos)[n];
  void title(
    _StudioPage sheet,
    String text,
    double x,
    double y,
    double w,
    double h, {
    double size = .070,
  }) => _milestoneTitle(sheet, text, x, y, w, h, size: size);
  void caption(_StudioPage sheet, double x, double y, double w, double h) =>
      _milestoneCaption(sheet, story.$2, x, y, w, h);
  _milestoneLabel(
    l,
    e.premium ? 'VOW ARCHIVE / ${i + 1}' : 'OUR PROMISE / ${i + 1}',
    .07,
    .04,
    .86,
  );
  if (!e.premium) {
    switch (i) {
      case 0:
        l.scene(p(0), .08, .14, .84, .64, fill: true);
        _milestoneLabel(l, 'OUR BEGINNING, TOGETHER', .10, .84, .80);
        title(r, '함께하기로\n한 우리', .13, .19, .74, .25);
        caption(r, .14, .59, .71, .17);
        r.rule(.14, .84, .23, color: '#8FA6AD');
      case 1:
        l.scene(p(1), .08, .13, .55, .68, frame: 'studyFloatMount', fill: true);
        l.type('기다리던\n아침의 준비', .69, .35, .23, .26, size: .032, font: 'Eulyoo');
        r.scene(p(6), .15, .15, .70, .38, frame: 'studioDeckle');
        title(r, '작은 것까지\n너를 생각하며', .12, .62, .76, .19, size: .055);
      case 2:
        title(l, '꽃을 고르는\n마음', .10, .14, .80, .21, size: .068);
        l.scene(p(2), .12, .45, .56, .38, frame: 'studioOval', fill: true);
        r.scene(p(6), .08, .09, .84, .53, frame: 'studioDoubleMat');
        caption(r, .13, .73, .75, .16);
      case 3:
        l.scene(p(3), .12, .12, .76, .75, frame: 'studyArchWindow', fill: true);
        r.type(
          '처음 보는 듯\n다시 반한 날',
          .12,
          .25,
          .76,
          .26,
          size: .070,
          font: 'Eulyoo',
        );
        caption(r, .13, .69, .73, .15);
      case 4:
        l.scene(p(0), .06, .21, .88, .48, fill: true);
        l.type(
          '같은 속도로 걷기로 했어.',
          .12,
          .78,
          .76,
          .09,
          size: .035,
          font: 'Eulyoo',
        );
        r.scene(
          p(3),
          .10,
          .12,
          .44,
          .44,
          frame: 'studioPhotoCorners',
          fill: true,
        );
        r.scene(p(1), .58, .41, .32, .40, frame: 'studioRounded', fill: true);
      case 5:
        _milestoneNote(
          l,
          'atelierWritingVow',
          '우리의 약속\n\n서로의 이야기를 끝까지 듣고\n작은 기쁨을 먼저 나누며\n같은 편으로 오래 함께할게.',
          .09,
          .14,
          .82,
          .70,
        );
        r.scene(p(6), .10, .18, .80, .43, frame: 'studioGallery');
        title(r, '마주 보고\n건넨 마음', .13, .70, .74, .17, size: .056);
      case 6:
        title(l, '곁에 있어\n고마운 사람들', .10, .13, .80, .22, size: .061);
        l.scene(p(4), .09, .47, .82, .39, frame: 'studioPostcard');
        r.scene(p(4), .07, .12, .86, .48, fill: true);
        caption(r, .13, .70, .73, .15);
      case 7:
        l.scene(p(5), .08, .15, .84, .51, frame: 'studioDoubleMat');
        caption(l, .12, .76, .76, .12);
        title(r, '작은\n축하의 자리', .12, .13, .76, .23, size: .075);
        r.scene(p(2), .36, .49, .51, .34, frame: 'studioOvalMat');
      case 8:
        for (var n = 0; n < 3; n++) {
          l.scene(
            p([6, 2, 1][n]),
            .09 + n * .29,
            .24,
            .24,
            .27,
            frame: 'studioPhotoCorners',
            fill: true,
          );
        }
        title(l, '남겨 둔 작은 것들', .10, .65, .80, .13, size: .052);
        _milestoneNote(
          r,
          'atelierWritingLetter',
          '기억해 둘 것\n\n꽃의 이름\n우리의 첫 반지\n직접 쓴 짧은 편지',
          .12,
          .16,
          .76,
          .65,
        );
      case 9:
        l.scene(p(7), .10, .12, .80, .70, frame: 'studioRounded', fill: true);
        r.scene(p(0), .12, .15, .65, .36, frame: 'studioPhotoCorners');
        title(r, '사진 밖에서도\n계속된 웃음', .14, .62, .72, .20, size: .061);
      case 10:
        title(l, '너에게\n남기는 편지', .12, .15, .76, .22, size: .072);
        caption(l, .13, .52, .74, .22);
        l.rule(.13, .82, .32, color: '#B29999');
        r.scene(p(3), .15, .18, .70, .57, frame: 'studioOvalMat', fill: true);
        r.type(
          '오늘도, 내일도 같은 편.',
          .15,
          .83,
          .70,
          .07,
          size: .028,
          font: 'Eulyoo',
        );
      case 11:
        l.scene(p(0), .07, .12, .66, .70, frame: 'studyFloatMount', fill: true);
        l.type('함께\n걷는 쪽으로', .78, .40, .15, .28, size: .028, font: 'Eulyoo');
        title(r, '이제부터\n우리의 날들', .13, .21, .74, .23, size: .071);
        caption(r, .14, .61, .72, .16);
        _milestoneLabel(r, 'THE STORY CONTINUES', .14, .86, .72);
    }
  } else {
    switch (i) {
      case 0:
        l.scene(p(1), .09, .15, .74, .46, frame: 'atelierEnvelope', turn: -2);
        _milestoneNote(
          l,
          'atelierWritingVow',
          '두 사람의 시작에\n당신을\n초대합니다.',
          .45,
          .48,
          .46,
          .41,
        );
        title(r, '우리라는\n약속을 펼치다', .12, .15, .76, .26, size: .078);
        r.scene(p(0), .12, .51, .62, .32, frame: 'storyVowGate');
        r.mat('waveSilkKnot', .77, .73, .15, .13);
      case 1:
        title(l, '당신에게,\n가장 다정한 이름', .10, .16, .80, .23, size: .063);
        l.mat('materialVellumBand', .11, .52, .69, .14);
        l.type('지윤 & 도현', .16, .55, .55, .07, size: .040, font: 'Eulyoo');
        caption(l, .13, .74, .74, .13);
        r.scene(p(0), .14, .13, .72, .70, frame: 'storyVowCotton', fill: true);
      case 2:
        l.mat('atelierWritingLetter', .07, .13, .77, .68);
        l.scene(p(1), .17, .22, .73, .40, frame: 'atelierFolio', turn: 2);
        l.type('그날의 준비물', .15, .76, .71, .08, size: .039, font: 'Eulyoo');
        r.scene(
          p(6),
          .09,
          .12,
          .50,
          .49,
          frame: 'materialLaceMount',
          fill: true,
        );
        r.mat('materialRose', .66, .40, .24, .31);
        caption(r, .12, .76, .76, .14);
      case 3:
        title(l, '차려입어도\n늘 보던 웃음', .10, .14, .80, .25, size: .069);
        l.scene(p(0), .11, .54, .48, .29, frame: 'studioPhotoCorners');
        l.type(
          '가장 좋아하는\n너의 표정',
          .67,
          .61,
          .22,
          .17,
          size: .028,
          font: 'Eulyoo',
        );
        r.scene(p(2), .045, .11, .91, .69, frame: 'storyVowGate', fill: true);
        _milestoneLabel(r, 'BEFORE THE CEREMONY', .10, .85, .80);
      case 4:
        l.scene(p(2), .08, .12, .84, .50, frame: 'atelierFolio');
        _milestoneNote(
          l,
          'atelierWritingVow',
          '눈을 보고\n천천히 건넨\n우리의 약속',
          .49,
          .52,
          .40,
          .37,
        );
        title(r, '너에게\n약속할게', .13, .15, .74, .23, size: .080);
        r.type(
          '작은 일에도 함께 웃고\n힘든 날에는 먼저 손을 내밀고\n서로의 편으로 오래 서 있을게.',
          .14,
          .48,
          .72,
          .28,
          size: .037,
          font: 'Eulyoo',
        );
        r.rule(.14, .85, .42, color: '#9D767D');
      case 5:
        l.scene(p(6), .15, .14, .63, .62, frame: 'storyVowCotton', fill: true);
        l.mat('materialClip', .69, .12, .16, .18, turn: 8);
        r.type('힘을 빼고\n잡은 손', .13, .17, .74, .25, size: .072, font: 'Eulyoo');
        r.scene(p(1), .13, .57, .74, .29, frame: 'signatureVowPocket');
      case 6:
        l.scene(p(2), .07, .13, .47, .66, frame: 'storyVowGate', fill: true);
        l.scene(
          p(3),
          .59,
          .39,
          .33,
          .32,
          frame: 'studioPhotoCorners',
          fill: true,
        );
        l.type('문이 열리기 전', .60, .79, .30, .07, size: .028, font: 'Eulyoo');
        title(r, '깊게 숨 쉬고,\n너를 한 번 더', .12, .21, .76, .25, size: .067);
        caption(r, .14, .63, .72, .16);
        r.mat('waveSilkKnot', .66, .81, .21, .10);
      case 7:
        title(l, '오래 마주 보는\n사이가 되었다', .12, .15, .76, .23, size: .062);
        l.scene(p(0), .11, .48, .78, .37, frame: 'atelierEnvelope');
        r.scene(
          p(2),
          .18,
          .12,
          .64,
          .74,
          frame: 'materialLaceMount',
          fill: true,
        );
      case 8:
        _milestoneNote(
          l,
          'atelierWritingVow',
          '서로에게 읽어 준 말\n\n매일의 작은 이야기를 나누고\n잘 모르는 마음은 다시 물으며\n오래 편안한 사람이 되어 줄게.',
          .08,
          .14,
          .84,
          .73,
        );
        r.scene(p(2), .07, .13, .86, .57, fill: true);
        r.type(
          '한 문장마다 눈을 마주치며.',
          .13,
          .79,
          .74,
          .09,
          size: .034,
          font: 'Eulyoo',
        );
      case 9:
        l.scene(p(7), .05, .17, .90, .46, frame: 'signatureVowPocket');
        title(l, '우리 곁에\n모인 마음들', .11, .72, .78, .16, size: .052);
        r.scene(
          p(7),
          .11,
          .11,
          .44,
          .43,
          frame: 'studioPhotoCorners',
          fill: true,
        );
        _milestoneNote(
          r,
          'atelierWritingLetter',
          '먼 길 와 준 사람\n반갑게 웃어 준 사람\n오래 고마운 이름들',
          .36,
          .49,
          .55,
          .40,
        );
      case 10:
        title(l, '축하를\n모아 둔 곳', .12, .15, .76, .23, size: .077);
        _milestoneNote(
          l,
          'atelierWritingLetter',
          '좋은 날의 마음을\n오래 간직할게요.',
          .12,
          .43,
          .70,
          .39,
        );
        l.mat('materialRose', .65, .67, .25, .23);
        r.scene(p(1), .12, .14, .71, .50, frame: 'atelierEnvelope', turn: -1.5);
        r.scene(p(6), .55, .67, .34, .22, frame: 'studioPhotoCorners');
      case 11:
        l.scene(p(4), .09, .14, .82, .52, frame: 'storyVowGate');
        caption(l, .12, .76, .76, .12);
        title(r, '잔을\n내려놓은 뒤', .10, .15, .80, .25, size: .075);
        r.scene(p(5), .28, .49, .63, .34, frame: 'studioDeckle', turn: 1.5);
      case 12:
        for (var n = 0; n < 2; n++)
          l.scene(
            p([1, 6][n]),
            .10 + n * .42,
            .24,
            .37,
            .40,
            frame: n == 0 ? 'atelierFolio' : 'studioPhotoCorners',
            fill: true,
          );
        l.type(
          '작은 디테일을 기억하는 법',
          .12,
          .79,
          .76,
          .08,
          size: .036,
          font: 'Eulyoo',
        );
        r.scene(p(1), .12, .17, .70, .59, frame: 'storyVowCotton', fill: true);
        r.mat('materialBookmark', .75, .64, .15, .22, turn: 6);
      case 13:
        title(l, '네가 고른 한 장', .11, .14, .78, .14, size: .052);
        l.scene(p(0), .10, .36, .80, .43, frame: 'studioDoubleMat');
        r.scene(p(2), .11, .13, .78, .44, frame: 'atelierFolio');
        title(r, '내가 고른 한 장', .12, .72, .76, .13, size: .050);
      case 14:
        l.scene(
          p(5),
          .08,
          .14,
          .64,
          .67,
          frame: 'studioPhotoCorners',
          fill: true,
        );
        l.type('다시\n펼쳐 보면', .76, .35, .15, .25, size: .032, font: 'Eulyoo');
        title(r, '많이 웃었던\n오늘의 우리', .11, .18, .78, .24, size: .070);
        caption(r, .13, .59, .74, .17);
        r.mat('waveSilkKnot', .13, .82, .28, .075);
      case 15:
        l.scene(
          p(0),
          .10,
          .16,
          .80,
          .64,
          frame: 'materialLaceMount',
          fill: true,
        );
        title(r, '앞으로도\n같은 편', .12, .18, .76, .26, size: .082);
        caption(r, .14, .60, .72, .16);
        r.rule(.14, .83, .72, color: '#BFA0A6');
        _milestoneLabel(r, 'A VOW TO KEEP / OUR NEXT CHAPTER', .14, .87, .72);
    }
  }
  return [l, r];
}

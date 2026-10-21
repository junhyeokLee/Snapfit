part of 'authored_collections.dart';

const _cityPhotos = [
  'assets/templates/atelier_editions_2026/city-crossing.png',
  'assets/templates/atelier_editions_2026/city-cafe.png',
  'assets/frame_preview/night_city.jpg',
  'assets/templates/jeju_travel/images/approved_stock/arrival_station.jpg',
  'assets/templates/atelier_editions_2026/city-tram-interior.png',
  'assets/templates/atelier_editions_2026/city-river.png',
  'assets/templates/jeju_travel/images/approved_stock/cafe_detail.jpg',
  'assets/templates/atelier_editions_2026/city-afterglow.png',
];
const _alleyPhotos = [
  'assets/templates/original_editorial/images/travel_street.png',
  'assets/templates/original_editorial/images/travel_cafe.png',
  'assets/templates/jeju_travel/images/approved_stock/cafe_detail.jpg',
  'assets/templates/original_editorial/images/journey_market.png',
  'assets/templates/original_editorial/images/daily_fruit.png',
  'assets/templates/original_editorial/images/daily_desk.png',
  'assets/templates/atelier_editions_2026/alley-afternoon.png',
];
const _cityStoryPhotos = [
  [7, 1, 2, 3],
  [4, 3, 2, 1],
  [0, 2, 4, 5],
  [1, 0, 2, 6],
  [5, 4, 0, 1],
  [5, 4, 3, 0],
  [3, 4, 2, 7],
  [1, 6, 0, 2],
  [2, 5, 1, 4],
  [3, 6, 4, 1],
  [5, 0, 7, 1],
  [1, 6, 2, 0],
  [4, 2, 5, 0],
  [7, 0, 4, 1],
  [5, 1, 2, 7],
  [0, 1, 2, 3],
];

// A deliberate light/dark sequence, not the same colored pair on every turn.
const _cityPapers = [
  ('#192E33', true, '#DAE4DF', false),
  ('#E9E6DB', false, '#BCCFCC', false),
  ('#233D43', true, '#F1EDE4', false),
  ('#E6E2D7', false, '#18333B', true),
  ('#BDD2CF', false, '#F2EDE2', false),
  ('#EEEDE6', false, '#C9D8CF', false),
  ('#1D343A', true, '#E1D8C9', false),
  ('#EAE6DB', false, '#D6DCCF', false),
  ('#233C42', true, '#B7D5D6', false),
  ('#EEE9DE', false, '#253B3E', true),
  ('#AD473D', true, '#ECE8DB', false),
  ('#E9E4D8', false, '#BDD1CD', false),
  ('#213A3C', true, '#E5DFD2', false),
  ('#F0ECE3', false, '#263B3F', true),
  ('#263C3D', true, '#E9E4D7', false),
  ('#1A3238', true, '#D8DCCF', false),
];

List<_StudioPage> _studioSpread(StudioEdition e, CollectionAspect a, int i) {
  final premium = e.premium;
  final paper = premium ? _cityPapers[i] : ('#F7F8F2', false, '#E7EFF0', false);
  final l = _StudioPage(e, a, i * 2 + 1, paper.$1, dark: paper.$2);
  final r = _StudioPage(e, a, i * 2 + 2, paper.$3, dark: paper.$4);
  final story = _studioStories[e]![i];
  final pool = premium ? _cityPhotos : _alleyPhotos;
  String p(int n) =>
      premium ? pool[_cityStoryPhotos[i][n % 4]] : pool[(i + n) % pool.length];
  void label(_StudioPage page, String text, double x, double y, double w) =>
      page.type(text, x, y, w, .045, size: .018, font: 'Poppins', weight: 600);
  void caption(_StudioPage page, double x, double y, double w, double h) =>
      page.type(story.$2, x, y, w, h, size: .027);
  label(
    l,
    '${(i + 1).toString().padLeft(2, '0')} / ${premium ? 'CITY JOURNAL' : 'WALK NOTES'}',
    .07,
    .055,
    .86,
  );
  if (!premium) {
    switch (i) {
      case 0:
        l.heading('조금 느린\n오후의 걸음', .08, .20, .84, .26, size: .078);
        l.rule(.08, .53, .19);
        caption(l, .08, .63, .54, .16);
        l.scene(p(2), .68, .64, .24, .19, frame: 'studioPhotoCorners');
        r.scene(p(0), .045, .06, .91, .76, fill: true);
        label(r, 'ONE AFTERNOON, AROUND THE BLOCK', .08, .86, .84);
      case 1:
        l.scene(p(0), .07, .18, .67, .51, frame: 'studioGallery');
        l.scene(p(2), .59, .63, .33, .22, frame: 'studioPhotoCorners');
        r.heading(story.$1, .10, .13, .80, .20);
        r.rule(.10, .40, .80);
        caption(r, .10, .47, .47, .23);
        r.scene(p(1), .61, .57, .28, .29, fill: true);
      case 2:
        l.scene(p(0), .12, .18, .76, .48, frame: 'studioArch');
        l.heading(story.$1, .10, .73, .80, .15, size: .052);
        r.scene(p(1), .04, .07, .92, .70, fill: true);
        caption(r, .08, .81, .84, .10);
      case 3:
        for (var n = 0; n < 4; n++) {
          l.scene(
            p(n),
            .07 + n % 2 * .445,
            .23 + n ~/ 2 * .28,
            .405,
            .23,
            frame: 'studioPhotoCorners',
          );
        }
        r.heading('작은 것을\n오래 보는 날', .10, .14, .80, .25, size: .077);
        r.scene(p(4), .10, .49, .80, .30);
        caption(r, .10, .83, .80, .075);
      case 4:
        l.heading(story.$1, .075, .16, .85, .15, size: .056);
        l.scene(p(0), .045, .39, .91, .36, fill: true);
        caption(l, .08, .82, .84, .08);
        r.scene(p(1), .10, .10, .53, .57, fill: true);
        r.type(
          '한 걸음,\n또 한 걸음.',
          .69,
          .20,
          .23,
          .25,
          size: .038,
          font: 'Eulyoo',
        );
        r.scene(p(2), .48, .70, .43, .17, frame: 'studioPhotoCorners');
      case 5:
        l.scene(p(0), .09, .20, .82, .57, frame: 'studioPostcard');
        l.mat('studioWashiRose', .59, .16, .26, .06, turn: -3);
        r.heading('창밖을\n잠시 바라보다', .10, .12, .80, .22, size: .070);
        r.scene(p(2), .10, .44, .80, .31, frame: 'studioGallery');
        caption(r, .10, .81, .80, .09);
      case 6:
        l.scene(p(1), .07, .17, .86, .49);
        l.heading(story.$1, .08, .74, .84, .13, size: .049);
        r.mat('studioCottonRag', .07, .12, .85, .65);
        r.type('오늘 고른 것', .15, .24, .68, .09, size: .039, font: 'Eulyoo');
        r.scene(p(3), .16, .40, .67, .27, frame: 'studioPhotoCorners');
        caption(r, .14, .79, .72, .10);
      case 7:
        l.box(l.uid, .04, .14, .92, .71, '#EBC9BC');
        l.heading('같은 길의\n다른 오후', .10, .26, .80, .26, size: .079);
        caption(l, .10, .64, .68, .14);
        r.scene(p(0), .08, .08, .84, .39, frame: 'studioPhotoCorners');
        r.scene(p(3), .29, .56, .63, .28, frame: 'studioDeckle');
      case 8:
        l.scene(p(1), .07, .16, .48, .64, fill: true);
        l.scene(p(3), .62, .36, .30, .23, frame: 'studioPhotoCorners');
        l.type('다음 골목은\n어떤 모습일까.', .62, .66, .30, .17, size: .031);
        r.heading(story.$1, .09, .12, .82, .20);
        r.scene(p(0), .09, .45, .82, .37, frame: 'studioGallery');
      case 9:
        l.scene(p(1), .12, .22, .76, .45, frame: 'studioOval');
        l.heading(story.$1, .10, .75, .80, .13, size: .050);
        r.scene(p(2), .05, .08, .90, .71, fill: true);
        caption(r, .09, .83, .82, .07);
      case 10:
        l.heading('오늘의\n산책 목록', .08, .15, .84, .20, size: .070);
        for (var n = 0; n < 4; n++) {
          label(
            l,
            ['01  머문 자리', '02  좋아한 가게', '03  들고 온 것', '04  다음에 갈 곳'][n],
            .09,
            .43 + n * .10,
            .82,
          );
          l.rule(.09, .49 + n * .10, .82, color: '#99B6B9');
        }
        r.scene(p(0), .10, .10, .80, .43, frame: 'studioDeckle');
        r.scene(p(2), .43, .65, .47, .23, frame: 'studioPhotoCorners');
      case 11:
        l.scene(p(0), .04, .15, .92, .64, fill: true);
        label(l, 'A GOOD DAY, NOT FAR FROM HOME', .08, .85, .84);
        r.heading('다음 오후에도\n천천히 걸을게', .10, .16, .80, .24, size: .068);
        r.rule(.10, .47, .20);
        caption(r, .10, .57, .80, .18);
        r.type(
          '우리의 산책 기록\n2026. 10.',
          .10,
          .80,
          .80,
          .09,
          size: .021,
          font: 'Eulyoo',
        );
    }
  } else {
    switch (i) {
      case 0:
        l.type(
          '01',
          .075,
          .15,
          .80,
          .23,
          size: .20,
          font: 'Poppins',
          weight: 600,
          color: '#B54D3E',
        );
        l.heading('저녁의 도시를\n펼쳐 보는 일', .08, .45, .84, .20, size: .068);
        l.mat('materialTransitPunch', .70, .71, .18, .16);
        caption(l, .08, .73, .54, .14);
        r.scene(p(0), .035, .045, .93, .79, fill: true);
        r.mat('atelierPostalBand', .09, .77, .39, .12);
        label(r, 'ARRIVAL / FIRST IMPRESSION', .54, .86, .39);
      case 1:
        l.scene(
          p(2),
          .075,
          .19,
          .62,
          .65,
          frame: 'atelierNegative',
          fill: true,
        );
        l.type(
          '한 정거장\n더 가도 좋아',
          .75,
          .29,
          .19,
          .30,
          size: .030,
          font: 'BookMyungjo',
        );
        r.mat('atelierWritingLetter', .06, .14, .87, .57, turn: -2);
        r.scene(p(0), .14, .20, .70, .31, frame: 'materialSlideMount');
        r.mat('atelierBoardingStub', .40, .54, .49, .19);
        r.heading(story.$1, .10, .77, .80, .13, size: .052);
      case 2:
        l.scene(p(0), .04, .19, .92, .60, fill: true);
        l.mat('materialVellumBand', .07, .74, .57, .13);
        r.heading('비가 그친\n교차로에서', .10, .11, .80, .23, size: .073);
        r.box(r.uid, .08, .42, .84, .40, '#1C434B');
        r.scene(p(3), .13, .47, .43, .29, frame: 'studioPhotoCorners');
        r.type(
          '건너편에서\n다시 만나요.',
          .62,
          .49,
          .24,
          .24,
          size: .030,
          color: '#F4F5ED',
        );
        caption(r, .10, .85, .80, .055);
      case 3:
        l.heading(story.$1, .08, .14, .84, .16, size: .058);
        l.scene(
          _cityPhotos[1],
          .075,
          .39,
          .85,
          .42,
          frame: 'signatureRailWallet',
        );
        l.mat('studioWashiIndigo', .62, .355, .23, .06, turn: -2);
        r.scene(p(1), .09, .09, .82, .40, frame: 'atelierFolio');
        r.mat('atelierWritingReceipt', .09, .56, .35, .31);
        r.type(
          '주문한 것\n머문 시간\n다음에 올 자리',
          .14,
          .63,
          .25,
          .18,
          size: .023,
          color: '#233A3E',
        );
        r.scene(p(0), .56, .65, .34, .20, frame: 'materialSlideMount');
      case 4:
        l.scene(p(0), .08, .19, .84, .43, frame: 'studioDeckle');
        l.heading('멈추고,\n뒤돌아보고', .09, .69, .82, .20, size: .063);
        r.scene(p(2), .08, .09, .46, .49, frame: 'atelierDeepMat', fill: true);
        r.scene(
          p(3),
          .58,
          .44,
          .34,
          .33,
          frame: 'studioPhotoCorners',
          fill: true,
        );
        r.mat('materialIndexTabs', .10, .70, .32, .12);
        caption(r, .10, .83, .80, .065);
      case 5:
        l.heading('돌아올 길을\n표시해 두었다', .08, .17, .84, .23, size: .064);
        l.mat('materialContourMap', .08, .49, .53, .36);
        l.scene(p(0), .63, .57, .28, .25, frame: 'materialSlideMount');
        r.mat('atelierWritingLetter', .075, .12, .85, .71);
        r.scene(p(2), .15, .21, .70, .40, frame: 'studioPhotoCorners');
        r.type(
          '지도를 접으면\n기억에 남는 길',
          .17,
          .65,
          .63,
          .12,
          size: .039,
          font: 'BookMyungjo',
        );
      case 6:
        for (var n = 0; n < 3; n++) {
          l.scene(
            p(n),
            .07,
            .18 + n * .225,
            .69,
            .18,
            frame: 'atelierNegative',
          );
          label(l, '${n + 1}', .81, .22 + n * .225, .10);
        }
        r.scene(p(3), .045, .08, .91, .66, fill: true);
        r.heading(story.$1, .09, .79, .82, .12, size: .054);
      case 7:
        l.box(l.uid, .045, .13, .91, .73, '#243E46');
        l.type(
          'TABLE\nFOR TWO',
          .10,
          .22,
          .80,
          .22,
          size: .09,
          font: 'Poppins',
          weight: 600,
          color: '#F4F5EA',
        );
        l.scene(p(1), .10, .52, .53, .25, frame: 'studioPhotoCorners');
        l.type(
          '늦은 저녁의\n작은 선택',
          .69,
          .55,
          .20,
          .20,
          size: .026,
          color: '#F4F5EA',
        );
        r.scene(_cityPhotos[1], .08, .09, .84, .43, frame: 'atelierEnvelope');
        caption(r, .10, .64, .51, .20);
        r.mat('atelierBoardingStub', .66, .68, .25, .14);
      case 8:
        l.scene(p(0), .10, .17, .70, .67, frame: 'atelierFolio', fill: true);
        r.type(
          'WINDOW\nSTUDIES',
          .09,
          .11,
          .82,
          .18,
          size: .081,
          font: 'Poppins',
          weight: 600,
        );
        r.scene(p(1), .09, .40, .46, .29, frame: 'materialSlideMount');
        r.scene(p(3), .63, .54, .28, .28, frame: 'atelierNegative', fill: true);
        caption(r, .09, .78, .46, .12);
      case 9:
        l.mat('atelierWritingLetter', .055, .28, .88, .52);
        l.scene(p(0), .11, .18, .62, .39, frame: 'studioGallery');
        l.mat('atelierBoardingStub', .47, .60, .42, .17);
        l.heading(story.$1, .09, .80, .82, .11, size: .049);
        r.heading('버리지 않고\n접어 둔 것들', .09, .11, .82, .21, size: .067);
        r.scene(
          p(2),
          .10,
          .44,
          .34,
          .40,
          frame: 'materialSlideMount',
          fill: true,
        );
        r.mat('atelierWritingReceipt', .54, .43, .36, .44);
        r.type(
          '머문 곳\n지나온 역\n다음의 약속',
          .59,
          .53,
          .25,
          .25,
          size: .025,
          color: '#233A3E',
        );
      case 10:
        l.scene(p(0), .07, .19, .56, .30, frame: 'studioPhotoCorners');
        l.scene(p(1), .37, .60, .56, .27, frame: 'atelierNegative');
        label(l, 'EARLIER', .70, .23, .22);
        label(l, 'LATER', .08, .69, .24);
        r.scene(p(2), .04, .07, .92, .67, fill: true);
        r.heading(story.$1, .08, .79, .84, .12, size: .049);
      case 11:
        l.scene(
          _cityPhotos[1],
          .045,
          .24,
          .91,
          .47,
          frame: 'signatureCinemaGate',
        );
        l.heading('한 잔을\n비우는 동안', .08, .75, .84, .15, size: .059);
        r.mat('atelierWritingLetter', .07, .11, .86, .67);
        r.type(
          '오늘 좋았던 곳\n\n다음에 같이 갈 곳',
          .16,
          .25,
          .67,
          .31,
          size: .036,
          font: 'BookMyungjo',
        );
        r.scene(p(3), .53, .68, .37, .20, frame: 'studioPhotoCorners');
      case 12:
        l.heading(story.$1, .08, .15, .84, .16, size: .056);
        l.scene(p(0), .08, .39, .48, .44, frame: 'atelierDeepMat', fill: true);
        l.scene(p(1), .64, .56, .28, .19, frame: 'studioPhotoCorners');
        r.scene(p(2), .09, .09, .82, .44, frame: 'studioDeckle');
        r.rule(.10, .65, .80);
        caption(r, .10, .72, .80, .15);
      case 13:
        l.type(
          'NIGHT\nWALK LOG',
          .08,
          .16,
          .84,
          .20,
          size: .081,
          font: 'Poppins',
          weight: 600,
        );
        for (var n = 0; n < 3; n++) {
          label(
            l,
            ['18:40 / 첫 번째 역', '20:10 / 창가의 자리', '21:30 / 돌아가는 길'][n],
            .09,
            .44 + n * .135,
            .82,
          );
          l.rule(.09, .51 + n * .135, .82, color: '#86A6A5');
        }
        r.scene(p(0), .085, .10, .83, .43, frame: 'atelierNegative');
        r.scene(p(2), .10, .67, .36, .20, frame: 'materialSlideMount');
        r.scene(p(3), .56, .62, .35, .25, frame: 'studioPhotoCorners');
      case 14:
        l.scene(p(0), .08, .17, .84, .50, frame: 'signatureRailWallet');
        l.mat('materialVellumBand', .16, .63, .55, .15);
        l.type(
          '다시 오면,\n이 길부터 걸을게.',
          .10,
          .80,
          .80,
          .10,
          size: .034,
          font: 'BookMyungjo',
        );
        r.heading('두고 온\n도시에게', .10, .12, .80, .23, size: .078);
        caption(r, .10, .45, .80, .16);
        r.scene(p(2), .43, .70, .46, .20, frame: 'materialSlideMount');
      case 15:
        l.scene(e.coverAsset, .04, .16, .92, .64, fill: true);
        label(l, 'OUR EVENING, BOUND TOGETHER', .08, .85, .84);
        r.type(
          'AFTER / HOURS',
          .10,
          .12,
          .80,
          .07,
          size: .036,
          font: 'Poppins',
          weight: 600,
        );
        r.heading('사진집을\n덮기 전에', .10, .28, .80, .22, size: .077);
        r.rule(.10, .56, .80);
        caption(r, .10, .64, .80, .13);
        r.type('도시의 잔광 / 2026\n사진과 글, 우리', .10, .82, .80, .08, size: .020);
    }
  }
  return [l, r];
}

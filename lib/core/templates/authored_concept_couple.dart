part of 'authored_collections.dart';

void _conceptCouple(_ConceptBook b) {
  const ink = '#354C44', rose = '#895D68', milk = '#F3F2ED';
  const mist = '#DDE5E3', blush = '#E9DBDE';

  b.add('our-door-opening', mist, (p) {
    p.label('${b.copy.byline}의 생활 기록', .085, .065, .80, color: ink);
    final width = math.min(.93, .67 * (1388 / 1133) / p.ratio);
    final paper = p.mat(
      'studioCottonRag',
      (1 - width) / 2,
      .195,
      width,
      .67,
      turn: -.018,
    );
    p.txt(
      '같이',
      paper.left + paper.width * .12,
      paper.top + paper.height * .12,
      paper.width * .73,
      paper.height * .23,
      size: .10,
      color: ink,
    );
    p.txt(
      '사는',
      paper.left + paper.width * .31,
      paper.top + paper.height * .39,
      paper.width * .55,
      paper.height * .23,
      size: .097,
      color: ink,
    );
    p.txt(
      '계절',
      paper.left + paper.width * .53,
      paper.top + paper.height * .65,
      paper.width * .43,
      paper.height * .23,
      size: .10,
      color: ink,
    );
    p.mat(
      'studioOlivePress',
      paper.left + .015,
      math.min(paper.bottom - .19, .58),
      .23,
      .18,
      turn: -.16,
    );
    p.txt(
      '너와 나, 그리고 우리의 매일.',
      .12,
      .82,
      .76,
      .075,
      size: .041,
      font: 'NanumPen',
      color: rose,
    );
  });
  b.add('homecoming-portrait', mist, (p) {
    p.mat('studioBlushPaper', .06, .115, .87, .75, turn: .025);
    p.pic(
      'couple_anniversary',
      .085,
      .08,
      .83,
      .71,
      frame: 'studioDeckle',
      turn: -.012,
    );
    p.mat('studioWashiSage', .58, .065, .26, .055, turn: .13);
    p.txt(
      '돌아오면 네가 있다.',
      .095,
      .835,
      .81,
      .07,
      font: 'NanumPen',
      size: .044,
      color: ink,
    );
  });

  b.add('our-chosen-corner', milk, (p) {
    p.txt('너의 자리', .075, .075, .68, .12, size: .077, color: ink);
    p.txt(
      '햇볕이 먼저 드는 쪽으로.',
      .34,
      .215,
      .57,
      .065,
      font: 'NanumPen',
      size: .038,
      color: rose,
    );
    p.mat('studioWashiRose', .54, .325, .23, .055, turn: .09);
    p.pic(
      'daily_desk',
      .08,
      .355,
      .78,
      .425,
      frame: 'studioPhotoCorners',
      turn: -.015,
    );
    p.label('커튼을 고르던 날 / 06. 08', .11, .855, .78, color: ink);
  });
  b.add('things-we-agreed-on', milk, (p) {
    p.pic(
      'couple_keepsakes',
      .055,
      .065,
      .60,
      .47,
      frame: 'studioDeckle',
      turn: .018,
    );
    p.txt(
      '네가\n좋아하는\n색으로',
      .71,
      .245,
      .22,
      .21,
      font: 'NanumPen',
      size: .039,
      color: rose,
    );
    p.txt('나의 자리', .255, .585, .68, .12, size: .077, color: ink);
    p.rule(.27, .75, .63, color: '#ADBDB3');
    p.txt(
      '한쪽은 비워 두었다.\n네가 가져올 것들을 위해.',
      .27,
      .795,
      .65,
      .12,
      size: .031,
      color: ink,
    );
  });

  b.add('morning-table', '#E6EBE3', (p) {
    p.label('아침에는', .07, .055, .83, color: ink);
    p.pic('small_days_breakfast', .04, .145, .92, .64, frame: 'studioLinen');
    p.txt('늘, 두 잔', .065, .83, .47, .09, size: .060, color: ink);
    p.txt(
      '먼저 일어난 사람이 물을 올린다.',
      .58,
      .835,
      .34,
      .075,
      font: 'NanumPen',
      size: .030,
      color: rose,
    );
  });
  b.add('two-cups-note', '#E6EBE3', (p) {
    p.txt(
      '커피는 조금 연하게,',
      .12,
      .125,
      .77,
      .095,
      font: 'NanumPen',
      size: .052,
      color: ink,
    );
    p.txt(
      '잼은 넉넉하게.',
      .25,
      .225,
      .65,
      .085,
      font: 'NanumPen',
      size: .054,
      color: ink,
    );
    p.pic('daily_fruit', .17, .38, .43, .35, frame: 'studioOval', turn: -.025);
    p.txt('매일\n외워 가는\n너의 취향', .675, .43, .235, .23, size: .042, color: rose);
    p.label('천천히 먹어도 괜찮은 아침.', .13, .825, .77, color: ink);
  });

  b.add('market-weekend', milk, (p) {
    p.txt('토요일의', .08, .065, .82, .12, size: .075, color: ink);
    p.txt('장바구니', .275, .19, .65, .12, size: .075, color: ink);
    p.pic(
      'journey_market',
      .06,
      .37,
      .89,
      .40,
      frame: 'studioFilm',
      turn: -.012,
    );
    p.mat('materialTicketDuo', .60, .74, .30, .11, turn: -.05);
    p.txt(
      '오늘 저녁은 뭘 먹을까?',
      .09,
      .84,
      .64,
      .07,
      size: .042,
      font: 'NanumPen',
      color: rose,
    );
  });
  b.add('grocery-list', milk, (p) {
    final paper = p.mat('studioLedger', .055, .075, .64, .78, turn: -.02);
    p.paperText(
      paper,
      '잊지 말고 사 올 것',
      .13,
      .14,
      .76,
      .13,
      size: .043,
      font: 'NanumPen',
    );
    p.paperText(
      paper,
      '잘 익은 토마토\n내일 먹을 빵\n네가 좋아하는 복숭아\n그리고 작은 꽃 한 단',
      .15,
      .36,
      .71,
      .44,
      size: .037,
      font: 'NanumPen',
    );
    p.pic('daily_fruit', .72, .24, .23, .29, frame: 'studioOvalMat');
    p.txt(
      '꽃은\n계획에\n없었지만.',
      .735,
      .60,
      .23,
      .20,
      size: .035,
      font: 'NanumPen',
      color: rose,
    );
    p.label('돌아오는 길에는 하나씩 나눠 들었다.', .09, .87, .82, color: ink);
  });

  b.add('dinner-for-two', ink, (p) {
    p.txt('오늘은', .07, .07, .78, .115, size: .077, color: milk);
    p.txt('집에서 먹자.', .235, .195, .69, .11, size: .062, color: milk);
    p.pic(
      'family_table',
      .045,
      .365,
      .91,
      .43,
      frame: 'studioDeckle',
      turn: -.012,
    );
    p.txt(
      '조금 서툴러도, 같이 만들었으니까.',
      .075,
      .85,
      .85,
      .065,
      size: .035,
      font: 'NanumPen',
      color: '#DAE1CE',
    );
  }, dark: true);
  b.add('dinner-conversation', ink, (p) {
    p.mat('studioBlushPaper', .035, .055, .92, .64, turn: .023);
    p.pic(
      'small_days_breakfast',
      .095,
      .105,
      .81,
      .46,
      frame: 'studioPhotoCorners',
    );
    p.txt('잘 먹었습니다.', .075, .71, .83, .105, size: .064, color: milk);
    p.txt(
      '설거지는 같이 하자.',
      .47,
      .855,
      .43,
      .07,
      size: .038,
      font: 'NanumPen',
      color: '#DAE1CE',
    );
  }, dark: true);

  b.add('rainy-window-reading', mist, (p) {
    p.pic(
      'daily_book',
      .055,
      .07,
      .61,
      .72,
      frame: 'atelierFolio',
      turn: -.012,
    );
    p.txt(
      '비\n오\n는\n주\n말',
      .76,
      .18,
      .15,
      .48,
      size: .064,
      color: ink,
      align: 'center',
      lineHeight: 1.4,
    );
    p.mat('materialBookmark', .57, .61, .16, .20, turn: .08);
    p.txt(
      '읽던 페이지를 잠깐 접어 두고.',
      .095,
      .86,
      .80,
      .065,
      size: .038,
      font: 'NanumPen',
      color: ink,
    );
  });
  b.add('rainy-day-letter', mist, (p) {
    p.mat('studioBlueFibre', .025, .255, .95, .61, turn: -.018);
    p.txt('아무 데도', .08, .075, .82, .12, size: .067, color: ink);
    p.txt('가지 않기로 했다.', .15, .20, .77, .105, size: .057, color: ink);
    p.txt(
      '각자 책을 읽다가\n같은 장면에 웃었다.\n창문은 조금만 열어 두었다.',
      .13,
      .445,
      .69,
      .225,
      font: 'NanumPen',
      size: .045,
      color: ink,
    );
    p.txt(
      '이런 주말도 좋네.',
      .37,
      .83,
      .55,
      .075,
      font: 'NanumPen',
      size: .048,
      color: rose,
    );
  });

  b.add('regular-cafe-table', milk, (p) {
    p.numeral('Table for two', .075, .055, .86, .125, size: .09, color: ink);
    p.group('couple_cafe', .045, .245, .91, .60, frame: 'studioDeckle');
    p.txt(
      '메뉴를 보지 않아도 아는 사이.',
      .08,
      .855,
      .84,
      .065,
      font: 'NanumPen',
      size: .038,
      color: rose,
    );
  });
  b.add('regular-order-card', milk, (p) {
    p.pic('travel_cafe', .075, .085, .51, .60, frame: 'studioDoubleMat');
    p.txt('늘\n앉던\n자리', .665, .24, .26, .31, size: .063, color: ink);
    p.mat('materialTicketDuo', .57, .61, .32, .13, turn: -.06);
    p.rule(.10, .78, .78, color: '#ACBCB1');
    p.txt(
      '같은 주문,\n조금 다른 하루의 이야기.',
      .11,
      .815,
      .77,
      .105,
      size: .035,
      font: 'NanumPen',
      color: ink,
    );
  });

  b.add('anniversary-preparations', blush, (p) {
    p.label('처음 만난 날을 기억하는 방법', .085, .06, .84, color: rose);
    p.txt('너에게', .08, .16, .69, .14, size: .099, color: rose);
    p.mat('studioCotton', .04, .35, .73, .50, turn: -.025);
    p.pic(
      'couple_keepsakes',
      .075,
      .38,
      .72,
      .43,
      frame: 'studioDeckle',
      turn: .012,
    );
    p.mat('studioRoseSilk', .69, .68, .24, .21, turn: -.12);
    p.txt(
      '올해도 같이 축하하자.',
      .09,
      .855,
      .64,
      .065,
      size: .037,
      font: 'NanumPen',
      color: rose,
    );
  });
  b.add('anniversary-with-you', blush, (p) {
    p.pic('couple_anniversary', .05, .055, .90, .65, frame: 'studioOval');
    p.txt('또 한 해, 우리.', .085, .74, .83, .105, size: .072, color: rose);
    p.label('큰 선물보다 오래 남은 저녁.', .095, .865, .83, color: rose);
  });

  b.add('letter-for-you', milk, (p) {
    p.label('서로에게 남긴 말', .09, .055, .82, color: ink);
    final letter = p.mat('studioCotton', .045, .175, .75, .69, turn: -.015);
    p.paperText(
      letter,
      '너에게,',
      .135,
      .13,
      .74,
      .14,
      font: 'NanumPen',
      size: .045,
    );
    p.paperText(
      letter,
      b.copy.note == b.volume.defaultCopy.note
          ? '사소한 하루를 나누는\n사이가 됐다.\n\n내일도 같은 문을\n열고 들어오자.'
          : b.copy.note,
      .135,
      .32,
      .74,
      .51,
      font: 'NanumPen',
      size: .042,
    );
    p.mat('studioPressedCosmos', .72, .53, .22, .32, turn: .10);
    p.paperText(
      letter,
      b.copy.byline,
      .30,
      .875,
      .55,
      .10,
      font: 'NanumPen',
      size: .031,
    );
  });
  b.add('letter-keepsakes', milk, (p) {
    p.mat('studioGlassineEnvelope', .09, .23, .82, .66, turn: -.03);
    p.pic(
      'couple_keepsakes',
      .10,
      .20,
      .65,
      .395,
      frame: 'studioPhotoCorners',
      turn: -.025,
    );
    p.mat('studioWashiRose', .54, .19, .26, .06, turn: .13);
    p.txt('버리지 못한 편지', .07, .06, .86, .105, size: .058, color: ink);
    p.txt(
      '읽을 때마다 그날이 생각나서.',
      .13,
      .84,
      .78,
      .075,
      size: .043,
      font: 'NanumPen',
      color: rose,
    );
  });

  b.add('seasonal-walk', '#DCE4D6', (p) {
    p.txt('같은 길을', .07, .07, .82, .12, size: .076, color: ink);
    p.group('couple_walk', .04, .23, .92, .53, frame: 'studioDeckle');
    p.txt('다른 계절에.', .30, .79, .62, .115, size: .068, color: ink);
  });
  b.add('seasonal-home-pair', '#DCE4D6', (p) {
    p.mat('studioOlivePress', .07, .065, .28, .26, turn: -.09);
    p.txt(
      '창문을 여는 시간이\n조금씩 길어졌다.',
      .41,
      .145,
      .50,
      .16,
      font: 'NanumPen',
      size: .045,
      color: ink,
    );
    p.pic('daily_desk', .065, .40, .57, .36, frame: 'studioLinen', turn: -.03);
    p.pic(
      'couple_walk',
      .68,
      .47,
      .255,
      .305,
      frame: 'studioInstant',
      turn: .025,
    );
    p.label('커튼을 바꾸고 / 같은 길을 걷고', .105, .86, .81, color: ink);
  });

  b.add('home-object-cabinet', '#E8E3E1', (p) {
    p.label('우리 집의 작은 물건들', .075, .055, .84, color: ink);
    p.pic(
      'couple_keepsakes',
      .065,
      .16,
      .69,
      .45,
      frame: 'studioDoubleMat',
      turn: -.012,
    );
    p.txt(
      '모\n아\n둔\n날\n들',
      .805,
      .31,
      .075,
      .255,
      font: 'NanumPen',
      size: .038,
      color: rose,
    );
    p.txt('물건보다', .075, .67, .78, .105, size: .069, color: ink);
    p.txt('그날이 남았다.', .25, .795, .67, .105, size: .066, color: ink);
  });
  b.add('ordinary-days-contact', '#E8E3E1', (p) {
    p.pic(
      'small_days_breakfast',
      .095,
      .10,
      .50,
      .35,
      frame: 'studioPhotoCorners',
      turn: -.022,
    );
    p.pic(
      'daily_book',
      .62,
      .225,
      .30,
      .315,
      frame: 'studioInstant',
      turn: .02,
    );
    p.pic('couple_cafe', .20, .535, .49, .28, frame: 'studioFilm', turn: -.015);
    p.txt(
      '아침. 책. 단골 카페.',
      .075,
      .865,
      .82,
      .065,
      size: .040,
      font: 'NanumPen',
      color: ink,
    );
  });

  b.add('returning-home-letter', mist, (p) {
    p.label('다음 계절에도', .09, .065, .81, color: ink);
    final width = math.min(.93, .63 * (1388 / 1133) / p.ratio);
    final paper = p.mat(
      'studioCottonRag',
      (1 - width) / 2,
      .24,
      width,
      .63,
      turn: .018,
    );
    p.txt(
      '다녀왔어,',
      paper.left + paper.width * .11,
      paper.top + paper.height * .12,
      paper.width * .82,
      paper.height * .23,
      size: .075,
      color: ink,
    );
    p.txt(
      '하는 말이',
      paper.left + paper.width * .23,
      paper.top + paper.height * .40,
      paper.width * .70,
      paper.height * .23,
      size: .064,
      color: ink,
    );
    p.txt(
      '좋아졌다.',
      paper.left + paper.width * .35,
      paper.top + paper.height * .66,
      paper.width * .61,
      paper.height * .23,
      size: .073,
      color: ink,
    );
    p.txt(
      '내일도 같은 문을 열고 들어오자.',
      .105,
      .825,
      .80,
      .08,
      font: 'NanumPen',
      size: .044,
      color: rose,
    );
  });
  b.add('last-shared-portrait', mist, (p) {
    p.mat('studioBlueFibre', .03, .175, .94, .66, turn: -.02);
    p.pic(
      'couple_anniversary',
      .085,
      .075,
      .83,
      .65,
      frame: 'studioDeckle',
      turn: .012,
    );
    p.mat('studioWashiSage', .135, .06, .25, .06, turn: -.15);
    p.txt(
      '우리의 다음 장에서 만나.',
      .09,
      .83,
      .82,
      .08,
      size: .048,
      font: 'NanumPen',
      color: ink,
    );
  });
}

part of 'authored_collections.dart';

void _conceptFamily(_ConceptBook b) {
  const green = '#345947',
      paper = '#F8F6EE',
      tomato = '#9B5144',
      yellow = '#E1D89B';
  b.add('picnic-invitation', green, (p) {
    p.label('이번 일요일, 시간 어때?', .075, .055, .85, color: paper);
    p.numeral('Sunday', .07, .13, .86, .23, size: .21, color: yellow);
    p.txt('나무 그늘\n아래에서', .085, .415, .47, .23, size: .074, color: paper);
    p.mat('lifeBasket', .58, .39, .34, .35);
    p.box(p.uid, .07, .745, .86, .135, paper);
    p.label('준비물', .105, .785, .20, color: green);
    p.txt('도시락 하나, 오래 앉을 마음', .32, .78, .56, .075, size: .031, color: green);
  }, dark: true);
  b.add('basket-opening-still-life', paper, (p) {
    p.pic('daily_picnic', .04, .055, .92, .825);
    p.photoLabel('밖에서 보내는 하루', .085, .74, .64, .11, color: green, size: .04);
    p.mat('materialCrossStitchBand', .65, .075, .25, .055);
  });
  b.add('packing-the-basket', yellow, (p) {
    p.label('바구니를 채우며', .075, .055, .85, color: green);
    p.numeral('Pack a little.', .07, .135, .85, .17, size: .115, color: green);
    p.box(p.uid, .055, .365, .89, .50, paper);
    p.ledger('01', '사과 몇 개', .09, .425, .44, color: green);
    p.ledger('02', '접시와 작은 컵', .09, .55, .44, color: green);
    p.ledger('03', '나눠 앉을 천', .09, .675, .44, color: green);
    p.pic('daily_fruit', .595, .415, .29, .36, frame: 'studioScallop');
    p.mat('materialVellumBand', .59, .78, .29, .055);
  });
  b.add('kitchen-before-leaving', paper, (p) {
    p.group(
      'family_kitchen',
      .055,
      .065,
      .89,
      .59,
      frame: 'studioPhotoCorners',
    );
    p.box(p.uid, .055, .695, .89, .185, tomato);
    p.txt('같이 준비하는 일도\n즐거웠다.', .095, .725, .80, .12, size: .039, color: paper);
    p.mat('atelierPostalBand', .56, .63, .33, .055);
  });
  b.add('gingham-meeting-place', paper, (p) {
    p.label('돗자리를 펼친 자리', .075, .055, .85, color: green);
    p.mat('lifeGingham', .05, .15, .89, .62);
    p.group('family_picnic', .135, .25, .73, .41, frame: 'studioInstant');
    p.txt('여기, 우리 자리', .085, .81, .83, .105, size: .055, color: green);
  });
  b.add('tree-shade-note', '#DCE4D6', (p) {
    p.numeral('Under the trees', .075, .045, .85, .17, size: .10, color: green);
    p.board(
      'daily_picnic',
      .075,
      .27,
      .52,
      .565,
      edge: green,
      caption: '나무 아래 오래 앉았다',
    );
    p.txt('가방을\n내려놓고', .65, .325, .27, .17, size: .047, color: green);
    p.rule(.65, .54, .25, color: tomato);
    p.txt('조금 더\n가까이', .65, .62, .27, .15, size: .047, color: green);
  });
  b.add('lunch-menu-photo', green, (p) {
    p.label('TODAY ON THE TABLE', .075, .055, .85, color: paper);
    p.txt('오늘의\n도시락', .075, .13, .82, .225, size: .08, color: paper);
    p.pic('family_table', .055, .40, .89, .445, frame: 'materialNotebookMount');
    p.mat('materialCrossStitchBand', .58, .37, .32, .055);
  }, dark: true);
  b.add('shared-recipe', paper, (p) {
    p.box(p.uid, .055, .055, .89, .83, '#E5E0BE');
    p.label('각자 하나씩, 같이 한 상', .09, .09, .81, color: green);
    p.numeral('The menu', .09, .17, .81, .16, size: .125, color: green);
    final recipeWidth = math.min(.78, .42 * 1.55 / p.ratio);
    p.recipe(
      '도시락\n과일\n따뜻한 차',
      '각자 하나씩\n만들어 오기.\n다음엔 더 넉넉히.',
      (1 - recipeWidth) / 2,
      .345,
      recipeWidth,
      .42,
    );
    p.txt('누가 만든 게 제일 맛있어?', .10, .775, .79, .075, size: .036, color: green);
  });
  b.add('family-group-large', '#DBE3D7', (p) {
    p.group('family_picnic', .035, .045, .93, .62);
    p.numeral('All of us', .07, .715, .58, .15, size: .14, color: green);
    p.label('모두 모인 얼굴', .68, .82, .25, color: green);
  });
  b.add('attendance-and-smiles', paper, (p) {
    p.label('한 명도 빠짐없이, 사진 안으로', .075, .055, .85, color: green);
    p.box(p.uid, .055, .175, .89, .63, green);
    p.group('family_friends', .085, .225, .83, .43, frame: 'studioDoubleMat');
    p.label('오래 못 봤어도 금방 익숙해지는 얼굴들', .10, .735, .80, color: paper);
    p.mat('materialTicketDuo', .56, .79, .34, .10);
  });
  b.add('play-afternoon', yellow, (p) {
    p.numeral('No plans', .075, .045, .85, .17, size: .15, color: green);
    p.board(
      'family_picnic',
      .055,
      .29,
      .89,
      .54,
      edge: green,
      caption: '아이들이 고른 놀이',
      groupPhoto: true,
    );
    p.mat('atelierColorSlips', .73, .155, .17, .10);
  });
  b.add('play-list', paper, (p) {
    p.txt(
      '아무것도 안 해도\n심심하지 않은 날',
      .075,
      .065,
      .85,
      .21,
      size: .062,
      color: green,
    );
    p.note(
      'lifePicnicSlip',
      '집에 가자는 말은\n조금 나중에.',
      .065,
      .36,
      .55,
      .28,
      size: .03,
    );
    p.pic('daily_picnic', .655, .385, .27, .28, frame: 'studioPostage');
    p.box(p.uid, .07, .74, .86, .12, green);
    p.label('뛰어놀고, 쉬었다가, 다시 한 번.', .10, .775, .80, color: paper);
  });
  b.add('shade-wide-pause', green, (p) {
    p.numeral(
      'A long afternoon',
      .07,
      .055,
      .86,
      .155,
      size: .094,
      color: yellow,
    );
    p.group('family_picnic', .045, .265, .91, .51);
    p.label('그늘 아래 잠깐', .075, .835, .85, color: paper);
  }, dark: true);
  b.add('quiet-picnic-objects', '#E0E5D3', (p) {
    p.box(p.uid, .055, .055, .89, .80, paper);
    p.edgeStitches(.075, .075, .85, .76, '#A5B19A');
    p.pic('daily_picnic', .105, .12, .51, .46, frame: 'studioArch');
    p.mat('lifeMug', .66, .265, .235, .23);
    p.txt('옆 사람 이야기를\n오래 들었다.', .11, .65, .78, .14, size: .046, color: green);
  });
  b.add('fruit-on-cloth', paper, (p) {
    p.label('한 조각 더 먹고 가자', .075, .055, .85, color: tomato);
    p.mat('lifeGingham', .05, .18, .90, .59);
    p.pic('daily_fruit', .12, .235, .76, .49, frame: 'studioPhotoCorners');
    p.numeral(
      'One more slice?',
      .08,
      .805,
      .83,
      .105,
      size: .08,
      color: tomato,
    );
  });
  b.add('snack-and-conversation', '#EBDDCC', (p) {
    p.numeral('A little more', .075, .06, .85, .17, size: .115, color: tomato);
    p.txt('조금만 더\n먹고 가자', .085, .31, .46, .23, size: .073, color: tomato);
    p.pic('family_table', .58, .325, .33, .37, frame: 'studioOvalMat');
    p.box(p.uid, .07, .74, .86, .12, paper);
    p.label('메뉴보다 길어진 우리의 이야기', .10, .775, .80, color: tomato);
    p.mat('atelierRibbonPlate', .09, .61, .38, .075);
  });
  b.add('friends-arrive', '#DDE4D8', (p) {
    p.label('자리를 조금 더 넓히자', .075, .055, .85, color: green);
    p.group('family_friends', .045, .175, .91, .54, frame: 'atelierNegative');
    p.txt('빈자리를 채우는 얼굴', .075, .795, .85, .115, size: .047, color: green);
  });
  b.add('friendship-contact-pair', paper, (p) {
    p.numeral('Saved for you', .075, .045, .85, .16, size: .115, color: green);
    p.board(
      'daily_friends',
      .06,
      .265,
      .62,
      .48,
      edge: green,
      caption: '너도 이쪽에 앉아',
      groupPhoto: true,
    );
    p.pic('daily_picnic', .715, .47, .215, .285, frame: 'studioPostcard');
    p.mat('materialTicketDuo', .53, .78, .36, .10);
    p.label('비워 둔 자리가 채워졌다.', .075, .835, .40);
  });
  b.add('late-afternoon-landscape', green, (p) {
    p.group('family_picnic', .045, .055, .91, .59);
    p.txt('해가 기울 때까지', .075, .705, .85, .11, size: .059, color: paper);
    p.label('조금 더 있다가 돌아가기로 했다.', .075, .845, .85, color: paper);
  }, dark: true);
  b.add('packing-up', paper, (p) {
    p.label('다음 일요일을 위해', .075, .055, .85, color: green);
    p.box(p.uid, .055, .175, .89, .48, '#DDE3D2');
    p.mat('lifeBasket', .085, .265, .37, .31);
    p.pic('daily_picnic', .53, .22, .36, .34, frame: 'studioDeckle');
    p.txt('천을 개고\n이야기를 챙기고', .085, .725, .83, .16, size: .051, color: green);
  });
  b.add('sunday-contact-sheet', '#E8DFC8', (p) {
    p.numeral('Take home', .075, .045, .85, .16, size: .13, color: green);
    p.board(
      'family_friends',
      .065,
      .255,
      .56,
      .585,
      edge: green,
      caption: '다음에 또 만나',
      groupPhoto: true,
    );
    p.pic('daily_fruit', .67, .265, .255, .235, frame: 'studioInstant');
    p.pic('daily_picnic', .67, .57, .255, .26, frame: 'studioPostage');
  });
  b.add('sunday-keepsake-label', paper, (p) {
    p.txt('남겨 온\n장면들', .075, .065, .51, .235, size: .08, color: green);
    p.mat('lifeMug', .655, .125, .25, .235);
    p.note(
      'lifePicnicSlip',
      '오늘 함께한 사람들\n다음에 만날 장소',
      .09,
      .43,
      .78,
      .34,
      size: .033,
    );
    p.caption('사진을 보면 다시 모인 기분.', .09, .84, .82);
  });
  b.add('next-sunday-note', green, (p) {
    p.box(p.uid, .055, .055, .89, .83, paper);
    p.label('다음 일요일에도', .095, .095, .81, color: green);
    p.numeral('See you soon.', .095, .20, .81, .18, size: .11, color: green);
    p.txt(b.copy.note, .095, .46, .81, .22, size: .035, color: green);
    p.rule(.095, .745, .79, color: tomato);
    p.label(b.copy.byline, .095, .80, .79, color: green);
  }, dark: true);
  b.add('last-group-photograph', paper, (p) {
    p.box(p.uid, .055, .055, .89, .825, green);
    p.group('family_picnic', .085, .145, .83, .52);
    p.txt('같이 앉으니 더 좋은 자리', .095, .755, .81, .09, size: .038, color: paper);
  });
}

part of 'authored_collections.dart';

void _conceptBaby(_ConceptBook b) {
  const blue = '#385873', milk = '#FAF9F2', butter = '#EADBAB';
  b.add('wardrobe-opening-inventory', '#D7E4E8', (p) {
    p.edgeStitches(.045, .04, .91, .86, '#8EA9B7');
    p.label('너를 기다리는 서랍 / 첫 번째 기록', .085, .075, .83);
    p.numeral('Little', .075, .15, .82, .19, size: .18, color: blue);
    p.txt('작은 옷장', .095, .38, .80, .14, size: .086, color: blue);
    p.box(p.uid, .08, .56, .84, .30, milk);
    p.mat('lifeBonnet', .10, .575, .28, .25);
    p.ledger('준비', '모자와 작은 옷', .435, .60, .43);
    p.ledger('마음', '어서 만나고 싶어', .435, .725, .43);
  });
  b.add('first-clothes-flatlay', blue, (p) {
    p.pic('growth_keepsakes', .055, .045, .89, .85);
    p.photoLabel('아직은 조금 큰 옷', .10, .77, .58, .095, color: blue, size: .035);
    p.mat('materialCrossStitchBand', .60, .065, .29, .055);
  }, dark: true);
  b.add('hand-detail-museum', milk, (p) {
    p.label('처음 맞잡은 손', .075, .055, .84, color: blue);
    p.numeral('Hello, you.', .07, .13, .85, .17, size: .125, color: blue);
    p.box(p.uid, .07, .355, .86, .49, '#D7E3E8');
    p.edgeStitches(.09, .375, .82, .45, '#96AFBC');
    p.pic('growth_hand', .125, .40, .61, .38, frame: 'materialScallopMount');
    p.mat('materialBooties', .73, .47, .16, .24);
    p.label('가장 작은 손으로, 가장 꼭 잡았다.', .095, .865, .82);
  });
  b.add('first-touch-letter', '#EADFD8', (p) {
    p.txt('손가락\n하나를 꼭', .075, .075, .48, .23, size: .078, color: blue);
    p.pic(
      'growth_sleep',
      .615,
      .075,
      .30,
      .285,
      frame: 'studioInstant',
      turn: .025,
    );
    p.note(
      'materialScallopNote',
      '작은 손이 먼저\n내 손을 잡았다.\n잊지 못할 감촉.',
      .08,
      .425,
      .77,
      .43,
      size: .033,
    );
    p.mat('materialVellumBand', .64, .54, .26, .055);
    p.pic('growth_hand', .56, .555, .34, .275, frame: 'studioDeckle');
  });
  b.add('first-smile-dominant', blue, (p) {
    p.pic('growth_play', .035, .045, .93, .77);
    p.photoLabel('이름을 부르면', .075, .07, .54, .105, color: blue, size: .041);
    p.label('눈을 맞추던 그날의 표정을 오래 기억할게.', .075, .855, .85, color: milk);
  }, dark: true);
  b.add('smile-observation-card', butter, (p) {
    p.label('작은 표정 수집', .075, .06, .85, color: blue);
    p.txt('처음엔\n아주 조금씩', .075, .15, .54, .225, size: .073, color: blue);
    p.mat('lifeRattle', .68, .15, .23, .25);
    p.box(p.uid, .06, .445, .88, .43, milk);
    p.pic('growth_play', .085, .475, .36, .31, frame: 'studioSticker');
    p.ledger('눈', '우리 쪽을 보고', .50, .505, .38);
    p.ledger('입', '조금씩 웃었다', .50, .645, .38);
    p.label('매일 새로 배우는 얼굴', .10, .805, .79, color: blue);
  });
  b.add('outfit-preparation', milk, (p) {
    p.numeral('Out & about', .065, .045, .86, .16, size: .115, color: blue);
    p.box(p.uid, .055, .255, .89, .54, '#D7E3DF');
    p.edgeStitches(.08, .28, .84, .49, '#8EA79E');
    p.mat('lifeBib', .10, .32, .37, .31);
    p.mat('materialBooties', .56, .39, .31, .29);
    p.label('턱받이 하나', .12, .715, .33);
    p.label('작은 신발 한 켤레', .57, .715, .32);
    p.caption('오늘은 조금 더 멀리 가 보자.', .08, .845, .85);
  });
  b.add('first-outing', '#DAE4DB', (p) {
    p.label('우리의 첫 외출', .075, .055, .84);
    p.group('growth_walk', .05, .145, .90, .57, frame: 'studioPhotoCorners');
    p.box(p.uid, .07, .745, .86, .14, blue);
    p.txt('세상을 만나러', .10, .775, .78, .085, size: .052, color: milk);
    p.mat('materialCrossStitchBand', .53, .13, .32, .06);
  });
  b.add('nap-full-portrait', '#D6DEE8', (p) {
    p.pic('growth_sleep', .055, .055, .89, .82, frame: 'studioArch');
    p.photoLabel('조용히, 네가 잠든 동안', .115, .75, .73, .09, color: blue, size: .03);
  });
  b.add('sleep-routine-note', milk, (p) {
    p.numeral('Quiet hours', .07, .045, .85, .165, size: .115, color: blue);
    p.txt('오래 잠든\n오후', .08, .255, .50, .25, size: .085, color: blue);
    p.mat('materialMonthDial', .65, .30, .25, .25);
    p.board('growth_hand', .075, .565, .44, .29, edge: blue);
    p.txt('작은 숨소리에\n방도 조용해졌다.', .58, .64, .34, .15, size: .035);
    p.rule(.58, .84, .32);
  });
  b.add('playroom-record', butter, (p) {
    p.label('좋아하는 놀이가 생겼다', .075, .055, .84, color: blue);
    p.numeral('Play!', .07, .12, .84, .20, size: .185, color: blue);
    p.board(
      'growth_play',
      .06,
      .37,
      .68,
      .48,
      edge: blue,
      caption: '자꾸만 손이 가는 쪽으로',
    );
    p.mat('lifeRattle', .755, .43, .16, .23);
    p.mat('atelierColorSlips', .74, .715, .19, .13);
  });
  b.add('little-favorites', milk, (p) {
    p.txt('손이 먼저\n향하는 것들', .08, .07, .82, .21, size: .07, color: blue);
    p.box(p.uid, .06, .34, .88, .51, '#DCE6E9');
    p.pic(
      'growth_keepsakes',
      .095,
      .38,
      .45,
      .40,
      frame: 'studioDeckle',
      turn: -.025,
    );
    p.pic('growth_play', .59, .465, .30, .285, frame: 'studioInstant');
    p.label('새 장난감보다 익숙한 물건이 좋았던 너.', .085, .865, .84);
  });
  b.add('outgrown-wardrobe-label', '#D6E1E8', (p) {
    p.box(p.uid, .06, .06, .17, .82, blue);
    p.txt('작\n아\n진\n옷', .105, .22, .09, .46, size: .06, color: milk);
    p.board(
      'growth_keepsakes',
      .285,
      .06,
      .65,
      .59,
      edge: blue,
      caption: '첫 계절의 옷을 접어 두다',
    );
    p.mat('heirloomGrowthRuler', .285, .70, .63, .06);
    p.txt('너는 이만큼\n자랐구나', .30, .79, .61, .11, size: .038);
  });
  b.add('keepsake-pocket', milk, (p) {
    p.label('첫해의 작은 물건들', .08, .055, .83);
    p.mat('materialSpecimenPocket', .12, .175, .77, .57);
    p.mat('lifeBib', .25, .255, .40, .31);
    p.note(
      'lifeWardrobeLabel',
      '다시 꺼내 보면\n그때의 네가 생각나.',
      .50,
      .59,
      .41,
      .225,
      size: .025,
    );
    p.caption('버릴 수 없어서, 한 번 더 접어서.', .085, .85, .83);
  });
  b.add('first-steps-landscape', '#D8E3D9', (p) {
    p.numeral('Step by step', .07, .045, .85, .16, size: .12, color: blue);
    p.group('growth_walk', .05, .24, .90, .53);
    p.rule(.075, .82, .15);
    p.txt('함께 걷는 연습', .30, .80, .61, .105, size: .045);
  });
  b.add('steps-diagonal-record', blue, (p) {
    p.label('너의 속도로 걸었다', .08, .055, .83, color: milk);
    p.numeral('1, 2, 3', .08, .155, .84, .20, size: .17, color: butter);
    p.box(p.uid, .07, .40, .86, .46, milk);
    p.pic('growth_hand', .105, .445, .38, .34, frame: 'studioOvalMat');
    p.txt('잡은 손을\n놓지 않고', .55, .475, .32, .18, size: .047, color: blue);
    p.label('오늘도 한 걸음 더', .55, .735, .31);
  }, dark: true);
  b.add('family-embrace-photo', milk, (p) {
    p.label('WITH YOU, ALWAYS', .075, .055, .85, color: blue);
    p.box(p.uid, .055, .15, .89, .61, '#D4DFDA');
    p.group('growth_walk', .08, .18, .84, .54, frame: 'materialNotebookMount');
    p.txt('가족의 품에서', .08, .805, .83, .10, size: .052);
  });
  b.add('family-handwritten-page', '#E9DED6', (p) {
    p.txt('우리도\n처음이었어', .08, .08, .83, .23, size: .075, color: blue);
    p.note(
      'lifeWardrobeLabel',
      '처음인 날마다\n우리도 함께 배웠어.',
      .075,
      .42,
      .58,
      .30,
      size: .029,
    );
    p.pic('growth_hand', .675, .47, .255, .31, frame: 'editionPostage');
    p.mat('atelierRibbonPlate', .09, .80, .43, .075);
  });
  b.add('birthday-countdown', butter, (p) {
    p.numeral('One', .065, .03, .86, .26, size: .25, color: blue);
    p.label('첫 생일을 앞두고', .075, .30, .84, color: blue);
    p.board(
      'growth_birthday',
      .06,
      .41,
      .88,
      .44,
      edge: blue,
      caption: '함께 보낸 첫 번째 한 해',
    );
    p.mat('materialMonthDial', .74, .17, .15, .15);
  });
  b.add('birthday-gift-note', milk, (p) {
    p.pic(
      'growth_birthday',
      .07,
      .055,
      .64,
      .47,
      frame: 'materialScallopMount',
    );
    p.mat('materialVellumBand', .63, .10, .27, .055);
    p.box(p.uid, .22, .575, .71, .30, '#D9E3E9');
    p.edgeStitches(.245, .595, .66, .26, '#9AAFB8');
    p.txt('한 살의\n너에게', .275, .635, .60, .18, size: .067, color: blue);
  });
  b.add('growing-contact-board', milk, (p) {
    p.label('하루하루 자란 너 / 네 장의 기록', .075, .055, .85);
    p.box(p.uid, .055, .15, .89, .715, blue);
    p.pic('growth_sleep', .085, .185, .38, .295, frame: 'studioInstant');
    p.pic('growth_play', .535, .185, .38, .295, frame: 'studioInstant');
    p.pic('growth_walk', .085, .525, .38, .295, frame: 'studioPostage');
    p.pic('growth_birthday', .535, .525, .38, .295, frame: 'studioPostage');
  });
  b.add('growth-summary', '#DDE6E4', (p) {
    p.numeral('Your first year', .075, .055, .85, .16, size: .106, color: blue);
    p.box(p.uid, .06, .255, .88, .59, milk);
    p.ledger('처음', '우리에게 웃어 준 날', .105, .315, .78);
    p.ledger('조금 더', '혼자 앉아 있던 날', .105, .46, .78);
    p.ledger('드디어', '첫걸음을 내딛던 날', .105, .605, .78);
    p.label('모든 처음을 가까이에서', .11, .77, .77, color: blue);
  });
  b.add('next-season-letter', blue, (p) {
    p.edgeStitches(.06, .05, .88, .85, '#91A9B7');
    p.label('다음 계절의 옷장', .095, .09, .81, color: milk);
    p.txt('조금 더\n자란 너에게', .095, .23, .81, .23, size: .077, color: milk);
    p.txt(b.copy.note, .095, .53, .80, .18, size: .034, color: milk);
    p.mat('lifeBonnet', .10, .725, .20, .15);
    p.label(b.copy.byline, .55, .80, .34, color: milk);
  }, dark: true);
  b.add('wardrobe-last-portrait', '#D6E2E6', (p) {
    p.pic('growth_play', .06, .05, .88, .84);
    p.photoLabel(
      '조금 천천히 자라도 괜찮아',
      .105,
      .765,
      .79,
      .095,
      color: blue,
      size: .031,
    );
  });
}

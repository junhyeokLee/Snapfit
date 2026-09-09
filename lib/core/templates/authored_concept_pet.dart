part of 'authored_collections.dart';

void _conceptPet(_ConceptBook b) {
  const teal = '#245955', cream = '#F7F7EE', lime = '#DDDFAE', blue = '#315B9B';
  b.add('new-housemate-introduction', teal, (p) {
    p.label('우리 집의 새 식구 / 생활 관찰집', .075, .055, .85, color: cream);
    p.numeral('Roommate', .065, .14, .88, .19, size: .148, color: lime);
    p.txt('오늘부터\n같이 살자', .085, .415, .49, .22, size: .078, color: cream);
    p.box(p.uid, .63, .405, .27, .305, '#D9E5DD');
    p.mat('lifeRopeBall', .645, .435, .245, .25);
    p.rule(.085, .77, .80, color: '#8AB1A5');
    p.label('네 자리 하나가 생기고, 집이 달라졌다.', .085, .825, .80, color: cream);
  }, dark: true);
  b.add('first-housemate-portrait', '#D5E4DC', (p) {
    p.pic('pet_cat', .045, .045, .91, .84);
    p.photoLabel(
      '작은 동거인을 소개합니다',
      .075,
      .075,
      .75,
      .10,
      color: teal,
      size: .033,
    );
    p.mat('materialIndexTabs', .70, .835, .22, .06);
  });
  b.add('companion-profile', cream, (p) {
    p.box(p.uid, .055, .055, .89, .825, '#DFE7DE');
    p.label('MEMBER CARD / 우리 집의 보리', .085, .085, .83, color: teal);
    p.numeral('Bori', .085, .17, .81, .18, size: .17, color: teal);
    p.pic('pet_cat', .085, .415, .36, .34, frame: 'studioOvalMat');
    p.ledger('이름', '보리', .50, .425, .39, color: teal);
    p.ledger('취향', '햇볕 드는 곳', .50, .55, .39, color: teal);
    p.ledger('특기', '곁에 있기', .50, .675, .39, color: teal);
    p.mat('materialNamePatch', .085, .79, .29, .065);
  });
  b.add('profile-belongings', lime, (p) {
    p.txt('너의 물건도\n하나씩 늘었다', .075, .06, .82, .215, size: .066, color: teal);
    p.board(
      'pet_keepsakes',
      .065,
      .35,
      .64,
      .49,
      edge: teal,
      caption: '이 집에 네 자리가 생겼다',
    );
    p.mat('lifeBowl', .72, .52, .21, .24);
    p.label('매일 쓰는 작은 것들', .71, .80, .24, color: teal);
  });
  b.add('sunlit-morning-portrait', cream, (p) {
    p.pic('pet_cat', .055, .055, .89, .815, frame: 'atelierKeyhole');
    p.photoLabel('아침의 단골 자리', .115, .735, .69, .105, color: teal, size: .036);
  });
  b.add('morning-observation-note', '#D5E5DF', (p) {
    p.label('오전 관찰 기록', .075, .055, .84, color: teal);
    p.numeral('Sun seeker', .07, .145, .85, .17, size: .125, color: teal);
    p.txt('햇볕이 먼저\n자리를 잡으면', .08, .36, .82, .18, size: .057, color: teal);
    p.note(
      'lifeCompanionTab',
      '조용히 다가와\n햇볕 속에 앉는다.',
      .075,
      .61,
      .57,
      .265,
      size: .029,
    );
    p.pic('pet_cat', .69, .625, .24, .24, frame: 'studioInstant');
  });
  b.add('favorite-toy-object', blue, (p) {
    p.label('놀이 시간 / 가장 좋아하는 것', .075, .055, .85, color: cream);
    p.numeral('Play time', .07, .13, .86, .20, size: .15, color: cream);
    p.box(p.uid, .065, .40, .87, .45, '#DFE7D7');
    p.mat('lifeRopeBall', .095, .44, .42, .33);
    p.pic('pet_keepsakes', .59, .465, .28, .265, frame: 'materialSlideMount');
    p.label('먼저 달려가는 쪽', .59, .775, .28, color: teal);
  }, dark: true);
  b.add('toy-scorecard', cream, (p) {
    p.label('오래 물고 놀던 것', .075, .055, .85, color: blue);
    p.box(p.uid, .055, .155, .89, .70, '#E4E7EE');
    p.pic(
      'pet_keepsakes',
      .095,
      .20,
      .51,
      .38,
      frame: 'studioDeckle',
      turn: -.02,
    );
    p.mat('lifeFeltMouse', .65, .26, .23, .24);
    p.txt('새것보다\n익숙한 게 좋아', .095, .65, .78, .15, size: .048, color: blue);
    p.mat('atelierArchiveSeal', .755, .585, .125, .10);
  });
  b.add('play-and-rest-photo', '#DBE6DF', (p) {
    p.label('놀다가, 쉬다가', .075, .055, .85, color: teal);
    p.board(
      'pet_nap',
      .055,
      .165,
      .89,
      .68,
      edge: teal,
      caption: '오늘의 놀이가 끝난 자리',
    );
    p.mat('materialVellumBand', .58, .145, .31, .055);
  });
  b.add('resting-rhythm', lime, (p) {
    p.numeral('Pause.', .075, .07, .85, .23, size: .22, color: teal);
    p.txt('네가 정하는\n하루의 속도', .085, .37, .79, .20, size: .068, color: teal);
    p.box(p.uid, .07, .67, .86, .185, cream);
    p.ledger('할 일', '아주 오래 쉬기', .105, .71, .78, color: teal);
    p.label('방해하지 않는 시간도 필요해.', .105, .805, .78, color: teal);
  });
  b.add('snack-listening', cream, (p) {
    p.numeral('Did you hear?', .075, .045, .85, .16, size: .115, color: teal);
    p.pic('pet_cat', .075, .26, .67, .58, frame: 'studioArch');
    p.box(p.uid, .79, .26, .135, .58, teal);
    p.txt('간\n식\n시\n간', .832, .38, .075, .37, size: .048, color: cream);
  });
  b.add('snack-cupboard-record', '#DFE7D5', (p) {
    p.label('소리만 나면 제일 먼저', .075, .055, .85, color: teal);
    p.box(p.uid, .055, .17, .89, .48, cream);
    p.mat('lifeBowl', .105, .28, .36, .29);
    p.txt('어디에\n있다가도', .545, .235, .33, .20, size: .054, color: teal);
    p.label('달려오는 너', .55, .53, .33, color: teal);
    p.note(
      'atelierRibbonPlate',
      '조금씩, 약속한 만큼만.',
      .08,
      .75,
      .82,
      .14,
      size: .024,
    );
  });
  b.add('window-watch', teal, (p) {
    p.label('너의 창가, 너의 세상', .075, .055, .85, color: cream);
    p.pic('pet_cat', .055, .16, .89, .655);
    p.photoLabel('창가를 지키는 시간', .105, .71, .71, .09, color: teal, size: .033);
    p.label('오래 보고 있어도 지루하지 않은 풍경', .075, .855, .85, color: cream);
  }, dark: true);
  b.add('window-observation-card', cream, (p) {
    p.numeral('Window notes', .075, .045, .85, .16, size: .105, color: teal);
    p.note(
      'materialWalkLedger',
      '창밖의 손님\n오늘의 자리\n가만히 앉아 있는 시간',
      .075,
      .30,
      .59,
      .535,
      size: .028,
    );
    p.pic('pet_cat', .69, .38, .24, .37, frame: 'studioPostage');
    p.label('무엇을 그렇게 오래 보고 있을까.', .08, .86, .84, color: teal);
  });
  b.add('outside-day-keepsake', '#DCE5E7', (p) {
    p.txt('외출을\n준비하며', .075, .055, .84, .225, size: .08, color: blue);
    p.board(
      'pet_keepsakes',
      .06,
      .35,
      .88,
      .50,
      edge: blue,
      caption: '익숙한 물건을 함께 챙긴다',
    );
    p.mat('materialNamePatch', .61, .305, .27, .07);
  });
  b.add('back-from-outside', cream, (p) {
    p.label('낯선 하루가 끝나면', .075, .055, .85, color: blue);
    p.pic('pet_nap', .075, .185, .56, .49, frame: 'studioOvalMat');
    p.mat('materialLeash', .68, .355, .23, .235);
    p.txt('다시,\n익숙한 자리로', .085, .735, .82, .16, size: .051, color: blue);
  });
  b.add('little-habits-triptych', cream, (p) {
    p.label('우리만 아는 작은 버릇', .075, .055, .85, color: teal);
    p.box(p.uid, .055, .16, .89, .70, '#D7E4DE');
    p.pic('pet_cat', .085, .20, .43, .55, frame: 'studioFilm');
    p.pic('pet_keepsakes', .59, .23, .285, .25, frame: 'materialSlideMount');
    p.mat('lifeFeltMouse', .60, .54, .265, .23);
    p.label('한 번 알면 잊기 어려운 취향', .09, .795, .81, color: teal);
  });
  b.add('habits-written-down', lime, (p) {
    p.numeral('Little habits', .075, .055, .85, .16, size: .115, color: teal);
    p.txt('잠들기 전에는\n꼭 한 바퀴', .085, .29, .82, .20, size: .069, color: teal);
    p.box(p.uid, .07, .565, .86, .31, cream);
    p.ledger('현관', '문 앞에서 기다리기', .105, .605, .77, color: teal);
    p.ledger('잠자리', '마지막으로 둘러보기', .105, .745, .77, color: teal);
  });
  b.add('side-by-side-afternoon', '#DFE7DC', (p) {
    p.pic('pet_nap', .055, .055, .89, .825);
    p.photoLabel('나란히 쉬는 오후', .10, .755, .62, .095, color: teal, size: .036);
    p.mat('materialVellumBand', .58, .075, .30, .06);
  });
  b.add('companion-quiet-note', teal, (p) {
    p.label('말없이 곁에 있어도', .075, .06, .85, color: cream);
    p.numeral('Together.', .075, .145, .85, .20, size: .157, color: lime);
    p.pic('pet_nap', .58, .435, .33, .32, frame: 'studioOvalMat');
    p.txt(
      '같이 있다는 건\n생각보다 큰\n위로가 됐다.',
      .085,
      .475,
      .425,
      .25,
      size: .044,
      color: cream,
    );
    p.rule(.085, .845, .80, color: '#89A89B');
  }, dark: true);
  b.add('well-loved-belongings', cream, (p) {
    p.numeral('Well loved', .075, .045, .85, .17, size: .125, color: teal);
    p.board(
      'pet_keepsakes',
      .065,
      .29,
      .70,
      .55,
      edge: teal,
      caption: '오래 쓴 물건들',
    );
    p.mat('heirloomPetTag', .77, .415, .15, .215);
    p.mat('atelierColorSlips', .72, .735, .19, .10);
  });
  b.add('toy-archive-label', '#DDE6DB', (p) {
    p.txt('버릴 수 없는\n이유가 있어', .075, .055, .84, .235, size: .073, color: teal);
    p.note(
      'lifeCompanionTab',
      '가장 많이 가지고 논 것\n아직 버릴 수 없는 것',
      .09,
      .36,
      .80,
      .35,
      size: .032,
    );
    p.box(p.uid, .09, .785, .80, .075, teal);
    p.label('네가 고른 것들을 오래 보관할게.', .115, .803, .75, color: cream);
  });
  b.add('tomorrow-together-letter', teal, (p) {
    p.box(p.uid, .055, .055, .89, .825, cream);
    p.label('우리의 평범한 하루를 남겨 둔다', .10, .10, .80, color: teal);
    p.txt('내일도\n같이 살자', .10, .255, .80, .24, size: .088, color: teal);
    p.txt(b.copy.note, .10, .56, .80, .18, size: .033, color: teal);
    p.rule(.10, .78, .79, color: teal);
    p.label(b.copy.byline, .10, .82, .79, color: teal);
  }, dark: true);
  b.add('last-housemate-portrait', cream, (p) {
    p.pic('pet_cat', .06, .055, .88, .82, frame: 'atelierNegative');
    p.photoLabel('오늘도 네가 있어서', .115, .75, .70, .095, color: teal, size: .037);
  });
}

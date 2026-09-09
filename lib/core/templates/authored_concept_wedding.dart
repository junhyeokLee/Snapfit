part of 'authored_collections.dart';

void _conceptWedding(_ConceptBook b) {
  b.add('silk-opening-title', '#F5F5F1', (p) {
    p.label('THE DAY WE CHOSE', .09, .07, .55);
    p.numeral('01', .74, .15, .17, .2, color: '#BCC6C0', size: .16);
    p.txt('예식을 앞둔\n아침', .09, .19, .60, .23, size: .077);
    p.rule(.09, .45, .18);
    final card = p.mat('atelierTitlePlate', .09, .53, .60, .34);
    p.paperText(
      card,
      '평소보다 일찍 눈을 떴다.\n오늘의 작은 순간들을\n천천히 기억해 두기로 했다.',
      .14,
      .25,
      .73,
      .60,
      size: .025,
    );
    p.mat('waveSilkKnot', .61, .65, .29, .23);
  });
  b.add('veil-gatefold', '#E2E9E4', (p) {
    p.pic('petal_veil', .055, .055, .89, .82);
    p.mat('materialVellumBand', .02, .76, .62, .14);
    p.label('17 OCTOBER / DRESSING ROOM', .09, .805, .76);
  });
  b.add('preparation-contact-pair', '#F8F8F5', (p) {
    p.label('BEFORE THE CEREMONY', .08, .065, .8);
    p.mount('petal_details', .075, .16, .52, .43, frame: 'atelierCrossRibbon');
    p.mount('petal_bouquet', .51, .48, .40, .35, frame: 'studioOvalMat');
    p.mat('atelierRibbonPlate', .08, .65, .36, .13);
    p.txt('하나씩,\n마음을 담아', .11, .73, .36, .13, size: .038);
  });
  b.add('preparation-inventory', '#EFF1ED', (p) {
    p.numeral('A / B', .08, .05, .68, .15, size: .10);
    p.pic('petal_details', .08, .25, .34, .42, frame: 'materialLaceMount');
    p.txt('작은 준비들', .48, .25, .44, .11, size: .044);
    p.rule(.48, .40, .42);
    p.txt('손에 쥔 부케\n나란히 놓인 반지\n접어 둔 손수건', .49, .44, .42, .22, size: .027);
    p.mat('materialLace', .69, .71, .24, .17);
    p.caption('어떤 장면보다 먼저 기억나는 것들.', .08, .82, .62);
  });
  b.add('couple-unframed-portrait', '#FFFFFF', (p) {
    p.pic('petal_couple', .06, .07, .88, .74);
    p.txt('나란히 선 두 사람', .075, .835, .78, .075, size: .037);
  });
  b.add('couple-oval-letter', '#E4EAE6', (p) {
    p.label('PORTRAIT / TOGETHER', .08, .065, .85);
    p.pic('petal_couple', .23, .15, .56, .48, frame: 'studioOvalMat');
    p.mat('waveSilkKnot', .08, .58, .27, .25);
    p.txt('같은 곳을 바라보며\n조금 더 가까이', .39, .69, .5, .15, size: .038);
  });
  b.add('handwritten-vow', '#F9F9F5', (p) {
    final card = p.mat('materialBlindEmboss', .07, .08, .85, .79);
    p.paperText(
      card,
      'OUR VOWS',
      .16,
      .12,
      .67,
      .08,
      size: .019,
      font: 'NotoSans',
    );
    p.paperText(card, '서로에게', .16, .28, .70, .16, size: .067);
    p.paperText(card, b.copy.note, .16, .53, .68, .25, size: .027);
    p.paperText(
      card,
      b.copy.byline,
      .16,
      .84,
      .68,
      .08,
      size: .021,
      font: 'NotoSans',
    );
    p.mat('waveSilkKnot', .72, .60, .19, .23);
  });
  b.add('vow-sealed-portrait', '#CDD9D1', (p) {
    p.mount('lightbound_ceremony', .10, .10, .80, .57, frame: 'atelierFolio');
    final ribbon = p.mat('atelierRibbonPlate', .12, .70, .74, .15);
    p.paperText(ribbon, '오늘 적은 마음을 오래', .13, .29, .76, .55, size: .027);
    p.label(b.copy.period, .32, .855, .52);
  });
  b.add('bouquet-study', '#F4F5F1', (p) {
    p.numeral('Flowers', .08, .07, .85, .14, size: .115);
    p.pic('petal_bouquet', .075, .255, .68, .52, frame: 'atelierKeyhole');
    p.mat('materialLace', .65, .65, .27, .23);
    p.caption('꽃을 건네던 순간', .085, .83, .7);
  });
  b.add('flowers-detail-column', '#E6EAE6', (p) {
    p.pic('petal_table', .08, .08, .49, .50);
    p.pic('petal_bouquet', .61, .29, .31, .44, frame: 'studioRounded');
    p.label('STILL LIFE / 05', .08, .64, .48);
    p.txt('작은 꽃까지\n잊지 않도록', .08, .73, .68, .14, size: .044);
  });
  b.add('ceremony-large-photo', '#EFF2ED', (p) {
    p.label('THE CEREMONY', .075, .055, .8);
    p.pic('lightbound_ceremony', .04, .15, .92, .64);
    p.rule(.075, .835, .15);
    p.caption('입장하던 길, 맞잡은 손.', .29, .823, .63);
  });
  b.add('ceremony-type-inset', '#3B4D45', (p) {
    p.txt('입장', .09, .07, .72, .18, size: .105, color: '#F6F7F2');
    p.pic('petal_veil', .42, .27, .49, .51, frame: 'studioPhotoCorners');
    p.txt(
      '가장 익숙한 얼굴이\n가장 먼저 보였다.',
      .09,
      .35,
      .29,
      .25,
      size: .029,
      color: '#F6F7F2',
    );
    p.label('A MOMENT TO KEEP', .09, .84, .8, color: '#F6F7F2');
  }, dark: true);
  b.add('ring-mat', '#E9EDE8', (p) {
    p.label('THE PROMISE', .08, .075, .8);
    p.pic('petal_details', .145, .18, .71, .58, frame: 'atelierDeepMat');
    p.mat('waveSilkKnot', .57, .64, .29, .22);
    p.txt('서로의 손', .09, .82, .53, .085, size: .046);
  });
  b.add('ring-quiet-diptych', '#FAFAF7', (p) {
    p.txt('오늘도,\n내일도', .09, .085, .76, .23, size: .068);
    p.pic('petal_couple', .09, .38, .37, .39, frame: 'studioPhotoCorners');
    p.pic('petal_details', .51, .43, .40, .38, frame: 'studioPhotoCorners');
    p.caption('같은 편이 되어 주기로 한 날.', .09, .84, .8);
  });
  b.add('guests-group-record', '#F3F5F0', (p) {
    p.numeral('Together', .08, .065, .84, .16, size: .13);
    p.pic('lightbound_guests', .055, .26, .89, .52);
    p.mat('materialVellumBand', .08, .79, .8, .09);
    p.label('함께 웃은 얼굴을 한 장에', .15, .83, .74);
  });
  b.add('guest-note-and-photo', '#E1E8E1', (p) {
    p.mount('lightbound_guests', .09, .08, .68, .40);
    final card = p.mat('materialScallopNote', .39, .49, .51, .35);
    p.paperText(card, '먼 길 와 준\n소중한 사람들', .16, .31, .70, .55, size: .025);
    p.txt('고마워요', .09, .74, .30, .10, size: .046);
  });
  b.add('table-wide-still-life', '#EDF0EA', (p) {
    p.pic('petal_table', .04, .045, .92, .65);
    final plate = p.mat('atelierTitlePlate', .06, .72, .55, .18);
    p.paperText(plate, '오래 앉은 식탁', .14, .31, .76, .50, size: .025);
    p.label('DINNER / 09', .66, .79, .28);
  });
  b.add('dinner-menu-layout', '#FAFAF5', (p) {
    p.rule(.13, .10, .74);
    p.txt('오늘의 테이블', .15, .16, .72, .11, size: .055);
    p.label('FLOWERS / CAKE / TOAST', .15, .30, .7);
    p.pic('lightbound_cake', .15, .42, .44, .38, frame: 'studioArch');
    p.mat('materialLace', .63, .53, .25, .22);
    p.txt('한 번 더\n축하를 나누고', .65, .76, .26, .12, size: .027);
  });
  b.add('toasts-type-and-portrait', '#DCE6DE', (p) {
    p.numeral('Cheers', .08, .045, .85, .17, size: .145);
    p.pic('lightbound_guests', .09, .26, .62, .42, frame: 'atelierEnvelope');
    final ribbon = p.mat('atelierRibbonPlate', .29, .70, .61, .12);
    p.paperText(ribbon, '축하를 모아', .15, .28, .73, .55, size: .030);
  });
  b.add('kept-words', '#F5F6F1', (p) {
    p.label('WORDS WE KEPT', .09, .075, .8);
    final card = p.mat('atelierTitlePlate', .10, .19, .80, .38);
    p.paperText(card, '잘 살아.\n서로 많이 웃게 해 줘.', .14, .27, .73, .60, size: .034);
    p.pic('lightbound_cake', .60, .65, .29, .23, frame: 'studioInstant');
    p.caption('마음에 오래 남은 한마디.', .10, .78, .46);
  });
  b.add('evening-full-photo', '#3F514A', (p) {
    p.pic('lightbound_twilight', .04, .04, .92, .84);
  }, dark: true);
  b.add('evening-editorial', '#E7ECE5', (p) {
    p.label('AFTER THE CELEBRATION', .085, .065, .83);
    p.txt('저녁의\n마지막 장면', .085, .17, .79, .24, size: .068);
    p.pic('petal_evening', .37, .48, .54, .34, frame: 'studioPhotoCorners');
    p.rule(.085, .53, .19);
    p.txt('사진을 보며\n한 번 더 웃었다.', .085, .63, .24, .17, size: .027);
  });
  b.add('next-morning-letter', '#F8F8F3', (p) {
    p.label('AND EVERY DAY AFTER', .09, .07, .8);
    p.txt('다음 날에도', .09, .23, .83, .14, size: .075);
    p.txt(b.copy.note, .10, .44, .79, .19, size: .031);
    p.mat('waveSilkKnot', .08, .68, .28, .21);
    p.rule(.45, .755, .41);
    p.caption(b.copy.byline, .45, .80, .42);
  });
  b.add('last-portrait', '#D9E3DA', (p) {
    p.pic('petal_couple', .10, .075, .80, .65, frame: 'studioDoubleMat');
    p.txt('우리의 첫 장', .10, .785, .79, .09, size: .044, align: 'center');
  });
}

part of 'authored_collections.dart';

void _conceptCoast(_ConceptBook b) {
  b.add('coastal-opening-chart', '#EAF2EE', (p) {
    p.mat('materialContourMap', .05, .26, .86, .28);
    p.numeral('SEA', .10, .055, .79, .20, size: .19, color: '#326B70');
    p.txt('바다가 보이기\n시작했다', .09, .57, .80, .22, size: .071);
    p.mat('waveSeaGlass', .65, .72, .24, .18);
    p.label('COASTAL JOURNAL / 01', .09, .83, .53);
  });
  b.add('arrival-sea-window', '#C8E3E2', (p) {
    p.pic('travel_coast', .045, .05, .91, .71, frame: 'atelierCoastline');
    p.rule(.085, .815, .17);
    p.caption('짐을 내려놓고 곧장 바다로 갔다.', .31, .79, .6);
  });
  b.add('coast-path-atlas', '#F6F8F3', (p) {
    p.label('ON FOOT / 02', .08, .06, .8);
    p.pic('travel_coast', .08, .17, .55, .49, frame: 'studioDeckle');
    p.mat('materialTransitPunch', .69, .20, .22, .31);
    p.label('AM 09:10', .71, .31, .19);
    p.txt('해안선을 따라', .08, .72, .80, .11, size: .058);
    p.label('왼편에는 바다, 오른편에는 작은 집들.', .08, .855, .82);
  });
  b.add('path-two-vantages', '#236773', (p) {
    p.pic('travel_harbor', .07, .08, .40, .41, frame: 'studioPhotoCorners');
    p.pic('travel_street', .52, .30, .41, .49, frame: 'studioPostcard');
    p.numeral('02', .075, .55, .34, .22, color: '#C2E1DE');
    p.label('같은 길의 다른 풍경', .08, .845, .78, color: '#F3FAF5');
  }, dark: true);
  b.add('harbor-large-plate', '#E1ECE6', (p) {
    p.txt('항구에서', .075, .065, .85, .12, size: .070);
    p.pic('travel_harbor', .045, .255, .91, .54);
    p.mat('atelierPostalBand', .10, .79, .76, .07);
    p.label('BOATS / ROPES / MORNING LIGHT', .10, .867, .82);
  });
  b.add('harbor-chart-notebook', '#F5F7F2', (p) {
    p.mat('materialContourMap', .11, .08, .80, .51);
    p.mount('travel_harbor', .19, .13, .66, .41, frame: 'materialSlideMount');
    p.mat('waveSeaGlass', .065, .57, .29, .23);
    p.txt('배가 돌아오는\n시간을 기다리며', .43, .65, .48, .18, size: .044);
  });
  b.add('cafe-long-lunch', '#CFDDD8', (p) {
    p.pic('travel_cafe', .06, .065, .88, .70, frame: 'studioDoubleMat');
    p.txt('느린 점심', .085, .81, .68, .095, size: .048);
  });
  b.add('lunch-receipt-letter', '#F5F7F2', (p) {
    p.label('TABLE BY THE WINDOW', .085, .07, .82);
    p.txt('한 잔 더\n마시고 가기로 했다', .085, .19, .81, .22, size: .055);
    final ticket = p.mat('atelierBoardingStub', .09, .50, .80, .35);
    p.paperText(
      ticket,
      'LUNCH BREAK',
      .12,
      .22,
      .63,
      .13,
      size: .018,
      font: 'NotoSans',
    );
    p.paperText(
      ticket,
      '커피 두 잔, 창가 자리.\n오늘은 서두르지 않기로.',
      .12,
      .50,
      .69,
      .36,
      size: .024,
    );
    p.mat('materialShell', .74, .80, .16, .09);
  });
  b.add('sea-glass-specimen', '#C9E0DB', (p) {
    p.label('FOUND / NOT BOUGHT', .09, .07, .8);
    p.mat('materialSpecimenPocket', .10, .18, .80, .58);
    p.mat('waveSeaGlass', .22, .255, .55, .39);
    p.txt('파도가 다듬은 것', .13, .79, .76, .10, size: .048);
  });
  b.add('found-object-diary', '#F7F8F2', (p) {
    p.pic('travel_coast', .08, .08, .56, .37, frame: 'studioTorn');
    p.mat('materialShell', .69, .14, .22, .23);
    p.rule(.08, .535, .83);
    p.numeral('01', .08, .585, .21, .12, size: .09);
    p.txt('물빛 유리 조각', .33, .60, .58, .08, size: .032);
    p.numeral('02', .08, .715, .21, .12, size: .09);
    p.txt('바닷가에서 주운 조개', .33, .73, .58, .08, size: .030);
  });
  b.add('town-photo-vertical', '#EEF2EB', (p) {
    p.pic('travel_street', .04, .05, .63, .82);
    p.txt('동네를\n한 바퀴', .72, .14, .24, .23, size: .048);
    p.mat('atelierPostalBand', .53, .72, .4, .055);
    p.label('WALK / 06', .72, .82, .24);
  });
  b.add('market-postcard-stack', '#CAE1DA', (p) {
    p.label('NO FIXED ROUTE', .08, .065, .8);
    p.pic('journey_market', .10, .175, .66, .42, frame: 'studioPostcard');
    p.pic('travel_street', .48, .56, .40, .30, frame: 'materialSlideMount');
    p.txt('지도를 접고\n걷는 날', .09, .69, .33, .16, size: .040);
  });
  b.add('train-observation', '#204E5C', (p) {
    p.numeral('Window seat', .075, .05, .86, .16, size: .10, color: '#F2F7ED');
    p.pic('journey_train', .065, .27, .87, .49, frame: 'atelierNegative');
    p.label('다음 역까지 조금 더 바라본다.', .085, .83, .81, color: '#F2F7ED');
  }, dark: true);
  b.add('transit-note', '#EDF3EA', (p) {
    p.mat('materialContourMap', .06, .075, .85, .37);
    p.mat('atelierBoardingStub', .20, .23, .64, .29);
    p.label('ONE DAY / ONE COAST', .28, .335, .55);
    p.txt('기차 창밖', .09, .61, .8, .12, size: .075);
    p.txt('지나가는 풍경은 빨랐지만\n그날의 기분은 오래 남았다.', .10, .775, .77, .115, size: .031);
  });
  b.add('return-to-water', '#D8E9E4', (p) {
    p.pic('travel_coast', .04, .05, .92, .71);
    p.txt('다시 물가로', .075, .81, .85, .10, size: .052);
  });
  b.add('coastal-border-study', '#F4F7F0', (p) {
    p.numeral('Tide', .085, .06, .68, .16, size: .14);
    p.pic('travel_coast', .25, .27, .66, .50, frame: 'atelierCoastline');
    p.mat('waveSeaGlass', .065, .55, .24, .25);
    p.label('발자국이 지워질 때까지.', .32, .825, .60);
  });
  b.add('postcard-address', '#E6EFE8', (p) {
    p.pic('travel_harbor', .08, .09, .84, .49, frame: 'studioPostcard');
    p.mat('atelierPostalBand', .09, .59, .79, .08);
    p.txt('여기서 너에게', .09, .73, .77, .11, size: .059);
  });
  b.add('unsent-letter', '#F8F9F2', (p) {
    p.label('A POSTCARD, UNSENT', .10, .08, .8);
    final letter = p.mat('materialAirLetter', .085, .19, .83, .49);
    p.paperText(letter, b.copy.note, .14, .32, .73, .50, size: .024);
    p.rule(.11, .74, .76);
    p.caption(b.copy.byline, .11, .80, .76);
  });
  b.add('last-walk-pair', '#BCD9D9', (p) {
    p.pic('travel_street', .06, .06, .43, .63, frame: 'studioDeckle');
    p.pic('travel_harbor', .53, .21, .40, .49, frame: 'studioDeckle');
    p.txt('마지막 산책', .08, .795, .84, .105, size: .059);
  });
  b.add('footnote-of-a-walk', '#F7F8F2', (p) {
    p.label('THE LONG WAY BACK', .09, .07, .82);
    p.numeral('10', .66, .135, .24, .20, size: .17, color: '#95B4AD');
    p.txt('아는 길을\n한 번 더', .09, .18, .50, .23, size: .07);
    p.pic('travel_coast', .09, .50, .79, .31, frame: 'studioPhotoCorners');
    p.caption('조금 돌아서 숙소로 갔다.', .09, .84, .8);
  });
  b.add('travel-contact-inventory', '#F0F4EC', (p) {
    p.txt('여행의 목록', .08, .07, .81, .13, size: .066);
    p.pic('travel_coast', .08, .27, .40, .24, frame: 'materialSlideMount');
    p.pic('travel_cafe', .53, .27, .39, .24, frame: 'materialSlideMount');
    p.pic('journey_train', .08, .56, .40, .24, frame: 'materialSlideMount');
    p.pic('journey_market', .53, .56, .39, .24, frame: 'materialSlideMount');
    p.label('SEA / COFFEE / TRAIN / MARKET', .08, .855, .84);
  });
  b.add('route-record', '#D5E7DE', (p) {
    p.mat('materialContourMap', .04, .05, .90, .49);
    p.label('OUR COASTAL NOTES', .09, .55, .82);
    p.rule(.09, .63, .8);
    p.txt(
      '다시 걷고 싶은 길\n다시 앉고 싶은 자리\n다시 보고 싶은 바다',
      .10,
      .68,
      .80,
      .20,
      size: .038,
    );
  });
  b.add('home-with-sea-glass', '#F7F9F2', (p) {
    p.txt('돌아온 뒤에', .09, .10, .82, .13, size: .071);
    p.txt(b.copy.note, .10, .32, .78, .20, size: .032);
    p.mat('materialSpecimenPocket', .12, .58, .43, .30);
    p.mat('waveSeaGlass', .22, .615, .25, .20);
    p.label(b.copy.period, .63, .76, .28);
    p.label('KEPT FROM THE COAST', .63, .83, .29);
  });
  b.add('coast-last-view', '#D3E7E1', (p) {
    p.pic('travel_coast', .10, .085, .80, .65, frame: 'studioDeckle');
    p.txt('다음 바다에서 만나', .10, .80, .82, .10, size: .043, align: 'center');
  });
}

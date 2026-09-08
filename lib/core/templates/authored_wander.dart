part of 'authored_collections.dart';

List<Map<String, dynamic>> _wander(CollectionAspect aspect) {
  const ink = '#183F48',
      blue = '#E2F0F3',
      paper = '#FBFCFA',
      red = '#AD4855',
      blush = '#F1E2E5';
  const harbor = '${_editorial}travel_harbor.png',
      cafe = '${_editorial}travel_cafe.png';
  const station = '${_editorial}travel_street.png',
      road = '${_editorial}travel_coast.png';
  const beach = '${_editorial}travel_coast.png',
      sunset = '${_editorial}travel_coast.png';
  const book = '${_editorial}daily_book.png',
      fruit = '${_editorial}daily_fruit.png';
  final pages = <Map<String, dynamic>>[];
  _Sheet sheet([String bg = paper, String color = ink]) => _Sheet(
    'wander',
    aspect,
    pages.length,
    bg,
    ink: color,
    display: 'Raleway',
    displayWeight: 800,
  );
  var p = sheet();
  p.kicker('A JOURNAL OF PLACES & PEOPLE');
  p.title(
    p.wide ? _wanderTitle.replaceFirst(' 조각들', '\n조각들') : _wanderTitle,
    y: p.wide ? .18 : .12,
    w: p.wide ? .41 : .84,
    h: p.wide ? .25 : .12,
    size: .080,
  );
  p.photo(
    'cover_harbor',
    harbor,
    p.wide ? .52 : .08,
    p.wide ? .12 : .30,
    p.wide ? .40 : .84,
    p.wide ? .70 : .49,
    shape: 'studioTorn',
  );
  p.material(
    'tape',
    'studioWashiSage',
    p.wide ? .62 : .38,
    p.wide ? .095 : .277,
    .22,
    h: .045,
    rotation: -3,
  );
  p.copy(
    '길 위에서 모은 우리의 기록',
    .08,
    p.wide ? .60 : .835,
    p.wide ? .40 : .84,
    .06,
    size: .028,
  );
  pages.add(p.finish(_wanderTitle, 'cover'));

  p = sheet(blue);
  p.kicker('CHAPTER 01 / DEPARTURE');
  p.title('A little\nfurther.', y: .16, h: .25, size: .089);
  p.copy(
    '계획은 가볍게, 마음은 넉넉하게.\n익숙한 하루를 잠시 벗어나\n처음 보는 풍경 쪽으로 걸었다.',
    .08,
    .49,
    .62,
    .22,
    size: .032,
  );
  p.photo(
    'departure_stamp',
    station,
    .74,
    .68,
    .17,
    .18,
    shape: 'studioScallop',
    rotation: 3,
  );
  p.material('ticket', 'studioKeepsakeTicket', .08, .77, .33, rotation: -3);
  pages.add(p.finish('01 / 여행의 시작', 'departure-note'));

  p = sheet();
  p.photo('arrival', harbor, .05, .06, .90, .70);
  p.title('처음 만난 풍경', y: .81, h: .08, size: .038);
  pages.add(p.finish('오늘의 목적지', 'arrival-hero'));

  p = sheet();
  p.title('On the way', y: .08, size: .079);
  p.photo('window', road, .08, .25, .52, .46, shape: 'studioTorn');
  p.photo(
    'station',
    station,
    .66,
    .39,
    .26,
    .40,
    shape: 'studioScallop',
    rotation: 2,
  );
  p.copy('해안길을 천천히 걷던 시간.\n도착하기 전부터 여행이었다.', .08, .77, .53, .12, size: .028);
  pages.add(p.finish('출발과 도착 사이', 'journey-pair'));

  p = sheet();
  p.kicker('OUR TRAVEL NOTES');
  p.title('이번 여행의 작은 계획', y: .14, size: .038);
  const plans = [
    '느긋하게 아침 먹기',
    '지도 없이 한 시간 걷기',
    '마음에 든 가게에 들어가기',
    '사진보다 풍경을 먼저 보기',
  ];
  for (var i = 0; i < plans.length; i++) {
    p.text(
      'number_$i',
      '0${i + 1}',
      .08,
      .32 + i * .13,
      .07,
      .05,
      size: .024,
      color: red,
    );
    p.copy(plans[i], .19, .31 + i * .13, .43, .075, size: .029);
    p.box('rule_$i', .19, .40 + i * .13, .43, .0015, '#CEDDE0');
  }
  p.photo('plan_photo', harbor, .70, .31, .22, .35, shape: 'studioOval');
  pages.add(p.finish('가볍게 적어 둔 목록', 'itinerary'));

  p = sheet(ink, paper);
  p.kicker('CHAPTER 02 / WANDER');
  p.title('Turn left.\nGet a little lost.', y: .15, h: .24, size: .075);
  p.photo('roaming', harbor, .08, .45, .84, .40, shape: 'studioTicket');
  pages.add(p.finish('02 / 낯선 길 위에서', 'chapter'));

  p = sheet(blue);
  p.photo('street_1', station, .08, .10, .40, .65, shape: 'studioFilm');
  p.photo('street_2', cafe, .52, .22, .40, .53, shape: 'studioArch');
  p.copy('돌아가는 길에서 발견한 장면들.', .08, .82, .84, .07);
  pages.add(p.finish('골목의 표정', 'street-duet'));

  p = sheet();
  p.kicker('A WALK WITHOUT A MAP');
  p.title('길의 색을 모으다', y: .13, size: .044);
  for (var i = 0; i < 3; i++) {
    p.photo(
      'walk_$i',
      [road, harbor, cafe][i],
      .08 + i * .29,
      .31,
      .26,
      .40,
      shape: i == 1 ? 'studioScallop' : 'none',
    );
    p.copy(
      ['해안의 길', '푸른 물결', '작은 테이블'][i],
      .08 + i * .29,
      .77,
      .26,
      .07,
      size: .026,
    );
  }
  pages.add(p.finish('걷다가 멈춘 세 번의 순간', 'walking-sequence'));

  p = sheet();
  p.photo('sea', beach, .04, .04, .92, .82);
  pages.add(p.finish('한참을 바라본 풍경', 'full-photo'));

  p = sheet(blush);
  p.kicker('CHAPTER 03 / AT THE TABLE');
  p.title('A place\nto pause.', y: .15, w: .45, h: .24, size: .083);
  p.photo('coffee', cafe, .55, .17, .37, .60, shape: 'studioOval');
  p.copy('커피 한 잔만큼\n느려진 여행의 속도.', .08, .57, .41, .16, size: .032);
  pages.add(p.finish('03 / 동네의 맛', 'cafe-opener'));

  p = sheet();
  p.photo('table', cafe, .08, .08, .84, .55, shape: 'studioGallery');
  p.title('오래 앉아 있고 싶은 자리', y: .70, h: .09, size: .035);
  p.copy('기억해 둘 메뉴와 그날의 대화.', .08, .83, .84, .05, size: .027);
  pages.add(p.finish('창가에 앉아서', 'cafe-hero'));

  p = sheet();
  p.title('Taste notes', y: .08, size: .085);
  p.circle('coffee_detail', cafe, .08, .30, .26);
  p.circle('fruit_detail', fruit, .39, .30, .22);
  p.photo('table_view', harbor, .67, .29, .25, .33, shape: 'studioScallop');
  p.copy(
    '첫 모금의 향\n돌아가서도 생각날 맛\n함께 나누어 더 좋았던 시간',
    .08,
    .71,
    .84,
    .17,
    size: .032,
  );
  pages.add(p.finish('마음에 남은 맛', 'taste-notes'));

  p = sheet(blue);
  p.photo(
    'cafe_print',
    cafe,
    .08,
    .10,
    .49,
    .58,
    shape: 'studioTorn',
    rotation: -2,
  );
  p.material(
    'cafe_tape',
    'studioWashiRose',
    .20,
    .085,
    .22,
    h: .045,
    rotation: 3,
  );
  p.photo(
    'fruit_print',
    fruit,
    .64,
    .39,
    .27,
    .33,
    shape: 'studioScallop',
    rotation: 3,
  );
  p.copy('다음에 다시 오고 싶은 곳.', .08, .80, .84, .07, size: .033);
  pages.add(p.finish('주소 대신 기억해 둔 장면', 'food-collage'));

  p = sheet();
  p.kicker('CHAPTER 04 / COLLECTED');
  p.title('Pocket\nmemories.', y: .15, h: .23, size: .090);
  p.photo(
    'collected',
    station,
    .58,
    .41,
    .34,
    .40,
    shape: 'studioScallop',
    rotation: 2,
  );
  p.copy(
    '티켓 한 장, 짧은 메모,\n우연히 찍힌 사진.\n작은 조각에 남은 긴 이야기.',
    .08,
    .51,
    .44,
    .22,
    size: .028,
  );
  p.material('ticket', 'studioKeepsakeTicket', .08, .77, .32, rotation: -2);
  pages.add(p.finish('04 / 주머니 속 기록', 'keepsake-opener'));

  p = sheet();
  p.title('The contact sheet', y: .08, size: .068);
  for (var i = 0; i < 6; i++) {
    p.photo(
      'roll_$i',
      [station, road, harbor, cafe, fruit, book][i],
      .08 + (i % 3) * .29,
      .27 + (i ~/ 3) * .30,
      .26,
      .26,
    );
  }
  pages.add(p.finish('여행의 시간순으로', 'six-frame-roll'));

  p = sheet(blush);
  p.box('postcard_rule', .51, .15, .002, .68, '#D4BEC6');
  p.title('Wish you\nwere here.', y: .16, w: .39, h: .23, size: .073);
  p.copy(
    '바람이 기분 좋게 부는 곳.\n네가 좋아할 것 같아서\n한 장을 남겨 보낸다.\n다음에는 우리 함께 오자.',
    .08,
    .48,
    .38,
    .26,
    size: .027,
  );
  p.photo(
    'postcard_stamp',
    harbor,
    .69,
    .14,
    .22,
    .27,
    shape: 'studioScallop',
    rotation: 2,
  );
  p.copy('TO. 보고 싶은 사람에게', .57, .53, .35, .08, size: .024);
  p.box('address_1', .57, .69, .35, .0015, '#D4BEC6');
  p.box('address_2', .57, .79, .35, .0015, '#D4BEC6');
  pages.add(p.finish('먼 곳에서 보내는 엽서', 'postcard'));

  p = sheet();
  p.photo('souvenir_1', book, .08, .11, .39, .35);
  p.photo('souvenir_2', cafe, .53, .11, .39, .35, shape: 'studioRounded');
  p.photo('souvenir_3', station, .08, .51, .39, .35, shape: 'studioTorn');
  p.material('note', 'studioCotton', .52, .52, .41, h: .34, rotation: 1);
  p.copy('가방보다 마음에\n더 많이 담아 온 여행.', .58, .63, .29, .14, size: .029);
  pages.add(p.finish('물건보다 오래 남는 것', 'souvenir-board'));

  p = sheet(ink, paper);
  p.kicker('CHAPTER 05 / WAY BACK');
  p.title('One more\nevening.', y: .15, h: .23, size: .087);
  p.photo('last_light', sunset, .08, .45, .84, .40);
  pages.add(p.finish('05 / 돌아오는 길', 'evening-chapter'));

  p = sheet(blue);
  p.photo('quiet', beach, .08, .09, .84, .51);
  p.copy(
    '일정을 비워 둔 마지막 오후.\n더 많이 보기보다 조금 더 오래 머물렀다.',
    .08,
    .69,
    .84,
    .16,
    size: .032,
  );
  pages.add(p.finish('서두르지 않았던 하루', 'quiet-page'));

  p = sheet();
  p.title('We brought it home.', y: .09, size: .060);
  p.photo('homeward', road, .08, .26, .40, .41, shape: 'studioTorn');
  p.photo(
    'remember',
    harbor,
    .55,
    .39,
    .37,
    .41,
    shape: 'studioScallop',
    rotation: 2,
  );
  p.copy('사진 속 바람까지\n다시 꺼내 볼 수 있도록.', .08, .75, .40, .13, size: .029);
  pages.add(p.finish('조금 달라진 마음으로', 'return-pair'));

  p = sheet(blue);
  p.title('Until next time.', y: .12, size: .075, align: 'center');
  p.photo(
    'closing',
    harbor,
    .22,
    .32,
    .56,
    .37,
    shape: 'studioTorn',
    rotation: -1,
  );
  p.copy('다음 여행에서 이어 쓸 이야기.', .08, .80, .84, .06, size: .030, align: 'center');
  pages.add(p.finish('TO BE CONTINUED', 'closing'));
  return pages;
}

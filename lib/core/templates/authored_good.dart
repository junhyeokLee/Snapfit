part of 'authored_collections.dart';

List<Map<String, dynamic>> _good(CollectionAspect aspect) {
  const ink = '#263B33',
      lime = '#ECF3A2',
      pink = '#F7DDE6',
      paper = '#FDFEFA',
      blue = '#E1EEF5';
  const picnic = '${_editorial}daily_picnic.png',
      desk = '${_editorial}daily_desk.png';
  const coffee = '${_editorial}travel_cafe.png',
      fruit = '${_editorial}daily_fruit.png';
  const book = '${_editorial}daily_book.png',
      road = '${_editorial}travel_street.png';
  const beach = '${_editorial}daily_friends.png',
      evening = '${_editorial}travel_coast.png';
  final pages = <Map<String, dynamic>>[];
  _Sheet sheet([String bg = paper, String color = ink]) => _Sheet(
    'good',
    aspect,
    pages.length,
    bg,
    ink: color,
    display: 'Poppins',
    displayWeight: 700,
  );
  var p = sheet(lime);
  p.kicker('THE EVERYDAY JOURNAL');
  p.title(
    p.wide ? _goodTitle.replaceFirst(' ', '\n') : _goodTitle,
    y: p.wide ? .19 : .12,
    w: p.wide ? .41 : .84,
    h: p.wide ? .27 : .13,
    size: .085,
  );
  p.photo(
    'cover_picnic',
    picnic,
    p.wide ? .54 : .12,
    p.wide ? .15 : .31,
    p.wide ? .37 : .76,
    p.wide ? .64 : .46,
    shape: 'studioSticker',
    rotation: -2,
  );
  p.copy(
    '좋아하는 순간을 모으면',
    .08,
    p.wide ? .62 : .835,
    p.wide ? .41 : .84,
    .06,
    size: .029,
  );
  p.material(
    'citrus',
    'studioCitrusPrint',
    p.wide ? .40 : .79,
    .68,
    .12,
    rotation: 10,
  );
  pages.add(p.finish(_goodTitle, 'cover'));

  p = sheet();
  p.kicker('CHAPTER 01 / MORNING CLUB');
  p.title('A good\nplace to start.', y: .15, h: .25, size: .077);
  p.photo('morning_inset', desk, .61, .45, .30, .36, shape: 'studioRounded');
  p.copy(
    '창문을 열고,\n물을 한 잔 마시고,\n오늘의 작은 기대를 적는다.',
    .08,
    .53,
    .47,
    .21,
    size: .031,
  );
  p.material('small_citrus', 'studioCitrusPrint', .09, .79, .09, rotation: -10);
  pages.add(p.finish('01 / 좋은 아침', 'morning-note'));

  p = sheet(blue);
  p.photo('morning', desk, .08, .09, .84, .59);
  p.title('별일 없어도, 좋은 하루.', y: .75, h: .10, size: .037);
  pages.add(p.finish('아침의 빛을 담아서', 'morning-hero'));

  p = sheet();
  p.title('Morning rituals', y: .08, size: .071);
  p.photo('coffee', coffee, .08, .26, .40, .42, shape: 'studioArch');
  p.photo('flowers', desk, .55, .40, .37, .39, shape: 'studioWave');
  p.copy('천천히 마시는 한 잔', .08, .75, .40, .08, size: .027);
  p.copy('창가의 작은 변화', .55, .83, .38, .05, size: .025);
  pages.add(p.finish('반복하고 싶은 습관', 'ritual-duet'));

  p = sheet(pink);
  p.kicker('TODAY, IN FOUR FRAMES');
  p.title('아침부터 점심까지', y: .13, size: .041);
  for (var i = 0; i < 4; i++) {
    p.photo(
      'morning_$i',
      [desk, coffee, fruit, picnic][i],
      .08 + (i % 2) * .44,
      .29 + (i ~/ 2) * .28,
      .40,
      .24,
      shape: i == 2 ? 'studioRounded' : 'none',
    );
  }
  p.copy('평범한 순간도 남기고 나면 특별해진다.', .08, .85, .84, .05, size: .025);
  pages.add(p.finish('오늘의 첫 네 장', 'morning-grid'));

  p = sheet(lime);
  p.kicker('CHAPTER 02 / FAVOURITES');
  p.title('Small things.\nBig feelings.', y: .15, h: .25, size: .074);
  p.photo(
    'favourite',
    picnic,
    .19,
    .47,
    .62,
    .35,
    shape: 'studioSticker',
    rotation: 2,
  );
  pages.add(p.finish('02 / 취향을 모아서', 'favourites-opener'));

  p = sheet();
  p.circle('colour', fruit, .08, .16, .36);
  p.photo('texture', desk, .56, .28, .36, .47, shape: 'studioArch');
  p.copy('내가 좋아하는 색과\n손이 자주 가는 물건들.', .08, .71, .41, .16, size: .032);
  pages.add(p.finish('설명하지 않아도 좋은 것들', 'favourites-pair'));

  p = sheet();
  p.title('The happy list', y: .09, size: .074);
  const favourites = [
    '요즘 자주 듣는 노래',
    '또 가고 싶은 작은 가게',
    '다시 펼쳐 읽는 문장',
    '생각만 해도 좋은 사람',
  ];
  for (var i = 0; i < favourites.length; i++) {
    p.text(
      'index_$i',
      '0${i + 1}',
      .08,
      .31 + i * .135,
      .07,
      .05,
      size: .024,
      color: ink,
    );
    p.copy(favourites[i], .18, .30 + i * .135, .44, .08, size: .028);
    p.box('underline_$i', .18, .40 + i * .135, .44, .0015, '#DCE4D3');
  }
  p.photo(
    'list_photo',
    book,
    .70,
    .31,
    .22,
    .38,
    shape: 'studioSticker',
    rotation: 3,
  );
  p.material('citrus', 'studioCitrusPrint', .73, .76, .12, rotation: 12);
  pages.add(p.finish('이번 달의 취향 목록', 'favourites-list'));

  p = sheet(ink, paper);
  p.title('On repeat.', y: .08, size: .091, color: lime);
  p.photo('coffee', coffee, .08, .28, .26, .43, shape: 'studioArch');
  p.photo('fruit', fruit, .37, .28, .26, .43, shape: 'studioOval');
  p.photo('book', book, .66, .28, .26, .43, shape: 'studioRounded');
  p.copy('자꾸 찾게 되는 나만의 작은 즐거움.', .08, .81, .84, .07, size: .030);
  pages.add(p.finish('나의 일상에 오래 남은 것', 'three-favourites'));

  p = sheet(blue);
  p.kicker('CHAPTER 03 / OUTSIDE');
  p.title('Out of office,\ninto the sun.', y: .15, h: .25, size: .069);
  p.photo('outside', picnic, .08, .47, .84, .38);
  pages.add(p.finish('03 / 밖에서 보낸 시간', 'outside-opener'));

  p = sheet();
  p.photo('picnic', picnic, .05, .06, .90, .70);
  p.title('느긋한 오후의 약속', y: .82, h: .07, size: .036);
  pages.add(p.finish('준비한 건 돗자리 하나', 'picnic-hero'));

  p = sheet();
  p.photo('walk', road, .08, .10, .49, .53, shape: 'studioInstant');
  p.photo(
    'rest',
    beach,
    .64,
    .29,
    .28,
    .44,
    shape: 'studioSticker',
    rotation: 2,
  );
  p.copy(
    '멀리 가지 않아도 괜찮아.\n익숙한 길에서 새로운 장면을 찾았다.',
    .08,
    .78,
    .84,
    .11,
    size: .029,
  );
  pages.add(p.finish('동네 한 바퀴', 'walk-pair'));

  p = sheet(pink);
  p.title('Little weekend', y: .09, size: .072);
  p.photo('weekend_1', picnic, .08, .28, .40, .25);
  p.photo('weekend_2', road, .52, .28, .40, .25, shape: 'studioDiagonal');
  p.photo('weekend_3', beach, .08, .59, .40, .25, shape: 'studioRounded');
  p.photo('weekend_4', evening, .52, .59, .40, .25);
  pages.add(p.finish('함께 보낸 주말의 조각', 'weekend-grid'));

  p = sheet();
  p.kicker('CHAPTER 04 / LITTLE RECORDS');
  p.title('Keep the\nordinary.', y: .16, h: .25, size: .084);
  p.copy(
    '기억에 남는 날만 기록하지 않기.\n사소해서 지나쳤던 순간에도\n우리다운 이야기가 있으니까.',
    .08,
    .51,
    .60,
    .21,
    size: .031,
  );
  p.circle('ordinary', desk, .74, .70, .15);
  pages.add(p.finish('04 / 작은 기록들', 'record-opener'));

  p = sheet(lime);
  p.title('Six good moments', y: .10, size: .062);
  for (var i = 0; i < 6; i++) {
    p.photo(
      'moment_$i',
      [desk, coffee, fruit, picnic, road, book][i],
      .08 + (i % 3) * .29,
      .29 + (i ~/ 3) * .29,
      .26,
      .25,
      shape: i == 4 ? 'studioRounded' : 'none',
    );
  }
  pages.add(p.finish('이번 달, 마음에 남은 여섯 장', 'six-frame-roll'));

  p = sheet();
  p.title('오늘의 작은 발견', y: .09, size: .043);
  p.material(
    'note_paper',
    'studioCotton',
    .045,
    .29,
    .56,
    h: .49,
    rotation: -1,
  );
  p.copy(
    '생각보다 잘해낸 일 하나.\n오늘 새롭게 알게 된 것 하나.\n잊기 전에 전하고 싶은 말 하나.\n내일 다시 해보고 싶은 일 하나.',
    .09,
    .38,
    .46,
    .30,
    size: .029,
  );
  p.photo(
    'note_photo',
    desk,
    .67,
    .32,
    .25,
    .36,
    shape: 'studioScallop',
    rotation: 2,
  );
  p.material(
    'note_tape',
    'studioWashiRose',
    .66,
    .30,
    .23,
    h: .042,
    rotation: -3,
  );
  pages.add(p.finish('나에게 남기는 짧은 메모', 'daily-journal'));

  p = sheet(blue);
  p.photo(
    'cut_1',
    picnic,
    .08,
    .10,
    .48,
    .50,
    shape: 'studioTorn',
    rotation: -2,
  );
  p.photo(
    'cut_2',
    desk,
    .64,
    .26,
    .28,
    .35,
    shape: 'studioScallop',
    rotation: 3,
  );
  p.material('citrus', 'studioCitrusPrint', .47, .53, .14, rotation: -7);
  p.copy('사진 두 장과 작은 메모.\n이 정도면 충분한 오늘의 기록.', .08, .75, .84, .12, size: .031);
  pages.add(p.finish('주머니 속 작은 수집', 'scrapbook'));

  p = sheet(pink);
  p.kicker('CHAPTER 05 / MORE OF THIS');
  p.title('Make room\nfor more.', y: .15, h: .25, size: .081);
  p.photo('more', picnic, .24, .46, .52, .38, shape: 'studioOval');
  pages.add(p.finish('05 / 다음의 우리', 'next-chapter'));

  p = sheet();
  p.title('함께여서 더 좋았던 순간', y: .09, size: .038);
  p.photo('together_1', beach, .08, .28, .40, .43, shape: 'studioRounded');
  p.photo('together_2', evening, .52, .28, .40, .43);
  p.copy('같이 웃었던 이유는 잊어도,\n그때의 기분은 오래 남는다.', .08, .77, .84, .11, size: .032);
  pages.add(p.finish('나의 좋은 사람들에게', 'together'));

  p = sheet(ink, paper);
  p.title('Next month,\nsame us.', y: .12, h: .23, size: .076, color: lime);
  p.copy(
    '꼭 해보고 싶은 일\n다시 만나고 싶은 사람\n계속 지켜가고 싶은 작은 습관',
    .08,
    .48,
    .57,
    .25,
    size: .032,
  );
  p.photo(
    'next_month',
    desk,
    .70,
    .49,
    .22,
    .30,
    shape: 'studioSticker',
    rotation: 2,
  );
  pages.add(p.finish('다음 달의 나에게', 'next-month'));

  p = sheet(lime);
  p.title('More of this.', y: .13, size: .087, align: 'center');
  p.photo(
    'closing',
    picnic,
    .22,
    .34,
    .56,
    .37,
    shape: 'studioSticker',
    rotation: -1,
  );
  p.copy('계속 모아갈, 우리의 좋은 날들.', .08, .81, .84, .06, size: .029, align: 'center');
  pages.add(p.finish('LITTLE JOYS, BIG DAYS', 'closing'));
  return pages;
}

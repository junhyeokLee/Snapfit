part of 'authored_collections.dart';

List<Map<String, dynamic>> _petal(CollectionAspect aspect) {
  const plum = '#482B3D', rose = '#EDDCE3', paper = '#FEFCFD', sage = '#E7EDE7';
  const couple = '${_editorial}petal_couple.png',
      details = '${_editorial}petal_details.png';
  const ribbon = '${_editorial}petal_veil.png',
      bouquet = '${_editorial}petal_bouquet.png';
  const keepsake = '${_editorial}petal_table.png',
      evening = '${_editorial}petal_evening.png';
  final pages = <Map<String, dynamic>>[];
  _Sheet sheet([String bg = paper, String ink = plum]) =>
      _Sheet('petal', aspect, pages.length, bg, ink: ink);
  var p = sheet();
  p.kicker('THE WEDDING JOURNAL');
  p.title(
    p.wide ? _petalTitle.replaceFirst(' ', '\n') : _petalTitle,
    y: p.wide ? .20 : .105,
    w: p.wide ? .42 : .84,
    h: p.wide ? .27 : .12,
    size: .087,
  );
  p.photo(
    'cover_portrait',
    couple,
    p.wide ? .54 : .10,
    p.wide ? .13 : .27,
    p.wide ? .37 : .80,
    p.wide ? .70 : .52,
  );
  p.copy(
    '우리의 가장 다정한 날',
    .08,
    p.wide ? .60 : .825,
    p.wide ? .42 : .76,
    .06,
    size: .029,
  );
  p.material(
    'flower',
    'studioPressedCosmos',
    p.wide ? .38 : .79,
    p.wide ? .65 : .69,
    .12,
    rotation: 9,
  );
  pages.add(p.finish(_petalTitle, 'cover'));

  // 01-04: a dedication faces the first portrait; details lead into preparations.
  p = sheet();
  p.kicker('CHAPTER 01 / PRELUDE');
  p.title('Before\nthe bloom.', y: .17, h: .25, size: .092);
  p.copy(
    '서로를 만나기 전의 떨림,\n이름을 부르던 작은 목소리.\n그날의 시작부터 천천히 담았다.',
    .08,
    .51,
    .56,
    .21,
  );
  p.circle('ring_inset', details, .73, .65, .18);
  p.material(
    'ribbon',
    'studioSageRibbon',
    .08,
    .70,
    p.wide ? .11 : .17,
    rotation: -5,
  );
  pages.add(p.finish('01 / 설레는 준비', 'dedication'));

  p = sheet();
  p.photo('first_portrait', couple, .07, .07, .86, .73);
  p.copy('오늘의 우리를, 오래 기억하기.', .08, .84, .84, .06);
  pages.add(p.finish('처음 마주한 순간', 'hero'));

  p = sheet(rose);
  p.kicker('THE LITTLE DETAILS');
  p.title('작은 것부터, 우리답게.', y: .14, h: .09, size: .038);
  p.photo('rings', details, .08, .30, .51, .45, shape: 'studioOval');
  p.photo('ribbon', ribbon, .65, .35, .27, .40, shape: 'studioDiagonal');
  p.copy('01  오래 남을 약속', .08, .80, .50, .06, size: .025);
  p.copy('02  부드러운 결', .63, .80, .30, .06, size: .025);
  pages.add(p.finish('반지와 리본', 'details'));

  p = sheet();
  p.title('The making of a day', y: .08, size: .067);
  p.photo('prepare_1', details, .08, .25, .40, .28);
  p.photo('prepare_2', bouquet, .52, .25, .40, .28, shape: 'studioRounded');
  p.photo('prepare_3', ribbon, .08, .57, .40, .28);
  p.photo('prepare_4', couple, .52, .57, .40, .28);
  pages.add(p.finish('준비의 조각들', 'contact-sheet'));

  // 05-08: the vow has a quiet opening, a paired portrait and a written record.
  p = sheet(plum, paper);
  p.kicker('CHAPTER 02 / OUR VOWS');
  p.title('A small promise,\na whole life.', y: .15, h: .23, size: .087);
  p.photo('promise', details, .12, .45, .76, .37, shape: 'studioOval');
  pages.add(p.finish('02 / 우리의 약속', 'chapter'));

  p = sheet(rose);
  p.photo('us', couple, .08, .08, .48, .66, shape: 'studioArch');
  p.photo('our_rings', details, .63, .18, .29, .45, shape: 'studioCapsule');
  p.copy('좋은 날에도, 평범한 날에도\n가장 가까운 편이 되어주기로.', .08, .80, .84, .09, size: .032);
  pages.add(p.finish('두 사람이 나눈 마음', 'duet'));

  p = sheet();
  p.title('오늘의 약속', y: .10, size: .052);
  p.material(
    'letter_stock',
    'studioCotton',
    .05,
    .30,
    .57,
    h: .51,
    rotation: -1,
  );
  p.copy(
    '급하게 답하기보다 먼저 듣기.\n작은 고마움도 말로 전하기.\n익숙한 하루를 소중히 대하기.\n서로의 새로운 꿈을 응원하기.',
    .09,
    .38,
    .47,
    .31,
    size: .031,
  );
  p.photo('vow_photo', couple, .67, .29, .25, .43, shape: 'studioOval');
  p.material('pressed_flower', 'studioPressedCosmos', .73, .68, .12);
  pages.add(p.finish('우리의 말로 적은 서약', 'journal'));

  p = sheet();
  p.kicker('THREE THINGS TO REMEMBER');
  p.title('그날의 빛, 향기, 온도.', y: .14, size: .038);
  for (var i = 0; i < 3; i++) {
    p.photo(
      'detail_$i',
      [details, bouquet, ribbon][i],
      .08 + .29 * i,
      .31,
      .26,
      .41,
      shape: i == 1 ? 'studioArch' : 'none',
    );
    p.copy(
      ['작은 약속', '꽃의 향기', '부드러운 빛'][i],
      .08 + .29 * i,
      .78,
      .26,
      .06,
      size: .026,
    );
  }
  pages.add(p.finish('기억의 세 가지 조각', 'sequence'));

  p = sheet(sage);
  p.photo('company', couple, .08, .09, .50, .73);
  p.title('In good\ncompany.', x: .64, y: .15, w: .28, h: .26, size: .066);
  p.copy('함께 웃어준\n마음들 덕분에\n더 따뜻했던 날.', .64, .52, .28, .22, size: .031);
  pages.add(p.finish('03 / 함께한 마음', 'chapter-portrait'));

  p = sheet();
  p.title('The people we love', y: .08, size: .069);
  p.photo('together', couple, .08, .25, .84, .33);
  p.photo('flowers', bouquet, .08, .62, .40, .23);
  p.photo('little_gifts', keepsake, .52, .62, .40, .23);
  pages.add(p.finish('우리 곁에 있어준 사람들', 'gathering'));

  p = sheet(rose);
  p.kicker('WITH GRATITUDE');
  p.title('고마운 마음을\n한 장에 담아.', y: .17, h: .18, size: .051);
  p.copy(
    '멀리서 와준 발걸음,\n말없이 건네준 응원,\n사진 밖에서 애써준 손길까지.\n우리의 하루를 함께 만들어줘서 고마워요.',
    .08,
    .43,
    .83,
    .26,
    size: .030,
  );
  p.circle('thanks', bouquet, .74, .72, .14);
  pages.add(p.finish('소중한 사람들에게', 'thank-you'));

  p = sheet();
  p.photo('memory', evening, .04, .04, .92, .82, shape: 'studioGallery');
  pages.add(p.finish('말없이도 남는 한 장', 'full-photo'));

  p = sheet(sage);
  p.kicker('CHAPTER 04 / AFTERGLOW');
  p.photo('afternoon', evening, .08, .17, .84, .51);
  p.title('Stay a little longer.', y: .75, h: .12, size: .073);
  pages.add(p.finish('04 / 오후의 여운', 'afternoon'));

  p = sheet();
  p.photo('ribbon_light', ribbon, .08, .10, .39, .53, shape: 'studioArch');
  p.photo('keepsakes', details, .53, .28, .39, .53, shape: 'studioDeckle');
  p.copy('햇빛이 머물던 자리', .08, .69, .38, .07, size: .029);
  p.copy('아직 남아 있는 온기', .53, .84, .40, .05, size: .026);
  pages.add(p.finish('조용해진 오후', 'staggered-pair'));

  p = sheet();
  p.title('Pieces of the day', y: .075, size: .076);
  p.material(
    'collage_paper',
    'studioCotton',
    .08,
    .27,
    .50,
    h: .52,
    rotation: -2,
  );
  p.photo(
    'print',
    couple,
    .105,
    .29,
    .45,
    .45,
    shape: 'studioTorn',
    rotation: -2,
  );
  p.photo(
    'small_print',
    details,
    .63,
    .43,
    .25,
    .30,
    shape: 'studioScallop',
    rotation: 3,
  );
  p.material('flower', 'studioPressedCosmos', .53, .61, .14, rotation: -9);
  p.copy('그날의 작은 조각들을 모아.', .08, .84, .84, .055, size: .028);
  pages.add(p.finish('사진과 꽃 한 송이', 'keepsake-collage'));

  p = sheet(rose);
  p.kicker('THE CONTACT SHEET');
  p.title('한 번 더, 그날로.', y: .13, size: .041);
  for (var i = 0; i < 6; i++) {
    p.photo(
      'roll_$i',
      [couple, details, bouquet, ribbon, keepsake, evening][i],
      .08 + (i % 3) * .29,
      .28 + (i ~/ 3) * .29,
      .26,
      .25,
    );
  }
  p.copy('마음에 남은 여섯 장', .08, .85, .84, .05, size: .026);
  pages.add(p.finish('시간순으로 모은 기억', 'six-frame-roll'));

  p = sheet();
  p.kicker('CHAPTER 05 / LETTERS');
  p.title('A letter\nfor our future.', y: .15, h: .24, size: .084);
  p.copy('지금의 마음을 잊지 않도록,\n미래의 우리에게 남기는 기록.', .08, .48, .54, .16, size: .032);
  p.photo('future', details, .67, .45, .25, .33, shape: 'studioOval');
  p.material('postage', 'studioBotanicalStamp', .09, .73, .13, rotation: -3);
  pages.add(p.finish('05 / 오래 남길 편지', 'letter-opener'));

  p = sheet();
  p.title('일 년 뒤에도 기억할 것', y: .08, size: .039);
  p.copy(
    '서로를 바라보며 웃었던 얼굴.\n긴장이 풀린 뒤에 잡았던 손.\n집으로 돌아오며 나눴던 이야기.\n그리고 오늘, 함께 시작했다는 사실.',
    .08,
    .25,
    .84,
    .26,
    size: .032,
  );
  p.photo('letter_photo', couple, .08, .57, .84, .28);
  pages.add(p.finish('미래의 우리에게', 'letter'));

  p = sheet(plum, paper);
  p.photo('last_portrait', evening, .08, .09, .52, .64);
  p.photo('last_detail', details, .66, .20, .26, .27, shape: 'studioOval');
  p.photo('last_flower', bouquet, .66, .53, .26, .28);
  p.copy('다시 펼칠 때마다, 같은 마음으로.', .08, .83, .84, .06, size: .032);
  pages.add(p.finish('이 마음을 간직하며', 'last-mosaic'));

  p = sheet(rose);
  p.title('And so it blooms.', y: .11, size: .078, align: 'center');
  p.photo('closing', evening, .26, .30, .48, .40, shape: 'studioOval');
  p.copy('우리의 이야기는 계속된다.', .08, .79, .84, .06, size: .031, align: 'center');
  pages.add(p.finish('OUR STORY, STILL GROWING', 'closing'));
  return pages;
}

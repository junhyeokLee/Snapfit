part of 'authored_collections.dart';

const gardenLettersChapters = [
  '초대장을 펼치며',
  '꽃을 고르던 아침',
  '나란히 걷는 길',
  '서로에게 쓴 편지',
  '꽃다발의 작은 조각',
  '함께 앉은 식탁',
  '필름에 남은 표정',
  '우리의 약속',
  '축하를 건네준 얼굴',
  '저녁 정원',
  '간직하고 싶은 것',
  '다음 계절에도',
];

/// A separate 24-page design study; publication follows visual review.
Map<String, dynamic> buildGardenLetters(CollectionAspect aspect) {
  const ink = '#344B41';
  const rose = '#ECDADB';
  const paper = '#F9FAF7';
  const gold = '#AA9467';
  final pages = <Map<String, dynamic>>[];
  _Sheet sheet(int index, [String background = paper]) =>
      _Sheet('garden-letters', aspect, index, background,
          ink: background == ink ? '#F0E9D5' : ink);

  void photo(
    _Sheet s,
    String name,
    double x,
    double y,
    double w,
    double h, {
    String shape = 'none',
  }) => s.photo(
    'photo_${s.layers.length}',
    '$_editorial$name.png',
    x,
    y,
    w,
    h,
    shape: shape,
  );
  void mat(_Sheet s, String name, double x, double y, double w, double h) {
    s.box('mat_shadow_${s.layers.length}', x + .008, y + .009, w, h, '#CFD4CB');
    s.box('mat_${s.layers.length}', x, y, w, h, '#FFFFFF');
    s.box(
      'inset_${s.layers.length}',
      x + .016,
      y + .016,
      w - .032,
      h - .032,
      '#DFE5D8',
    );
    photo(s, name, x + .025, y + .025, w - .05, h - .05);
  }

  void rule(_Sheet s, double x, double y, double w, {String color = gold}) =>
      s.box('rule_${s.layers.length}', x, y, w, .0015, color);
  void note(
    _Sheet s,
    String title,
    String body,
    double x,
    double y, {
    double w = .8,
    String color = ink,
  }) {
    final compact = y >= .65;
    s.text(
      'heading_${s.layers.length}',
      title,
      x,
      y,
      w,
      compact ? .07 : .12,
      size: compact ? .04 : .056,
      font: 'Eulyoo',
      color: color,
    );
    s.text(
      'note_${s.layers.length}',
      body,
      x,
      y + (compact ? .075 : .13),
      w,
      compact ? .09 : .13,
      size: compact ? .020 : .023,
      color: color,
      lineHeight: 1.5,
    );
  }

  final cover = sheet(0);
  photo(cover, 'petal_couple', 0, 0, 1, 1);
  cover.text(
    'cover_title',
    '정원의 편지',
    .075,
    .08,
    .85,
    .16,
    size: .096,
    font: 'Eulyoo',
    color: '#FFFFFF',
  );
  cover.text(
    'cover_note',
    '우리가 함께 시작한 날',
    .08,
    .26,
    .78,
    .06,
    size: .028,
    color: '#FFFFFF',
  );
  cover.text(
    'cover_date',
    '2026. 05. 24',
    .08,
    .87,
    .65,
    .06,
    size: .024,
    color: '#FFFFFF',
  );
  rule(cover, .08, .855, .28, color: '#FFFFFF');
  pages.add({...cover.json, 'name': '정원의 편지', 'role': 'cover'});

  for (var spread = 0; spread < 12; spread++) {
    final left = sheet(spread * 2 + 1, spread == 7 ? ink : paper);
    final right = sheet(
      spread * 2 + 2,
      [1, 5, 8].contains(spread) ? rose : paper,
    );
    switch (spread) {
      case 0:
        left.material('rag', 'studioCottonRag', .035, .03, .92, h: .85);
        rule(left, .17, .18, .66);
        note(
          left,
          '당신을 초대합니다',
          '가장 가까운 사람들과\n우리의 시작을 나누던 날.',
          .14,
          .26,
          w: .73,
        );
        left.text(
          'date',
          '05 / 24',
          .16,
          .63,
          .65,
          .12,
          size: .08,
          font: 'Cormorant Garamond',
          color: ink,
        );
        left.material('olive', 'studioOlivePress', .63, .56, .26);
        mat(right, 'petal_veil', .09, .07, .82, .75);
        right.copy('조금 일찍 도착한 아침', .12, .85, .78, .05, size: .023);
      case 1:
        photo(left, 'petal_bouquet', .06, .07, .59, .72);
        left.material('olive', 'studioOlivePress', .65, .22, .29);
        left.text(
          'specimen',
          'FLOWER\nSTUDY',
          .68,
          .65,
          .27,
          .16,
          size: .033,
          font: 'Cormorant Garamond',
          color: ink,
        );
        photo(right, 'petal_details', .16, .09, .68, .52, shape: 'studioOval');
        note(right, '꽃을 고르는 마음', '작은 꽃 한 송이에도\n오늘의 취향을 담았다.', .12, .67, w: .78);
      case 2:
        photo(left, 'lightbound_ceremony', 0, 0, 1, .88);
        right.box('binding', .06, .06, .035, .78, ink);
        mat(right, 'petal_couple', .15, .09, .70, .66);
        right.copy('같은 쪽을 바라보며, 한 걸음씩.', .16, .80, .73, .08);
      case 3:
        left.box('letter', .09, .08, .83, .79, '#F0F1EA');
        left.box('fold', .5, .08, .002, .79, '#D2D9CC');
        note(left, '너에게', '평범한 하루에도\n서로의 편이 되어 주기로 했다.', .16, .18, w: .69);
        for (var i = 0; i < 6; i++)
          rule(left, .17, .53 + i * .047, .64, color: '#D0D6C9');
        right.material(
          'envelope',
          'studioGlassineEnvelope',
          .10,
          .29,
          .81,
          h: .56,
        );
        mat(right, 'petal_details', .17, .09, .66, .57);
        right.copy('짧은 편지 한 장을 함께 넣어 둔다.', .12, .85, .80, .05, size: .023);
      case 4:
        for (var i = 0; i < 3; i++) {
          photo(
            left,
            ['petal_bouquet', 'petal_details', 'petal_table'][i],
            .09 + i * .285,
            .17 + (i == 1 ? .09 : 0),
            .255,
            .49,
          );
        }
        note(left, '오늘의 작은 조각', '꽃잎과 리본, 손끝에 남은 기억.', .10, .75);
        photo(right, 'petal_bouquet', .07, .06, .86, .83, shape: 'studioTorn');
      case 5:
        photo(left, 'petal_table', 0, 0, 1, .89);
        right.box('menu', .11, .09, .78, .76, paper);
        note(
          right,
          '오래 앉은 식탁',
          '익숙한 목소리가 모이면\n어느새 집 같은 자리가 된다.',
          .18,
          .18,
          w: .65,
        );
        rule(right, .18, .48, .62);
        mat(right, 'lightbound_cake', .24, .54, .51, .24);
      case 6:
        left.box('film', .06, .07, .87, .77, '#27352F');
        photo(left, 'lightbound_guests', .1, .12, .79, .29);
        photo(left, 'petal_couple', .1, .48, .79, .29);
        for (var i = 0; i < 12; i++) {
          left.box(
            'perforation_top_$i',
            .1 + i * .065,
            .082,
            .025,
            .014,
            paper,
          );
          left.box(
            'perforation_bottom_$i',
            .1 + i * .065,
            .81,
            .025,
            .014,
            paper,
          );
        }
        mat(right, 'lightbound_guests', .11, .11, .78, .62);
        right.copy('포즈를 풀고 난 뒤의 표정이 더 좋았다.', .12, .79, .76, .09);
      case 7:
        left.text(
          'promise',
          '우리의\n약속',
          .12,
          .16,
          .74,
          .4,
          size: .13,
          font: 'Eulyoo',
          color: '#E2D8B7',
        );
        rule(left, .12, .64, .67);
        left.copy('오래도록, 다정하게.', .12, .72, .77, .08, color: '#F5F6EC');
        right.box('blush_mat', .08, .06, .84, .83, rose);
        photo(right, 'petal_details', .15, .12, .70, .66);
        right.text(
          'signature',
          '함께 쓴 첫 문장',
          .16,
          .81,
          .70,
          .07,
          size: .027,
          font: 'Eulyoo',
          color: ink,
        );
      case 8:
        note(left, '함께여서 더 좋은 날', '축하를 건네준 얼굴들을\n한 사람씩 기억해 본다.', .1, .10);
        mat(left, 'lightbound_guests', .08, .44, .84, .40);
        mat(right, 'petal_table', .09, .09, .56, .49);
        mat(right, 'lightbound_cake', .39, .43, .51, .40);
        right.material('ribbon', 'studioRoseSilk', .10, .65, .24);
      case 9:
        photo(left, 'petal_evening', 0, 0, 1, .89);
        photo(right, 'lightbound_twilight', .07, .07, .86, .60);
        note(right, '저녁까지 남은 마음', '돌아가는 길이 아쉬워\n조금 더 정원을 걸었다.', .12, .70);
      case 10:
        left.material('rag', 'studioCottonRag', .04, .04, .91, h: .82);
        mat(left, 'petal_bouquet', .13, .12, .57, .48);
        left.material('olive', 'studioOlivePress', .56, .46, .29);
        left.copy('꽃 한 송이와 사진 한 장.', .13, .78, .72, .07);
        note(right, '버리지 못한 것들', '작은 물건들이\n그날을 가장 정확하게 기억한다.', .12, .12);
        mat(right, 'petal_details', .12, .44, .76, .39);
      case 11:
        photo(left, 'petal_couple', .08, .07, .84, .76);
        right.text(
          'closing',
          '다음 계절에도\n너와 함께',
          .12,
          .19,
          .78,
          .30,
          size: .08,
          font: 'Eulyoo',
          color: ink,
        );
        rule(right, .12, .57, .73);
        right.copy('이 책 다음의 날들도\n함께 채워 가기로 했다.', .12, .63, .77, .15);
        right.material('olive', 'studioOlivePress', .68, .76, .15);
    }
    pages.add(left.finish(gardenLettersChapters[spread], 'interior'));
    pages.add(right.finish(gardenLettersChapters[spread], 'interior'));
  }
  return {
    'id': 'snapfit_garden_letters_${aspect.name}',
    'collectionId': 'garden-letters',
    'title': '정원의 편지',
    'category': '웨딩',
    'innerPageCount': 24,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'aspect': aspect.name,
    'publicationStatus': 'design-review',
    'catalogPublishable': false,
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
  };
}

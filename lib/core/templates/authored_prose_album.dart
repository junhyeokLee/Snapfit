part of 'authored_collections.dart';

const proseAlbumBundledId = -9305;
const proseAlbumSpreads = [
  '웃음이 먼저 남은 날',
  '나란히 앉은 오후',
  '당신에게 쓰는 편지',
  '같이 시작한 아침',
  '오래 머문 자리',
  '걷다가 발견한 것',
  '우리의 작은 취향',
  '한 장의 사진 밖으로',
  '기념일의 식탁',
  '돌아보면 가까운 날',
  '다음 계절의 약속',
  '다음에도, 이렇게',
];

/// Complete free edition; the approved cover and first five pages stay intact.
Map<String, dynamic> buildProseAlbum(
  CollectionAspect aspect, {
  ProseStudyCopy copy = const ProseStudyCopy(),
}) {
  final source = buildProseStudy(aspect, copy: copy);
  final seed = (source['pages'] as List).cast<Map<String, dynamic>>();
  final pages = <Map<String, dynamic>>[...seed.take(5)];
  const paper = '#FAFAF6', ink = '#233D35', red = '#842B3D', blue = '#DCE9ED';
  _Sheet sheet([String bg = paper, String color = ink]) =>
      _Sheet(proseStudyId, aspect, pages.length + 1, bg, ink: color);
  void photo(
    _Sheet p,
    String file,
    double x,
    double y,
    double w,
    double h, {
    String frame = 'studyFloatMount',
  }) => p.photo(
    'photo_${p.layers.length}',
    '$_editorial$file.png',
    x,
    y,
    w,
    h,
    shape: frame,
  );
  void type(
    _Sheet p,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .055,
    String? color,
  }) => p.text(
    'text_${p.layers.length}',
    value,
    x,
    y,
    w,
    h,
    size: size,
    color: color ?? p.ink,
    font: 'Eulyoo',
    lineHeight: 1.32,
  );
  void caption(_Sheet p, String value, double x, double y, double w) => p.text(
    'caption_${p.layers.length}',
    value,
    x,
    y,
    w,
    .07,
    size: .022,
    color: p.ink,
    lineHeight: 1.4,
  );
  void finish(_Sheet p, String name, String role) {
    final left = p.index.isOdd;
    p.text(
      'folio',
      p.index.toString().padLeft(2, '0'),
      left ? .07 : .84,
      .955,
      .09,
      .029,
      size: .017,
      color: p.ink,
      align: left ? 'left' : 'right',
    );
    p.text(
      'running_title',
      proseStudyTitle,
      left ? .60 : .12,
      .957,
      .27,
      .027,
      size: .015,
      color: p.ink,
      align: left ? 'right' : 'left',
    );
    pages.add({
      ...p.json,
      'name': name,
      'role': role,
      'spreadIndex': (p.index + 1) ~/ 2,
      'side': left ? 'left' : 'right',
    });
  }

  var p = sheet(); // 6: a quiet portrait opposite the letter.
  photo(p, 'petal_evening', .15, .10, .72, .68, frame: 'studyArchWindow');
  type(p, '사진을 고르다,\n또 한 번 웃었어.', .15, .81, .72, .10, size: .036);
  finish(p, '편지 곁의 얼굴', 'letter-companion');

  p = sheet(blue); // 7
  p.kicker('같이 시작한 아침');
  type(p, '우리의\n보통날', .09, .17, .37, .33, size: .104, color: red);
  photo(p, 'small_days_breakfast', .51, .17, .35, .43);
  p.box('rule', .09, .66, .77, .0018, ink);
  caption(p, '먼저 일어난 사람이\n컵을 두 개 꺼내 놓는 아침.', .09, .72, .55);
  finish(p, '컵을 두 개 꺼내는 일', 'daily-opening');

  p = sheet(); // 8
  photo(p, 'couple_cafe', .13, .10, .78, .67, frame: 'studyNotchedMat');
  type(p, '급할 것 없는 대화', .13, .81, .78, .08, size: .044);
  finish(p, '급할 것 없는 대화', 'daily-portrait');

  p = sheet(); // 9
  photo(p, 'daily_book', .09, .12, .39, .52, frame: 'studyArchWindow');
  type(p, '같은 자리,\n다른 페이지.', .54, .16, .32, .24, size: .052);
  caption(p, '각자의 책을 읽다가\n좋은 문장은 서로에게 들려주기.', .09, .74, .77);
  finish(p, '같은 자리 다른 페이지', 'reading-diptych');

  p = sheet(ink, paper); // 10
  type(p, '말이 없어도\n편안한 사이', .14, .12, .76, .23, size: .084);
  photo(p, 'couple_keepsakes', .14, .43, .76, .38);
  caption(p, '따로 고른 것들이 한자리에 모였다.', .14, .845, .76);
  finish(p, '한자리에 모인 취향', 'quiet-still-life');

  p = sheet(); // 11
  photo(p, 'couple_walk', .09, .09, .78, .58);
  type(p, '조금 돌아가도\n좋았던 길', .09, .70, .78, .19, size: .066, color: red);
  finish(p, '조금 돌아가도 좋았던 길', 'walking-scene');

  p = sheet(blue); // 12
  photo(p, 'small_days_walk', .14, .12, .46, .62, frame: 'studyArchWindow');
  photo(p, 'travel_coast', .64, .40, .25, .30, frame: 'studyNotchedMat');
  caption(p, '앞서 걷던 네가 돌아보는 순간을 좋아해.', .14, .81, .75);
  finish(p, '뒤돌아본 순간', 'walking-details');

  p = sheet(); // 13
  p.kicker('서로에게 옮겨 온 취향');
  photo(p, 'daily_fruit', .09, .16, .35, .39, frame: 'studyNotchedMat');
  photo(p, 'daily_book', .50, .31, .36, .43);
  type(p, '네가 좋아해서,\n나도 좋아진 것.', .09, .76, .77, .14, size: .043);
  finish(p, '나도 좋아진 것', 'offset-still-lifes');

  p = sheet(); // 14
  type(p, '너의 목록', .14, .09, .75, .12, size: .086, color: red);
  for (final e in ['함께 먹고 싶은 것', '다시 가 보고 싶은 곳', '다음에 들려주고 싶은 이야기'].indexed) {
    final y = .31 + e.$1 * .18;
    p.text(
      'number_${e.$1}',
      '0${e.$1 + 1}',
      .14,
      y,
      .09,
      .06,
      size: .028,
      color: red,
      font: 'Cormorant Garamond',
    );
    caption(p, e.$2, .29, y, .60);
    p.box('line_${e.$1}', .29, y + .10, .60, .0015, '#BBC8C0');
  }
  finish(p, '아직 쓰지 않은 목록', 'editable-list');

  p = sheet(ink, paper); // 15
  type(p, '사진 밖의\n기억까지', .09, .10, .77, .27, size: .093);
  photo(p, 'petal_table', .09, .46, .77, .35, frame: 'studyNotchedMat');
  caption(p, '그날의 공기와 우리가 나눈 이야기.', .09, .85, .77);
  finish(p, '그날의 공기', 'memory-opening');

  p = sheet(); // 16
  photo(p, 'petal_details', .14, .10, .33, .44, frame: 'studyNotchedMat');
  photo(p, 'petal_bouquet', .55, .27, .34, .44, frame: 'studyArchWindow');
  type(p, '작은 것들이\n그날을 기억해.', .14, .74, .75, .15, size: .052);
  finish(p, '작은 것들의 기억', 'memory-pair');

  p = sheet(blue); // 17
  p.kicker('오늘은 조금 특별하게');
  photo(p, 'couple_anniversary', .09, .17, .77, .57);
  type(p, '축하할 일이\n또 하나 늘었어.', .09, .77, .77, .13, size: .043);
  finish(p, '축하할 일이 늘었어', 'anniversary-opening');

  p = sheet(); // 18
  photo(p, 'lightbound_cake', .14, .09, .75, .65, frame: 'studyArchWindow');
  type(p, '소원은 각자,\n촛불은 함께.', .14, .77, .75, .14, size: .05, color: red);
  finish(p, '촛불은 함께', 'anniversary-detail');

  p = sheet(); // 19
  photo(p, 'couple_cafe', .09, .13, .77, .43);
  photo(p, 'couple_walk', .09, .61, .32, .23, frame: 'studyNotchedMat');
  caption(p, '같은 사람과 보낸\n서로 다른 날들.', .49, .69, .37);
  finish(p, '서로 다른 날들', 'collected-dates');

  p = sheet(ink, paper); // 20
  type(p, '돌아보면,\n늘 가까이에.', .14, .10, .75, .25, size: .079);
  photo(p, 'petal_couple', .14, .43, .75, .39);
  caption(p, '사진마다 네가 있어서 좋다.', .14, .86, .75);
  finish(p, '늘 가까이에', 'looking-back');

  p = sheet(blue); // 21
  photo(p, 'small_days_walk', .09, .09, .77, .55, frame: 'studyNotchedMat');
  type(p, '다음 계절에도\n나란히 걷자.', .09, .68, .77, .19, size: .068, color: red);
  finish(p, '다음 계절의 약속', 'next-season');

  p = sheet(); // 22
  type(p, '함께 해 보고 싶은 일', .14, .10, .75, .12, size: .051);
  for (var i = 0; i < 3; i++) {
    final y = .32 + i * .17;
    p.text(
      'index_$i',
      '0${i + 1}',
      .14,
      y,
      .09,
      .05,
      size: .025,
      color: red,
      font: 'Cormorant Garamond',
    );
    p.box('wish_line_$i', .29, y + .07, .60, .0015, '#BBC8C0');
  }
  caption(p, '빈칸은 함께 채워 가기로.', .14, .85, .75);
  finish(p, '함께 채울 빈칸', 'future-list');

  p = sheet(); // 23
  photo(p, 'couple_keepsakes', .09, .12, .77, .43, frame: 'studyNotchedMat');
  type(p, '여기까지가\n우리의 오늘.', .09, .62, .77, .21, size: .073, color: red);
  caption(p, '그다음 이야기는 다음 앨범에.', .09, .85, .77);
  finish(p, '우리의 오늘', 'album-colophon');

  // Preserve approved closing art, updating only page metadata and folio.
  final last = seed.last;
  pages.add({
    ...last,
    'spreadIndex': 12,
    'side': 'right',
    'layers': [
      for (final raw in last['layers'] as List)
        {
          ...raw as Map<String, dynamic>,
          'id': (raw['id'] as String).replaceFirst(
            '${proseStudyId}_${aspect.name}_6_',
            '${proseStudyId}_${aspect.name}_24_',
          ),
          if ((raw['id'] as String).endsWith('_folio')) 'text': '24',
        },
    ],
  });
  return {
    ...source,
    'source': 'snapfit-authored',
    'version': 4,
    'accessTier': 'free',
    'publicationStatus': 'bundled',
    'catalogPublishable': false,
    'approvalStatus': 'accepted-as-free',
    'innerPageCount': 24,
    'pages': pages,
    'chapters': [
      for (final e in proseAlbumSpreads.indexed)
        {'title': e.$2, 'from': e.$1 * 2 + 1, 'to': e.$1 * 2 + 2},
    ],
  };
}

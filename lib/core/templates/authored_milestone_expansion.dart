part of 'authored_collections.dart';

int _milestoneKind(StoryEdition e) => e.catalogId.abs() - 9781;
String _milestoneFont(StoryEdition e) => const [
  'Samlip',
  'Arita',
  'Tenada',
  'Eulyoo',
  'BookMyungjo',
][_milestoneKind(e)];

Rect _milestonePhoto(
  _StoryPage p,
  int photo,
  Rect region, {
  bool framed = false,
}) {
  final frame = framed ? p.edition.photoFrames.single : 'none';
  final padding = StudioMaterial.photoInsets(frame, const Size(1.5, 1));
  final outerRatio = 1.5 * (1 - padding.vertical) + padding.horizontal;
  final width = math.min(region.width, region.height * outerRatio / p.ratio);
  final bounds = Rect.fromCenter(
    center: region.center,
    width: width,
    height: width * p.ratio / outerRatio,
  );
  p.image(photo, bounds, frame: frame);
  p.layers.last['milestoneFullSourcePhoto'] = true;
  return bounds;
}

void _milestoneTitle(_StoryPage p, int i, Rect rect, {double size = .043}) =>
    p.type(
      p.edition.chapters[i],
      rect,
      size: size,
      font: _milestoneFont(p.edition),
      role: 'headline',
    );
void _milestoneNote(_StoryPage p, int i, Rect rect) => p.type(
  p.edition.notes[i],
  rect,
  size: .025,
  font: 'BookMyungjo',
  role: 'body',
);
void _milestoneLabel(_StoryPage p, int i, {double y = .06}) => p.type(
  '${(i + 1).toString().padLeft(2, '0')} / ${const ['LITTLE GRADUATE', 'OUR FIRST PLACE', 'WORK IN PROGRESS', 'A NEW SEASON', 'FIRST EXHIBITION'][_milestoneKind(p.edition)]}',
  Rect.fromLTWH(.08, y, .84, .035),
  size: .015,
  font: 'Poppins',
  color: p.edition.accent,
);

Rect _milestoneCard(_StoryPage p, Rect region) {
  const ratio = 1.25;
  final w = math.min(region.width, region.height * ratio / p.ratio);
  final card = Rect.fromCenter(
    center: region.center,
    width: w,
    height: w * p.ratio / ratio,
  );
  p.piece(p.edition.paperId, card);
  return card;
}

void _milestoneFields(
  _StoryPage p,
  Rect region,
  String title,
  List<String> fields,
) {
  final card = _milestoneCard(p, region);
  Rect field(double y, double h) => Rect.fromLTWH(
    card.left + card.width * .14,
    card.top + card.height * y,
    card.width * .72,
    card.height * h,
  );
  p.type(
    title,
    field(.16, .12),
    size: .031,
    font: _milestoneFont(p.edition),
    role: 'headline',
  );
  p.type(
    fields.join('\n'),
    field(.38, .35),
    size: .026,
    font: 'BookMyungjo',
    role: 'body',
  );
}

void _milestoneArt(_StoryPage p, Rect region) => _diversityWordArt(p, region);

void _milestoneExpansionCover(_StoryPage p) {
  switch (_milestoneKind(p.edition)) {
    case 0:
      p.box(p.uid, 0, 0, 1, 1, '#FBF5E6');
      p.line(const Rect.fromLTWH(.06, .055, .23, .017), color: '#CF6B45');
      p.type(
        '작은 졸업,\n큰 박수',
        const Rect.fromLTWH(.07, .13, .68, .20),
        size: .078,
        font: 'Samlip',
        role: 'headline',
      );
      p.piece(p.edition.motifId, const Rect.fromLTWH(.78, .12, .16, .20));
      _milestonePhoto(
        p,
        0,
        const Rect.fromLTWH(.055, .38, .89, .45),
        framed: true,
      );
      p.type(
        '이만큼 자란 우리에게',
        const Rect.fromLTWH(.08, .89, .84, .05),
        size: .027,
        font: 'NanumPen',
      );
    case 1:
      p.box(p.uid, 0, 0, 1, 1, '#EDF3F1');
      p.line(const Rect.fromLTWH(.07, .07, .02, .82));
      p.type(
        'THE FIRST KEY / A HOME JOURNAL',
        const Rect.fromLTWH(.13, .07, .80, .04),
        size: .016,
        font: 'Poppins',
        color: p.edition.accent,
      );
      _milestonePhoto(p, 0, const Rect.fromLTWH(.12, .19, .82, .48));
      p.type(
        '처음 여는\n우리 집',
        const Rect.fromLTWH(.13, .73, .62, .18),
        size: .067,
        font: 'Arita',
        role: 'headline',
      );
      p.piece(p.edition.motifId, const Rect.fromLTWH(.79, .77, .14, .15));
    case 2:
      p.box(p.uid, 0, 0, 1, 1, '#243A47');
      p.type(
        'BEGIN / AGAIN',
        const Rect.fromLTWH(.06, .065, .87, .04),
        size: .018,
        font: 'Poppins',
        color: '#E8C69D',
      );
      _milestonePhoto(
        p,
        0,
        const Rect.fromLTWH(.43, .18, .52, .51),
        framed: true,
      );
      p.type(
        '나의\n두 번째\n출발',
        const Rect.fromLTWH(.06, .23, .31, .34),
        size: .069,
        font: 'Tenada',
        color: '#F2EEE5',
        role: 'headline',
      );
      p.line(const Rect.fromLTWH(.06, .76, .12, .007), color: '#E8C69D');
      p.type(
        '지나온 경험으로 새로운 일을 시작하다',
        const Rect.fromLTWH(.06, .83, .87, .07),
        size: .026,
        font: 'BookMyungjo',
        color: '#F2EEE5',
      );
    case 3:
      p.box(p.uid, 0, 0, 1, 1, '#F5F0E5');
      p.type(
        'after the last working day',
        const Rect.fromLTWH(.10, .065, .80, .06),
        size: .034,
        font: 'Cormorant Garamond',
        color: p.edition.accent,
      );
      _milestonePhoto(p, 0, const Rect.fromLTWH(.09, .20, .82, .44));
      p.type(
        '퇴근 다음의 계절',
        const Rect.fromLTWH(.09, .73, .82, .10),
        size: .060,
        font: 'Eulyoo',
        role: 'headline',
      );
      p.type(
        '오래 함께한 시간, 새로 열리는 하루',
        const Rect.fromLTWH(.09, .89, .82, .04),
        size: .023,
        font: 'BookMyungjo',
      );
    default:
      p.box(p.uid, 0, 0, 1, 1, '#FEFDF9');
      p.type(
        'FIRST EXHIBITION / ARCHIVE',
        const Rect.fromLTWH(.07, .055, .86, .04),
        size: .016,
        font: 'Poppins',
        color: p.edition.accent,
      );
      _milestonePhoto(
        p,
        0,
        const Rect.fromLTWH(.07, .18, .62, .44),
        framed: true,
      );
      p.piece(p.edition.motifId, const Rect.fromLTWH(.76, .23, .17, .22));
      p.type(
        '처음 내 이름을\n걸다',
        const Rect.fromLTWH(.07, .72, .86, .19),
        size: .064,
        font: 'BookMyungjo',
        role: 'headline',
      );
  }
}

List<_StoryPage> _milestoneExpansionSpread(
  StoryEdition e,
  CollectionAspect a,
  int i,
) {
  final k = _milestoneKind(e);
  final paper = const [
    '#FCF7EC',
    '#F3F7F5',
    '#F2F5F6',
    '#F6F2E8',
    '#FEFDF9',
  ][k];
  final l = _StoryPage(e, a, i * 2 + 1, paper),
      r = _StoryPage(e, a, i * 2 + 2, (i == 3 || i == 7) ? e.tint : paper);
  switch (k) {
    case 0:
      _milestoneApplause(l, r, i);
    case 1:
      _milestoneHome(l, r, i);
    case 2:
      _milestoneRestart(l, r, i);
    case 3:
      _milestoneSeason(l, r, i);
    default:
      _milestoneGallery(l, r, i);
  }
  return [l, r];
}

void _milestoneApplause(_StoryPage l, _StoryPage r, int i) {
  switch (i) {
    case 0:
      _milestoneLabel(l, i);
      _milestoneArt(l, const Rect.fromLTWH(.08, .22, .84, .50));
      _milestonePhoto(
        r,
        0,
        const Rect.fromLTWH(.04, .12, .92, .61),
        framed: true,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.09, .81, .82, .10));
    case 1:
      _milestoneTitle(l, i, const Rect.fromLTWH(.08, .09, .84, .09));
      _milestonePhoto(l, 1, const Rect.fromLTWH(.06, .28, .88, .52));
      r.piece(r.edition.motifId, const Rect.fromLTWH(.20, .13, .60, .37));
      _milestoneNote(r, i, const Rect.fromLTWH(.10, .66, .80, .17));
    case 2:
      _milestonePhoto(l, 0, const Rect.fromLTWH(.07, .09, .86, .47));
      _milestoneTitle(l, i, const Rect.fromLTWH(.09, .68, .82, .11));
      _milestonePhoto(
        r,
        3,
        const Rect.fromLTWH(.09, .12, .54, .36),
        framed: true,
      );
      _milestonePhoto(r, 2, const Rect.fromLTWH(.42, .53, .49, .32));
      _milestoneNote(r, i, const Rect.fromLTWH(.09, .88, .82, .05));
    case 3:
      _milestonePhoto(
        l,
        3,
        const Rect.fromLTWH(.05, .15, .90, .56),
        framed: true,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.09, .80, .82, .11));
      _milestoneFields(r, const Rect.fromLTWH(.08, .15, .84, .70), '내가 만든 것들', [
        '그림의 이름',
        '처음 해 본 일',
        '가장 좋아한 색',
      ]);
    case 4:
      _milestoneTitle(l, i, const Rect.fromLTWH(.08, .07, .84, .10));
      _milestonePhoto(l, 0, const Rect.fromLTWH(.045, .24, .91, .56));
      _milestonePhoto(
        r,
        1,
        const Rect.fromLTWH(.08, .14, .84, .43),
        framed: true,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.10, .68, .80, .14));
    case 5:
      _milestoneLabel(l, i);
      _milestoneNote(l, i, const Rect.fromLTWH(.10, .24, .80, .16));
      _milestonePhoto(l, 4, const Rect.fromLTWH(.10, .56, .52, .32));
      _milestonePhoto(r, 1, const Rect.fromLTWH(.04, .11, .92, .62));
      _milestoneTitle(r, i, const Rect.fromLTWH(.10, .83, .80, .08));
    case 6:
      _milestoneTitle(l, i, const Rect.fromLTWH(.08, .08, .84, .10));
      _milestonePhoto(
        l,
        2,
        const Rect.fromLTWH(.09, .28, .82, .46),
        framed: true,
      );
      _milestoneFields(r, const Rect.fromLTWH(.08, .17, .84, .69), '이만큼 자랐어요', [
        '내 이름 / 오늘의 날짜',
        '혼자 해낸 일',
        '나에게 주는 큰 박수',
      ]);
    case 7:
      _milestonePhoto(
        l,
        0,
        const Rect.fromLTWH(.08, .11, .84, .45),
        framed: true,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.10, .70, .80, .15));
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.09, .13, .82, .15),
        size: .052,
      );
      r.piece(r.edition.motifId, const Rect.fromLTWH(.29, .40, .42, .31));
      r.type(
        '우리 또 같이 놀자!',
        const Rect.fromLTWH(.11, .83, .78, .06),
        size: .039,
        font: 'NanumPen',
      );
    case 8:
      _milestonePhoto(l, 0, const Rect.fromLTWH(.045, .18, .91, .56));
      _milestoneTitle(l, i, const Rect.fromLTWH(.08, .81, .84, .08));
      _milestonePhoto(r, 2, const Rect.fromLTWH(.09, .11, .52, .33));
      _milestoneNote(r, i, const Rect.fromLTWH(.10, .57, .80, .14));
      r.piece(r.edition.motifId, const Rect.fromLTWH(.70, .75, .20, .16));
    case 9:
      _milestonePhoto(l, 4, const Rect.fromLTWH(.055, .18, .89, .53));
      _milestoneNote(l, i, const Rect.fromLTWH(.09, .80, .82, .11));
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.09, .20, .82, .16),
        size: .059,
      );
      r.type(
        '고마웠어,\n우리의 교실.',
        const Rect.fromLTWH(.11, .49, .78, .22),
        size: .060,
        font: 'Samlip',
      );
    case 10:
      _milestonePhoto(l, 3, const Rect.fromLTWH(.06, .13, .88, .47));
      _milestoneTitle(l, i, const Rect.fromLTWH(.08, .71, .84, .08));
      _milestonePhoto(
        r,
        2,
        const Rect.fromLTWH(.12, .16, .76, .47),
        framed: true,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.10, .77, .80, .12));
    default:
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.08, .09, .84, .14),
        size: .051,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.10, .35, .80, .16));
      l.piece(l.edition.motifId, const Rect.fromLTWH(.57, .65, .32, .24));
      _milestonePhoto(
        r,
        0,
        const Rect.fromLTWH(.05, .16, .90, .56),
        framed: true,
      );
      r.type(
        '다음의 너도 응원해',
        const Rect.fromLTWH(.10, .83, .80, .06),
        size: .037,
        font: 'NanumPen',
      );
  }
}

void _milestoneHome(_StoryPage l, _StoryPage r, int i) {
  switch (i) {
    case 0:
      _milestonePhoto(
        l,
        1,
        const Rect.fromLTWH(.09, .11, .82, .48),
        framed: true,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.10, .72, .80, .13));
      _milestoneLabel(r, i);
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.10, .25, .80, .19),
        size: .062,
      );
      r.piece(r.edition.motifId, const Rect.fromLTWH(.56, .65, .34, .23));
    case 1:
      _milestoneTitle(l, i, const Rect.fromLTWH(.08, .08, .84, .09));
      _milestonePhoto(l, 0, const Rect.fromLTWH(.07, .30, .86, .49));
      _milestoneFields(r, const Rect.fromLTWH(.10, .16, .80, .70), '상자를 열며', [
        '먼저 꺼낼 물건',
        '데려온 추억',
        '새로 필요한 것',
      ]);
    case 2:
      _milestoneFields(l, const Rect.fromLTWH(.07, .19, .86, .65), '우리 집의 자리', [
        '자주 머무는 곳',
        '햇빛 드는 방향',
        '천천히 바꿀 공간',
      ]);
      _milestonePhoto(
        r,
        2,
        const Rect.fromLTWH(.07, .15, .86, .50),
        framed: true,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.10, .77, .80, .11));
    case 3:
      _milestonePhoto(l, 2, const Rect.fromLTWH(.05, .10, .90, .60));
      _milestoneTitle(l, i, const Rect.fromLTWH(.08, .81, .84, .08));
      _milestonePhoto(r, 0, const Rect.fromLTWH(.08, .13, .50, .35));
      _milestonePhoto(r, 4, const Rect.fromLTWH(.42, .56, .49, .30));
      r.type(
        '조금씩 제자리를 찾는 중',
        const Rect.fromLTWH(.08, .91, .84, .035),
        size: .022,
        font: 'Arita',
      );
    case 4:
      _milestoneLabel(l, i);
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.09, .27, .82, .13),
        size: .052,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.10, .51, .80, .14));
      _milestonePhoto(
        r,
        4,
        const Rect.fromLTWH(.08, .13, .84, .62),
        framed: true,
      );
      r.piece(r.edition.motifId, const Rect.fromLTWH(.72, .82, .19, .12));
    case 5:
      _milestonePhoto(
        l,
        3,
        const Rect.fromLTWH(.05, .12, .90, .55),
        framed: true,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.10, .78, .80, .13));
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.10, .14, .80, .16),
        size: .054,
      );
      r.type(
        '첫 식탁의 메뉴\n함께 앉은 사람\n기억하고 싶은 맛',
        const Rect.fromLTWH(.12, .42, .76, .24),
        size: .031,
        font: 'BookMyungjo',
      );
      r.piece(r.edition.motifId, const Rect.fromLTWH(.63, .76, .27, .17));
    case 6:
      _milestoneTitle(l, i, const Rect.fromLTWH(.09, .10, .82, .10));
      _milestonePhoto(l, 1, const Rect.fromLTWH(.10, .32, .80, .43));
      _milestoneFields(r, const Rect.fromLTWH(.08, .15, .84, .70), '한 번에 하나씩', [
        '오늘 해낸 살림',
        '다음 주의 작은 계획',
        '함께 정한 생활 약속',
      ]);
    case 7:
      _milestonePhoto(l, 4, const Rect.fromLTWH(.05, .14, .90, .60));
      _milestoneTitle(l, i, const Rect.fromLTWH(.09, .82, .82, .07));
      _milestonePhoto(
        r,
        2,
        const Rect.fromLTWH(.11, .09, .78, .45),
        framed: true,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.10, .68, .80, .17));
    case 8:
      _milestoneArt(l, const Rect.fromLTWH(.08, .18, .84, .50));
      _milestoneNote(l, i, const Rect.fromLTWH(.10, .79, .80, .10));
      _milestonePhoto(r, 1, const Rect.fromLTWH(.07, .13, .86, .50));
      r.type(
        '집을 나서면 만나는 풍경',
        const Rect.fromLTWH(.10, .77, .80, .09),
        size: .032,
        font: 'Arita',
      );
    case 9:
      _milestonePhoto(
        l,
        2,
        const Rect.fromLTWH(.08, .10, .84, .45),
        framed: true,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.10, .69, .80, .15));
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.10, .18, .80, .14),
        size: .054,
      );
      _milestonePhoto(r, 3, const Rect.fromLTWH(.10, .46, .58, .34));
      r.piece(r.edition.motifId, const Rect.fromLTWH(.75, .59, .16, .17));
    case 10:
      _milestonePhoto(l, 0, const Rect.fromLTWH(.07, .12, .86, .44));
      _milestonePhoto(l, 4, const Rect.fromLTWH(.44, .64, .45, .28));
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.09, .16, .82, .15),
        size: .054,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.11, .43, .78, .19));
      r.type(
        '우리에게 맞는 집이 되는 중',
        const Rect.fromLTWH(.11, .79, .78, .06),
        size: .026,
        font: 'Arita',
      );
    default:
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.09, .10, .82, .14),
        size: .048,
      );
      _milestonePhoto(
        l,
        4,
        const Rect.fromLTWH(.08, .34, .84, .46),
        framed: true,
      );
      _milestoneFields(r, const Rect.fromLTWH(.09, .17, .82, .68), '다음 계절에는', [
        '바꾸고 싶은 한 귀퉁이',
        '초대하고 싶은 사람',
        '집에서 해 보고 싶은 일',
      ]);
  }
}

void _milestoneRestart(_StoryPage l, _StoryPage r, int i) {
  l.line(const Rect.fromLTWH(.035, .08, .008, .79));
  switch (i) {
    case 0:
      _milestoneLabel(l, i);
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.10, .25, .78, .18),
        size: .060,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.11, .56, .77, .16));
      _milestonePhoto(
        r,
        0,
        const Rect.fromLTWH(.06, .12, .88, .62),
        framed: true,
      );
      r.type(
        'STEP 01 / START HERE',
        const Rect.fromLTWH(.10, .84, .80, .04),
        size: .018,
        font: 'Poppins',
      );
    case 1:
      _milestoneFields(l, const Rect.fromLTWH(.09, .16, .82, .70), '지금의 나', [
        '오래 해 온 일',
        '다시 쓰고 싶은 경험',
        '앞으로 배울 한 가지',
      ]);
      _milestonePhoto(r, 1, const Rect.fromLTWH(.08, .13, .84, .48));
      _milestoneNote(r, i, const Rect.fromLTWH(.11, .74, .78, .13));
    case 2:
      _milestonePhoto(l, 2, const Rect.fromLTWH(.07, .12, .86, .57));
      _milestoneTitle(l, i, const Rect.fromLTWH(.10, .80, .78, .09));
      _milestonePhoto(
        r,
        1,
        const Rect.fromLTWH(.10, .14, .51, .34),
        framed: true,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.10, .61, .80, .16));
      r.piece(r.edition.motifId, const Rect.fromLTWH(.72, .81, .18, .12));
    case 3:
      _milestonePhoto(
        l,
        1,
        const Rect.fromLTWH(.09, .10, .82, .43),
        framed: true,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.11, .67, .77, .16));
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.09, .11, .82, .15),
        size: .053,
      );
      r.type(
        '실패한 흔적도\n다음 시도의\n자료가 된다.',
        const Rect.fromLTWH(.12, .40, .76, .28),
        size: .056,
        font: 'Tenada',
      );
      r.line(const Rect.fromLTWH(.12, .80, .60, .006));
    case 4:
      _milestonePhoto(l, 1, const Rect.fromLTWH(.07, .16, .86, .51));
      _milestoneTitle(l, i, const Rect.fromLTWH(.10, .81, .78, .08));
      _milestonePhoto(
        r,
        3,
        const Rect.fromLTWH(.10, .13, .80, .46),
        framed: true,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.11, .73, .78, .14));
    case 5:
      _milestoneTitle(l, i, const Rect.fromLTWH(.10, .08, .78, .12));
      _milestonePhoto(
        l,
        3,
        const Rect.fromLTWH(.08, .29, .84, .48),
        framed: true,
      );
      _milestonePhoto(r, 1, const Rect.fromLTWH(.09, .10, .42, .29));
      _milestonePhoto(r, 2, const Rect.fromLTWH(.49, .46, .42, .29));
      _milestoneNote(r, i, const Rect.fromLTWH(.10, .85, .80, .08));
    case 6:
      _milestonePhoto(l, 0, const Rect.fromLTWH(.08, .12, .84, .51));
      _milestoneNote(l, i, const Rect.fromLTWH(.11, .77, .77, .13));
      _milestoneFields(r, const Rect.fromLTWH(.07, .17, .86, .68), '경험을 연결하기', [
        '지난 경험의 강점',
        '새로 배운 기술',
        '함께 써 볼 방법',
      ]);
    case 7:
      _milestonePhoto(
        l,
        2,
        const Rect.fromLTWH(.055, .18, .89, .57),
        framed: true,
      );
      _milestoneTitle(l, i, const Rect.fromLTWH(.10, .84, .78, .08));
      _milestoneLabel(r, i);
      _milestoneNote(r, i, const Rect.fromLTWH(.11, .28, .78, .17));
      r.piece(r.edition.motifId, const Rect.fromLTWH(.30, .59, .48, .28));
    case 8:
      _milestoneArt(l, const Rect.fromLTWH(.10, .19, .80, .50));
      _milestoneNote(l, i, const Rect.fromLTWH(.11, .80, .77, .10));
      _milestonePhoto(r, 3, const Rect.fromLTWH(.06, .12, .88, .57));
      r.type(
        '이번 작업에서 내가 고른 것',
        const Rect.fromLTWH(.10, .81, .80, .07),
        size: .030,
        font: 'Tenada',
      );
    case 9:
      _milestonePhoto(l, 4, const Rect.fromLTWH(.055, .15, .89, .60));
      _milestoneTitle(l, i, const Rect.fromLTWH(.10, .84, .78, .07));
      _milestonePhoto(
        r,
        0,
        const Rect.fromLTWH(.10, .13, .80, .43),
        framed: true,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.11, .69, .78, .17));
    case 10:
      _milestoneLabel(l, i);
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.10, .27, .78, .17),
        size: .058,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.11, .58, .77, .17));
      _milestonePhoto(
        r,
        3,
        const Rect.fromLTWH(.08, .12, .84, .51),
        framed: true,
      );
      r.piece(r.edition.motifId, const Rect.fromLTWH(.65, .74, .25, .16));
    default:
      _milestonePhoto(
        l,
        4,
        const Rect.fromLTWH(.07, .15, .86, .51),
        framed: true,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.11, .79, .77, .11));
      _milestoneFields(
        r,
        const Rect.fromLTWH(.08, .17, .84, .70),
        '이어 갈 나의 일',
        ['이번에 해낸 것', '다음에 시도할 일', '미래의 나에게 남길 말'],
      );
  }
}

void _milestoneSeason(_StoryPage l, _StoryPage r, int i) {
  switch (i) {
    case 0:
      _milestonePhoto(
        l,
        0,
        const Rect.fromLTWH(.08, .16, .84, .55),
        framed: true,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.12, .83, .76, .07));
      r.type(
        'a long chapter,\na new morning',
        const Rect.fromLTWH(.10, .21, .80, .25),
        size: .073,
        font: 'Cormorant Garamond',
      );
      _milestoneTitle(r, i, const Rect.fromLTWH(.10, .64, .80, .10));
    case 1:
      _milestoneLabel(l, i);
      _milestonePhoto(l, 1, const Rect.fromLTWH(.10, .26, .80, .43));
      _milestoneNote(l, i, const Rect.fromLTWH(.12, .81, .76, .10));
      _milestonePhoto(
        r,
        1,
        const Rect.fromLTWH(.20, .20, .60, .40),
        framed: true,
      );
      r.piece(r.edition.motifId, const Rect.fromLTWH(.64, .70, .24, .18));
    case 2:
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.10, .14, .80, .11),
        size: .054,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.12, .43, .76, .19));
      _milestonePhoto(r, 0, const Rect.fromLTWH(.055, .16, .89, .56));
      r.type(
        '함께여서 오래 걸을 수 있었다.',
        const Rect.fromLTWH(.12, .83, .76, .06),
        size: .026,
        font: 'Eulyoo',
      );
    case 3:
      _milestonePhoto(l, 0, const Rect.fromLTWH(.08, .12, .84, .48));
      // Keep the companion image clear of the automatic folio at y=.93.
      _milestonePhoto(l, 2, const Rect.fromLTWH(.44, .655, .44, .25));
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.11, .14, .78, .15),
        size: .051,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.12, .43, .76, .18));
      r.piece(r.edition.motifId, const Rect.fromLTWH(.29, .74, .42, .17));
    case 4:
      _milestoneFields(
        l,
        const Rect.fromLTWH(.10, .15, .80, .70),
        '오래 걸어온 시간',
        ['처음 일을 시작한 날', '가장 마음에 남은 시절', '함께 기억할 사람'],
      );
      _milestonePhoto(
        r,
        1,
        const Rect.fromLTWH(.11, .15, .78, .45),
        framed: true,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.12, .75, .76, .13));
    case 5:
      _milestonePhoto(
        l,
        1,
        const Rect.fromLTWH(.12, .12, .76, .43),
        framed: true,
      );
      _milestoneTitle(l, i, const Rect.fromLTWH(.12, .71, .76, .10));
      _milestoneArt(r, const Rect.fromLTWH(.10, .21, .80, .49));
      _milestoneNote(r, i, const Rect.fromLTWH(.12, .83, .76, .07));
    case 6:
      _milestonePhoto(l, 2, const Rect.fromLTWH(.08, .17, .84, .48));
      _milestoneNote(l, i, const Rect.fromLTWH(.12, .79, .76, .13));
      _milestoneFields(
        r,
        const Rect.fromLTWH(.09, .16, .82, .70),
        '오래 전하고 싶은 말',
        ['함께여서 고마웠던 일', '다시 만나고 싶은 날', '앞날에 보내는 마음'],
      );
    case 7:
      _milestoneTitle(l, i, const Rect.fromLTWH(.11, .09, .78, .11));
      _milestonePhoto(
        l,
        2,
        const Rect.fromLTWH(.08, .31, .84, .47),
        framed: true,
      );
      _milestonePhoto(r, 4, const Rect.fromLTWH(.14, .13, .72, .43));
      _milestoneNote(r, i, const Rect.fromLTWH(.12, .72, .76, .16));
    case 8:
      _milestoneLabel(l, i);
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.11, .26, .78, .15),
        size: .055,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.12, .55, .76, .18));
      _milestonePhoto(
        r,
        4,
        const Rect.fromLTWH(.08, .15, .84, .56),
        framed: true,
      );
      r.type(
        '서두르지 않아도 되는 아침',
        const Rect.fromLTWH(.12, .84, .76, .05),
        size: .026,
        font: 'Eulyoo',
      );
    case 9:
      _milestonePhoto(l, 3, const Rect.fromLTWH(.06, .16, .88, .57));
      _milestoneNote(l, i, const Rect.fromLTWH(.12, .84, .76, .08));
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.12, .19, .76, .13),
        size: .054,
      );
      r.piece(r.edition.motifId, const Rect.fromLTWH(.28, .45, .44, .24));
      r.type(
        '걷고 싶은 만큼만 천천히',
        const Rect.fromLTWH(.12, .83, .76, .05),
        size: .026,
        font: 'BookMyungjo',
      );
    case 10:
      _milestonePhoto(l, 4, const Rect.fromLTWH(.12, .15, .76, .46));
      _milestoneTitle(l, i, const Rect.fromLTWH(.12, .76, .76, .09));
      _milestoneFields(
        r,
        const Rect.fromLTWH(.10, .16, .80, .70),
        '다가올 계절의 약속',
        ['해 보고 싶은 일', '만나고 싶은 사람', '나에게 허락할 시간'],
      );
    default:
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.12, .17, .76, .14),
        size: .056,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.12, .48, .76, .19));
      l.piece(l.edition.motifId, const Rect.fromLTWH(.64, .77, .22, .13));
      _milestonePhoto(
        r,
        3,
        const Rect.fromLTWH(.08, .17, .84, .54),
        framed: true,
      );
      r.type(
        'a good day, again.',
        const Rect.fromLTWH(.12, .84, .76, .05),
        size: .037,
        font: 'Cormorant Garamond',
      );
  }
}

void _milestoneGallery(_StoryPage l, _StoryPage r, int i) {
  switch (i) {
    case 0:
      _milestoneLabel(l, i);
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.09, .23, .82, .18),
        size: .058,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.11, .56, .78, .16));
      _milestonePhoto(
        r,
        0,
        const Rect.fromLTWH(.08, .15, .84, .53),
        framed: true,
      );
      r.type(
        '01 / THE FIRST ROOM',
        const Rect.fromLTWH(.11, .81, .78, .04),
        size: .017,
        font: 'Poppins',
      );
    case 1:
      _milestonePhoto(l, 4, const Rect.fromLTWH(.055, .16, .89, .57));
      _milestoneTitle(l, i, const Rect.fromLTWH(.10, .83, .80, .07));
      _milestonePhoto(r, 0, const Rect.fromLTWH(.13, .12, .74, .44));
      _milestoneNote(r, i, const Rect.fromLTWH(.11, .70, .78, .15));
    case 2:
      _milestoneTitle(l, i, const Rect.fromLTWH(.09, .08, .82, .10));
      _milestonePhoto(
        l,
        1,
        const Rect.fromLTWH(.08, .29, .84, .47),
        framed: true,
      );
      _milestonePhoto(r, 2, const Rect.fromLTWH(.19, .15, .62, .38));
      _milestoneNote(r, i, const Rect.fromLTWH(.11, .69, .78, .16));
    case 3:
      _milestonePhoto(l, 0, const Rect.fromLTWH(.08, .09, .84, .42));
      _milestonePhoto(l, 2, const Rect.fromLTWH(.49, .61, .42, .29));
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.10, .15, .80, .15),
        size: .051,
      );
      r.type(
        '작품 사이에도\n머물 수 있는\n자리를 남겼다.',
        const Rect.fromLTWH(.12, .43, .76, .27),
        size: .053,
        font: 'BookMyungjo',
      );
      r.line(const Rect.fromLTWH(.12, .82, .21, .002));
    case 4:
      _milestonePhoto(
        l,
        2,
        const Rect.fromLTWH(.08, .16, .84, .54),
        framed: true,
      );
      l.type(
        'WORK / DETAIL',
        const Rect.fromLTWH(.11, .83, .78, .04),
        size: .017,
        font: 'Poppins',
      );
      _milestoneTitle(
        r,
        i,
        const Rect.fromLTWH(.10, .15, .80, .12),
        size: .052,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.12, .45, .76, .20));
      r.piece(r.edition.motifId, const Rect.fromLTWH(.70, .78, .18, .14));
    case 5:
      _milestoneLabel(l, i);
      _milestonePhoto(l, 0, const Rect.fromLTWH(.12, .23, .76, .45));
      _milestoneNote(l, i, const Rect.fromLTWH(.11, .81, .78, .10));
      _milestonePhoto(
        r,
        2,
        const Rect.fromLTWH(.13, .11, .74, .44),
        framed: true,
      );
      _milestoneTitle(r, i, const Rect.fromLTWH(.11, .72, .78, .12));
    case 6:
      _milestoneFields(
        l,
        const Rect.fromLTWH(.08, .16, .84, .68),
        '전시의 작은 안내',
        ['전시 제목 / 공간 / 날짜', '작품명과 재료', '작업에 담은 생각'],
      );
      _milestonePhoto(r, 1, const Rect.fromLTWH(.08, .15, .84, .52));
      _milestoneNote(r, i, const Rect.fromLTWH(.11, .80, .78, .11));
    case 7:
      _milestonePhoto(l, 3, const Rect.fromLTWH(.045, .16, .91, .59));
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.09, .85, .82, .07),
        size: .035,
      );
      _milestonePhoto(
        r,
        0,
        const Rect.fromLTWH(.14, .13, .72, .43),
        framed: true,
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.11, .72, .78, .17));
    case 8:
      _milestoneTitle(
        l,
        i,
        const Rect.fromLTWH(.11, .16, .78, .13),
        size: .053,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.12, .44, .76, .20));
      _milestonePhoto(
        r,
        3,
        const Rect.fromLTWH(.08, .14, .84, .53),
        framed: true,
      );
      r.type(
        '질문 하나를 오래 가져가다',
        const Rect.fromLTWH(.11, .82, .78, .07),
        size: .028,
        font: 'BookMyungjo',
      );
    case 9:
      _milestonePhoto(l, 0, const Rect.fromLTWH(.07, .12, .86, .52));
      _milestoneNote(l, i, const Rect.fromLTWH(.11, .78, .78, .12));
      _milestoneArt(r, const Rect.fromLTWH(.09, .17, .82, .52));
      r.piece(r.edition.motifId, const Rect.fromLTWH(.69, .80, .20, .13));
    case 10:
      _milestonePhoto(l, 4, const Rect.fromLTWH(.045, .18, .91, .56));
      _milestoneTitle(l, i, const Rect.fromLTWH(.10, .84, .80, .08));
      r.type(
        'when the\nroom is empty',
        const Rect.fromLTWH(.11, .21, .78, .25),
        size: .081,
        font: 'Cormorant Garamond',
      );
      _milestoneNote(r, i, const Rect.fromLTWH(.12, .66, .76, .18));
    default:
      _milestonePhoto(
        l,
        1,
        const Rect.fromLTWH(.12, .15, .76, .45),
        framed: true,
      );
      _milestoneNote(l, i, const Rect.fromLTWH(.11, .77, .78, .13));
      _milestoneFields(
        r,
        const Rect.fromLTWH(.09, .15, .82, .70),
        '다음 작업의 첫 줄',
        ['새로 떠오른 장면', '계속 붙잡고 싶은 질문', '다음 작업을 시작할 때'],
      );
  }
}

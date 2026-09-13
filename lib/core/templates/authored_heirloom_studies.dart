part of 'authored_collections.dart';

/// Unpublished, independently composed category studies. Never an AI fallback.
enum HeirloomStudy {
  wedding(
    'vow-keepsake',
    '약속을 묶은 책',
    '웨딩',
    '서약서와 압화, 청첩장의 기록',
    'petal_couple',
    '#3F5148',
    'Eulyoo',
    ['준비한 마음', '약속을 적은 종이', '함께 앉은 자리', '오래 간직할 것'],
  ),
  daily(
    'daily-cabinet',
    '하루의 수집함',
    '일상',
    '메모와 책갈피, 작은 사진의 분류',
    'daily_desk',
    '#34505A',
    'BookMyungjo',
    ['창가의 아침', '읽다가 접은 자리', '장을 보고 돌아와', '오늘을 넣어 둔다'],
  ),
  baby(
    'first-year-keepsake',
    '너의 첫 계절',
    '성장·육아',
    '작은 손과 첫 기록을 담은 성장 보관함',
    'growth_sleep',
    '#485954',
    'Eulyoo',
    ['처음 마주한 너', '조금씩 자라는 중', '작아진 물건들', '첫 생일의 기록'],
  ),
  family(
    'table-stories',
    '우리 집 식탁',
    '가족·친구',
    '레시피와 식탁보, 모여 앉은 날의 기록',
    'family_table',
    '#354D3D',
    'BookMyungjo',
    ['식탁을 펴는 날', '우리 집 조리법', '같이 웃던 자리', '다음 모임의 약속'],
  ),
  couple(
    'two-tickets',
    '둘이 모은 장면',
    '커플·기념일',
    '영화표와 편지, 둘이 남긴 작은 증거',
    'couple_keepsakes',
    '#65424B',
    'Eulyoo',
    ['두 장의 티켓', '카페에서 나눈 말', '기념일의 테이블', '다음 장면으로'],
  ),
  pet(
    'walk-and-nap',
    '산책하고 낮잠',
    '반려동물',
    '산책 수첩과 이름표, 익숙한 표정의 기록',
    'pet_dog',
    '#345147',
    'BookMyungjo',
    ['오늘도 같이 걷자', '너를 알아가는 기록', '집에서 보내는 시간', '우리의 단골 코스'],
  );

  const HeirloomStudy(
    this.id,
    this.title,
    this.category,
    this.concept,
    this.coverPhoto,
    this.ink,
    this.font,
    this.chapters,
  );
  final String id, title, category, concept, coverPhoto, ink, font;
  final List<String> chapters;
  static HeirloomStudy? byId(String id) =>
      values.where((s) => s.id == id).firstOrNull;
  EditorialCopy get defaultCopy => EditorialCopy(
    place: title,
    period: this == baby ? '2026. 01 ~ 12' : '2026. 10. 17',
    byline: switch (this) {
      baby => '서우의 첫해',
      daily => '지우의 기록',
      family => '우리 가족',
      pet => '보리와 함께',
      _ => '서연과 지우',
    },
    note: switch (this) {
      wedding =>
        '서로의 이야기를 끝까지 듣고,\n같이 웃을 일을 자주 만들기로 했다.\n오늘 적은 마음을 오래 간직하고 싶다.',
      daily => '책을 읽고 꽃에 물을 줬다.\n돌아오는 길에 과일을 조금 샀다.\n별일 없던 하루에서 고른 장면들.',
      baby => '처음 눈을 맞추던 날을 적어 둔다.\n작은 손을 잡고 천천히 걸어가자.\n다음의 처음도 곁에서 지켜볼게.',
      family =>
        '식탁을 치우다가 사진을 한 번 더 봤다.\n남은 반찬을 나누고 다음 날짜를 정했다.\n다음에도 이 자리에 함께 앉자.',
      couple =>
        '영화가 끝나고 한 정거장을 더 걸었다.\n무슨 이야기를 했는지까지 남겨 두고 싶다.\n다음에도 나란히 앉을 두 자리.',
      pet => '익숙한 길에서도 매번 멈추는 자리가 있다.\n오늘은 조금 더 천천히 기다렸다.\n내일도 같은 시간에 함께 나가자.',
    },
  );
  Map<String, dynamic> document(
    CollectionAspect aspect, {
    EditorialCopy? copy,
  }) {
    final book = _HeirloomBook(this, aspect, copy ?? defaultCopy);
    book.cover();
    switch (this) {
      case wedding:
        _heirloomWedding(book);
      case daily:
        _heirloomDaily(book);
      case baby:
        _heirloomBaby(book);
      case family:
        _heirloomFamily(book);
      case couple:
        _heirloomCouple(book);
      case pet:
        _heirloomPet(book);
    }
    return book.document;
  }
}

/// Shared layer primitives only; every spread below is authored independently.
class _HeirloomBook {
  _HeirloomBook(this.study, this.aspect, this.copy, {this.chapterNames});
  final HeirloomStudy study;
  final CollectionAspect aspect;
  final EditorialCopy copy;
  final List<String>? chapterNames;
  List<String> get chapters => chapterNames ?? study.chapters;
  final pages = <Map<String, dynamic>>[];
  _Sheet page(String color) =>
      _Sheet(study.id, aspect, pages.length, color, ink: study.ink);
  void photo(
    _Sheet p,
    String id,
    String file,
    double x,
    double y,
    double w,
    double h, {
    String frame = 'none',
    double turn = 0,
  }) => p.photo(
    id,
    '$_editorial$file.png',
    x,
    y,
    w,
    h,
    shape: frame,
    rotation: turn,
  );
  void print(
    _Sheet p,
    String id,
    String file,
    double x,
    double y,
    double w,
    double h, {
    double turn = 0,
  }) {
    p.box('${id}_mount', x, y, w, h, '#F8F8F2');
    p.layers.last['rotation'] = turn;
    final dy = .01 * p.ratio;
    photo(p, id, file, x + .01, y + dy, w - .02, h - dy * 2, turn: turn);
  }

  // Group photographs retain the full 3:2 composition in every album ratio.
  Rect groupPhoto(
    _Sheet p,
    String id,
    String file,
    Rect bounds, {
    bool mounted = false,
  }) {
    final w = math.min(bounds.width, bounds.height * 1.5 / p.ratio);
    final h = w * p.ratio / 1.5;
    final r = Rect.fromLTWH(bounds.center.dx - w / 2, bounds.top, w, h);
    if (mounted) {
      print(p, id, file, r.left, r.top, r.width, r.height);
    } else {
      photo(p, id, file, r.left, r.top, r.width, r.height);
    }
    return r;
  }

  Rect material(
    _Sheet p,
    String key,
    double x,
    double y,
    double w,
    double h, {
    double turn = 0,
  }) {
    final ratio = studioDecorationById(key)!.aspectRatio;
    final width = math.min(w, h * ratio / p.ratio);
    final rect = Rect.fromLTWH(x, y, width, width * p.ratio / ratio);
    p.material(
      '${key}_${p.layers.length}',
      key,
      x,
      y,
      rect.width,
      h: rect.height,
      rotation: turn,
    );
    return rect;
  }

  void text(
    _Sheet p,
    String id,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .025,
    String? font,
    String? color,
    double leading = 1.25,
    String? overlay,
  }) {
    p.text(
      id,
      value,
      x,
      y,
      w,
      h,
      size: size,
      font: font ?? study.font,
      color: color ?? study.ink,
      lineHeight: leading,
    );
    if (overlay != null) p.layers.last['overlayImageId'] = overlay;
  }

  void footer(_Sheet p) {
    text(
      p,
      'byline',
      copy.byline,
      .07,
      .938,
      .54,
      .038,
      size: .017,
      font: 'NotoSans',
    );
    text(
      p,
      'folio',
      p.index.toString().padLeft(2, '0'),
      .88,
      .938,
      .05,
      .038,
      size: .017,
      font: 'NotoSans',
    );
  }

  void save(_Sheet p, String role) {
    if (p.index != 0) footer(p);
    pages.add({
      ...p.json,
      'name': p.index == 0
          ? study.title
          : '${chapters[(p.index - 1) ~/ 2]} ${p.index}',
      'role': role,
      'side': p.index == 0
          ? 'cover'
          : p.index.isOdd
          ? 'left'
          : 'right',
      'spreadIndex': p.index == 0 ? 0 : (p.index + 1) ~/ 2,
    });
  }

  void cover() {
    final p = page('#F5F6F1');
    photo(p, 'cover_photo', study.coverPhoto, 0, 0, 1, 1);
    final imageId = p.layers.last['id'] as String;
    final bottomTitle =
        study == HeirloomStudy.daily || study == HeirloomStudy.family;
    final noteCard = study == HeirloomStudy.couple;
    final y = noteCard
        ? .535
        : bottomTitle
        ? .815
        : .06;
    final x = noteCard ? .31 : .075;
    final width = noteCard ? .40 : .85;
    final titleSize = math.min(
      noteCard ? .046 : .066,
      width * .94 / math.max(1, copy.place.runes.length),
    );
    text(
      p,
      'cover_title',
      copy.place,
      x,
      y,
      width,
      .103,
      size: titleSize,
      color: study == HeirloomStudy.wedding ? '#FFFFFF' : study.ink,
      overlay: imageId,
    );
    text(
      p,
      'cover_byline',
      copy.byline,
      .075,
      .938,
      .48,
      .037,
      size: .022,
      font: 'NotoSans',
      overlay: imageId,
    );
    text(
      p,
      'cover_period',
      copy.period,
      .62,
      .941,
      .31,
      .030,
      size: .017,
      font: 'NotoSans',
      overlay: imageId,
    );
    save(p, 'full-photo-cover');
  }

  Map<String, dynamic> get document => {
    'id': 'snapfit_heirloom_${study.id}_${aspect.name}',
    'collectionId': study.id,
    'title': study.title,
    'category': study.category,
    'concept': study.concept,
    'source': 'snapfit-authored-study',
    'aiGenerated': false,
    'qualityBaseline': 'luminous-edition:8',
    'version': 1,
    'accessTier': 'unassigned',
    'intendedTier': 'premium',
    'catalogPublishable': false,
    'publicationStatus': 'design-study',
    'approvalStatus': 'approved-design-study',
    'approvedAt': '2026-09-09',
    'approvalScope': 'cover-and-eight-inner-pages',
    'studyScope': 'four-category-specific-spreads',
    'innerPageCount': pages.length - 1,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
    'chapters': [
      for (final chapter in chapters.indexed)
        {
          'title': chapter.$2,
          'from': chapter.$1 * 2 + 1,
          'to': chapter.$1 * 2 + 2,
        },
    ],
  };
}

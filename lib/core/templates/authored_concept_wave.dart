part of 'authored_collections.dart';

/// New complete volumes are review candidates, not additions to the free store.
enum ConceptVolume {
  silkVows(
    'silk-vows',
    '서약의 결',
    '웨딩',
    '실크 매듭과 압인, 은빛 여백의 웨딩 기록',
    'petal_veil',
    '#404A47',
    'Eulyoo',
    'waveSilkKnot',
    [
      '예식을 앞둔 아침',
      '작은 준비들',
      '나란히 선 두 사람',
      '서약을 적는다',
      '꽃을 건네던 순간',
      '입장',
      '서로의 손',
      '함께 웃은 얼굴',
      '오래 앉은 식탁',
      '축하를 모아',
      '저녁의 마지막 장면',
      '다음 날에도',
    ],
  ),
  shoreDays(
    'shore-days',
    '해변에서 보낸 날',
    '여행',
    '바다 유리와 해안선, 물빛 여행 기록집',
    'travel_coast',
    '#24545D',
    'BookMyungjo',
    'waveSeaGlass',
    [
      '바다가 보이기 시작했다',
      '해안선을 따라',
      '항구에서',
      '느린 점심',
      '주머니 속 작은 것',
      '동네를 한 바퀴',
      '기차 창밖',
      '다시 물가로',
      '보내지 않은 엽서',
      '마지막 산책',
      '여행의 목록',
      '돌아온 뒤에',
    ],
  ),
  readingRoom(
    'reading-room',
    '문장을 모으는 생활',
    '일상',
    '코발트 연필과 책등, 읽고 적는 일상의 조판',
    'daily_book',
    '#244993',
    'BookMyungjo',
    'wavePencil',
    [
      '책상에 앉기 전',
      '오늘 펼친 책',
      '밑줄 대신 사진',
      '창가의 자리',
      '밖에서 읽는 날',
      '돌아오는 길',
      '책과 식탁 사이',
      '함께 읽은 시간',
      '노트에 남긴 것',
      '다시 찾은 문장',
      '한 달의 책상',
      '다음 책을 펼치며',
    ],
  ),
  firstWardrobe(
    'first-wardrobe',
    '너의 작은 옷장',
    '성장·육아',
    '코튼 보닛과 성장 태그, 첫해의 작은 물건들',
    'growth_play',
    '#486478',
    'Eulyoo',
    'lifeBonnet',
    [
      '너를 기다리는 서랍',
      '처음 맞잡은 손',
      '이름을 부르면',
      '첫 외출 준비',
      '오래 잠든 오후',
      '좋아하는 놀이',
      '작아진 옷들',
      '함께 걷는 연습',
      '가족의 품에서',
      '첫 생일을 앞두고',
      '하루하루 자란 너',
      '다음 계절의 옷장',
    ],
  ),
  sundayPicnic(
    'sunday-picnic',
    '일요일의 피크닉',
    '가족·친구',
    '체크 천과 피크닉 바구니, 함께 보낸 일요일',
    'daily_picnic',
    '#70443E',
    'BookMyungjo',
    'lifeGingham',
    [
      '이번 일요일의 약속',
      '바구니를 채우며',
      '돗자리를 펼친 자리',
      '오늘의 도시락',
      '모두 모인 얼굴',
      '아이들이 고른 놀이',
      '그늘 아래 잠깐',
      '나눠 먹는 간식',
      '친구가 도착했다',
      '해가 기울 때까지',
      '남겨 온 장면들',
      '다음 일요일에도',
    ],
  ),
  sharedSeasons(
    'shared-seasons',
    '같이 사는 계절',
    '커플·기념일',
    '손으로 적은 편지와 수제지, 두 사람의 생활 사진집',
    'couple_anniversary',
    '#5D525F',
    'Eulyoo',
    'studioCottonRag',
    [
      '우리의 문을 열고',
      '두 사람이 고른 자리',
      '아침의 순서',
      '장 보러 가는 길',
      '같이 만든 저녁',
      '비 오는 주말',
      '집 밖의 단골 자리',
      '기념일의 작은 준비',
      '서로에게 남긴 말',
      '계절이 바뀌는 동안',
      '우리 집의 작은 물건',
      '돌아올 곳이 있다는 것',
    ],
  ),
  littleCompanion(
    'little-companion',
    '작은 동거인',
    '반려동물',
    '직조 장난감과 관찰 노트, 함께 사는 집의 풍경',
    'pet_cat',
    '#31666A',
    'BookMyungjo',
    'lifeRopeBall',
    [
      '우리 집의 새 식구',
      '너를 소개합니다',
      '아침의 단골 자리',
      '가장 좋아하는 장난감',
      '놀다가 쉬다가',
      '간식 소리가 나면',
      '창가를 지키는 시간',
      '외출을 준비하며',
      '너의 작은 버릇',
      '나란히 쉬는 오후',
      '오래 쓴 물건들',
      '내일도 같이 살자',
    ],
  );

  const ConceptVolume(
    this.id,
    this.title,
    this.category,
    this.concept,
    this.coverPhoto,
    this.ink,
    this.font,
    this.signatureMaterial,
    this.chapters,
  );
  final String id,
      title,
      category,
      concept,
      coverPhoto,
      ink,
      font,
      signatureMaterial;
  final List<String> chapters;
  static ConceptVolume? byId(String id) =>
      values.where((v) => v.id == id).firstOrNull;
  bool get isApprovedDesign => approvedConceptVolumes.contains(this);
  int get contentRevision => this == sharedSeasons
      ? 3
      : lifeConceptVolumes.contains(this)
      ? 2
      : 1;
  EditorialCopy get defaultCopy => EditorialCopy(
    place: title,
    period: this == silkVows ? '2026. 10. 17' : '2026. 06',
    byline: switch (this) {
      silkVows || sharedSeasons => '서연과 지우',
      shoreDays => '우리의 해안 여행',
      readingRoom => '지우의 독서 기록',
      firstWardrobe => '서우의 첫해',
      sundayPicnic => '함께 보낸 일요일',
      littleCompanion => '보리의 생활 기록',
    },
    note: switch (this) {
      silkVows => '서로의 이야기를 끝까지 듣고,\n평범한 날에도 같이 웃기로 했다.',
      shoreDays => '바닷가에서는 시간을 자주 잊었다.\n돌아와서도 그 길을 기억하고 싶다.',
      readingRoom => '좋아하는 구절 옆에 날짜를 적었다.\n그날의 풍경도 함께 남겨 둔다.',
      firstWardrobe => '금세 작아진 옷을 접어 두었다.\n함께 자란 마음도 여기에 남긴다.',
      sundayPicnic => '다 같이 앉으니 자리가 더 좋아졌다.\n다음에도 같은 곳에서 만나자.',
      sharedSeasons => '사소한 하루를 나누는 사이가 됐다.\n내일도 같은 문을 열고 들어오자.',
      littleCompanion => '말없이 곁에 있어 주는 너에게.\n우리의 평범한 하루를 남겨 둔다.',
    },
  );
  Map<String, dynamic> document(
    CollectionAspect aspect, {
    EditorialCopy? copy,
  }) {
    final book = _ConceptBook(this, aspect, copy ?? defaultCopy);
    if (lifeConceptVolumes.contains(this)) {
      _lifeConceptCover(book);
    } else {
      book.cover();
    }
    switch (this) {
      case silkVows:
        _conceptWedding(book);
      case shoreDays:
        _conceptCoast(book);
      case readingRoom:
        _conceptReading(book);
      case firstWardrobe:
        _conceptBaby(book);
      case sundayPicnic:
        _conceptFamily(book);
      case sharedSeasons:
        _conceptCouple(book);
      case littleCompanion:
        _conceptPet(book);
    }
    if (book.pages.length != 25) throw StateError('$id needs cover + 24 pages');
    return {
      'id': 'snapfit_concept_${id}_${aspect.name}',
      'collectionId': id,
      'editionId': '$id-24',
      'title': title,
      'category': category,
      'concept': concept,
      'source': 'snapfit-authored-concept-volume',
      'aiGenerated': false,
      'version': contentRevision,
      'innerPageCount': 24,
      'qualityBaseline': 'luminous-edition:spread-contrast-8',
      'aspect': aspect.name,
      'designWidth': aspect.canvas.width,
      'designHeight': aspect.canvas.height,
      'accessTier': 'premium',
      'intendedTier': 'premium',
      'catalogPublishable': false,
      'approvalStatus': isApprovedDesign
          ? 'approved-volume-design'
          : 'awaiting-design-review',
      if (isApprovedDesign)
        'approvedAt': this == sharedSeasons ? '2026-09-10' : '2026-09-09',
      'publicationStatus': isApprovedDesign
          ? 'production-review'
          : 'design-review',
      'releaseGates': {
        'design': isApprovedDesign ? 'approved' : 'pending',
        'printProof': 'pending',
        'distributionRights': 'pending',
        'price': 'launch-price-set-sale-held',
        'commerceIntegration': 'not-published',
      },
      'cover': book.pages.first,
      'pages': book.pages.skip(1).toList(),
      'chapters': [
        for (final c in chapters.indexed)
          {'title': c.$2, 'from': c.$1 * 2 + 1, 'to': c.$1 * 2 + 2},
      ],
    };
  }
}

class _ConceptBook {
  _ConceptBook(this.volume, this.aspect, this.copy);
  final ConceptVolume volume;
  final CollectionAspect aspect;
  final EditorialCopy copy;
  final pages = <Map<String, dynamic>>[];
  void add(
    String role,
    String background,
    void Function(_ConceptPage) paint, {
    bool dark = false,
    bool cover = false,
  }) {
    final p = _ConceptPage(volume, aspect, pages.length, background);
    paint(p);
    final name = cover
        ? volume.title
        : volume.chapters[(pages.length - 1) ~/ 2];
    if (!cover) p.folio(volume.title, color: dark ? '#F2F5F2' : volume.ink);
    pages.add({
      ...p.json,
      'name': name,
      'role': role,
      'spreadIndex': cover ? 0 : (pages.length + 1) ~/ 2,
      'side': cover
          ? 'cover'
          : pages.length.isOdd
          ? 'left'
          : 'right',
    });
  }

  void cover() => add('full-photo-cover', '#FFFFFF', (p) {
    p.pic(volume.coverPhoto, 0, 0, 1, 1);
    // A light scrim protects editable white titles without obscuring the photo.
    p.box('cover_scrim', 0, 0, 1, 1, '#111C23');
    p.layers.last['opacity'] = .20;
    p.rule(.075, .095, .85, color: '#FFFFFF');
    p.label(
      volume.category == '웨딩'
          ? 'OUR WEDDING / 01'
          : volume.category == '여행'
          ? 'COASTAL JOURNAL / 02'
          : 'A READING LIFE / 03',
      .075,
      .045,
      .85,
      color: '#FFFFFF',
    );
    if (volume == ConceptVolume.silkVows) {
      p.txt(copy.place, .075, .14, .85, .15, size: .104, color: '#FFFFFF');
      p.txt(
        '서로에게 건넨 약속을\n한 권에 묶다',
        .08,
        .31,
        .6,
        .15,
        size: .028,
        color: '#FFFFFF',
        font: 'NotoSans',
      );
      p.mat('waveSilkKnot', .74, .74, .22, .19);
    } else if (volume == ConceptVolume.shoreDays) {
      p.txt(
        copy.place == volume.title ? '해변에서\n보낸 날' : copy.place,
        .075,
        .14,
        .82,
        .31,
        size: .100,
        color: '#FFFFFF',
      );
      p.label(
        'WALKS, POSTCARDS & SMALL FINDS',
        .08,
        .49,
        .82,
        color: '#FFFFFF',
      );
    } else {
      p.txt(
        copy.place == volume.title ? '문장을\n모으는 생활' : copy.place,
        .075,
        .13,
        .86,
        .32,
        size: .094,
        color: '#FFFFFF',
      );
      p.txt('읽고 적으며 남긴 장면들', .08, .50, .8, .08, size: .03, color: '#FFFFFF');
    }
    p.txt(
      copy.byline,
      .08,
      .83,
      .8,
      .055,
      size: .027,
      color: '#FFFFFF',
      font: 'NotoSans',
    );
    p.label(copy.period, .08, .91, .8, color: '#FFFFFF');
  }, cover: true);
}

/// Native layer primitives; composition is authored separately for every page.
class _ConceptPage extends _Sheet {
  _ConceptPage(
    this.volume,
    CollectionAspect aspect,
    int index,
    String background,
  ) : super(
        volume.id,
        aspect,
        index,
        background,
        ink: volume.ink,
        display: volume.font,
      );
  final ConceptVolume volume;
  final _photoTextIds = <String>[];
  @override
  Map<String, dynamic> get json => {
    ...super.json,
    if (_photoTextIds.isNotEmpty) 'photoOverlayTextIds': _photoTextIds,
  };
  String get uid => 'part_${layers.length}';
  void pic(
    String file,
    double x,
    double y,
    double w,
    double h, {
    String frame = 'none',
    double turn = 0,
  }) => photo(
    uid,
    '$_editorial$file.png',
    x,
    y,
    w,
    h,
    shape: frame,
    rotation: turn,
  );
  Rect mat(
    String key,
    double x,
    double y,
    double w,
    double h, {
    double turn = 0,
  }) {
    final r = studioDecorationById(key)!.aspectRatio;
    final width = math.min(w, h * r / ratio);
    material(uid, key, x, y, width, rotation: turn);
    return Rect.fromLTWH(x, y, width, width * ratio / r);
  }

  void paperText(
    Rect paper,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .027,
    String? font,
  }) => txt(
    value,
    paper.left + x * paper.width,
    paper.top + y * paper.height,
    paper.width * w,
    paper.height * h,
    size: size,
    font: font,
  );

  void txt(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .036,
    String? color,
    String? font,
    int weight = 400,
    String align = 'left',
    double lineHeight = 1.3,
  }) => text(
    uid,
    value,
    x,
    y,
    w,
    h,
    size: size,
    color: color ?? ink,
    font: font ?? volume.font,
    weight: weight,
    align: align,
    lineHeight: lineHeight,
  );
  void label(String value, double x, double y, double w, {String? color}) =>
      txt(value, x, y, w, .055, size: .019, color: color, font: 'NotoSans');
  void rule(double x, double y, double w, {String? color}) =>
      box(uid, x, y, w, .0016 * ratio, color ?? ink);
  void numeral(
    String value,
    double x,
    double y,
    double w,
    double h, {
    String? color,
    double size = .19,
  }) => txt(
    value,
    x,
    y,
    w,
    h,
    size: size,
    color: color,
    font: 'Cormorant Garamond',
    lineHeight: 1.0,
  );
  void mount(
    String file,
    double x,
    double y,
    double w,
    double h, {
    String frame = 'atelierDeepMat',
  }) => pic(file, x, y, w, h, frame: frame);
  void caption(String value, double x, double y, double w) =>
      txt(value, x, y, w, .075, size: .024, font: 'NotoSans');
}

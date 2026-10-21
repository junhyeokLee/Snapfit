part of 'authored_collections.dart';

enum StudioEdition {
  alleyAfternoon('alley-afternoon', -9471, '골목의 오후', '일상', false),
  cityAfterglow('city-afterglow', -9531, '도시의 잔광', '여행', true),
  saturdayTogether('saturday-together', -9472, '같이 보낸 토요일', '가족·친구', false),
  summerKeepsakeBox('summer-keepsake-box', -9532, '한여름 수집함', '가족·친구', true),
  dailyPawWalk('daily-paw-walk', -9473, '오늘도 산책!', '반려동물', false),
  companionJournal('companion-journal', -9533, '우리 집 주인공', '반려동물', true),
  ourFirstPromise('our-first-promise', -9474, '우리의 첫 약속', '웨딩', false),
  velvetVowArchive('velvet-vow-archive', -9534, '벨벳 서약집', '웨딩', true),
  littleDayDiscoveries(
    'little-day-discoveries',
    -9475,
    '작은 날의 발견',
    '성장·육아',
    false,
  ),
  littleExplorerBook('little-explorer-book', -9535, '꼬마 탐험 사전', '성장·육아', true);

  const StudioEdition(
    this.id,
    this.catalogId,
    this.title,
    this.category,
    this.premium,
  );
  final String id, title, category;
  final int catalogId;
  final bool premium;
  bool get familyEdition =>
      this == saturdayTogether || this == summerKeepsakeBox;
  bool get petEdition => this == dailyPawWalk || this == companionJournal;
  bool get weddingEdition =>
      this == ourFirstPromise || this == velvetVowArchive;
  bool get discoveryEdition =>
      this == littleDayDiscoveries || this == littleExplorerBook;
  bool get milestoneEdition => weddingEdition || discoveryEdition;
  String get subtitle => switch (this) {
    alleyAfternoon => '가게와 작은 장면을 담는 동네 산책 사진집',
    cityAfterglow => '야간 도시 포토저널 · 절취 반권과 사진 보관 폴더',
    saturdayTogether => '소풍과 식탁, 함께 웃은 하루의 기록',
    summerKeepsakeBox => '여름 소풍 아카이브 · 직조 매트와 접힌 사진 띠',
    dailyPawWalk => '선명한 블루와 노란 기록지 · 매일의 산책 사진 일지',
    companionJournal => '컴패니언 매거진 · 초상과 행동, 생활을 담는 관찰 사진집',
    ourFirstPromise => '바다와 하얀 사진 여백 · 두 사람의 시작을 담는 웨딩 북',
    velvetVowArchive => '벨벳 서약 아카이브 · 접힌 초대장과 코튼 압인 사진 창',
    littleDayDiscoveries => '밝은 성장 일지 · 처음 만난 표정과 작은 생활의 기록',
    littleExplorerBook => '그림책형 발견 아카이브 · 색인 슬라이드와 탐험 스티치',
  };
  String get productKey => 'template:$id';
  String get coverAsset => 'assets/templates/atelier_editions_2026/$id.png';
  int get innerPageCount => premium ? 32 : 24;
  List<String> get chapters => _studioStories[this]!.map((s) => s.$1).toList();
  static StudioEdition? byId(String id) =>
      values.where((e) => e.id == id).firstOrNull;

  Map<String, dynamic> document(CollectionAspect aspect) {
    final cover = _StudioPage(this, aspect, 0, premium ? '#182C32' : '#F8F8F3');
    if (milestoneEdition) {
      _studioMilestoneCover(cover, this);
    } else if (petEdition) {
      _studioPetCover(cover, this);
    } else if (familyEdition) {
      _studioFamilyCover(cover, this);
    } else {
      cover.photo('cover_photo', coverAsset, 0, 0, 1, 1);
      if (premium) _coverShade(cover, top: true, strength: .42);
      cover.type(
        premium ? 'AFTER / HOURS' : 'NEIGHBOURHOOD NOTES',
        .08,
        .055,
        .84,
        .05,
        size: .020,
        color: premium ? '#FFFFFF' : '#183C44',
        font: 'Poppins',
        weight: 600,
      );
      cover.type(
        premium ? '도시의\n잔광' : '골목의\n오후',
        .08,
        .14,
        .78,
        .27,
        size: premium ? .105 : .098,
        color: premium ? '#FFFFFF' : '#183C44',
        font: premium ? 'BookMyungjo' : 'NotoSans',
        weight: premium ? 800 : 600,
      );
      cover.type(
        '2026 / OUR PHOTO JOURNAL',
        .08,
        .91,
        .84,
        .045,
        size: .018,
        color: premium ? '#FFFFFF' : '#183C44',
        font: 'Poppins',
      );
    }
    final pages = <Map<String, dynamic>>[];
    for (var spread = 0; spread < chapters.length; spread++) {
      final pair = weddingEdition
          ? _studioVowSpread(this, aspect, spread)
          : discoveryEdition
          ? _studioDiscoverySpread(this, aspect, spread)
          : petEdition
          ? _studioPetSpread(this, aspect, spread)
          : familyEdition
          ? _studioFamilySpread(this, aspect, spread)
          : _studioSpread(this, aspect, spread);
      for (final p in pair) {
        p.folio(title, color: p.ink);
        pages.add({
          ...p.json,
          'name': chapters[spread],
          'role': 'studio-$spread-${p.index.isOdd ? 'left' : 'right'}',
          'side': p.index.isOdd ? 'left' : 'right',
          'spreadIndex': spread + 1,
        });
      }
    }
    final doc = <String, dynamic>{
      'id': 'snapfit_studio_${id}_${aspect.name}',
      'collectionId': id,
      'editionId': '$id-$innerPageCount',
      'title': title,
      'category': category,
      'source': 'snapfit-authored-studio',
      'aiGenerated': false,
      'samplePhotography': 'generated-and-bundled-samples',
      'version': 1,
      'qualityRevision': milestoneEdition
          ? 'wedding-growth-2026-10-18'
          : petEdition
          ? 'pet-editorial-2026-10-16'
          : familyEdition
          ? 'family-archive-2026-10-16'
          : 'studio-pairs-2026-10-16',
      'aspect': aspect.name,
      'designWidth': aspect.canvas.width,
      'designHeight': aspect.canvas.height,
      'innerPageCount': innerPageCount,
      'accessTier': premium ? 'premium' : 'free',
      'catalogPublishable': false,
      'publicationStatus': premium ? 'registration-approved' : 'bundled',
      'releaseGates': {
        'design': 'owner-approved',
        'printProof': 'pending',
        'distributionRights': 'pending',
        'commerceIntegration': 'awaiting-server-activation',
      },
      'chapters': [
        for (var i = 0; i < chapters.length; i++)
          {'title': chapters[i], 'from': i * 2 + 1, 'to': i * 2 + 2},
      ],
      'cover': {
        ...cover.json,
        'name': title,
        'role': 'studio-photo-cover',
        'side': 'cover',
        'spreadIndex': 0,
      },
      'pages': pages,
    };
    if (!premium) {
      validateFreeTemplateMaterials(doc);
      doc['materialPolicyRevision'] = freeTemplateMaterialPolicyRevision;
    }
    return doc;
  }

  Map<String, dynamic> catalogDocument() => {
    ...(premium
        ? refinePaidCatalogDocument(
            id,
            CollectionAspect.square,
            document(CollectionAspect.square),
          )
        : document(CollectionAspect.square)),
    'variants': {
      for (final a in CollectionAspect.values)
        a.name: premium
            ? refinePaidCatalogDocument(id, a, document(a))
            : document(a),
    },
  };
}

const _studioStories = {
  StudioEdition.ourFirstPromise: _firstPromiseStories,
  StudioEdition.velvetVowArchive: _velvetVowStories,
  StudioEdition.littleDayDiscoveries: _littleDayStories,
  StudioEdition.littleExplorerBook: _explorerStories,
  StudioEdition.dailyPawWalk: _pawWalkStories,
  StudioEdition.companionJournal: _companionStories,
  StudioEdition.saturdayTogether: _saturdayStories,
  StudioEdition.summerKeepsakeBox: _summerStories,
  StudioEdition.alleyAfternoon: [
    ('집을 나서는 오후', '목적지를 정하지 않고, 익숙한 길을 조금 다르게 걸었다.'),
    ('모퉁이에서 잠깐', '그냥 지나쳤던 가게 앞에서 처음으로 걸음을 멈췄다.'),
    ('열린 문 너머로', '문을 열자 커피 향과 낮은 인사가 함께 건너왔다.'),
    ('눈에 들어온 작은 것', '간판보다 오래 바라본 것은 창가의 작은 물건들이었다.'),
    ('한 블록 더 걸어서', '다음 모퉁이까지 걷고, 사진을 한 장 더 남겼다.'),
    ('창가에 앉은 시간', '주문한 잔이 비워질 때까지 바깥을 천천히 보았다.'),
    ('가볍게 들고 온 것', '꼭 필요한 것은 아니었지만 오늘을 닮아서 골랐다.'),
    ('다시 걷기 좋은 길', '볕이 달라지니 같은 길도 다른 표정이 되었다.'),
    ('지도를 접어 두고', '아는 길을 따라가다 모르는 골목으로 들어섰다.'),
    ('좋아하는 가게 앞', '다음에도 혼자 혹은 함께, 다시 와 보고 싶은 곳.'),
    ('오늘의 산책 목록', '주소보다 잘 기억나는 장면들을 순서 없이 적었다.'),
    ('집에 돌아와 펼치면', '멀리 가지 않아도 남겨 두고 싶은 하루가 있었다.'),
  ],
  StudioEdition.cityAfterglow: [
    ('해가 진 뒤에 도착', '가방을 내려놓고 저녁의 도시를 만나러 나갔다.'),
    ('첫 번째 승차권', '목적지보다 창밖을 오래 보게 된 짧은 이동.'),
    ('비가 그친 교차로', '사람들이 건너는 동안 바닥에 남은 불빛을 찍었다.'),
    ('유리창 안쪽의 자리', '젖은 외투를 벗고, 오늘 걸은 길을 펼쳐 보았다.'),
    ('다른 속도로 걷기', '한 번은 멈추고, 한 번은 뒤돌아보며 걸었다.'),
    ('접어 둔 도시 지도', '가 보고 싶은 곳보다 다시 돌아올 길을 표시했다.'),
    ('잠깐의 정차', '문이 열리고 닫히는 사이, 사람들의 하루가 스쳤다.'),
    ('저녁을 고르는 시간', '낯선 메뉴 앞에서 서로 다른 것을 하나씩 골랐다.'),
    ('사진이 된 창문들', '불이 켜진 창마다 잠시 다른 이야기를 상상했다.'),
    ('주머니 속 종이들', '구겨진 반권과 영수증을 버리지 않고 넣어 두었다.'),
    ('같은 거리의 두 표정', '조금 전과 지금, 같은 장소를 두 번 남겼다.'),
    ('늦은 잔을 비우며', '다음 일정 대신 오늘 좋았던 곳을 이야기했다.'),
    ('돌아가는 길의 장면', '한 번 더 카메라를 꺼내게 된 마지막 모퉁이.'),
    ('밤 산책의 기록', '몇 시에 어디를 걸었는지, 작게 적어 두었다.'),
    ('두고 온 도시에게', '다시 오면 가장 먼저 걷고 싶은 길이 생겼다.'),
    ('사진집을 덮기 전에', '이 도시에서 보낸 우리의 저녁을 한 권에 묶었다.'),
  ],
};

class _StudioPage extends _Sheet {
  _StudioPage(
    this.edition,
    CollectionAspect aspect,
    int index,
    String paper, {
    bool dark = false,
  }) : super(
         edition.id,
         aspect,
         index,
         paper,
         ink: dark ? '#F5F6EF' : '#233A3E',
       );
  final StudioEdition edition;
  String get uid => 'piece_${layers.length}';
  void type(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .032,
    String? color,
    String font = 'NotoSans',
    int weight = 400,
  }) => _fittedEditorialType(
    this,
    uid,
    value,
    Rect.fromLTWH(x, y, w, h),
    font: font,
    size: size,
    color: color ?? ink,
    weight: weight,
    leading: 1.3,
  );
  void heading(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .065,
  }) => type(
    value,
    x,
    y,
    w,
    h,
    size: size,
    font: edition.premium ? 'BookMyungjo' : 'NotoSans',
    weight: 600,
  );
  void rule(double x, double y, double w, {String? color}) =>
      box(uid, x, y, w, .0015 * ratio, color ?? ink);
  void scene(
    String asset,
    double x,
    double y,
    double w,
    double h, {
    String frame = 'none',
    bool fill = false,
    double turn = 0,
  }) {
    final width = fill ? w : math.min(w, h * 1.5 / ratio);
    final height = fill ? h : width * ratio / 1.5;
    final photoId = uid;
    photo(photoId, asset, x + (w - width) / 2, y, width, height, shape: frame);
    if (turn != 0) layers.last['rotation'] = turn;
  }

  void mat(
    String key,
    double x,
    double y,
    double w,
    double h, {
    double turn = 0,
  }) {
    final r = studioDecorationById(key)!.aspectRatio;
    final width = math.min(w, h * r / ratio);
    material(uid, key, x, y, width, h: width * ratio / r, rotation: turn);
  }
}

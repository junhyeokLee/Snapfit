part of 'authored_collections.dart';

/// New artwork is delivered locally; server review still controls paid access.
enum AtelierEdition {
  nightVows(
    'night-vows',
    -9521,
    '밤에 피어난 약속',
    '웨딩',
    '나이트 가든 · 새틴과 초대장, 촛불 아래의 웨딩 북',
    '#202C40',
    '#DDE3EE',
    '#B7A178',
    '#F4F0E8',
    'BookMyungjo',
    [
      'materialLace',
      'heirloomVowEnvelope',
      'heirloomVowSeal',
      'studioRoseSilk',
    ],
    ['editionCameo', 'atelierDeco', 'materialLaceMount'],
  ),
  slowRail(
    'slow-rail',
    -9522,
    '느린 열차의 기록',
    '여행',
    '레일 저널 · 노선과 승차권, 창밖의 풍경을 모은 여행집',
    '#693A35',
    '#D9E9EB',
    '#C9A157',
    '#F2EEE6',
    'Eulyoo',
    [
      'atelierBoardingStub',
      'materialContourMap',
      'studioPostalMark',
      'studioTravelMap',
    ],
    ['studioTicket', 'atelierAccordion', 'studioPostage'],
  ),
  greenHours(
    'green-hours',
    -9523,
    '초록을 돌보는 날',
    '일상',
    '보태니컬 다이어리 · 압화와 관찰지, 초록을 돌보는 생활',
    '#294C38',
    '#DCE6CB',
    '#B6A550',
    '#F4F1E5',
    'BookMyungjo',
    [
      'studioPressedCosmos',
      'materialSpecimenPocket',
      'studioBotanicalStamp',
      'studioCitrusPrint',
    ],
    ['studyArchWindow', 'studioDeckle', 'materialNotebookMount'],
  ),
  firstOrbit(
    'first-orbit',
    -9524,
    '너의 첫 번째 행성',
    '성장·육아',
    '첫해의 관측 일지 · 코튼과 둥근 창, 작은 성장의 궤적',
    '#34536B',
    '#DDE8F0',
    '#D9AC68',
    '#F6F1E5',
    'Eulyoo',
    ['materialBooties', 'materialMonthDial', 'lifeRattle', 'lifeWardrobeLabel'],
    ['studioOvalMat', 'editionScallop', 'materialScallopMount'],
  ),
  tableStories(
    'family-recipe-book',
    -9525,
    '우리 집의 한 접시',
    '가족·친구',
    '패밀리 레시피 북 · 식탁의 체크와 손글씨, 같이 만든 저녁',
    '#8D3933',
    '#E9E1C8',
    '#728151',
    '#F7F1E6',
    'BookMyungjo',
    [
      'materialRecipeFoldout',
      'lifeGingham',
      'lifeBasket',
      'materialCrossStitchBand',
    ],
    ['atelierWeave', 'studioLinen', 'studioScallop'],
  ),
  privateCinema(
    'private-cinema',
    -9526,
    '둘만의 상영관',
    '커플·기념일',
    '시네마 스크랩북 · 필름과 영화표, 두 사람이 남긴 장면',
    '#592C36',
    '#E8D5D4',
    '#BF9A5F',
    '#F1E9DF',
    'Eulyoo',
    [
      'heirloomCinemaStub',
      'materialTicketDuo',
      'studioKeepsakeTicket',
      'materialAirLetter',
    ],
    ['atelierNegative', 'materialSlideMount', 'zineContact'],
  ),
  walkMap(
    'walk-map',
    -9527,
    '너와 걷는 지도',
    '반려동물',
    '워크 클럽 · 산책 지도와 이름표, 발맞춰 걷는 매일',
    '#345C4F',
    '#E5DEF0',
    '#A69B67',
    '#F0F2E7',
    'BookMyungjo',
    [
      'materialLeash',
      'heirloomPetTag',
      'materialWalkLedger',
      'materialNamePatch',
    ],
    ['studioCapsule', 'atelierOxford', 'studioRounded'],
  );

  const AtelierEdition(
    this.id,
    this.catalogId,
    this.title,
    this.category,
    this.concept,
    this.ink,
    this.tint,
    this.accent,
    this.paper,
    this.font,
    this.materials,
    this.frames,
  );
  final String id, title, category, concept, ink, tint, accent, paper, font;
  final int catalogId;
  final List<String> materials, frames;
  String get coverAsset => 'assets/templates/atelier_editions_2026/$id.png';
  String get productKey => 'template:$id';
  String get byline => switch (this) {
    nightVows => '서연과 지우',
    slowRail => '우리의 철도 여행',
    greenHours => '나의 초록 일기',
    firstOrbit => '서우의 첫해',
    tableStories => '우리 집 식탁',
    privateCinema => '두 사람의 기록',
    walkMap => '보리의 산책',
  };
  String get signatureMaterial => switch (this) {
    nightVows => 'editionNightSeal',
    slowRail => 'editionRailBundle',
    greenHours => 'editionBotanicalPassport',
    firstOrbit => 'editionOrbitMobile',
    tableStories => 'editionRecipeBundle',
    privateCinema => 'editionCinemaBundle',
    walkMap => 'editionWalkPatch',
  };
  String get paperMaterial => atelierLayeredMaterialKits[id]![0];
  String get mountMaterial => atelierLayeredMaterialKits[id]![1];
  String get bandMaterial => atelierLayeredMaterialKits[id]![2];
  int get innerPageCount => 32;
  List<String> get chapters =>
      _atelierStories[this]!.map((s) => s.title).toList();

  Map<String, dynamic> document(CollectionAspect aspect) {
    final pages = <Map<String, dynamic>>[];
    final cover = _AtelierPage(this, aspect, 0, paper);
    _atelierCover(cover);
    final coverDocument = {
      ...cover.json,
      'name': title,
      'role': 'atelier-photo-cover',
      'side': 'cover',
      'spreadIndex': 0,
    };
    final stories = _atelierStories[this]!;
    for (final entry in stories.indexed) {
      final pair = _atelierSpread(this, aspect, entry.$1, entry.$2);
      for (final page in pair) {
        page.folio(title, color: page.ink);
        pages.add({
          ...page.json,
          'name': entry.$2.title,
          'role':
              '${entry.$2.layout.name}-${page.index.isOdd ? 'left' : 'right'}',
          'side': page.index.isOdd ? 'left' : 'right',
          'spreadIndex': entry.$1 + 1,
        });
      }
    }
    if (pages.length != innerPageCount)
      throw StateError('$id: incomplete edition');
    return {
      'id': 'snapfit_atelier_${id}_${aspect.name}',
      'collectionId': id,
      'editionId': '$id-32',
      'title': title,
      'category': category,
      'concept': concept,
      'source': 'snapfit-authored-atelier',
      'aiGenerated': false,
      'samplePhotography': 'ai-generated',
      'version': 3,
      'compositionSystem': 'category-layered-atelier',
      'interiorDirection': 'individual-spreads-per-topic',
      'aspect': aspect.name,
      'innerPageCount': innerPageCount,
      'designWidth': aspect.canvas.width,
      'designHeight': aspect.canvas.height,
      'accessTier': 'premium',
      'intendedTier': 'premium',
      'catalogPublishable': false,
      'approvalStatus': 'owner-approved-digital-registration',
      'releaseGates': {
        'design': 'owner-approved',
        'printProof': 'pending',
        'price': 'approved-awaiting-server',
        'commerceIntegration': 'awaiting-server-activation',
      },
      'cover': coverDocument,
      'pages': pages,
      'chapters': [
        for (final e in stories.indexed)
          {'title': e.$2.title, 'from': e.$1 * 2 + 1, 'to': e.$1 * 2 + 2},
      ],
    };
  }

  Map<String, dynamic> catalogDocument() => {
    ...refinePaidCatalogDocument(
      id,
      CollectionAspect.square,
      document(CollectionAspect.square),
    ),
    'variants': {
      for (final aspect in CollectionAspect.values)
        aspect.name: refinePaidCatalogDocument(id, aspect, document(aspect)),
    },
  };
}

class _AtelierPage extends _Sheet {
  _AtelierPage(
    this.edition,
    CollectionAspect aspect,
    int index,
    String background, {
    bool reverse = false,
  }) : super(
         edition.id,
         aspect,
         index,
         background,
         ink: reverse ? edition.paper : edition.ink,
         display: edition.font,
       );
  final AtelierEdition edition;
  String get uid => 'element_${layers.length}';
  void pic(
    String source,
    double x,
    double y,
    double w,
    double h, {
    String frame = 'none',
    double turn = 0,
  }) => photo(
    uid,
    source == '@cover'
        ? edition.coverAsset
        : source.startsWith('assets/')
        ? source
        : '$_editorial$source.png',
    x,
    y,
    w,
    h,
    shape: frame,
    rotation: turn,
  );
  void txt(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .029,
    String? color,
    String? font,
    int weight = 400,
    String align = 'left',
    double leading = 1.25,
  }) => text(
    uid,
    value,
    x,
    y,
    w,
    h,
    size: size,
    color: color ?? ink,
    font: font ?? edition.font,
    weight: weight,
    align: align,
    lineHeight: leading,
  );
  void label(String value, double x, double y, double w, {String? color}) =>
      txt(value, x, y, w, .045, size: .017, color: color, font: 'NotoSans');
  void hand(String value, double x, double y, double w, {String? color}) =>
      txt(value, x, y, w, .10, size: .047, color: color, font: 'NanumPen');
  void rule(double x, double y, double w, {String? color}) =>
      box(uid, x, y, w, .0018 * ratio, color ?? ink);
  void plate(double x, double y, double w, double h, {String? color}) {
    box(uid, x + .008, y + .009, w, h, edition.accent);
    box(uid, x, y, w, h, color ?? edition.paper);
    rule(x + .025, y + .028, w - .05, color: edition.accent);
  }

  Rect mat(
    String key,
    double x,
    double y,
    double w,
    double h, {
    double turn = 0,
  }) {
    final spec = studioDecorationById(key)!;
    final width = math.min(w, h * spec.aspectRatio / ratio);
    material(uid, key, x, y, width, rotation: turn);
    return Rect.fromLTWH(x, y, width, width * ratio / spec.aspectRatio);
  }

  /// Procedural stock reflows its grain and folds; bitmap cutouts never stretch.
  Rect stock(
    String key,
    double x,
    double y,
    double w,
    double h, {
    double turn = 0,
  }) {
    final spec = studioDecorationById(key)!;
    if (spec.assetPath != null)
      throw ArgumentError('Use mat for bitmap material $key');
    material(uid, key, x, y, w, h: h, rotation: turn);
    return Rect.fromLTWH(x, y, w, h);
  }

  void tag(
    String value,
    double x,
    double y,
    double w, {
    bool inverted = false,
  }) {
    box(uid, x, y, w, .052, inverted ? edition.paper : edition.ink);
    txt(
      value,
      x + .014,
      y + .006,
      w - .028,
      .04,
      size: .018,
      font: 'NotoSans',
      color: inverted ? edition.ink : edition.paper,
    );
  }

  /// Mount dimensions are physical: a round aperture stays round in every book.
  Rect mount(String source, double x, double y, double w, double h) {
    final spec = studioDecorationById(edition.mountMaterial)!;
    final width = math.min(w, h * spec.aspectRatio / ratio);
    final height = width * ratio / spec.aspectRatio;
    final left = x + (w - width) / 2;
    final top = y + (h - height) / 2;
    final hole = atelierMountWindow(spec.id);
    pic(
      source,
      left + hole.left * width,
      top + hole.top * height,
      hole.width * width,
      hole.height * height,
      frame: edition == AtelierEdition.firstOrbit ? 'studioOval' : 'none',
    );
    material(uid, spec.id, left, top, width);
    return Rect.fromLTWH(left, top, width, height);
  }

  /// Fit an intact photograph into a layout region, including short wide pages.
  Rect scene(
    String source,
    double x,
    double y,
    double w,
    double h, {
    String frame = 'studioDoubleMat',
    double turn = 0,
    double photoRatio = 1.5,
    Alignment alignment = Alignment.center,
  }) {
    final width = math.min(w, h * photoRatio / ratio);
    final height = width * ratio / photoRatio;
    final rect = Rect.fromLTWH(
      x + (w - width) * (alignment.x + 1) / 2,
      y + (h - height) * (alignment.y + 1) / 2,
      width,
      height,
    );
    pic(
      source,
      rect.left,
      rect.top,
      rect.width,
      rect.height,
      frame: frame,
      turn: turn,
    );
    return rect;
  }

  void binding(String value, double x, double y, double w, double h) {
    final rect = mat(edition.bandMaterial, x, y, w, h);
    final dark =
        edition == AtelierEdition.nightVows ||
        edition == AtelierEdition.privateCinema;
    final textWidth = rect.width * .62;
    var fontSize = math.min(
      unit * .019,
      rect.height * aspect.canvas.height * .26,
    );
    final measure = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: value,
        style: TextStyle(fontFamily: 'NotoSans', fontSize: fontSize),
      ),
    )..layout();
    if (measure.width > 0) {
      fontSize *= math.min(
        1,
        textWidth * aspect.canvas.width * .96 / measure.width,
      );
    }
    measure.dispose();
    txt(
      value,
      rect.left + rect.width * .075,
      rect.top + rect.height * .28,
      textWidth,
      rect.height * .47,
      size: fontSize / unit,
      color: dark ? edition.paper : edition.ink,
      font: 'NotoSans',
    );
  }
}

void _atelierCover(_AtelierPage p) {
  final e = p.edition;
  p.pic('@cover', 0, 0, 1, 1);
  final light =
      e == AtelierEdition.firstOrbit ||
      e == AtelierEdition.walkMap ||
      e == AtelierEdition.slowRail;
  final color = light ? e.ink : e.paper;
  if (!light) {
    p._add('cover_title_shade', 'decoration', 0, 0, 1, .55, {
      'style': 'photoCoverShadeTop',
      'opacity':
          e == AtelierEdition.tableStories || e == AtelierEdition.privateCinema
          ? .82
          : .35,
    });
  }
  if (e == AtelierEdition.tableStories) {
    p._add('cover_caption_shade', 'decoration', 0, .75, 1, .25, {
      'style': 'photoCoverShadeBottom',
      'opacity': .70,
    });
  }
  final title = switch (e) {
    AtelierEdition.nightVows => '밤에 피어난\n약속',
    AtelierEdition.slowRail => '느린 열차의\n기록',
    AtelierEdition.greenHours => '초록을\n돌보는 날',
    AtelierEdition.firstOrbit => '너의 첫 번째\n행성',
    AtelierEdition.tableStories => '우리 집의\n한 접시',
    AtelierEdition.privateCinema => '둘만의\n상영관',
    AtelierEdition.walkMap => '너와 걷는\n지도',
  };
  // Wide sources crop vertically, so all title and date live inside the safe top band.
  p.label('SNAPFIT ATELIER / ${e.category}', .075, .055, .85, color: color);
  p.txt(
    title,
    .07,
    .13,
    .82,
    .29,
    size: .100,
    color: color,
    weight: e.font == 'BookMyungjo' ? 800 : 400,
    leading: 1.12,
  );
  p.rule(.075, .445, .17, color: color);
  p.label('2026 / OUR PERSONAL ARCHIVE', .075, .475, .85, color: color);
  p.label('PHOTO ALBUM / ${e.byline}', .075, .90, .85, color: color);
}

import 'package:flutter/painting.dart';

import '../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../core/templates/studio_phrase_catalog.dart';
import '../../../../core/templates/studio_word_art_catalog.dart';

enum MaterialPreviewPlacement { card, backing, accent, frame, lettering, band }

/// Preview-only geometry. Catalog artwork and saved album layers stay unchanged.
class MaterialPreviewComposition {
  const MaterialPreviewComposition({
    required this.placement,
    required this.materialRect,
    required this.caption,
    this.photoAsset,
    this.photoRect,
    this.captionRect,
    this.sampleText,
    this.sampleTextRect,
    this.serif = false,
    this.paperColor = const Color(0xFFF7F8F6),
    this.photoAlignment = Alignment.center,
    this.letteringSourceSize,
    this.circularPhoto = false,
    this.sampleTextColor = const Color(0xFF3D524B),
  });

  static const canvas = Size(600, 680);
  final MaterialPreviewPlacement placement;
  final Rect materialRect;
  final Rect? photoRect, captionRect, sampleTextRect;
  final String? photoAsset, sampleText;
  final String caption;
  final bool serif;
  final Color paperColor;
  final Alignment photoAlignment;
  final Size? letteringSourceSize;
  final bool circularPhoto;
  final Color sampleTextColor;
  bool get materialBelowPhoto => placement == MaterialPreviewPlacement.backing;

  factory MaterialPreviewComposition.forProduct(
    String productKey,
    String type, {
    int photoIndex = 0,
  }) {
    final id = productKey.split(':').last;
    final spec = studioDecorationById(id);
    final art = studioWordArts
        .where((a) => a.productKey == productKey)
        .firstOrNull;
    final phrase = studioPhrases.where((p) => p.id == id).firstOrNull;
    final theme = _themeFor(spec?.collection ?? phrase?.category, art?.id);
    final scenes = art?.id == 'atelier-postcard'
        ? _letterScenes
        : _scenes[theme]!;
    final curated = _photoOverrides[id];
    final peers = studioDecorations
        .where((s) => s.collection == spec?.collection)
        .toList();
    final ordinal = spec == null
        ? (art == null
              ? studioPhrases.indexOf(phrase ?? studioPhrases.first)
              : studioWordArts.indexOf(art))
        : peers.indexOf(spec);
    final curatedIndex = scenes.indexWhere((scene) => scene.photo == curated);
    final scene =
        scenes[((curatedIndex < 0 ? ordinal : curatedIndex) + photoIndex) %
            scenes.length];
    final photo = scene.photo.startsWith('assets/')
        ? scene.photo
        : 'assets/templates/original_editorial/images/${scene.photo}';
    final ratio = spec?.aspectRatio ?? 1;

    MaterialPreviewComposition compose(
      MaterialPreviewPlacement placement,
      Rect materialBounds,
      Rect? photoRect,
      Rect? captionRect, {
      double? aspect,
      String? sampleText,
      Rect? sampleArea,
      bool serif = false,
      Color? paperColor,
      Size? letteringSourceSize,
      bool circularPhoto = false,
      Color sampleTextColor = const Color(0xFF3D524B),
    }) {
      final material = _fit(aspect ?? ratio, materialBounds);
      return MaterialPreviewComposition(
        placement: placement,
        materialRect: material,
        photoRect: photoRect,
        photoAsset: photoRect == null ? null : photo,
        caption: scene.caption,
        captionRect: captionRect,
        sampleText: sampleText,
        sampleTextRect: sampleArea == null
            ? null
            : Rect.fromLTWH(
                material.left + material.width * sampleArea.left,
                material.top + material.height * sampleArea.top,
                material.width * sampleArea.width,
                material.height * sampleArea.height,
              ),
        serif: serif,
        paperColor: _translucentPapers.contains(id)
            ? const Color(0xFFD5DFDA)
            : paperColor ?? const Color(0xFFF7F8F6),
        photoAlignment: scene.photo == 'growth_birthday.png'
            ? const Alignment(-.4, 0)
            : Alignment.center,
        letteringSourceSize: letteringSourceSize,
        circularPhoto: circularPhoto,
        sampleTextColor: sampleTextColor,
      );
    }

    if (productKey.startsWith('frame:')) {
      return compose(
        MaterialPreviewPlacement.frame,
        const Rect.fromLTWH(36, 28, 528, 532),
        null,
        const Rect.fromLTWH(48, 584, 504, 64),
      );
    }
    if (atelierLayeredDecorations.any((s) => s.id == id)) {
      final support = _fit(ratio, const Rect.fromLTWH(44, 32, 512, 512));
      if (id.endsWith('Mount')) {
        final window = atelierMountWindow(id);
        return compose(
          MaterialPreviewPlacement.frame,
          support,
          Rect.fromLTWH(
            support.left + support.width * window.left,
            support.top + support.height * window.top,
            support.width * window.width,
            support.height * window.height,
          ),
          const Rect.fromLTWH(48, 582, 504, 72),
          circularPhoto: id == 'editionOrbitMount',
        );
      }
      if (id.endsWith('Paper')) {
        return compose(
          MaterialPreviewPlacement.backing,
          support,
          Rect.fromLTWH(
            support.left + support.width * .17,
            support.top + support.height * .15,
            support.width * .66,
            support.height * .46,
          ),
          const Rect.fromLTWH(48, 582, 504, 72),
        );
      }
      final sample = switch (id) {
        'editionGardenBand' => '서연 · 지우',
        'editionRailBand' => 'NEXT STOP',
        'editionHerbariumBand' => 'PLANT NOTES',
        'editionOrbitBand' => '너의 첫해',
        'editionKitchenBand' => '우리 집의 식탁',
        'editionCinemaBand' => 'ADMIT TWO',
        _ => 'WALK CLUB',
      };
      return compose(
        MaterialPreviewPlacement.accent,
        const Rect.fromLTWH(66, 340, 468, 132),
        const Rect.fromLTWH(44, 36, 512, 360),
        const Rect.fromLTWH(48, 582, 504, 72),
        sampleText: sample,
        sampleArea: const Rect.fromLTWH(.075, .20, .60, .60),
        sampleTextColor: id == 'editionGardenBand' || id == 'editionCinemaBand'
            ? const Color(0xFFF4F0E8)
            : const Color(0xFF3D524B),
      );
    }
    if (type == '문구') {
      final source = art?.sourceSize ?? const Size(300, 160);
      return compose(
        MaterialPreviewPlacement.lettering,
        const Rect.fromLTWH(48, 378, 504, 260),
        const Rect.fromLTWH(44, 36, 512, 310),
        null,
        aspect: source.aspectRatio,
        letteringSourceSize: source,
      );
    }
    if (atelierWritingPapers.any((s) => s.id == id)) {
      final sample = switch (id) {
        'atelierWritingVow' => '서로에게\n쓴 약속',
        'atelierWritingReceipt' => '점심은\n천천히',
        'atelierWritingLetter' => '자막 대신\n남기는 말',
        _ => '매일 조금씩\n살펴본 기록',
      };
      return compose(
        MaterialPreviewPlacement.card,
        const Rect.fromLTWH(264, 188, 304, 440),
        const Rect.fromLTWH(34, 48, 212, 316),
        const Rect.fromLTWH(36, 408, 204, 174),
        sampleText: sample,
        sampleArea: const Rect.fromLTWH(.16, .29, .68, .40),
        serif: id == 'atelierWritingVow' || id == 'atelierWritingLetter',
      );
    }
    if (id == 'luminousLace' || id == 'atelierCornerBrackets') {
      final frame = _fit(ratio, const Rect.fromLTWH(44, 40, 512, 512));
      return compose(
        MaterialPreviewPlacement.frame,
        frame,
        frame.deflate(frame.width * (id == 'luminousLace' ? .20 : .08)),
        const Rect.fromLTWH(48, 580, 504, 76),
      );
    }
    if (type == '종이') {
      if (_backingPapers.contains(id)) {
        final paper = _fit(ratio, const Rect.fromLTWH(34, 32, 532, 536));
        return compose(
          MaterialPreviewPlacement.backing,
          paper,
          Rect.fromLTWH(
            paper.left + paper.width * .16,
            paper.top + paper.height * .12,
            paper.width * .70,
            paper.height * .46,
          ),
          const Rect.fromLTWH(48, 588, 504, 68),
        );
      }
      if (ratio < 1.15) {
        return compose(
          MaterialPreviewPlacement.card,
          const Rect.fromLTWH(264, 188, 304, 440),
          const Rect.fromLTWH(34, 48, 212, 316),
          const Rect.fromLTWH(36, 408, 204, 174),
          sampleText: id == 'materialBlindEmboss' ? '오래도록\n함께할 우리' : null,
          sampleArea: id == 'materialBlindEmboss'
              ? const Rect.fromLTWH(.19, .29, .62, .36)
              : null,
          serif: id == 'materialBlindEmboss',
          paperColor: const Color(0xFFEDF1EF),
        );
      }
      final sampleText = switch (id) {
        'lifeWardrobeLabel' => '너의 첫 계절\n작고 소중한 순간들',
        'lifeCompanionTab' => '오늘의 관찰\n함께 보낸 오후',
        'lifePicnicSlip' => '우리의 주말\n다 같이 모인 날',
        'lifeHomeNote' => '함께 사는 날들\n우리의 평범한 하루',
        _ => null,
      };
      return compose(
        MaterialPreviewPlacement.card,
        const Rect.fromLTWH(44, 354, 512, 280),
        const Rect.fromLTWH(44, 32, 512, 296),
        sampleText == null ? const Rect.fromLTWH(48, 644, 504, 28) : null,
        sampleText: sampleText,
        sampleArea: sampleText == null
            ? null
            : const Rect.fromLTWH(.17, .32, .66, .42),
      );
    }
    if (id == 'zineUnderline' || id == 'zineOrbit') {
      return compose(
        MaterialPreviewPlacement.accent,
        const Rect.fromLTWH(60, 520, 330, 126),
        const Rect.fromLTWH(44, 36, 512, 374),
        const Rect.fromLTWH(56, 444, 488, 60),
      );
    }
    if (spec?.category == StudioDecorationCategory.tape || ratio >= 2.4) {
      return compose(
        MaterialPreviewPlacement.band,
        const Rect.fromLTWH(66, 426, 468, 132),
        const Rect.fromLTWH(44, 36, 512, 360),
        const Rect.fromLTWH(48, 582, 504, 72),
      );
    }
    return compose(
      MaterialPreviewPlacement.accent,
      const Rect.fromLTWH(340, 366, 216, 244),
      const Rect.fromLTWH(44, 36, 512, 364),
      const Rect.fromLTWH(48, 446, 264, 172),
    );
  }
}

Rect _fit(double ratio, Rect bounds) => Alignment.center.inscribe(
  applyBoxFit(BoxFit.contain, Size(ratio, 1), bounds.size).destination,
  bounds,
);

const _backingPapers = {
  'studioCottonRag',
  'studioCotton',
  'studioBlushPaper',
  'studioVellum',
  'studioBlueFibre',
  'materialLinen',
  'lifeGingham',
  'heirloomTableLinen',
  'luminousGingham',
  'luminousMintStripe',
  'zineGridPaper',
  'zineTornBlue',
  'zineChecker',
  'atelierColorSlips',
};

const _translucentPapers = {
  'materialVellumBand',
  'travelDocumentPocket',
  'travelPhotoSleeve',
  'studioVellum',
};

enum _Theme {
  wedding,
  travel,
  daily,
  botanical,
  growth,
  family,
  couple,
  pet,
  celebration,
}

_Theme _themeFor(String? collection, String? wordArt) {
  final artTheme = switch (wordArt) {
    'atelier-vow' || 'atelier-promise' || 'atelier-ribbon' => _Theme.wedding,
    'atelier-boarding' ||
    'atelier-route' ||
    'atelier-postcard' => _Theme.travel,
    'atelier-first-year' || 'atelier-first-time' => _Theme.growth,
    'atelier-weekend' || 'atelier-laughter' || 'bold-cut' => _Theme.family,
    'atelier-anniversary' ||
    'atelier-cinema' ||
    'ribbon' ||
    'seal' => _Theme.couple,
    'atelier-walk' => _Theme.pet,
    'diecut' => _Theme.celebration,
    _ => null,
  };
  return artTheme ??
      switch (collection) {
        '웨딩' || '웨딩 기록' || '서약의 아틀리에' || '서체와 압인' || '밤의 가든' => _Theme.wedding,
        '여행' || '여행 기록' || '여행 인쇄소' || '해변의 기록' || '느린 열차' => _Theme.travel,
        '성장·육아' || '성장 기록' || '작은 첫 계절' || '첫 번째 행성' => _Theme.growth,
        '가족·친구' || '함께한 식탁' || '함께 차린 식탁' || '우리 집의 식탁' => _Theme.family,
        '커플·기념일' || '둘의 기록' || '둘의 보관함' || '둘만의 영화' => _Theme.couple,
        '반려동물' || '산책 수첩' || '산책의 흔적' || '산책 클럽' => _Theme.pet,
        '작은 축하' => _Theme.celebration,
        '초록의 관찰' => _Theme.botanical,
        _ => _Theme.daily,
      };
}

typedef _Scene = ({String photo, String caption});
// Keep a city-specific letter away from identifiable overseas scenery.
const List<_Scene> _letterScenes = [
  (photo: 'daily_desk.png', caption: '창가에서 적은 편지'),
  (photo: 'daily_book.png', caption: '한 장씩 모은 기억'),
];
const Map<_Theme, List<_Scene>> _scenes = {
  _Theme.botanical: [
    (
      photo: 'assets/templates/atelier_editions_2026/green-hours.png',
      caption: '초록을 돌보는 시간',
    ),
    (photo: 'daily_book.png', caption: '창가에 둔 꽃 한 송이'),
    (photo: 'small_days_walk.png', caption: '산책에서 만난 잎의 모양'),
    (photo: 'daily_picnic.png', caption: '계절의 초록을 모아서'),
  ],
  _Theme.growth: [
    (photo: 'growth_keepsakes.png', caption: '작은 물건을 모아'),
    (photo: 'growth_sleep.png', caption: '너의 작은 하루'),
    (photo: 'growth_hand.png', caption: '처음 잡은 손'),
    (photo: 'growth_play.png', caption: '하나씩 배워 가는 날'),
    (photo: 'growth_walk.png', caption: '처음 걷던 길'),
    (photo: 'growth_birthday.png', caption: '너의 첫 생일'),
  ],
  _Theme.wedding: [
    (photo: 'petal_couple.png', caption: '약속을 남긴 날'),
    (photo: 'petal_bouquet.png', caption: '그날 손에 들었던 꽃'),
    (photo: 'petal_details.png', caption: '오래 간직할 것들'),
    (photo: 'petal_veil.png', caption: '기다리던 순간'),
    (photo: 'lightbound_ceremony.png', caption: '우리의 시작'),
    (photo: 'petal_table.png', caption: '축하를 나눈 자리'),
    (photo: 'lightbound_twilight.png', caption: '저녁까지 함께'),
  ],
  _Theme.travel: [
    (photo: 'travel_coast.png', caption: '바다에 머문 날'),
    (photo: 'travel_harbor.png', caption: '항구의 오후'),
    (photo: 'travel_street.png', caption: '천천히 걸었던 골목'),
    (photo: 'travel_cafe.png', caption: '여행 중의 작은 쉼'),
    (photo: 'journey_market.png', caption: '시장에서 찾은 것들'),
    (photo: 'journey_train.png', caption: '다음 도시로 가는 길'),
  ],
  _Theme.daily: [
    (photo: 'daily_book.png', caption: '오래 펼쳐 둔 책'),
    (photo: 'daily_desk.png', caption: '좋아하는 것들'),
    (photo: 'daily_fruit.png', caption: '계절을 담은 한 접시'),
    (photo: 'small_days_breakfast.png', caption: '느긋한 아침'),
    (photo: 'daily_picnic.png', caption: '볕이 좋은 주말'),
    (photo: 'small_days_walk.png', caption: '익숙한 길에서'),
    (photo: 'daily_friends.png', caption: '오랜만에 모인 날'),
  ],
  _Theme.family: [
    (photo: 'family_table.png', caption: '다 같이 모인 날'),
    (photo: 'family_picnic.png', caption: '우리의 주말'),
    (photo: 'family_kitchen.png', caption: '함께 차린 한 끼'),
    (photo: 'family_friends.png', caption: '사진 밖까지 웃음소리'),
    (photo: 'daily_friends.png', caption: '다음에도 이 자리에서'),
  ],
  _Theme.couple: [
    (photo: 'couple_walk.png', caption: '둘이 걷는 시간'),
    (photo: 'couple_cafe.png', caption: '마주 앉은 오후'),
    (photo: 'couple_keepsakes.png', caption: '같이 모은 작은 기억'),
    (photo: 'couple_anniversary.png', caption: '우리의 기념일'),
  ],
  _Theme.pet: [
    (photo: 'pet_walk.png', caption: '오늘도 같이 걷자'),
    (photo: 'pet_cat.png', caption: '창가의 낮잠'),
    (photo: 'pet_dog.png', caption: '눈이 마주친 순간'),
    (photo: 'pet_nap.png', caption: '느긋하게 쉬는 날'),
    (photo: 'pet_rest.png', caption: '가장 편안한 자리'),
    (photo: 'pet_keepsakes.png', caption: '함께한 날의 흔적'),
  ],
  _Theme.celebration: [
    (photo: 'lightbound_cake.png', caption: '축하하고 싶은 날'),
    (photo: 'growth_birthday.png', caption: '한 살의 생일'),
    (photo: 'couple_anniversary.png', caption: '우리만의 기념일'),
  ],
};

const _photoOverrides = {
  'lifeWardrobeLabel': 'growth_keepsakes.png',
  'lifeCompanionTab': 'pet_walk.png',
  'materialBlindEmboss': 'petal_couple.png',
  'lifeRattle': 'growth_play.png',
  'lifeBib': 'growth_sleep.png',
  'lifeBonnet': 'growth_walk.png',
  'materialBooties': 'growth_hand.png',
  'materialScallopNote': 'growth_birthday.png',
  'materialMonthDial': 'growth_keepsakes.png',
  'lifeGingham': 'family_picnic.png',
  'lifeBasket': 'family_friends.png',
  'lifeMug': 'family_kitchen.png',
  'lifePicnicSlip': 'family_table.png',
  'lifeSlippers': 'couple_keepsakes.png',
  'lifeVase': 'couple_cafe.png',
  'lifeHomeNote': 'couple_walk.png',
  'materialRose': 'couple_anniversary.png',
  'lifeFeltMouse': 'pet_cat.png',
  'lifeBowl': 'pet_rest.png',
  'lifeRopeBall': 'pet_dog.png',
  'materialLeash': 'pet_walk.png',
  'materialNamePatch': 'pet_keepsakes.png',
  'materialBookmark': 'daily_book.png',
  'materialClip': 'daily_desk.png',
  'travelCafeReceipt': 'travel_cafe.png',
  'travelMarketReceipt': 'journey_market.png',
  'atelierBoardingStub': 'journey_train.png',
  'studioTravelTicket': 'travel_street.png',
  'waveSeaGlass': 'travel_coast.png',
  'materialShell': 'travel_harbor.png',
  'materialLace': 'petal_veil.png',
  'waveSilkKnot': 'petal_details.png',
};

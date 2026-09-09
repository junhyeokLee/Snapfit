import 'dart:math' as math;

import 'package:flutter/widgets.dart';

part 'keepsake_material_catalog.dart';
part 'atelier_composition_catalog.dart';
part 'concept_wave_material_catalog.dart';

enum StudioDecorationCategory {
  paper('종이'),
  sticker('스티커'),
  tape('테이프');

  const StudioDecorationCategory(this.label);
  final String label;
}

class StudioDecorationSpec {
  const StudioDecorationSpec(
    this.id,
    this.label,
    this.category,
    this.aspectRatio,
    this.relativeWidth, {
    this.assetPath,
    this.collection,
  });

  final String id, label;
  final StudioDecorationCategory category;
  final double aspectRatio, relativeWidth;
  final String? assetPath;
  final String? collection;

  String get insertionValue =>
      assetPath == null ? 'deco:$id@1.0' : 'asset:$assetPath';

  Size fittedSize(Size canvas, {double scale = 1}) {
    final width = canvas.width * relativeWidth * scale;
    final height = width / aspectRatio;
    final fit = math.min(
      1.0,
      math.min(canvas.width * .88 / width, canvas.height * .88 / height),
    );
    return Size(width * fit, height * fit);
  }
}

/// Stable keys are stored in album documents. Keep old decorations untouched.
const studioDecorations = [
  ...conceptWaveDecorations,
  ...keepsakeDecorations,
  ...atelierCompositionDecorations,
  ...zineDecorations,
  ...luminousDecorations,
  ...atelierDecorations,
  ...travelDecorations,
  ...heirloomDecorations,
  ...vowEditionDecorations,
  StudioDecorationSpec(
    'studioCottonRag',
    '수제지 조각',
    StudioDecorationCategory.paper,
    1388 / 1133,
    .64,
    assetPath: 'assets/sticker/studio/cotton_rag.png',
  ),
  StudioDecorationSpec(
    'studioPressedCosmos',
    '코스모스 압화',
    StudioDecorationCategory.sticker,
    2 / 3,
    .24,
    assetPath: 'assets/sticker/studio/pressed_cosmos.png',
  ),
  StudioDecorationSpec(
    'studioCotton',
    '코튼 페이퍼',
    StudioDecorationCategory.paper,
    .82,
    .64,
  ),
  StudioDecorationSpec(
    'studioSageRibbon',
    '세이지 리본',
    StudioDecorationCategory.sticker,
    1,
    .30,
    assetPath: 'assets/sticker/studio/sage_ribbon.png',
  ),
  StudioDecorationSpec(
    'studioWashiSage',
    '핀스트라이프',
    StudioDecorationCategory.tape,
    3.8,
    .40,
  ),
  StudioDecorationSpec(
    'studioCitrusPrint',
    '시트러스 프린트',
    StudioDecorationCategory.sticker,
    1,
    .26,
    assetPath: 'assets/sticker/studio/citrus_print.png',
  ),
  StudioDecorationSpec(
    'studioBlushPaper',
    '블러시 한지',
    StudioDecorationCategory.paper,
    1.28,
    .64,
  ),
  StudioDecorationSpec(
    'studioLedger',
    '아카이브 노트',
    StudioDecorationCategory.paper,
    .80,
    .62,
  ),
  StudioDecorationSpec(
    'studioVellum',
    '트레이싱 페이퍼',
    StudioDecorationCategory.paper,
    .84,
    .60,
  ),
  StudioDecorationSpec(
    'studioWashiRose',
    '로즈 체크',
    StudioDecorationCategory.tape,
    3.8,
    .40,
  ),
  StudioDecorationSpec(
    'studioWashiIndigo',
    '잉크 도트',
    StudioDecorationCategory.tape,
    3.8,
    .40,
  ),
  StudioDecorationSpec(
    'studioKeepsakeTicket',
    '메모리 티켓',
    StudioDecorationCategory.sticker,
    2.15,
    .43,
  ),
  StudioDecorationSpec(
    'studioBotanicalStamp',
    '보태니컬 우표',
    StudioDecorationCategory.sticker,
    .76,
    .26,
  ),
];

const travelDecorations = [
  ...travelJournalDecorations,
  StudioDecorationSpec(
    'studioTravelMap',
    '접어 둔 여행 지도',
    StudioDecorationCategory.paper,
    1.4,
    .64,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'studioTravelTicket',
    '여행 승차권',
    StudioDecorationCategory.paper,
    2.5,
    .52,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'studioPostalMark',
    '여행 소인',
    StudioDecorationCategory.sticker,
    1.8,
    .28,
    collection: '여행 기록',
  ),
];

const heirloomDecorations = [
  StudioDecorationSpec(
    'heirloomVowPaper',
    '서약서 제본지',
    StudioDecorationCategory.paper,
    .78,
    .72,
    collection: '웨딩 기록',
  ),
  StudioDecorationSpec(
    'heirloomLibraryCard',
    '수집함 도서 카드',
    StudioDecorationCategory.paper,
    .72,
    .48,
    collection: '일상 수집',
  ),
  StudioDecorationSpec(
    'heirloomGrowthRuler',
    '첫해의 기록 자',
    StudioDecorationCategory.paper,
    3.8,
    .74,
    collection: '성장 기록',
  ),
  StudioDecorationSpec(
    'heirloomTableLinen',
    '식탁의 체크 리넨',
    StudioDecorationCategory.paper,
    1.24,
    .76,
    collection: '함께한 식탁',
  ),
  StudioDecorationSpec(
    'heirloomCinemaStub',
    '둘이 앉은 영화표',
    StudioDecorationCategory.paper,
    2.6,
    .58,
    collection: '둘의 기록',
  ),
  StudioDecorationSpec(
    'heirloomPetTag',
    '산책 가방 이름표',
    StudioDecorationCategory.sticker,
    .72,
    .22,
    collection: '산책 수첩',
  ),
];

const vowEditionDecorations = [
  StudioDecorationSpec(
    'heirloomVowEnvelope',
    '서약을 담은 봉투',
    StudioDecorationCategory.paper,
    1.5,
    .62,
    collection: '웨딩 기록',
  ),
  StudioDecorationSpec(
    'heirloomVowPlaceCard',
    '피로연 접이 카드',
    StudioDecorationCategory.paper,
    2.15,
    .46,
    collection: '웨딩 기록',
  ),
  StudioDecorationSpec(
    'heirloomVowSeal',
    '올리브 압인 봉인',
    StudioDecorationCategory.sticker,
    1,
    .17,
    collection: '웨딩 기록',
  ),
];

const travelJournalDecorations = [
  StudioDecorationSpec(
    'travelDocumentPocket',
    '반투명 여행 서류 포켓',
    StudioDecorationCategory.paper,
    3.2,
    .76,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'travelMarketReceipt',
    '시장에서 받은 영수증',
    StudioDecorationCategory.paper,
    .58,
    .28,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'travelStayTag',
    '숙소 키 태그',
    StudioDecorationCategory.sticker,
    .56,
    .20,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'travelCafeReceipt',
    '카페 영수증',
    StudioDecorationCategory.paper,
    .58,
    .28,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'travelCafeCoaster',
    '종이 코스터',
    StudioDecorationCategory.sticker,
    1,
    .30,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'travelPostcard',
    '여행 엽서 뒷면',
    StudioDecorationCategory.paper,
    1.48,
    .58,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'travelLuggageLabel',
    '수하물 라벨',
    StudioDecorationCategory.sticker,
    2.8,
    .48,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'travelNotebook',
    '떼어 둔 여행 노트',
    StudioDecorationCategory.paper,
    .80,
    .56,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'travelPhotoSleeve',
    '반투명 사진 보관지',
    StudioDecorationCategory.paper,
    1.25,
    .64,
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'travelContourSlip',
    '해안 등고선 종이',
    StudioDecorationCategory.paper,
    .82,
    .52,
    collection: '여행 기록',
  ),
];

const atelierDecorations = [
  StudioDecorationSpec(
    'studioOlivePress',
    '올리브 압화',
    StudioDecorationCategory.sticker,
    1,
    .32,
    assetPath: 'assets/sticker/studio/olive_press.png',
    collection: '보태니컬',
  ),
  StudioDecorationSpec(
    'studioRoseSilk',
    '로즈 실크 리본',
    StudioDecorationCategory.sticker,
    1,
    .32,
    assetPath: 'assets/sticker/studio/rose_silk.png',
    collection: '보태니컬',
  ),
  StudioDecorationSpec(
    'studioCoastStamp',
    '해안 마을 우표',
    StudioDecorationCategory.sticker,
    1145 / 1374,
    .27,
    assetPath: 'assets/sticker/studio/coast_stamp.png',
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'studioArchiveTag',
    '아카이브 태그',
    StudioDecorationCategory.sticker,
    1,
    .38,
    assetPath: 'assets/sticker/studio/archive_tag.png',
    collection: '여행 기록',
  ),
  StudioDecorationSpec(
    'studioGouacheCake',
    '구아슈 케이크',
    StudioDecorationCategory.sticker,
    1,
    .29,
    assetPath: 'assets/sticker/studio/gouache_cake.png',
    collection: '작은 축하',
  ),
  StudioDecorationSpec(
    'studioPaperRosette',
    '페이퍼 로제트',
    StudioDecorationCategory.sticker,
    1,
    .30,
    assetPath: 'assets/sticker/studio/paper_rosette.png',
    collection: '작은 축하',
  ),
  StudioDecorationSpec(
    'studioBlueFibre',
    '꽃잎 블루 수제지',
    StudioDecorationCategory.paper,
    4 / 3,
    .70,
    assetPath: 'assets/sticker/studio/blue_fibre_paper.png',
    collection: '페이퍼 아카이브',
  ),
  StudioDecorationSpec(
    'studioGlassineEnvelope',
    '글라신 종이봉투',
    StudioDecorationCategory.paper,
    1,
    .60,
    assetPath: 'assets/sticker/studio/glassine_envelope.png',
    collection: '페이퍼 아카이브',
  ),
];

// Draft-only material registry. Do not expose these in the store before approval.
const luminousDecorations = [
  StudioDecorationSpec(
    'luminousBow',
    '체크 리본 콜라주',
    StudioDecorationCategory.sticker,
    1,
    .36,
    assetPath: 'assets/sticker/studio/luminous_bow_collage.png',
    collection: '빛나는 스크랩북',
  ),
  StudioDecorationSpec(
    'luminousLace',
    '로즈 레이스 프레임',
    StudioDecorationCategory.sticker,
    1,
    .64,
    assetPath: 'assets/sticker/studio/luminous_lace_frame.png',
    collection: '빛나는 스크랩북',
  ),
  StudioDecorationSpec(
    'luminousGingham',
    '체리 체크 페이퍼',
    StudioDecorationCategory.paper,
    1,
    .7,
    collection: '빛나는 스크랩북',
  ),
  StudioDecorationSpec(
    'luminousMintStripe',
    '민트 스트라이프',
    StudioDecorationCategory.paper,
    1,
    .7,
    collection: '빛나는 스크랩북',
  ),
  StudioDecorationSpec(
    'luminousRibbon',
    '접힌 리본 라벨',
    StudioDecorationCategory.sticker,
    4,
    .65,
    collection: '빛나는 스크랩북',
  ),
  StudioDecorationSpec(
    'luminousRosette',
    '레이스 메달',
    StudioDecorationCategory.sticker,
    1,
    .36,
    collection: '빛나는 스크랩북',
  ),
  StudioDecorationSpec(
    'luminousHeart',
    '하트 봉인',
    StudioDecorationCategory.sticker,
    1,
    .22,
    collection: '빛나는 스크랩북',
  ),
  StudioDecorationSpec(
    'luminousPostmark',
    '러브 포스트마크',
    StudioDecorationCategory.sticker,
    1.65,
    .34,
    collection: '빛나는 스크랩북',
  ),
  StudioDecorationSpec(
    'luminousNote',
    '찢어진 편지지',
    StudioDecorationCategory.paper,
    .8,
    .45,
    collection: '빛나는 스크랩북',
  ),
  StudioDecorationSpec(
    'luminousStar',
    '별빛 배지',
    StudioDecorationCategory.sticker,
    1,
    .24,
    collection: '빛나는 스크랩북',
  ),
];

// The current collage study. Historical luminous keys remain loadable below.
const zineDecorations = [
  StudioDecorationSpec(
    'zineCamera',
    '블루 포켓 카메라',
    StudioDecorationCategory.sticker,
    1,
    .32,
    assetPath: 'assets/sticker/studio/zine_camera.png',
    collection: '오브젝트 콜라주',
  ),
  StudioDecorationSpec(
    'zineHeartKey',
    '아크릴 하트 키링',
    StudioDecorationCategory.sticker,
    1,
    .28,
    assetPath: 'assets/sticker/studio/zine_heart_key.png',
    collection: '오브젝트 콜라주',
  ),
  StudioDecorationSpec(
    'zineSilverStar',
    '실버 포일 별',
    StudioDecorationCategory.sticker,
    1,
    .24,
    assetPath: 'assets/sticker/studio/zine_silver_star.png',
    collection: '오브젝트 콜라주',
  ),
  StudioDecorationSpec(
    'zineDaisyPatch',
    '블루 데이지 패치',
    StudioDecorationCategory.sticker,
    1,
    .24,
    assetPath: 'assets/sticker/studio/zine_daisy_patch.png',
    collection: '오브젝트 콜라주',
  ),
  StudioDecorationSpec(
    'zineCitrus',
    '시트러스 컷아웃',
    StudioDecorationCategory.sticker,
    1,
    .28,
    assetPath: 'assets/sticker/studio/zine_citrus.png',
    collection: '오브젝트 콜라주',
  ),
  StudioDecorationSpec(
    'zineGlasses',
    '레몬 선글라스',
    StudioDecorationCategory.sticker,
    1,
    .32,
    assetPath: 'assets/sticker/studio/zine_glasses.png',
    collection: '오브젝트 콜라주',
  ),
  StudioDecorationSpec(
    'zineGridPaper',
    '블루 모눈 종이',
    StudioDecorationCategory.paper,
    1,
    .70,
    collection: '그래픽 페이퍼',
  ),
  StudioDecorationSpec(
    'zineTornBlue',
    '코발트 찢은 종이',
    StudioDecorationCategory.paper,
    1.3,
    .65,
    collection: '그래픽 페이퍼',
  ),
  StudioDecorationSpec(
    'zineChecker',
    '블랙 체크 조각',
    StudioDecorationCategory.paper,
    2,
    .45,
    collection: '그래픽 페이퍼',
  ),
  StudioDecorationSpec(
    'zineTicket',
    '라임 티켓',
    StudioDecorationCategory.paper,
    2.4,
    .55,
    collection: '그래픽 페이퍼',
  ),
  StudioDecorationSpec(
    'zineTape',
    '오렌지 마스킹테이프',
    StudioDecorationCategory.tape,
    4,
    .35,
    collection: '그래픽 페이퍼',
  ),
  StudioDecorationSpec(
    'zineOrbit',
    '손그림 서클',
    StudioDecorationCategory.sticker,
    2,
    .4,
    collection: '그래픽 페이퍼',
  ),
  StudioDecorationSpec(
    'zineUnderline',
    '두 줄 밑줄',
    StudioDecorationCategory.sticker,
    4,
    .5,
    collection: '그래픽 페이퍼',
  ),
];

StudioDecorationSpec? studioDecorationById(String? id) =>
    studioDecorations.where((item) => item.id == id).firstOrNull;

StudioDecorationSpec? studioDecorationByAsset(String? path) => path == null
    ? null
    : studioDecorations.where((item) => item.assetPath == path).firstOrNull;

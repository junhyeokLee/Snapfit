part of 'studio_decoration_catalog.dart';

const atelierCompositionCollections = ['서체와 압인', '여행 인쇄소', '기록의 도구', '컬러 콜라주'];

const atelierCompositionDecorations = [
  StudioDecorationSpec(
    'atelierTitlePlate',
    '서체용 이중 압인판',
    StudioDecorationCategory.paper,
    1.5,
    .62,
    collection: '서체와 압인',
  ),
  StudioDecorationSpec(
    'atelierRibbonPlate',
    '접은 실크 라벨',
    StudioDecorationCategory.sticker,
    3.2,
    .58,
    collection: '서체와 압인',
  ),
  StudioDecorationSpec(
    'atelierBoardingStub',
    '절취선 탑승 반권',
    StudioDecorationCategory.paper,
    1.6,
    .60,
    collection: '여행 인쇄소',
  ),
  StudioDecorationSpec(
    'atelierPostalBand',
    '두 겹 우편 띠',
    StudioDecorationCategory.tape,
    5,
    .60,
    collection: '여행 인쇄소',
  ),
  StudioDecorationSpec(
    'atelierGridLeaf',
    '접힌 모눈 인쇄지',
    StudioDecorationCategory.paper,
    1.25,
    .60,
    collection: '기록의 도구',
  ),
  StudioDecorationSpec(
    'atelierArchiveSeal',
    '아카이브 타원 인장',
    StudioDecorationCategory.sticker,
    1.35,
    .40,
    collection: '기록의 도구',
  ),
  StudioDecorationSpec(
    'atelierColorSlips',
    '오려 붙인 컬러 종이',
    StudioDecorationCategory.paper,
    1.3,
    .60,
    collection: '컬러 콜라주',
  ),
  StudioDecorationSpec(
    'atelierCornerBrackets',
    '네 귀퉁이 포토 홀더',
    StudioDecorationCategory.sticker,
    1.25,
    .66,
    collection: '컬러 콜라주',
  ),
];

import '../../../core/templates/authored_collections.dart';
import '../../../core/templates/diversity_frame_specs.dart';
import '../../../core/templates/free_template_material_policy.dart';
import '../../../core/templates/studio_decoration_catalog.dart';
import '../../../core/templates/studio_photo_frame_catalog.dart';
import 'point_shop_template_key.dart';
import 'premium_volume_registration.dart';
import 'point_shop_catalog_release.dart';

/// Editorial launch prices, never a replacement for the server's purchase quote.
/// Unknown keys remain unreviewed; opening the catalog performs no price writes.
class PointShopLaunchPrice {
  const PointShopLaunchPrice(this.points, this.reason);
  final int points;
  final String reason;
}

const pointShopPricingRevision = pointShopCatalogApprovalRevision;

const _milestoneFrameLaunchPrices = <String, int>{
  'milestoneConfettiMat': 0,
  'milestoneBlueprintMount': 0,
  'milestonePortfolioTab': 300,
  'milestoneLinenMedal': 300,
  'milestoneGalleryLabel': 400,
};

bool isPendingAtelierMaterialProduct(String key) =>
    !ownerApprovedCatalogProductKeys.contains(key) &&
    !freeTemplateMaterialProductKeys.contains(key) &&
    (storyEditionMaterialKeys.contains(key) ||
        (key.startsWith('sticker:') &&
            (atelierEditionMaterialPrices[key.substring(8)] ?? 0) > 0) ||
        (key.startsWith('frame:') &&
            (atelierSignaturePhotoFrames.contains(key.substring(6)) ||
                atelierStoryPhotoFrames.contains(key.substring(6)) ||
                diversityFramePrices.containsKey(key.substring(6)) ||
                _milestoneFrameLaunchPrices.containsKey(key.substring(6)))));

bool pointShopRequiresFreePrice(String productKey) =>
    freeTemplateMaterialProductKeys.contains(productKey) ||
    storyEditions.any((e) => !e.isPremium && e.productKey == productKey) ||
    authoredCollections.any(
      (collection) => pointShopAuthoredTemplateKey(collection) == productKey,
    );

String _storyEditionLaunchPriceReason(StoryEdition edition) {
  if (edition.qualityRevision == premiumQuartetRevision) {
    return '${edition.title} 전용 아트 디렉션 · 32쪽 사진·수집·관찰·편지 지면과 독립 프레임·종이·스티커·문구 8종';
  }
  if (edition.qualityRevision == hobbyExpansionRevision) {
    return '${edition.isPremium ? '취미별 완성 에디션' : '무료 완성 취미 기록집'} · '
        '${edition.title}의 과정·관찰·수집 지면과 전용 프레임·종이·모티프·타이틀을 엮은 24쪽';
  }
  if (edition.qualityRevision == milestoneExpansionRevision) {
    return '${edition.isPremium ? '새출발 완성 에디션' : '무료 완성 새출발 기록집'} · '
        '${edition.title}의 사진·편지·계획 지면과 독립 프레임·기록지·문구를 갖춘 24쪽';
  }
  if (edition.isPremium) {
    return edition.qualityRevision == sensoryEditionRevision
        ? '야간 도시 전용 조판·경로 수집 지면·독립 프레임과 제목 조합을 갖춘 24쪽 아카이브'
        : '전용 표지·24쪽 내지와 인쇄 5가지 크기의 스토리 에디션 책정가';
  }
  if (edition.qualityRevision == sensoryEditionRevision) {
    return '무료 완성 카페 기록 · 24쪽과 전용 기본 소재 8종';
  }
  if (edition.id == 'story-reading-room') {
    return '무료 독서 기록집 · 사진·인용·독서 노트 24쪽과 편집 가능한 기본 소재';
  }
  return '무료 동아리 완성 템플릿 · 인쇄 5가지 크기와 기본 소재 포함';
}

String _diversityFramePriceReason(String frame) => switch (frame) {
  'clayContour' => '점토 비대칭 윤곽과 유약 표식 · 사진 전체를 보존하는 독립 매트',
  'leafHerbarium' => '표본 절개·잎맥 인덱스와 투명 사진 창을 가진 허브 슬리브',
  'filmContactRail' => '세로 퍼포레이션·노출 색인·독립 직사각 사진 창',
  'bakeRecipe' => '체크 제본 띠·물결 재단·레시피 기록 포켓',
  'knitStitch' => '스캘럽 재단과 교차 스티치·실 고리를 엮은 직조 매트',
  'musicSleeve' => '음반 슬리브의 손가락 절개·그루브·트랙 라벨 조합',
  'paperNotch' => '접힌 종이 노치·콜라주 탭과 비대칭 메모 띠',
  'galleryRegistration' => '독립 재단 등록표·회색조 색인·정밀 이중 사진 마운트',
  _ => '아일릿·봉제·등고선 수집 띠를 갖춘 캠프 지도 포켓',
};

final pointShopLaunchPrices = Map<String, PointShopLaunchPrice>.unmodifiable({
  for (final edition in storyEditions) ...{
    edition.productKey: PointShopLaunchPrice(
      edition.qualityRevision == premiumQuartetRevision
          ? 2500
          : edition.isPremium
          ? 1800
          : 0,
      _storyEditionLaunchPriceReason(edition),
    ),
    'sticker:${edition.paperId}': PointShopLaunchPrice(
      edition.isPremium ? 100 : 0,
      '사진 받침 여백·접지·색인 구조가 있는 편집용 종이',
    ),
    'sticker:${edition.motifId}': PointShopLaunchPrice(
      edition.isPremium ? 200 : 0,
      '주제별 독립 선화와 투명 여백을 보존한 장식',
    ),
    edition.phraseKey: PointShopLaunchPrice(
      edition.isPremium ? 300 : 0,
      '영문·한글 제목과 구분선을 개별 수정하는 타이틀 조합',
    ),
  },
  for (final entry in diversityFramePrices.entries)
    'frame:${entry.key}': PointShopLaunchPrice(
      entry.value,
      _diversityFramePriceReason(entry.key),
    ),
  for (final edition in premiumQuartetEditions) ...{
    'sticker:${edition.id}-vellum': const PointShopLaunchPrice(
      150,
      '주제별 접지와 가장자리 결을 살린 두 번째 편집 기록지',
    ),
    'sticker:${edition.id}-keepsake': const PointShopLaunchPrice(
      300,
      '전용으로 촬영한 듯한 재료 수집품 · 투명 배경과 원본 질감',
    ),
    'phrase:collage-${edition.id}-caption': const PointShopLaunchPrice(
      300,
      '독립적으로 편집 가능한 한글 문장과 보조 레터링 조합',
    ),
    'frame:${edition.photoFrames[0]}': const PointShopLaunchPrice(
      300,
      '전체 사진 비율을 보존하는 주제별 재단·제본·색인 마운트',
    ),
    'frame:${edition.photoFrames[1]}': const PointShopLaunchPrice(
      400,
      '두 번째 독립 마운트 · 절개·스티치·접지 구조와 온전한 사진 창',
    ),
  },
  for (final entry in _milestoneFrameLaunchPrices.entries)
    'frame:${entry.key}': PointShopLaunchPrice(entry.value, switch (entry.key) {
      'milestoneConfettiMat' => '색종이 재단과 축하 띠·전체 얼굴을 보존하는 졸업 사진 창',
      'milestoneBlueprintMount' => '입주 도면의 눈금과 동선 표식·첫 집 기록용 비대칭 마운트',
      'milestonePortfolioTab' => '포트폴리오 탭·금속 클립·새 과정의 색인 띠',
      'milestoneLinenMedal' => '직조 결·기념 메달·여백을 갖춘 은퇴 편지 사진 매트',
      _ => '전시 작품 라벨·행잉 인장·등록 색인이 분리된 정밀 마운트',
    }),
  for (final frame in atelierStoryPhotoFrames)
    'frame:$frame': PointShopLaunchPrice(
      frame.startsWith('storyVow') ? 400 : 300,
      '사진 교체 가능한 컨셉 전용 절개·접지 구조',
    ),
  'frame:nocturneTransit': const PointShopLaunchPrice(
    300,
    '환승 절개와 넓은 사진 창·코발트 승차 띠',
  ),
  'frame:nocturneDuplex': const PointShopLaunchPrice(
    400,
    '이중 청색 매트·은빛 스터드와 독립 포토 창',
  ),
  'sticker:nocturneGlassine': const PointShopLaunchPrice(
    200,
    '원본 투명도를 보존한 실사 글라신 접힘과 금속 가장자리',
  ),
  'phrase:collage-sensory-night-index': const PointShopLaunchPrice(
    300,
    '제목·야간 노선·날짜 안내를 각각 수정하는 색인 문구',
  ),
  for (final frame in atelierSignaturePhotoFrames)
    'frame:$frame': const PointShopLaunchPrice(400, '컨셉 전용 포켓·절개·봉제 구조'),
  for (final key in freeTemplateMaterialProductKeys)
    key: const PointShopLaunchPrice(0, '무료 템플릿 기본 소재 · 별도 구매 없이 사용'),
  for (final collection in authoredCollections)
    pointShopAuthoredTemplateKey(collection): const PointShopLaunchPrice(
      0,
      '기존 무료 완성 템플릿 기준 유지 · 인쇄 5가지 크기 포함',
    ),
  for (final entry in atelierEditionMaterialPrices.entries)
    'sticker:${entry.key}': PointShopLaunchPrice(
      entry.value,
      entry.value == 0
          ? '신규 기본 받침 종이 무료 · 기존 무료 소재의 권한 유지'
          : entry.value == 100
          ? '주제별 겹침 바인딩 · 편집 가능한 문구와 분리된 장식 띠'
          : entry.value == 200
          ? '주제별 절개 창·인쇄·봉제 디테일의 독립 포토 매트'
          : '투명 경계를 보존한 주제별 복합 꾸밈 오브젝트',
    ),
  'sticker:lifeRattle': const PointShopLaunchPrice(
    200,
    '나뭇결과 결합 구조가 있는 독립 오브젝트',
  ),
  'sticker:lifeBib': const PointShopLaunchPrice(200, '거즈 직조와 봉제선의 투명 오브젝트'),
  'sticker:lifeBasket': const PointShopLaunchPrice(300, '버드나무 짜임과 안감의 복합 오브젝트'),
  'sticker:lifeMug': const PointShopLaunchPrice(200, '법랑 마모와 입체 손잡이'),
  'sticker:lifeSlippers': const PointShopLaunchPrice(
    300,
    '한 켤레의 직조와 퀼팅을 살린 복합 오브젝트',
  ),
  'sticker:lifeVase': const PointShopLaunchPrice(300, '도자기와 식물의 세밀한 투명 경계'),
  'sticker:lifeFeltMouse': const PointShopLaunchPrice(200, '양모 섬유와 손바느질 디테일'),
  'sticker:lifeBowl': const PointShopLaunchPrice(200, '수제 유약과 도자기 단면'),
  'sticker:lifeWardrobeLabel': const PointShopLaunchPrice(
    100,
    '직조·봉제선을 분리한 성장 기록지',
  ),
  'sticker:lifePicnicSlip': const PointShopLaunchPrice(
    100,
    '절취선과 이중 인쇄 여백의 기록지',
  ),
  'sticker:lifeHomeNote': const PointShopLaunchPrice(100, '접힌 모서리와 제본된 생활 메모'),
  'sticker:lifeCompanionTab': const PointShopLaunchPrice(
    100,
    '탭과 기록 구획이 있는 관찰 카드',
  ),
  'sticker:lifeBonnet': const PointShopLaunchPrice(
    300,
    '코튼 봉제선과 끈의 세밀한 투명 오브젝트',
  ),
  'sticker:lifeGingham': const PointShopLaunchPrice(200, '체크 직조와 접힘을 살린 원단 받침'),
  'sticker:lifeHouseKey': const PointShopLaunchPrice(
    300,
    '황동 열쇠와 코튼 고리의 복합 오브젝트',
  ),
  'sticker:lifeRopeBall': const PointShopLaunchPrice(
    300,
    '세 가지 실의 입체 직조와 투명 경계',
  ),
  'sticker:waveSilkKnot': const PointShopLaunchPrice(
    300,
    '실크 직조와 은빛 링의 복합 투명 오브젝트',
  ),
  'sticker:waveSeaGlass': const PointShopLaunchPrice(
    200,
    '마모된 유리 질감과 독립 투명 경계',
  ),
  'sticker:wavePencil': const PointShopLaunchPrice(200, '나뭇결과 흑연의 독립 투명 오브젝트'),
  'sticker:materialLace': const PointShopLaunchPrice(300, '레이스 자수와 투명 가장자리'),
  'sticker:materialShell': const PointShopLaunchPrice(200, '실사 질감 오브젝트'),
  'sticker:materialBookmark': const PointShopLaunchPrice(200, '마블링 인쇄와 종이 질감'),
  'sticker:materialBooties': const PointShopLaunchPrice(300, '니트 조직과 복합 실루엣'),
  'sticker:materialLinen': const PointShopLaunchPrice(200, '직조 원단과 풀린 가장자리'),
  'sticker:materialRose': const PointShopLaunchPrice(300, '꽃잎·줄기의 세밀한 투명 오브젝트'),
  'sticker:materialLeash': const PointShopLaunchPrice(300, '직조 끈과 금속 연결부'),
  'sticker:materialClip': const PointShopLaunchPrice(200, '금속 질감의 범용 오브젝트'),
  'sticker:materialBlindEmboss': const PointShopLaunchPrice(0, '기본 기록 카드 무료'),
  'sticker:materialVellumBand': const PointShopLaunchPrice(0, '기본 봉합 띠 무료'),
  'sticker:materialContourMap': const PointShopLaunchPrice(100, '주제형 등고선 인쇄'),
  'sticker:materialTransitPunch': const PointShopLaunchPrice(0, '기본 태그 무료'),
  'sticker:materialSpecimenPocket': const PointShopLaunchPrice(100, '접힌 보관 포켓'),
  'sticker:materialIndexTabs': const PointShopLaunchPrice(0, '기본 인덱스 무료'),
  'sticker:materialScallopNote': const PointShopLaunchPrice(0, '기본 메모지 무료'),
  'sticker:materialMonthDial': const PointShopLaunchPrice(100, '열두 달 기록 원판'),
  'sticker:materialRecipeFoldout': const PointShopLaunchPrice(
    100,
    '접지형 레시피 지면',
  ),
  'sticker:materialCrossStitchBand': const PointShopLaunchPrice(0, '기본 테이프 무료'),
  'sticker:materialTicketDuo': const PointShopLaunchPrice(100, '두 좌석의 티켓 조합'),
  'sticker:materialAirLetter': const PointShopLaunchPrice(100, '접지와 항공 우편 인쇄'),
  'sticker:materialWalkLedger': const PointShopLaunchPrice(0, '기본 기록지 무료'),
  'sticker:materialNamePatch': const PointShopLaunchPrice(100, '이름표용 자수 경계'),
  'sticker:atelierTitlePlate': const PointShopLaunchPrice(0, '기본 문구 받침판 무료'),
  'sticker:atelierRibbonPlate': const PointShopLaunchPrice(100, '접지된 리본 조합'),
  'sticker:atelierBoardingStub': const PointShopLaunchPrice(100, '절취선과 반권 구조'),
  'sticker:atelierPostalBand': const PointShopLaunchPrice(0, '기본 우편 띠 무료'),
  'sticker:atelierGridLeaf': const PointShopLaunchPrice(0, '기본 모눈지 무료'),
  'sticker:atelierArchiveSeal': const PointShopLaunchPrice(100, '타원선과 인장 눈금'),
  'sticker:atelierColorSlips': const PointShopLaunchPrice(0, '기본 컬러 종이 무료'),
  'sticker:atelierCornerBrackets': const PointShopLaunchPrice(0, '기본 사진 홀더 무료'),
  'frame:materialLaceMount': const PointShopLaunchPrice(300, '레이스와 사진 매트의 결합'),
  'frame:materialTwinWindow': const PointShopLaunchPrice(200, '엇갈린 두 개의 창'),
  'frame:materialLinenOval': const PointShopLaunchPrice(300, '직조 원단과 타원 자수 경계'),
  'frame:materialNotebookMount': const PointShopLaunchPrice(
    200,
    '제본 구멍과 노트 인쇄',
  ),
  'frame:materialScallopMount': const PointShopLaunchPrice(200, '물결 외곽과 사진 매트'),
  'frame:materialSlideMount': const PointShopLaunchPrice(200, '슬라이드 마운트'),
  'frame:atelierDeepMat': const PointShopLaunchPrice(200, '세 겹 단차 액자'),
  'frame:atelierFolio': const PointShopLaunchPrice(300, '양문 접지와 바느질'),
  'frame:atelierKeyhole': const PointShopLaunchPrice(300, '키홀 실루엣과 다중 윤곽'),
  'frame:atelierCrossRibbon': const PointShopLaunchPrice(200, '교차 리본과 인화지'),
  'frame:atelierNegative': const PointShopLaunchPrice(200, '필름 구멍과 인쇄 경계'),
  'frame:atelierEnvelope': const PointShopLaunchPrice(300, '사진 위로 겹치는 봉투 접지'),
  'frame:atelierOxford': const PointShopLaunchPrice(200, '정밀 격자 매트'),
  'frame:atelierCoastline': const PointShopLaunchPrice(300, '비대칭 외곽과 연속 사진 창'),
  'frame:atelierWeave': const PointShopLaunchPrice(200, '가로·세로 직조 패턴'),
  'frame:atelierDeco': const PointShopLaunchPrice(400, '계단형 외곽과 세 겹 장식 윤곽'),
  'frame:atelierAccordion': const PointShopLaunchPrice(300, '연속된 세 창과 접지'),
  'frame:atelierCornerFold': const PointShopLaunchPrice(200, '사선 절개와 접힌 뒷면'),
  // These existing starter phrases retain their free access after refinement.
  // Registration makes the server catalog explicit; it is not a new paid tier.
  'phrase:collage-bold-cut': const PointShopLaunchPrice(
    0,
    '기존 무료 기본 문구 유지 · 편집 가능한 컷아웃 타이포 조합 개선',
  ),
  'phrase:collage-ticket-label': const PointShopLaunchPrice(
    0,
    '기존 무료 기본 문구 유지 · 편집 가능한 티켓 라벨 조판 개선',
  ),
  'phrase:collage-hand-note': const PointShopLaunchPrice(
    0,
    '기존 무료 기본 문구 유지 · 편집 가능한 손글씨 메모 조판 개선',
  ),
  'phrase:collage-diecut': const PointShopLaunchPrice(
    0,
    '기존 무료 기본 문구 유지 · 편집 가능한 겹인쇄 타이포 조합 개선',
  ),
  'phrase:collage-atelier-vow': const PointShopLaunchPrice(
    400,
    '압인판·제목·날짜의 다층 조판',
  ),
  'phrase:collage-atelier-promise': const PointShopLaunchPrice(
    300,
    '명조와 손글씨의 비대칭 조판',
  ),
  'phrase:collage-atelier-ribbon': const PointShopLaunchPrice(300, '리본과 제목·서명'),
  'phrase:collage-atelier-boarding': const PointShopLaunchPrice(
    400,
    '탑승권 구조와 여행 정보',
  ),
  'phrase:collage-atelier-route': const PointShopLaunchPrice(
    300,
    '번호·제목·노선 기록',
  ),
  'phrase:collage-atelier-postcard': const PointShopLaunchPrice(
    300,
    '도시 제목과 수신 문구',
  ),
  'phrase:collage-atelier-diary': const PointShopLaunchPrice(300, '모눈지·손글씨·날짜'),
  'phrase:collage-atelier-index': const PointShopLaunchPrice(300, '번호와 목차형 조판'),
  'phrase:collage-atelier-archive': const PointShopLaunchPrice(
    400,
    '타원 인장 안의 다단 제목',
  ),
  'phrase:collage-atelier-first-year': const PointShopLaunchPrice(
    400,
    '대형 숫자·제목·손글씨 구성',
  ),
  'phrase:collage-atelier-first-time': const PointShopLaunchPrice(
    300,
    '제목과 날짜·장소 기록',
  ),
  'phrase:collage-atelier-weekend': const PointShopLaunchPrice(
    300,
    '포토 홀더와 제목·손글씨',
  ),
  'phrase:collage-atelier-anniversary': const PointShopLaunchPrice(
    400,
    '숫자·단위·날짜가 분리된 조판',
  ),
  'phrase:collage-atelier-walk': const PointShopLaunchPrice(
    300,
    '손글씨 제목과 산책 라벨',
  ),
  'phrase:collage-atelier-laughter': const PointShopLaunchPrice(
    400,
    '다층 종이와 컷아웃 타이포',
  ),
  'phrase:collage-atelier-cinema': const PointShopLaunchPrice(
    300,
    '장면 번호·제목·크레딧',
  ),
  for (final product in pendingPremiumVolumeProducts)
    product.productKey: const PointShopLaunchPrice(
      premiumVolumeLaunchPointPrice,
      '기본판·확장판과 인쇄 5가지 크기을 묶은 컬렉션 출시 가격',
    ),
  for (final product in pendingConceptVolumeProducts)
    product.productKey: const PointShopLaunchPrice(
      conceptVolumeLaunchPointPrice,
      '컨셉별 24쪽 조판과 인쇄 5가지 크기을 묶은 단일 에디션 출시 가격',
    ),
  for (final product in pendingAtelierEditionProducts)
    product.productKey: const PointShopLaunchPrice(
      atelierEditionProposedPointPrice,
      '신규 표지 사진·32쪽 조판·인쇄 5가지 크기을 묶은 출시 가격',
    ),
  for (final product in pendingStudioEditionProducts)
    product.productKey: PointShopLaunchPrice(2800, switch (product.assetId) {
      'velvet-vow-archive' => '웨딩 접지·서약문·압인 사진 창 · 내지 32쪽 · 인쇄 5가지 크기',
      'little-explorer-book' => '발견 기록·그림책형 조판·전용 사진 창 · 내지 32쪽 · 인쇄 5가지 크기',
      'companion-journal' => '반려생활 매거진 조판 · 내지 32쪽 · 인쇄 5가지 크기',
      'summer-keepsake-box' => '여름 전용 직조·접지·겹침 조판 · 내지 32쪽 · 인쇄 5가지 크기',
      _ => '도시 전용 포토저널 조판 · 내지 32쪽 · 인쇄 5가지 크기',
    }),
});

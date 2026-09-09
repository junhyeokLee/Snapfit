import '../../../core/templates/authored_collections.dart';
import 'point_shop_template_key.dart';
import 'premium_volume_registration.dart';

/// Editorial launch prices, never a replacement for the server's purchase quote.
/// Unknown keys remain unreviewed; opening the catalog performs no price writes.
class PointShopLaunchPrice {
  const PointShopLaunchPrice(this.points, this.reason);
  final int points;
  final String reason;
}

const pointShopPricingRevision = '2026-09-10-catalog-5';

final pointShopLaunchPrices = Map<String, PointShopLaunchPrice>.unmodifiable({
  for (final collection in authoredCollections)
    pointShopAuthoredTemplateKey(collection): const PointShopLaunchPrice(
      0,
      '기존 무료 완성 템플릿 기준 유지 · 세 규격 포함',
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
      '기본판·확장판과 세 규격을 묶은 컬렉션 출시 가격',
    ),
  for (final product in pendingConceptVolumeProducts)
    product.productKey: const PointShopLaunchPrice(
      conceptVolumeLaunchPointPrice,
      '컨셉별 24쪽 조판과 세 규격을 묶은 단일 에디션 출시 가격',
    ),
});

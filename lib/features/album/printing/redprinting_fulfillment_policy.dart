/// Operational facts from the vendor reply shared by the user on 2026-09-10.
/// The email's actual receipt date was not provided. These facts do not certify
/// a particular PDF, order configuration, or cost estimate.
abstract final class RedprintingFulfillmentPolicy {
  /// Sender name selected by the operator for future vendor orders.
  static const senderName = '스냅핏';
  static const replySharedOn = '2026-09-10';
  static const sourceLabel = '레드프린팅 회신 · 2026-09-10 사용자 공유';

  static const dispatchEstimate = '제작·출고 예상 영업일 5~6일 · 택배 배송 기간 별도';
  static const dispatchInstructions =
      '실제 예상 출고일은 업체 주문창의 [주문하기] 버튼 하단에서 확인합니다.';
  static const directShippingInstructions =
      '배송지마다 각각 주문합니다. 보내는 고객정보에서 [주문자(발송자명)변경]을 체크하고 발송자명을 $senderName으로 설정합니다.';
  static const packagingNotice = '별도 동봉 자료는 없으며, OPP 포장에 업체 주문번호 스티커가 부착됩니다.';
  static const fileSubmissionInstructions =
      '내지는 페이지 순서대로 각 페이지를 담은 PDF 한 파일로 제출합니다. 표지는 업체가 제공하는 해당 상품의 표지 템플릿에 맞춥니다. 별도 도안은 제공되지 않습니다.';
  static const colorInstructions =
      '인화지는 RGB 모드로 작업합니다. 업체가 추천하는 ICC 프로파일은 없으며, 현재 sRGB는 SnapFit의 출력 기준입니다.';
  static const internalReviewInstructions =
      '업체는 사전 검수를 제공하지 않습니다. SnapFit이 표지 템플릿·페이지 순서·재단 여백·사진과 글씨를 직접 검수하고 실물 샘플 확인 근거를 남깁니다.';
  static const archiveNotice =
      '업체는 파일을 보관하지 않습니다. 주문별 표지·내지 PDF와 원본은 SnapFit에서 보관합니다.';
  static const pricingInstructions =
      '별도 견적서는 제공되지 않습니다. 업체 주문창에서 실제 규격·표지·페이지 수·수량을 입력한 뒤 청구금액과 배송비를 확인해 원가에 반영합니다.';
  static const smsInstructions =
      '주문 후 파일 문제가 있으면 고객정보 연락처로 문자 안내가 옵니다. 운영자가 받을 수 있는 연락처인지 확인합니다.';
  static const evidenceReference =
      '$sourceLabel: 발송자명 변경 가능, 별도 동봉 자료 없음, OPP 포장에 주문번호 스티커 부착. 실제 주문의 발송자명·배송지 설정은 별도로 확인합니다.';
}

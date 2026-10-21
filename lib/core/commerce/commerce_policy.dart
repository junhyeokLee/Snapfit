/// Customer-facing preparation documents. These do not certify a business
/// registration, payment contract, supplier contract, or a retention workflow.
enum CommercePolicyKind {
  terms,
  privacy,
  refund,
  shipping,
  seller,
  marketing,
  opensource,
}

class CommercePolicySection {
  const CommercePolicySection({required this.heading, required this.content});

  final String heading;
  final String content;
}

class CommercePolicyDocument {
  const CommercePolicyDocument({
    required this.kind,
    required this.title,
    required this.summary,
    required this.version,
    required this.sections,
    this.effectiveDate = CommercePolicy.effectiveDate,
  });

  final CommercePolicyKind kind;
  final String title;
  final String summary;
  final String version;
  final String effectiveDate;
  final List<CommercePolicySection> sections;
}

abstract final class CommercePolicy {
  static const updatedDate = '2026.10.19';
  static const effectiveDate = '운영 개시 전 확정 예정';
  static const termsVersion = 'v1.5-prelaunch-20261019';
  static const privacyVersion = 'v1.4-prelaunch-20261019';
  static const refundVersion = 'v1.0-prelaunch-20261019';
  static const contactEmail = 'junhyeoklee616@gmail.com';

  static const draftNotice =
      '스냅핏은 현재 개발·서비스 준비 단계입니다. 사업자등록과 운영 계약은 아직 완료되지 않았으며, 실제 결제·유료 주문·실제 제작은 열려 있지 않습니다. '
      '아래 문서는 운영 전 준비본이며, 확정되지 않은 판매자 정보와 시행일은 정식 판매 전에 안내합니다.';
  static const dispatchEstimate =
      '제작·출고 예상 영업일 5~6일이며 택배 배송 기간은 별도입니다. 정식 판매 전 실제 사양별 일정을 확인해 안내합니다.';
  static const refundSummary =
      '제작 시작 전 취소는 전액 환불을 원칙으로 준비합니다. 제작 시작 후 주문제작 상품의 단순 변심 취소는 법정 요건과 별도 사전 고지·동의가 충족된 경우에 제한될 수 있습니다. '
      '불량·오배송·계약과 다른 제작에 대한 법정 권리는 별도로 보장됩니다.';
  static const customProductionConsent =
      '주문 확정 후 제 앨범 내용으로 개별 제작되며, 제작이 시작되어 회복하기 어려운 중대한 손해가 예상되는 경우 단순 변심에 따른 청약철회가 제한될 수 있음을 안내받고 동의합니다. '
      '제작 전 취소 요청과 불량·오배송 등 법정 권리는 별도로 보장됩니다.';

  static const documents = <CommercePolicyDocument>[
    CommercePolicyDocument(
      kind: CommercePolicyKind.terms,
      title: '서비스 이용약관',
      summary: '앨범 편집·저장과 주문 서비스의 이용 기준입니다. 현재는 운영 전 준비본입니다.',
      version: termsVersion,
      sections: [
        CommercePolicySection(
          heading: '1. 서비스와 현재 운영 상태',
          content: draftNotice,
        ),
        CommercePolicySection(
          heading: '2. 회원가입과 계정',
          content:
              '이용자는 지원되는 이메일 또는 소셜 로그인으로 가입할 수 있습니다. 이메일 가입은 인증 완료가 필요합니다. '
              '본인이 사용할 수 있는 정보를 입력하고 계정을 안전하게 관리해야 합니다. 다른 사람의 계정을 무단으로 이용하거나 타인에게 피해를 주는 방식으로 사용해서는 안 됩니다.',
        ),
        CommercePolicySection(
          heading: '3. 앨범과 업로드한 콘텐츠',
          content:
              '스냅핏은 사진 업로드, 앨범 편집·저장, 템플릿·소재 및 지원되는 AI 편집 기능을 제공합니다. '
              '업로드한 사진·글의 권리는 이용자와 정당한 권리자에게 남습니다. 스냅핏은 저장·편집·이용자가 요청한 AI 처리·인쇄 준비 등 서비스 제공에 필요한 범위에서 콘텐츠를 처리합니다. '
              '이용자는 업로드·제작할 권리가 있는 콘텐츠를 사용해야 하며 타인의 저작권·초상권·개인정보를 침해해서는 안 됩니다.',
        ),
        CommercePolicySection(
          heading: '4. 상품·가격과 주문 성립',
          content:
              '정식 판매 시 규격, 커버, 페이지 수, 수량, 판매가, 배송비와 결제 총액을 주문 전에 표시합니다. 현재 표시되는 준비 가격·견적은 판매 개시 또는 주문 접수 약속이 아닙니다. '
              '내용·가격·배송지를 확인하고 결제를 완료한 뒤 서버가 결제와 주문 접수를 확인한 경우 주문 내역에 결과를 안내합니다. '
              '결제 화면의 성공 표시만으로 제작이 시작된 것으로 보지 않으며, 접수 실패·중복·금액 불일치 등이 확인되면 상태 확인과 취소·환불 절차를 안내합니다.',
        ),
        CommercePolicySection(
          heading: '5. 인쇄 내용 확인과 변경',
          content:
              '주문 전 최종 미리보기에서 사진·글·페이지 순서·재단 위치·제작 사양을 확인해야 합니다. 제작은 확정된 주문의 파일을 기준으로 진행하며, 이후 앨범 편집이 이미 접수된 인쇄 파일에 자동 반영되지는 않습니다. '
              '모니터와 인쇄물의 색상 차이 등 상품 특성은 주문 전에 안내하며, 안내한 범위를 벗어난 하자나 계약과 다른 제작에 대한 책임까지 면제되는 것은 아닙니다.',
        ),
        CommercePolicySection(
          heading: '6. 취소·환불과 배송',
          content:
              '$refundSummary 자세한 기준은 취소·환불 정책 및 제작·배송 안내를 따릅니다. '
              '법령이 정한 이용자 권리는 약관보다 우선합니다. $dispatchEstimate',
        ),
        CommercePolicySection(
          heading: '7. 서비스 변경·제한과 탈퇴',
          content:
              '점검, 보안 또는 서비스 변경으로 이용에 영향을 주는 경우 가능한 범위에서 사유와 일정을 안내합니다. '
              '불법 콘텐츠, 권리 침해, 다른 이용자에 대한 피해, 비정상적인 접근이 확인되면 필요한 범위에서 이용을 제한할 수 있으며, 긴급하지 않은 경우 사유와 이의 제기 방법을 안내합니다. '
              '이용자는 계정 설정에서 탈퇴하거나 문의 이메일로 요청할 수 있습니다. 주문·정산·분쟁 등 별도 처리가 필요한 기록은 해당 법령과 개인정보 처리방침에 따라 처리합니다.',
        ),
        CommercePolicySection(
          heading: '8. 문의와 정책 변경',
          content:
              '문의: $contactEmail. 정책을 변경할 경우 변경 내용·적용 시점과 필요한 동의 절차를 서비스에서 안내합니다. '
              '판매자 상호·사업자등록번호·통신판매업 신고 정보 등은 정식 판매 전에 판매자 정보 화면에 확정하여 공개합니다.',
        ),
      ],
    ),
    CommercePolicyDocument(
      kind: CommercePolicyKind.privacy,
      title: '개인정보 처리방침',
      summary: '현재 개발 서비스의 정보 처리와 정식 주문 운영 전에 확정할 범위를 안내합니다.',
      version: privacyVersion,
      sections: [
        CommercePolicySection(
          heading: '1. 문서 상태와 문의',
          content:
              '$draftNotice 개인정보 관련 문의: $contactEmail. 운영 준비 담당자는 이준혁입니다. 정식 판매 전 개인정보 보호책임자와 사업자 정보를 확정합니다.',
        ),
        CommercePolicySection(
          heading: '2. 처리하는 정보와 목적',
          content:
              '계정 식별자·이메일·선택한 소셜 로그인 제공 정보·프로필과 동의 기록은 가입, 인증, 계정 관리에 이용합니다. '
              '이용자가 올린 사진·글·앨범과 템플릿 선택 정보는 앨범 저장·편집·공유 및 이용자가 요청한 기능을 제공하는 데 이용합니다. '
              'AI 기능을 요청한 경우 해당 기능에 필요한 입력과 결과를 처리합니다. 접속·오류·알림 설정과 기기 토큰 등은 보안, 장애 대응, 요청한 알림 전달에 이용합니다. '
              '향후 정식 주문 시 수령인 이름·연락처·배송지·배송 요청, 주문 사양·결제 식별자·결제 및 배송 상태를 주문 이행과 고객 문의 처리에 이용합니다. 카드번호 등 결제수단 인증정보는 결제사 화면에서 입력하도록 구성합니다.',
        ),
        CommercePolicySection(
          heading: '3. 선택 정보와 동의',
          content:
              '정보는 계약 이행, 이용자의 동의 등 해당 처리에 맞는 적법한 근거에 따라 필요한 범위에서 처리합니다. '
              '선택적인 프로필, 마케팅 수신, 푸시 권한은 거부하거나 철회할 수 있습니다. 마케팅 동의를 하지 않아도 회원가입과 기본 서비스를 이용할 수 있습니다. '
              '카메라·사진·알림 등 기기 권한은 해당 기능 사용에 필요한 시점에 요청하며 기기 또는 브라우저 설정에서 변경할 수 있습니다.',
        ),
        CommercePolicySection(
          heading: '4. 서비스 제공자와 운영 전 확인 사항',
          content:
              '개발 서비스는 Supabase의 계정·데이터·파일 기능과 Brevo의 인증메일 발송, Firebase의 알림 기능을 사용합니다. 선택한 로그인 제공자(Google·카카오)는 해당 계정 인증을 처리합니다. '
              'AI 기능에서 사용하는 외부 처리 서비스, 각 서비스의 정확한 계약 주체·처리 지역·항목·기간과 국외 이전의 법적 근거 및 고지 사항은 실제 설정과 계약을 확인하여 정식 운영 전에 확정합니다. '
              '준비되지 않은 수탁자 계약이나 국외 이전 절차가 완료된 것으로 안내하지 않습니다.',
        ),
        CommercePolicySection(
          heading: '5. 결제·제작·배송 정보의 전달',
          content:
              '정식 판매 시 포트원 및 연결 PG는 결제 승인·조회·취소 등 필요한 정보를, 레드프린팅은 제작 사양·인쇄 PDF와 수령인 이름·연락처·주소 등 제작·배송에 필요한 정보를 처리하도록 준비하고 있습니다. '
              '현재는 개발 연동 단계이며 레드프린팅 운영 계약과 실제 제작을 위한 개인정보 처리위탁 계약이 완료된 상태가 아닙니다. '
              '정식 주문 전 실제 수탁자·업무·항목·보관 기준을 공개하고, 위탁과 제3자 제공의 관계에 맞는 계약·고지·동의 절차를 갖춥니다. 광고 목적의 제공은 주문 처리와 구분합니다.',
        ),
        CommercePolicySection(
          heading: '6. 앨범·사진·인쇄 파일 보관과 삭제',
          content:
              '저장한 앨범·사진은 이용자의 편집·열람을 위한 데이터이며 주문 거래기록과 구분합니다. 인쇄용 PDF는 주문 준비, 파일 전달, 제작 상태 확인 등에 사용합니다. '
              '현재 개발 시스템에는 미결제 파일 중 안전하게 삭제할 수 있는 만료·취소·실패 건을 정리하는 절차가 있으나, 모든 업로드 파일이 만료 즉시 삭제되는 것은 아닙니다. '
              '파일 다운로드 링크의 만료는 저장된 원본의 삭제를 뜻하지 않습니다. 운영용 인쇄 PDF 보관 기준은 제작업체 출고 확인일로부터 120일로 준비합니다. '
              '미해결 문의·취소·환불·분쟁이 있거나 별도 보존이 필요한 파일은 필요한 사유가 해소될 때까지 보존합니다. 이 기준은 이용자가 저장한 원본 앨범·사진의 자동 삭제 기준이 아닙니다. '
              '현재 개발 단계에서는 이 인쇄 파일 자동 삭제 작업을 가동하지 않습니다. 정식 운영 전 적용 시점과 계정 탈퇴 후 저장소 파일 삭제 절차·백업 반영 범위를 확정하여 안내하며, 현재 특정 일수 뒤 일괄 자동 삭제를 보장하지 않습니다. '
              '삭제·처리정지 요청은 $contactEmail로 접수할 수 있습니다. 보관이 필요한 사유가 있으면 대상과 사유를 안내합니다.',
        ),
        CommercePolicySection(
          heading: '7. 법령에 따라 보존하는 거래기록',
          content:
              '정식 거래가 발생한 경우 계약·청약철회 기록은 5년, 대금결제·재화 공급 기록은 5년, 소비자 불만·분쟁처리 기록은 3년, 표시·광고 기록은 6개월 보관하는 기준을 적용합니다. '
              '별도 법령에 따른 보존 사유가 있으면 해당 범위에서 보관합니다. 보존 목적의 기록은 일반 이용 데이터와 구분하고 기간이 끝나면 파기합니다. '
              '이 기간이 모든 원본 사진과 인쇄 PDF를 같은 기간 보관해야 한다는 의미는 아닙니다.',
        ),
        CommercePolicySection(
          heading: '8. 보호조치와 이용자 권리',
          content:
              '접근 권한 관리, 인증, 전송 구간 보호 등 서비스에 맞는 조치를 적용하며 외부 전달 링크와 운영 자격정보를 구분하여 관리합니다. '
              '이용자는 정보의 열람·정정·삭제·처리정지와 동의 철회를 요청할 수 있습니다. 요청을 받으면 본인 확인 후 법령에 따라 처리하고, 제한 사유가 있으면 안내합니다. '
              '정식 운영 전 확정하는 처리방침은 시행일과 변경 내용을 서비스에서 안내합니다.',
        ),
      ],
    ),
    CommercePolicyDocument(
      kind: CommercePolicyKind.refund,
      title: '취소·환불 정책',
      summary: '제작 전 취소, 주문제작 상품의 제한 요건, 불량·오배송 처리 기준을 구분합니다.',
      version: refundVersion,
      sections: [
        CommercePolicySection(heading: '현재 주문 접수 상태', content: draftNotice),
        CommercePolicySection(
          heading: '제작 시작 전 취소',
          content:
              '정식 판매 시 제작 시작 전 취소는 전액 환불을 원칙으로 준비합니다. 주문 내역에서 취소 요청하거나 문의 이메일로 주문 식별정보와 요청 내용을 보내면 결제·업체 접수 상태를 확인합니다. '
              '요청 접수와 취소 확정은 구분하며, 상태 확인 중 중복 결제나 재주문을 요구하지 않습니다. 취소가 확정되면 원 결제수단으로 환불을 요청하고 결과를 주문 내역에 안내합니다.',
        ),
        CommercePolicySection(
          heading: '제작 시작 후 단순 변심',
          content:
              '앨범은 주문자가 확정한 사진·글·사양으로 개별 생산됩니다. 청약철회를 인정하면 판매자에게 회복할 수 없는 중대한 피해가 예상되고, 해당 거래에 대해 사전에 별도 고지하여 서면 또는 전자문서 동의를 받은 경우에 한해 법령상 주문제작 제한이 적용될 수 있습니다. '
              '상품이 주문제작이라는 이유만으로 모든 취소·환불을 배제하지 않습니다. 제작 시작 여부와 제한 적용 근거를 확인하여 안내하며, 요건이 충족되지 않은 경우 법령에 따른 청약철회 권리를 보장합니다.',
        ),
        CommercePolicySection(
          heading: '일반 청약철회와 반송 비용',
          content:
              '법정 청약철회 제한이 적용되지 않는 경우 계약 내용에 관한 서면을 받은 날부터 7일 이내, 상품 공급이 더 늦은 경우 공급받은 날부터 7일 이내의 청약철회를 보장합니다. '
              '계약 서면 미교부 등 법령상 별도 기산 사유가 있으면 해당 기준을 따릅니다. '
              '단순 변심으로 반송하는 경우 실제 반환에 필요한 비용은 이용자가 부담할 수 있으며 청약철회를 이유로 별도 위약금이나 손해배상금을 부과하지 않습니다. 불량·오배송 등 판매자 귀책의 반환 비용은 판매자가 부담합니다.',
        ),
        CommercePolicySection(
          heading: '주문 시 별도로 확인할 내용',
          content:
              '$customProductionConsent 이 확인은 일반 이용약관·마케팅 동의와 구분하고 미리 선택하지 않습니다. 주문 시 실제 고지 내용·버전과 동의 기록을 확인할 수 있도록 운영 전 보관 절차를 갖춥니다.',
        ),
        CommercePolicySection(
          heading: '불량·파손·오배송·계약과 다른 제작',
          content:
              '판매자 또는 제작·배송 과정의 귀책이 확인되면 필요한 재제작·교환·환불을 진행하며 해당 반송·재배송 비용을 소비자에게 부담시키지 않습니다. '
              '표시·광고나 계약 내용과 다르게 이행된 경우에는 공급받은 날부터 3개월 이내, 그 사실을 안 날 또는 알 수 있었던 날부터 30일 이내의 법정 청약철회 기준을 적용합니다. '
              '확인에 도움이 되는 주문번호와 하자 사진을 요청할 수 있으나, 공급사의 자체 접수기한이나 포장 개봉만을 이유로 법정 권리를 일괄 제한하지 않습니다.',
        ),
        CommercePolicySection(
          heading: '파일 내용·색상·배송지 관련 확인',
          content:
              '확정 미리보기와 동일하게 제작된 경우의 오탈자·이용자 선택 사진·입력 주소 등은 제작 상태와 책임 범위를 확인하여 처리합니다. '
              '화면과 인쇄의 특성은 상품 안내에 구체적으로 알리며, 이를 근거로 인쇄 불량이나 안내와 다른 결과에 대한 책임까지 배제하지 않습니다. 주소 변경·재배송은 실제 진행 가능 여부와 추가 비용을 먼저 안내합니다.',
        ),
        CommercePolicySection(
          heading: '환불 시점·접수 경로',
          content:
              '상품을 공급한 경우 반환받은 날, 아직 공급하지 않은 경우 청약철회한 날부터 3영업일 이내에 환급하고, 결제수단 취소에 필요한 조치를 지체 없이 진행합니다. '
              '카드사 등에서 실제 이용내역에 반영하는 시점은 결제수단에 따라 달라질 수 있으므로 요청일·처리 결과를 안내합니다. '
              '반품이 필요한 경우 담당자가 접수 방법과 반품지를 먼저 안내합니다. 아직 확정되지 않은 개인 주소로 임의 발송하도록 요구하지 않습니다. 문의: $contactEmail.',
        ),
      ],
    ),
    CommercePolicyDocument(
      kind: CommercePolicyKind.shipping,
      title: '제작·배송 안내',
      summary: '상품 구성, 제작 시작 시점, 예상 출고와 배송비 확인 방법을 안내합니다.',
      version: 'v1.0-prelaunch-20261019',
      sections: [
        CommercePolicySection(heading: '현재 제공 상태', content: draftNotice),
        CommercePolicySection(
          heading: '규격·커버·페이지',
          content:
              '지원 예정 규격은 200×150, 200×200, 250×200, 250×250, 300×300mm이며 커버는 소프트커버·하드커버입니다. '
              '내지는 20~80페이지의 짝수 단위로 준비하고 있습니다. 표지와 내지의 페이지 계산은 주문 화면의 안내를 따릅니다. '
              '실제 판매는 주문관리코드 승인과 파일·실물 검수를 마친 조합에 한해 열리며 모든 예정 조합이 현재 주문 가능한 것은 아닙니다.',
        ),
        CommercePolicySection(
          heading: '제작·출고와 배송 기간',
          content:
              '$dispatchEstimate 제작 시작은 결제 성공 화면이 아니라 인쇄 파일 확인과 제작 확정 상태를 기준으로 안내합니다. '
              '주말·공휴일, 파일 보완, 물량, 배송 지역 등에 따라 달라질 수 있으며 변경·지연이 확인되면 주문 내역이나 연락처로 안내합니다. '
              '운송장 발급과 택배사 인계, 배송 완료를 구분하여 표시합니다.',
        ),
        CommercePolicySection(
          heading: '가격·배송비와 발송 정보',
          content:
              '정식 판매 시 세금 포함 상품 판매가, 배송비·추가 배송비와 결제 총액을 결제 전에 표시합니다. 현재의 배송비와 판매가는 준비 가격이며 업체 무료배송 조건이 고객 판매가의 무료배송 조건으로 자동 적용되지는 않습니다. '
              '발송자명은 스냅핏으로 준비하며 가격표·거래명세서·제작사 홍보물 미동봉 조건은 운영 계약과 실물 샘플로 확인한 뒤 확정합니다.',
        ),
        CommercePolicySection(
          heading: '배송지 변경·누락·파손',
          content:
              '주문 내역 또는 $contactEmail로 문의해 주세요. 배송지 수정은 제작·출고 상태에 따라 가능 여부를 확인합니다. '
              '누락·파손·오배송은 취소·환불 정책에 따라 접수하며, 제작업체의 내부 처리 상태와 별개로 스냅핏에서 주문 문의를 받습니다.',
        ),
      ],
    ),
    CommercePolicyDocument(
      kind: CommercePolicyKind.seller,
      title: '판매자 정보',
      summary: '확인된 서비스 연락처와 아직 등록되지 않은 사업자 정보를 구분합니다.',
      version: 'v1.0-prelaunch-20261019',
      sections: [
        CommercePolicySection(heading: '서비스 준비 상태', content: draftNotice),
        CommercePolicySection(
          heading: '확인된 정보',
          content: '서비스명: 스냅핏\n운영 준비 담당: 이준혁\n문의 이메일: $contactEmail',
        ),
        CommercePolicySection(
          heading: '정식 판매 전 등록할 정보',
          content:
              '사업자 상호·대표자, 사업자등록번호, 사업장 주소, 고객센터 전화번호·운영시간, 통신판매업 신고번호 또는 면제 여부, 반품 접수 주소는 사업자등록과 운영 준비 후 확정합니다. '
              '등록되지 않은 번호나 주소를 임의로 기재하지 않습니다. 현재 준비 화면은 사업자등록 또는 PG·카드사 심사 승인을 받은 판매점이라는 의미가 아닙니다.',
        ),
        CommercePolicySection(
          heading: '현재 결제·계약 상태',
          content:
              '포트원과 레드프린팅은 개발 연동을 준비한 상태이며 운영 계약·운영 결제·실제 제작은 아직 활성화하지 않았습니다. '
              '문의만으로 주문이 접수되거나 요금이 청구되지 않습니다.',
        ),
      ],
    ),
    CommercePolicyDocument(
      kind: CommercePolicyKind.marketing,
      title: '마케팅 정보 수신 동의',
      summary: '선택 동의이며 가입·주문과 구분합니다.',
      version: 'v1.2-prelaunch-20261019',
      sections: [
        CommercePolicySection(
          heading: '선택 동의',
          content:
              '동의한 이용자에게 신규 템플릿·이벤트·혜택 등 마케팅 정보를 선택한 수단으로 안내할 수 있습니다. '
              '동의하지 않아도 가입과 기본 서비스 이용이 가능하며, 실제 전송 범위와 수단은 서비스 설정에서 안내합니다.',
        ),
        CommercePolicySection(
          heading: '철회와 필수 안내',
          content:
              '계정의 마케팅 수신 설정 또는 $contactEmail로 수신 거부를 요청할 수 있습니다. 기기·브라우저의 푸시 권한도 별도로 변경할 수 있습니다. '
              '계정 보안, 요청한 인증, 주문·결제·배송 등 서비스 이행에 필요한 안내는 마케팅과 구분됩니다. 마케팅을 거부한 이용자에게 광고를 필수 안내로 바꾸어 보내지 않습니다.',
        ),
      ],
    ),
    CommercePolicyDocument(
      kind: CommercePolicyKind.opensource,
      title: '오픈소스 라이선스',
      summary: '사용 중인 오픈소스 구성요소의 라이선스 고지 안내입니다.',
      version: 'v1.0',
      sections: [
        CommercePolicySection(
          heading: '저작권과 라이선스',
          content:
              '스냅핏이 사용하는 오픈소스 소프트웨어의 저작권은 각 권리자에게 있습니다. '
              '실제 포함된 구성요소에 대한 라이선스 고지와 원문을 제공합니다. 서비스 준비 문서의 변경이 해당 구성요소의 라이선스 조건을 변경하지 않습니다.',
        ),
      ],
    ),
  ];

  static CommercePolicyDocument document(CommercePolicyKind kind) =>
      documents.firstWhere((doc) => doc.kind == kind);
}

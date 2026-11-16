import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/commerce/commerce_policy.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/auth/domain/consent_policy.dart';
import 'package:snap_fit/features/billing/domain/web_point_topup.dart';

void main() {
  test(
    'every public policy has a unique document and no invented effective date',
    () {
      expect(
        CommercePolicy.documents.map((doc) => doc.kind).toSet(),
        CommercePolicyKind.values.toSet(),
      );
      for (final doc in CommercePolicy.documents) {
        expect(CommercePolicy.document(doc.kind), same(doc));
        expect(doc.effectiveDate, '운영 개시 전 확정 예정');
        expect(doc.sections, isNotEmpty);
        expect(
          doc.sections.every((section) => section.content.isNotEmpty),
          isTrue,
        );
      }
    },
  );

  test('stored signup consent versions identify the displayed documents', () {
    expect(
      ConsentPolicy.termsVersion,
      CommercePolicy.document(CommercePolicyKind.terms).version,
    );
    expect(
      ConsentPolicy.privacyVersion,
      CommercePolicy.document(CommercePolicyKind.privacy).version,
    );
    expect(
      CommercePolicy.document(CommercePolicyKind.refund).version,
      CommercePolicy.refundVersion,
    );
    expect(CommercePolicy.bundleVersion, 'v1.1-prelaunch-20261030');
    expect(CommercePolicy.refundVersion, CommercePolicy.bundleVersion);
    expect(CommercePolicy.termsVersion, 'v1.6-prelaunch-20261030');
    expect(CommercePolicy.privacyVersion, 'v1.5-prelaunch-20261030');
  });

  test(
    'shipping information describes only the current five catalog sizes',
    () {
      final shipping = CommercePolicy.document(
        CommercePolicyKind.shipping,
      ).sections.map((section) => section.content).join('\n');
      for (final size in coverSizes) {
        final width = (size.realSize.width * 10).round();
        final height = (size.realSize.height * 10).round();
        expect(shipping, contains('$width×$height'));
      }
      expect(shipping, isNot(contains('150×150')));
      expect(shipping, contains('모든 예정 조합이 현재 주문 가능한 것은 아닙니다'));
    },
  );

  test(
    'review and live sales remain distinct from registration and contract claims',
    () {
      final seller = CommercePolicy.document(
        CommercePolicyKind.seller,
      ).sections.map((section) => section.content).join('\n');
      expect(seller, contains('사업자등록을 마쳤으며'));
      expect(seller, contains('상호: 스냅핏'));
      expect(seller, contains('대표자: 이준혁'));
      expect(seller, contains('사업자등록번호: 219-14-74705'));
      expect(seller, contains('개인사업자(일반과세자)'));
      expect(seller, contains('등록증상 개업일: 2026.11.27'));
      expect(seller, contains('실제 판매 개시일이나 PG 심사 승인일을 의미하지 않습니다'));
      expect(seller, contains('실제 결제·유료 충전·유료 주문·실제 제작은 열려 있지 않습니다'));
      expect(seller, contains('PG·카드사 심사와 제작업체 운영 계약은 별도로'));
      expect(seller, contains(CommercePolicy.contactEmail));
      expect(seller, contains('통신판매업 신고번호 또는 적용 면제 여부는 아직 확정되지 않았으며'));
      expect(seller, contains('고객지원에서 접수 방법과 반품 주소를 확인해 안내'));
      final all = CommercePolicy.documents
          .expand((doc) => doc.sections)
          .map((section) => section.content)
          .join('\n');
      expect(all, isNot(contains('support@snapfit.app')));
      expect(all, isNot(contains('privacy@snapfit.app')));
      expect(all, isNot(contains('사업자등록과 운영 계약은 아직 완료되지 않았으며')));
      expect(all, isNot(matches(RegExp(r'\d{3,4}동\s*\d{3,4}호'))));
      expect(all, isNot(matches(RegExp(r'010[- ]?\d{4}[- ]?\d{4}'))));
    },
  );

  test(
    'web point refund rules preserve remaining paid value and manual review',
    () {
      final refund = CommercePolicy.document(
        CommercePolicyKind.refund,
      ).sections.map((section) => section.content).join('\n');
      expect(refund, contains('충전 결제일로부터 7일 이내'));
      expect(refund, contains('실제 결제금액 전액을 원 결제수단으로 환불'));
      expect(refund, contains('남은 유료 충전금액'));
      expect(refund, contains('환불 범위와 산정내역을 먼저 안내'));
      expect(refund, contains('실제 결제금액과 지급 포인트의 비율'));
      expect(refund, contains('구매 당시 알리지 않은 차감 순서를 사후에 만들어'));
      expect(refund, contains('무상 포인트는 현금 환불 대상에 포함하지 않습니다'));
      expect(refund, contains('부분 환불은 담당자의 확인'));
      expect(refund, contains(CommercePolicy.contactEmail));
      expect(refund, contains('Apple App Store 또는 Google Play'));
      expect(refund, isNot(contains('7일이 지나면 환불이 불가합니다')));
      expect(refund, isNot(contains('환불 신청 즉시 자동 환불됩니다')));
      expect(webPointTopupLiveCheckoutReleased, isFalse);
    },
  );

  test(
    'digital supply, defects and expiry are not physical-order restrictions',
    () {
      final refund = CommercePolicy.document(
        CommercePolicyKind.refund,
      ).sections.map((section) => section.content).join('\n');
      expect(refund, contains('포토북의 주문제작 취소 제한을 포인트나 디지털 상품에 그대로 적용하지 않습니다'));
      expect(refund, contains('아직 제공하지 않은 부분에 대한 청약철회 권리는 보장'));
      expect(refund, contains('법정 요건에 따른 사전 고지와 필요한 조치'));
      expect(refund, contains('오류·중복 차감·제공 실패'));
      expect(refund, contains('TEST 결제는 실제 대금 청구와 실제 포인트 지급이 없는 개발 기록'));
      expect(refund, contains('사용기간이나 자동 소멸 조건을 설정하지 않았으며'));
      expect(refund, contains('기존 잔액에 소급해 적용'));
      expect(refund, isNot(contains('충전일로부터 1년 후 자동 소멸')));
      expect(refund, isNot(contains('보너스 포인트부터 우선 차감')));
    },
  );

  test(
    'web point summaries describe own service and link to the full rules',
    () {
      expect(CommercePolicy.webPointUsageSummary, contains('템플릿·디자인 소재·AI'));
      expect(
        CommercePolicy.webPointUsageSummary,
        contains('실제 결제는 아직 열려 있지 않습니다'),
      );
      expect(CommercePolicy.webPointRefundSummary, contains('7일 이내 전액 환불'));
      expect(CommercePolicy.webPointRefundSummary, contains('담당자가 확인'));
      expect(CommercePolicy.webPointRefundSummary, contains('원 결제수단'));
      expect(CommercePolicy.webPointRefundSummary, contains('취소·환불 정책'));
    },
  );

  test(
    'custom production restriction retains separate consent and defect rights',
    () {
      final refund = CommercePolicy.document(
        CommercePolicyKind.refund,
      ).sections.map((section) => section.content).join('\n');
      expect(refund, contains(CommercePolicy.customProductionConsent));
      expect(refund, contains('미리 선택하지 않습니다'));
      expect(refund, contains('전자문서'));
      expect(refund, contains('공급사의 자체 접수기한'));
      expect(refund, contains('3개월'));
      expect(refund, contains('30일'));
    },
  );

  test(
    'photo deletion is not confused with legal transaction retention or URL expiry',
    () {
      final privacy = CommercePolicy.document(
        CommercePolicyKind.privacy,
      ).sections.map((section) => section.content).join('\n');
      expect(privacy, contains('파일 다운로드 링크의 만료는 저장된 원본의 삭제를 뜻하지 않습니다'));
      expect(privacy, contains('모든 원본 사진과 인쇄 PDF를 같은 기간 보관해야 한다는 의미는 아닙니다'));
      expect(privacy, contains('특정 일수 뒤 일괄 자동 삭제를 보장하지 않습니다'));
    },
  );
}

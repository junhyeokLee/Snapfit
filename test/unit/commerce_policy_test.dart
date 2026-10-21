import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/commerce/commerce_policy.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/auth/domain/consent_policy.dart';

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
      expect(seller, contains('사업자등록과 운영 계약은 아직 완료되지 않았으며'));
      expect(seller, contains(CommercePolicy.contactEmail));
      expect(seller, contains('등록되지 않은 번호나 주소를 임의로 기재하지 않습니다'));
      final all = CommercePolicy.documents
          .expand((doc) => doc.sections)
          .map((section) => section.content)
          .join('\n');
      expect(all, isNot(contains('support@snapfit.app')));
      expect(all, isNot(contains('privacy@snapfit.app')));
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

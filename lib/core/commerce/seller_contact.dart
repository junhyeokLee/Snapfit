/// Public business contact details are supplied only to an approved web build.
/// Keep the owner's residential address and private phone out of source history.
abstract final class SellerContact {
  static const businessAddress = String.fromEnvironment(
    'SNAPFIT_SELLER_BUSINESS_ADDRESS',
  );
  static const supportPhone = String.fromEnvironment(
    'SNAPFIT_SELLER_SUPPORT_PHONE',
  );
  static const supportHours = '이메일 상시 접수 · 영업일 순차 답변';
  static const mailOrderStatus = '통신판매업 신고 또는 적용 면제 여부 확인 중';
}

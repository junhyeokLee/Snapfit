/// 충전 화면에 구매 목적만 전달합니다. 가격·잔액·구매 권한은 서버에서 다시 확인합니다.
class PointTopUpContext {
  const PointTopUpContext({
    required this.ownerId,
    required this.productKey,
    required this.title,
    required this.requiredPoints,
  });

  final String ownerId;
  final String productKey;
  final String title;
  final int requiredPoints;
}

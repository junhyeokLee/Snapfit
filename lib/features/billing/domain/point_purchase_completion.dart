/// 서버 검증과 스토어 완료, 영수증 정리가 끝난 뒤 표시하는 계정별 결과다.
/// alreadyGranted는 기존 구매 확인이며 새 포인트 지급으로 표시하지 않는다.
class PointPurchaseCompletion {
  const PointPurchaseCompletion({
    required this.ownerId,
    required this.productId,
    required this.grantedPoints,
    required this.remainingBalance,
    required this.alreadyGranted,
  });

  final String ownerId;
  final String productId;
  final int grantedPoints;
  final int remainingBalance;
  final bool alreadyGranted;
}

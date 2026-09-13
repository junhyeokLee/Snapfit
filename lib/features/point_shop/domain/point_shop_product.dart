class PointShopProduct {
  const PointShopProduct({
    required this.productKey,
    required this.kind,
    required this.assetId,
    required this.title,
    this.pointPrice,
    this.isActive = false,
  });

  final String productKey, kind, assetId, title;
  final int? pointPrice;
  final bool isActive;

  factory PointShopProduct.fromJson(Map<String, dynamic> json) =>
      PointShopProduct(
        productKey: json['product_key'] as String,
        kind: json['kind'] as String,
        assetId: json['asset_id'] as String,
        title: json['title'] as String,
        pointPrice: (json['point_price'] as num?)?.toInt(),
        isActive: json['is_active'] == true,
      );

  Map<String, dynamic> toJson() => {
    'product_key': productKey,
    'kind': kind,
    'asset_id': assetId,
    'title': title,
    'point_price': pointPrice,
    'is_active': isActive,
  };
}

class PointShopAccess {
  const PointShopAccess({
    required this.productKey,
    this.title,
    this.pointPrice,
    required this.available,
    required this.isFree,
    required this.owned,
    required this.remainingBalance,
  });

  final String productKey;
  final String? title;
  final int? pointPrice;
  final bool available, isFree, owned;
  final int remainingBalance;

  factory PointShopAccess.fromJson(Map<String, dynamic> json) =>
      PointShopAccess(
        productKey: json['product_key'] as String,
        title: json['title'] as String?,
        pointPrice: (json['point_price'] as num?)?.toInt(),
        available: json['available'] == true,
        isFree: json['is_free'] == true,
        owned: json['owned'] == true,
        remainingBalance: (json['remaining_balance'] as num?)?.toInt() ?? 0,
      );
}

class PointShopPurchase {
  const PointShopPurchase({
    required this.productKey,
    required this.owned,
    required this.isFree,
    required this.chargedPoints,
    required this.remainingBalance,
    required this.alreadyOwned,
  });

  final String productKey;
  final bool owned, isFree, alreadyOwned;
  final int chargedPoints, remainingBalance;

  factory PointShopPurchase.fromJson(Map<String, dynamic> json) =>
      PointShopPurchase(
        productKey: json['product_key'] as String,
        owned: json['owned'] == true,
        isFree: json['is_free'] == true,
        chargedPoints: (json['charged_points'] as num?)?.toInt() ?? 0,
        remainingBalance: (json['remaining_balance'] as num?)?.toInt() ?? 0,
        alreadyOwned: json['already_owned'] == true,
      );
}

class PointShopException implements Exception {
  const PointShopException(this.code);
  final String code;

  String get message => switch (code) {
    'authentication_required' => '로그인 후 구매할 수 있어요.',
    'account_changed' => '계정이 변경됐어요. 다시 선택해 주세요.',
    'point_shop_product_unavailable' => '아직 판매 준비 중인 상품이에요.',
    'point_shop_price_changed' => '가격이 변경됐어요. 새 가격을 확인해 주세요.',
    'insufficient_points' => '포인트가 부족해요. 충전 후 다시 구매해 주세요.',
    _ => '구매 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.',
  };

  @override
  String toString() => code;
}

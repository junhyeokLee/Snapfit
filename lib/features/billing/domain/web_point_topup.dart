/// Web consumables are separate from print payments and mobile IAP receipts.
/// Dormant live SDK/wallet paths require reviewed source releases on client,
/// Edge and SQL. All three release gates remain closed in this preparation.
const webPointTopupLiveCheckoutReleased = false;
const webPointTestStoreId = 'store-33df409e-0ad9-4953-8194-70db7e32efae';
const webPointTestChannelKey = 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88';

class WebPointProduct {
  const WebPointProduct({required this.id, required this.title,
    required this.points, required this.amount});
  final String id, title;
  final int points, amount;
  factory WebPointProduct.fromJson(Map<String, dynamic> json) {
    if (!_productId(json['productId']) || json['title'] is! String ||
        (json['title'] as String).isEmpty || (json['title'] as String).length > 200 || !_positive(json['points']) ||
        !_positive(json['totalAmount']) || (json['totalAmount'] as int) > 1000000 || json['currency'] != 'KRW') {
      throw const FormatException('web_point_product_invalid');
    }
    return WebPointProduct(id: json['productId'] as String, title: json['title'] as String,
      points: json['points'] as int, amount: json['totalAmount'] as int);
  }
}

class WebPointCatalog {
  const WebPointCatalog({required this.testAvailable, required this.liveAvailable,
    required this.environment, required this.products});
  final bool testAvailable, liveAvailable;
  final String environment;
  final List<WebPointProduct> products;
  factory WebPointCatalog.fromJson(Map<String, dynamic> json) {
    final available = json['available'] == true;
    final live = json['liveAvailable'] == true;
    if (json['liveCheckoutReleased'] != webPointTopupLiveCheckoutReleased ||
        json['available'] is! bool || json['testAvailable'] is! bool || json['liveAvailable'] is! bool ||
        available != (json['testAvailable'] == true || live) || json['products'] is! List ||
        (json['products'] as List).length > 50 ||
        live && (!webPointTopupLiveCheckoutReleased || json['environment'] != 'live' || json['isTest'] != false) ||
        available && !live && (json['environment'] != 'test' || json['isTest'] != true) ||
        !available && json['environment'] != 'disabled') {
      throw const FormatException('web_point_catalog_invalid');
    }
    final products = (json['products'] as List).map((raw) =>
      WebPointProduct.fromJson(_map(raw))).toList(growable: false);
    if (products.map((p) => p.id).toSet().length != products.length) {
      throw const FormatException('web_point_catalog_invalid');
    }
    return WebPointCatalog(testAvailable: json['testAvailable'] == true, liveAvailable: live,
      environment: json['environment'] as String, products: products);
  }
}

class WebPointTopup {
  const WebPointTopup._({required this.paymentId, required this.ownerId,
    required this.productId, required this.title, required this.points,
    required this.amount, required this.status, required this.createdAt,
    required this.expiresAt, required this.canLaunch, required this.serverVerified,
    required this.environment, required this.storeId, required this.channelKey,
    this.sdkStartedAt, this.verifiedAt, this.refundedAt});
  final String paymentId, ownerId, productId, title, status, environment, storeId, channelKey;
  bool get isTest => environment == 'test';
  final int points, amount;
  final DateTime createdAt, expiresAt;
  final DateTime? sdkStartedAt, verifiedAt, refundedAt;
  final bool canLaunch, serverVerified;
  bool get needsRecovery => sdkStartedAt != null &&
      const {'PREPARED','PENDING','REVIEW'}.contains(status);
  bool get pending => const {'PREPARED','PENDING','REVIEW'}.contains(status);
  String get statusLabel => switch (status) {
    'PREPARED' => isTest ? 'TEST 결제 준비' : '결제 준비',
    'PENDING' => isTest ? 'TEST 결제 확인 중' : '결제 확인 중',
    'VERIFIED_TEST' => 'TEST 승인 확인 · 실잔액 미반영',
    'CREDITED' => '결제 확인 · 포인트 지급 완료',
    'FAILED' => '결제 실패 확인',
    'VOIDED' => '지급 전 취소 확인',
    'REFUNDED' => isTest ? 'TEST 취소 확인 · 테스트 기록 회수' : '환불 확인 · 지급 포인트 회수',
    'REVIEW' => '취소·결제 상태 확인 필요',
    _ => '상태 확인 필요',
  };
  factory WebPointTopup.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse('${json['createdAt'] ?? ''}');
    final expires = DateTime.tryParse('${json['expiresAt'] ?? ''}');
    DateTime? optionalDate(String key) {
      if (json[key] == null) return null;
      final parsed = DateTime.tryParse('${json[key]}');
      if (parsed == null) throw const FormatException('web_point_topup_invalid');
      return parsed;
    }
    final verified = optionalDate('verifiedAt'), refunded = optionalDate('refundedAt');
    final status = json['status'];
    final isTest = json['environment'] == 'test';
    final isLive = json['environment'] == 'live';
    if (isLive && !webPointTopupLiveCheckoutReleased) throw const FormatException('web_point_live_closed');
    if (!_paymentId(json['paymentId']) || !_uuid(json['ownerId']) ||
        !_productId(json['productId']) || json['title'] is! String ||
        !_positive(json['points']) || !_positive(json['totalAmount']) ||
        (json['totalAmount'] as int) > 1000000 || !isTest && !isLive ||
        json['isTest'] != isTest || json['productionApproved'] != isLive ||
        json['currency'] != 'KRW' || json['realPointsGranted'] != (isLive && status == 'CREDITED' ? json['points'] : 0) ||
        isTest && (json['storeId'] != webPointTestStoreId || json['channelKey'] != webPointTestChannelKey || !(json['paymentId'] as String).startsWith('SFPTT_')) ||
        isLive && (!_liveRoute(json['storeId'], json['channelKey']) || !(json['paymentId'] as String).startsWith('SFPTL_')) ||
        created == null || expires == null ||
        !const {'PREPARED','PENDING','VERIFIED_TEST','CREDITED','FAILED','VOIDED','REFUNDED','REVIEW'}.contains(status) ||
        json['serverVerified'] != (verified != null) ||
        status == 'VERIFIED_TEST' && verified == null ||
        status == 'VERIFIED_TEST' && !isTest || status == 'CREDITED' && (!isLive || verified == null) ||
        status == 'REFUNDED' && (verified == null || refunded == null) ||
        status == 'VOIDED' && (verified != null || refunded == null)) {
      throw const FormatException('web_point_topup_invalid');
    }
    return WebPointTopup._(paymentId: json['paymentId'] as String, ownerId: json['ownerId'] as String,
      productId: json['productId'] as String, title: json['title'] as String,
      points: json['points'] as int, amount: json['totalAmount'] as int, status: status as String,
      createdAt: created, expiresAt: expires, sdkStartedAt: optionalDate('sdkStartedAt'),
      verifiedAt: verified, refundedAt: refunded, serverVerified: verified != null,
      environment: json['environment'] as String, storeId: json['storeId'] as String, channelKey: json['channelKey'] as String,
      canLaunch: json['canLaunch'] == true && status == 'PREPARED' && json['sdkStartedAt'] == null);
  }
}

/// Only the authenticated `launch` response can create an SDK request. TEST is
/// available to authorized development accounts; dormant live construction also
/// requires the closed client source release gate. SDK return never means paid.
class WebPointSdkRequest {
  const WebPointSdkRequest._(this.topup);
  final WebPointTopup topup;
  factory WebPointSdkRequest.fromAuthorized(Map<String, dynamic> json) {
    if (json['environment'] == 'live') return WebPointSdkRequest.fromProductionAuthorized(json);
    if (json['environment'] != 'test') throw const FormatException('web_point_sdk_request_invalid');
    return WebPointSdkRequest._checked(json);
  }
  /// Dormant production factory: changing an environment flag is insufficient.
  factory WebPointSdkRequest.fromProductionAuthorized(Map<String, dynamic> json) {
    if (!webPointTopupLiveCheckoutReleased || json['environment'] != 'live' || json['productionApproved'] != true) {
      throw const FormatException('web_point_live_closed');
    }
    return WebPointSdkRequest._checked(json);
  }
  static WebPointSdkRequest _checked(Map<String, dynamic> json) {
    final topup = WebPointTopup.fromJson(json);
    if (json['sdkLaunchAuthorized'] != true || topup.status != 'PENDING' ||
        topup.sdkStartedAt == null || !topup.expiresAt.isAfter(DateTime.now())) {
      throw const FormatException('web_point_sdk_request_invalid');
    }
    return WebPointSdkRequest._(topup);
  }
  Map<String, dynamic> toBrowserJson() => {
    'storeId': topup.storeId, 'channelKey': topup.channelKey,
    'paymentId': topup.paymentId, 'orderName': '스냅핏 ${topup.points}P ${topup.isTest ? 'TEST ' : ''}충전',
    'totalAmount': topup.amount, 'currency': 'KRW', 'payMethod': 'CARD',
  };
}

class WebPointTopupException implements Exception {
  const WebPointTopupException(this.code);
  final String code;
  String get message => switch (code) {
    'web_point_checkout_closed' => '웹 포인트 충전은 아직 열리지 않았어요.',
    'web_point_price_changed' => '상품 정보가 변경됐어요. 새로고침한 뒤 다시 확인해주세요.',
    'web_point_pending_exists' => '확인 중인 결제가 있어요. 기존 결제부터 확인해주세요.',
    'web_point_owner_changed' => '로그인 계정이 바뀌었어요. 포인트 화면을 다시 열어주세요.',
    'web_point_desktop_required' => '현재 웹 결제는 PC 브라우저에서 진행해주세요.',
    'web_point_launch_not_available' => '기존 결제 상태를 확인해주세요. 새 결제를 자동으로 시작하지 않습니다.',
    _ => '결제 확인이 지연되고 있어요. 다시 결제하지 말고 상태를 확인해주세요.',
  };
  @override String toString() => code;
}
Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('web_point_payload_invalid');
  return Map<String, dynamic>.from(value);
}
bool _positive(Object? v) => v is int && v > 0;
bool _productId(Object? v) => v is String && RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(v);
bool _uuid(Object? v) => v is String && RegExp(r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$', caseSensitive: false).hasMatch(v);
bool _paymentId(Object? v) => v is String && RegExp(r'^SFPT[TL]_').hasMatch(v) && _uuid(v.substring(6));
bool _liveRoute(Object? store, Object? channel) => store is String && channel is String &&
  RegExp(r'^store-[A-Za-z0-9-]{8,100}$').hasMatch(store) &&
  RegExp(r'^channel-key-[A-Za-z0-9-]{8,100}$').hasMatch(channel) && channel != webPointTestChannelKey;

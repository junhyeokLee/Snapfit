import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/billing/domain/pending_point_purchase.dart';
import 'package:snap_fit/features/billing/domain/pending_point_checkout.dart';

const sku = 'snapfit_points_2500';
final product = ProductDetails(
  id: sku,
  title: '2,500P',
  description: '',
  price: '₩2,200',
  rawPrice: 2200,
  currencyCode: 'KRW',
);

PurchaseDetails purchase({
  String token = 'test-token',
  String productId = sku,
  PurchaseStatus status = PurchaseStatus.purchased,
  String? nativeOwner,
  int? transactionTime,
}) {
  final time = transactionTime ?? DateTime.now().millisecondsSinceEpoch;
  final verification = PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: token,
    source: 'google_play',
  );
  if (nativeOwner == null) {
    return PurchaseDetails(
      productID: productId,
      purchaseID: 'order-$token',
      transactionDate: '$time',
      status: status,
      verificationData: verification,
    );
  }
  return GooglePlayPurchaseDetails(
    productID: productId,
    purchaseID: 'order-$token',
    transactionDate: '$time',
    status: status,
    verificationData: verification,
    billingClientPurchase: PurchaseWrapper(
      orderId: 'order-$token',
      packageName: 'com.snapfit.fixture',
      purchaseTime: time,
      purchaseToken: token,
      signature: 'fixture-signature',
      products: [productId],
      isAutoRenewing: false,
      originalJson: '{}',
      isAcknowledged: false,
      purchaseState: PurchaseStateWrapper.purchased,
      obfuscatedAccountId: nativeOwner,
    ),
  );
}

class MemoryReceipts implements PendingPointPurchaseStorage {
  List<PendingPointPurchase> records = [];
  List<PendingPointCheckout> checkouts = [];
  bool failReadCheckouts = false, failWriteCheckouts = false;
  bool failWrite = false;
  int writeCalls = 0;
  final failOnWrites = <int>{};
  @override
  Future<List<PendingPointPurchase>> read() async => List.of(records);
  @override
  Future<void> write(List<PendingPointPurchase> value) async {
    writeCalls++;
    if (failWrite || failOnWrites.contains(writeCalls)) {
      throw StateError('secure_storage_failed');
    }
    records = List.of(value);
  }

  @override
  Future<List<PendingPointCheckout>> readCheckouts() async {
    if (failReadCheckouts) throw StateError('checkout_storage_read_failed');
    return List.of(checkouts);
  }

  @override
  Future<void> writeCheckouts(List<PendingPointCheckout> value) async {
    if (failWriteCheckouts || failWrite)
      throw StateError('checkout_storage_write_failed');
    checkouts = List.of(value);
  }
}

class FakeStore implements PointPurchaseStore {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  final List<String> actions = [];
  final List<String> finished = [];
  List<PurchaseDetails> restored = [];
  Set<String> requestedIds = {};
  String? accountId;
  bool failFinish = false;
  int buyCalls = 0;
  Future<bool> Function(ProductDetails, String)? buyResponse;
  @override
  Stream<List<PurchaseDetails>> get updates => controller.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) async {
    requestedIds = ids;
    return ProductDetailsResponse(productDetails: [product], notFoundIDs: []);
  }

  @override
  Future<bool> buy(ProductDetails product, String accountId) async {
    buyCalls++;
    this.accountId = accountId;
    if (buyResponse != null) return buyResponse!(product, accountId);
    return true;
  }

  @override
  Future<List<PurchaseDetails>> unfinished(String accountId) async => restored;
  @override
  Future<void> finish(
    PendingPointPurchase record,
    PurchaseDetails? native,
  ) async {
    actions.add('finish');
    if (failFinish) throw StateError('finish_failed');
    finished.add(record.key);
  }
}

PointPurchaseService fakePointPurchaseService({
  FakeStore? store,
  MemoryReceipts? storage,
}) => PointPurchaseService(
  store: store ?? FakeStore(),
  storage: storage ?? MemoryReceipts(),
  currentUserId: () => 'owner',
  ensureServerAvailable: () async {},
  verify: (record) async => StorePointPurchaseResult(
    productId: record.productId,
    grantedPoints: 2500,
    remainingBalance: 2500,
  ),
  onBalanceChanged: () {},
);

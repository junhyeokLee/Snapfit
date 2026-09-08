import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/billing/domain/pending_point_purchase.dart';

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
}) => PurchaseDetails(
  productID: productId,
  purchaseID: 'order-$token',
  transactionDate: '123',
  status: status,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: token,
    source: 'google_play',
  ),
);

class MemoryReceipts implements PendingPointPurchaseStorage {
  List<PendingPointPurchase> records = [];
  bool failWrite = false;
  @override
  Future<List<PendingPointPurchase>> read() async => List.of(records);
  @override
  Future<void> write(List<PendingPointPurchase> value) async {
    if (failWrite) throw StateError('secure_storage_failed');
    records = List.of(value);
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
    this.accountId = accountId;
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

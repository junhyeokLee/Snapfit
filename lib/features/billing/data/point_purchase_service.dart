import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../../../config/env.dart';
import '../domain/billing_failure_copy.dart';
import '../domain/pending_point_purchase.dart';
import 'billing_repository.dart';

abstract class PointPurchaseStore {
  Stream<List<PurchaseDetails>> get updates;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> products(Set<String> ids);
  Future<bool> buy(ProductDetails product, String accountId);
  Future<List<PurchaseDetails>> unfinished(String accountId);
  Future<void> finish(PendingPointPurchase record, PurchaseDetails? purchase);
}

class NativePointPurchaseStore implements PointPurchaseStore {
  final InAppPurchase _iap = InAppPurchase.instance;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _apple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Stream<List<PurchaseDetails>> get updates => _iap.purchaseStream;
  @override
  Future<bool> isAvailable() async =>
      (_android || _apple) && await _iap.isAvailable();
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) =>
      _iap.queryProductDetails(ids);
  @override
  Future<bool> buy(
    ProductDetails product,
    String accountId,
  ) => _iap.buyConsumable(
    purchaseParam: PurchaseParam(
      productDetails: product,
      applicationUserName: accountId,
    ),
    // Apple requires autoConsume=true; Google consumption is deferred until delivery.
    autoConsume: !_android,
  );

  @override
  Future<List<PurchaseDetails>> unfinished(String accountId) async {
    if (_android) {
      final result = await _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .queryPastPurchases(applicationUserName: accountId);
      if (result.error != null) throw StateError('store_purchase_query_failed');
      return result.pastPurchases;
    }
    if (_apple && InAppPurchaseStoreKitPlatform.isStoreKit2Enabled) {
      final transactions = await SK2Transaction.unfinishedTransactions();
      return transactions
          .map(
            (t) => SK2PurchaseDetails(
              productID: t.productId,
              purchaseID: t.id,
              transactionDate: t.purchaseDate,
              appAccountToken: t.appAccountToken,
              status: PurchaseStatus.purchased,
              verificationData: PurchaseVerificationData(
                localVerificationData: t.jsonRepresentation ?? '',
                serverVerificationData: t.receiptData ?? '',
                source: 'app_store',
              ),
            ),
          )
          .toList();
    }
    if (_apple) await _iap.restorePurchases(applicationUserName: accountId);
    return [];
  }

  @override
  Future<void> finish(
    PendingPointPurchase record,
    PurchaseDetails? purchase,
  ) async {
    if (record.isGoogle) {
      final details =
          purchase ??
          PurchaseDetails(
            productID: record.productId,
            purchaseID: record.transactionId,
            transactionDate: record.transactionDate,
            status: PurchaseStatus.purchased,
            verificationData: PurchaseVerificationData(
              localVerificationData: record.localData,
              serverVerificationData: record.serverData,
              source: record.source,
            ),
          );
      final result = await _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .consumePurchase(details);
      // A retry after consumption succeeded but local persistence failed is safe.
      if (result.responseCode != BillingResponse.ok &&
          result.responseCode != BillingResponse.itemNotOwned) {
        throw StateError('store_consume_failed');
      }
    } else if (purchase != null) {
      // Restored SK2 transactions may not set pendingCompletePurchase.
      await _iap.completePurchase(purchase);
    } else if (_apple && InAppPurchaseStoreKitPlatform.isStoreKit2Enabled) {
      await SK2Transaction.finish(int.parse(record.transactionId));
    } else {
      throw StateError('store_transaction_redelivery_required');
    }
  }
}

abstract class PendingPointPurchaseStorage {
  Future<List<PendingPointPurchase>> read();
  Future<void> write(List<PendingPointPurchase> records);
}

class SecurePendingPointPurchaseStorage implements PendingPointPurchaseStorage {
  static const _key = 'snapfit_pending_point_purchases_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  @override
  Future<List<PendingPointPurchase>> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (e) => PendingPointPurchase.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> write(List<PendingPointPurchase> records) => records.isEmpty
      ? _storage.delete(key: _key)
      : _storage.write(
          key: _key,
          value: jsonEncode(records.map((e) => e.toJson()).toList()),
        );
}

/// One instance per app container; survives navigation away from the billing page.
class PointPurchaseService extends ChangeNotifier {
  PointPurchaseService({
    required this.store,
    required this.storage,
    required this.currentUserId,
    required this.ensureServerAvailable,
    required this.verify,
    required this.onBalanceChanged,
  });

  final PointPurchaseStore store;
  final PendingPointPurchaseStorage storage;
  final String? Function() currentUserId;
  final Future<void> Function() ensureServerAvailable;
  final Future<StorePointPurchaseResult> Function(PendingPointPurchase) verify;
  final VoidCallback onBalanceChanged;
  final Map<String, PendingPointPurchase> _pending = {};
  final Set<String> _finished = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _queue = Future.value();
  Future<void>? _load;
  Timer? _retry;
  Timer? _purchaseTimeout;
  bool _disposed = false;
  bool _started = false;
  bool _recovering = false;
  String? _purchaseOwner;
  bool available = false;
  bool loadingProducts = false;
  bool busy = false;
  String? message;
  List<ProductDetails> products = [];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    try {
      _subscription = store.updates.listen(
        (batch) {
          for (final purchase in batch) {
            _enqueue(() => _handle(purchase));
          }
        },
        onError: (Object error) {
          _release();
          message = billingPurchaseUpdateFailureMessage(
            message: error.toString(),
          );
          _notify();
        },
      );
    } catch (_) {
      message = billingStoreUnavailableMessage();
    }
    unawaited(loadProducts());
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } catch (error) {
        _failed(error);
      }
    });
    return _queue;
  }

  Future<void> _ensureLoaded() async {
    try {
      await (_load ??= (() async {
        for (final item in await storage.read()) {
          _pending.putIfAbsent(item.key, () => item);
        }
      })());
    } catch (_) {
      _load = null;
      rethrow;
    }
  }

  Future<void> _persist() => storage.write(_pending.values.toList());

  Future<void> loadProducts() async {
    if (loadingProducts || _disposed) return;
    loadingProducts = true;
    _notify();
    try {
      available = await store.isAvailable().timeout(
        const Duration(seconds: 15),
      );
      if (!available) {
        message = billingStoreUnavailableMessage();
        return;
      }
      final result = await store
          .products(Env.iapPointProductIds.toSet())
          .timeout(const Duration(seconds: 15));
      if (result.error != null) throw StateError('store_product_query_failed');
      products =
          result.productDetails
              .where((p) => Env.iapPointProductIds.contains(p.id))
              .toList()
            ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      final missing = Env.iapPointProductIds.toSet().difference(
        products.map((p) => p.id).toSet(),
      );
      if (missing.isNotEmpty) message = billingMissingProductsMessage(missing);
    } catch (error) {
      message = billingProductQueryFailureMessage(error);
    } finally {
      loadingProducts = false;
      _notify();
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (busy ||
        _recovering ||
        !available ||
        !Env.iapPointProductIds.contains(product.id))
      return;
    final owner = currentUserId();
    if (owner == null || owner.isEmpty) {
      message = '로그인 후 포인트를 충전해 주세요.';
      _notify();
      return;
    }
    busy = true;
    _purchaseOwner = owner;
    message = '포인트 결제를 시작합니다.';
    _notify();
    _purchaseTimeout?.cancel();
    _purchaseTimeout = Timer(const Duration(minutes: 2), () {
      _release();
      message = '스토어 승인을 기다리고 있어요. 결제 상태는 구매 복원에서 다시 확인할 수 있습니다.';
      _notify();
    });
    try {
      await ensureServerAvailable().timeout(const Duration(seconds: 15));
      if (_disposed || currentUserId() != owner) {
        _release();
        message = '로그인 계정이 변경되었습니다. 다시 충전을 시작해 주세요.';
        _notify();
        return;
      }
      if (!await store
          .buy(product, owner)
          .timeout(const Duration(seconds: 30))) {
        _release();
        message = '포인트 결제 요청을 시작하지 못했습니다.';
        _notify();
      }
    } catch (error) {
      _release();
      message = billingPurchaseStartFailureMessage(
        kind: BillingPurchaseKind.points,
        error: error,
      );
      _notify();
    }
  }

  Future<void> _handle(PurchaseDetails purchase) async {
    // Old, already purchased point packs still need delivery after a catalog change.
    // The server authorizes the exact product against point_products.
    if (!Env.iapPointProductIds.contains(purchase.productID) &&
        !purchase.productID.startsWith('snapfit_points_'))
      return;
    if (purchase.status == PurchaseStatus.pending) {
      message = '결제 승인 대기 중입니다.';
      _notify();
      return;
    }
    if (purchase.status == PurchaseStatus.error ||
        purchase.status == PurchaseStatus.canceled) {
      _release();
      message = purchase.status == PurchaseStatus.canceled
          ? '결제가 취소되었습니다.'
          : billingPurchaseUpdateFailureMessage(
              code: purchase.error?.code,
              message: purchase.error?.message,
            );
      // Apple canceled/failed transactions still need to leave the transaction queue.
      if (!purchase.verificationData.source.toLowerCase().contains('google') &&
          purchase.pendingCompletePurchase) {
        final failed = PendingPointPurchase(
          ownerId: currentUserId() ?? '',
          productId: purchase.productID,
          transactionId: purchase.purchaseID ?? '',
          source: purchase.verificationData.source,
          serverData: purchase.verificationData.serverVerificationData,
          localData: purchase.verificationData.localVerificationData,
        );
        await store.finish(failed, purchase);
      }
      _notify();
      return;
    }
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored)
      return;
    await _ensureLoaded();
    final record = PendingPointPurchase.fromPurchase(
      purchase,
      // A redelivered purchase may belong to another account. Never permanently
      // pin an unknown receipt to whichever account happened to restore it first.
      _purchaseOwner ?? '',
    );
    if (_finished.contains(record.key)) {
      _release();
      _notify();
      return;
    }
    final saved = _pending[record.key] ?? record;
    _pending[saved.key] = saved;
    // Persist before verification or completion; do not lose a charged transaction on process death.
    await _persist();
    await _deliver(saved, purchase);
  }

  Future<void> _deliver(
    PendingPointPurchase record, [
    PurchaseDetails? purchase,
  ]) async {
    final owner = currentUserId();
    if (owner == null ||
        (record.ownerId.isNotEmpty && owner != record.ownerId)) {
      _release();
      message = '구매한 계정으로 로그인하면 미완료 결제를 다시 확인합니다.';
      _notify();
      return;
    }
    try {
      await _persist();
      final result = await verify(record).timeout(const Duration(seconds: 30));
      if (result.productId != record.productId)
        throw StateError('verified_product_mismatch');
      await store.finish(record, purchase).timeout(const Duration(seconds: 30));
      _pending.remove(record.key);
      try {
        await _persist();
      } catch (_) {
        _pending[record.key] = record;
        rethrow;
      }
      _finished.add(record.key);
      _release();
      if (currentUserId() == owner) {
        onBalanceChanged();
        message = result.alreadyGranted
            ? '이미 반영된 구매입니다. 현재 잔액 ${result.remainingBalance}P'
            : '${result.grantedPoints}포인트가 충전되었습니다. 현재 잔액 ${result.remainingBalance}P';
      }
      _notify();
    } catch (error) {
      _failed(error);
    }
  }

  void _release() {
    busy = _recovering;
    _purchaseTimeout?.cancel();
    _purchaseOwner = null;
  }

  void _failed(Object error) {
    _release();
    message = billingVerificationFailureMessage(
      error,
      supportCode: snapfitSupportCode(
        scope: 'PAY',
        seed: error.runtimeType.toString(),
      ),
    );
    _notify();
    _retry?.cancel();
    final retryable =
        error is! PointPurchaseVerificationException || error.retryable;
    if (!_disposed && _pending.isNotEmpty && retryable) {
      _retry = Timer(const Duration(seconds: 30), () => unawaited(recover()));
    }
  }

  Future<void> recover() async {
    if (_recovering || _disposed || busy) return;
    final owner = currentUserId();
    if (owner == null || owner.isEmpty) return;
    _recovering = true;
    busy = true;
    message = '미완료 구매를 확인합니다.';
    _notify();
    try {
      await _enqueue(() async {
        await _ensureLoaded();
        for (final record in _pending.values.toList()) {
          if (record.ownerId.isEmpty || record.ownerId == owner)
            await _deliver(record);
        }
      });
      final pending = await store
          .unfinished(owner)
          .timeout(const Duration(seconds: 20));
      for (final purchase in pending) {
        await _enqueue(() => _handle(purchase));
      }
      await _queue;
      if (_pending.isEmpty && pending.isEmpty)
        message = '미완료 구매가 없습니다. 포인트 잔액을 새로 확인했어요.';
      if (currentUserId() == owner) onBalanceChanged();
    } catch (error) {
      _failed(error);
    } finally {
      _recovering = false;
      _release();
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _purchaseTimeout?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

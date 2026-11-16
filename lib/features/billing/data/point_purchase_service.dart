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
import '../domain/pending_point_checkout.dart';
import '../domain/point_purchase_completion.dart';
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
  Future<List<PendingPointCheckout>> readCheckouts();
  Future<void> writeCheckouts(List<PendingPointCheckout> records);
}

class SecurePendingPointPurchaseStorage implements PendingPointPurchaseStorage {
  static const _key = 'snapfit_pending_point_purchases_v1';
  static const _checkoutKey = 'snapfit_pending_point_checkouts_v1';
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
  @override
  Future<List<PendingPointCheckout>> readCheckouts() async {
    final raw = await _storage.read(key: _checkoutKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (row) => PendingPointCheckout.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> writeCheckouts(List<PendingPointCheckout> records) =>
      records.isEmpty
      ? _storage.delete(key: _checkoutKey)
      : _storage.write(
          key: _checkoutKey,
          value: jsonEncode(records.map((row) => row.toJson()).toList()),
        );
}

/// Correlation for a store window, separate from durable receipt fulfillment.
class _PointCheckout {
  _PointCheckout({
    required this.owner,
    required this.product,
    required this.startedAt,
  });
  final String owner, product;
  final DateTime startedAt;
  final existingReceipts = <String>{};
  String? receiptKey;
  bool delayed = false, launched = false, receiptVerified = false;
  Timer? timeout;

  PendingPointCheckout get record => PendingPointCheckout(
    ownerId: owner,
    productId: product,
    startedAt: startedAt,
    existingReceiptKeys: existingReceipts,
    receiptKey: receiptKey,
    receiptVerified: receiptVerified,
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
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PointPurchaseStore store;
  final PendingPointPurchaseStorage storage;
  final String? Function() currentUserId;
  final Future<void> Function() ensureServerAvailable;
  final Future<StorePointPurchaseResult> Function(PendingPointPurchase) verify;
  final VoidCallback onBalanceChanged;
  final DateTime Function() _now;
  final Map<String, PendingPointPurchase> _pending = {};
  final Set<String> _finished = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _queue = Future.value();
  Future<void>? _load;
  Timer? _retry;
  final _checkouts = <String, _PointCheckout>{};
  Future<void> _checkoutWrites = Future.value();
  int _checkpointing = 0;
  bool _storageReady = false;
  bool _disposed = false;
  bool _started = false;
  bool _recovering = false;
  bool _processingReceipt = false;
  _PointCheckout? get _checkout => _checkouts[currentUserId()];
  bool available = false;
  bool loadingProducts = false;
  bool get busy =>
      _recovering ||
      _processingReceipt ||
      _checkpointing > 0 ||
      _checkouts.values.any((checkout) => !checkout.delayed);
  bool catalogFresh = false;
  bool get verificationDelayed {
    final owner = currentUserId();
    if (owner == null) return false;
    return _checkout?.delayed == true ||
        _pending.values.any((receipt) => receipt.ownerId == owner);
  }

  bool get canStartPurchase =>
      !_disposed &&
      _storageReady &&
      available &&
      catalogFresh &&
      !loadingProducts &&
      !busy &&
      !verificationDelayed &&
      _checkout == null;
  PointPurchaseCompletion? _completion;
  String? _completionMessage;
  bool get messageIsCompletion =>
      _completionMessage != null && message == _completionMessage;
  PointPurchaseCompletion? get completion {
    final result = _completion;
    return !_disposed && result?.ownerId == currentUserId() ? result : null;
  }

  void dismissCompletion() {
    if (_completion == null) return;
    if (message == _completionMessage) message = null;
    _completion = null;
    _completionMessage = null;
    _notify();
  }

  String? message;
  String? _catalogMessage;
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
          // A stream error has no checkout identity. Keep a current store flow
          // fenced until its matching result or its own watchdog completes.
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
      _processingReceipt = true;
      _notify();
      try {
        await action();
      } catch (error) {
        _failed(error);
      } finally {
        _processingReceipt = false;
        _notify();
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
        for (final record in await storage.readCheckouts()) {
          final checkout =
              _PointCheckout(
                  owner: record.ownerId,
                  product: record.productId,
                  startedAt: record.startedAt,
                )
                ..existingReceipts.addAll(record.existingReceiptKeys)
                ..receiptKey = record.receiptKey
                ..receiptVerified = record.receiptVerified
                ..delayed = true
                ..launched = true;
          _checkouts.putIfAbsent(checkout.owner, () => checkout);
        }
        _storageReady = true;
      })());
    } catch (_) {
      _load = null;
      _storageReady = false;
      rethrow;
    }
  }

  Future<void> _persist() => storage.write(_pending.values.toList());

  Future<void> _persistCheckouts() async {
    _checkpointing++;
    _notify();
    try {
      final write = _checkoutWrites.then(
        (_) => storage.writeCheckouts(
          _checkouts.values
              .where((checkout) => checkout.launched)
              .map((checkout) => checkout.record)
              .toList(),
        ),
      );
      _checkoutWrites = write.catchError((Object _) {});
      await write;
    } finally {
      _checkpointing--;
      _notify();
    }
  }

  Future<void> loadProducts() async {
    if (loadingProducts || _disposed) return;
    loadingProducts = true;
    catalogFresh = false;
    _notify();
    try {
      await _ensureLoaded();
      available = await store.isAvailable().timeout(
        const Duration(seconds: 15),
      );
      if (!available) {
        message = _catalogMessage = billingStoreUnavailableMessage();
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
      catalogFresh = true;
      if (missing.isNotEmpty) {
        message = _catalogMessage = billingMissingProductsMessage(missing);
      } else {
        // 상품 재조회 성공은 이전 상품 오류만 지우고 결제 상태 안내는 보존한다.
        if (message == _catalogMessage) message = null;
        _catalogMessage = null;
      }
    } catch (error) {
      products = [];
      message = _catalogMessage = billingProductQueryFailureMessage(error);
    } finally {
      loadingProducts = false;
      _notify();
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (!canStartPurchase || !Env.iapPointProductIds.contains(product.id))
      return;
    ProductDetails? currentProduct;
    for (final candidate in products) {
      if (candidate.id == product.id) currentProduct = candidate;
    }
    if (currentProduct == null) return;
    final owner = currentUserId();
    if (owner == null || owner.isEmpty) {
      message = '로그인 후 포인트를 충전해 주세요.';
      _notify();
      return;
    }
    final checkout = _PointCheckout(
      owner: owner,
      product: product.id,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        _now().millisecondsSinceEpoch,
        isUtc: true,
      ),
    );
    _completion = null;
    _completionMessage = null;
    _checkouts[owner] = checkout;
    message = '포인트 결제를 시작합니다.';
    _notify();
    try {
      await _ensureLoaded();
      checkout.existingReceipts.addAll(_pending.keys);
      await ensureServerAvailable().timeout(const Duration(seconds: 15));
      if (_disposed || !_isCheckout(checkout)) return;
      if (currentUserId() != owner) {
        await _endCheckout(checkout);
        message = '로그인 계정이 변경되었습니다. 다시 충전을 시작해 주세요.';
        _notify();
        return;
      }
      // Save the request before crossing into an SDK whose Future cannot be cancelled.
      checkout.launched = true;
      try {
        await _persistCheckouts();
      } catch (_) {
        checkout.launched = false;
        rethrow;
      }
      if (_disposed || !_isCheckout(checkout)) return;
      if (currentUserId() != owner) {
        await _endCheckout(checkout);
        return;
      }
      checkout.timeout = Timer(
        const Duration(minutes: 2),
        () => _delayCheckout(checkout),
      );
      final request = store.buy(currentProduct, owner);
      // A late explicit false proves that the store window never opened.
      unawaited(
        request.then((started) async {
          if (!started && !_disposed && _isCheckout(checkout)) {
            await _enqueue(() async {
              if (await _endCheckout(checkout)) {
                message = '포인트 결제 요청을 시작하지 못했습니다.';
                _notify();
              }
            });
          }
        }, onError: (Object _, StackTrace __) {}),
      );
      await request.timeout(const Duration(seconds: 30));
    } catch (error) {
      if (!_isCheckout(checkout)) return;
      if (checkout.launched) {
        _delayCheckout(checkout);
      } else if (await _endCheckout(checkout)) {
        message = billingPurchaseStartFailureMessage(
          kind: BillingPurchaseKind.points,
          error: error,
        );
        _notify();
      }
    }
  }

  bool _isCheckout(_PointCheckout checkout) =>
      identical(_checkouts[checkout.owner], checkout);

  void _delayCheckout(_PointCheckout checkout) {
    if (!_isCheckout(checkout) || _disposed) return;
    checkout.delayed = true;
    checkout.timeout?.cancel();
    if (checkout.owner == currentUserId()) {
      message = '결제 상태 확인이 지연되고 있어요. 다시 결제하지 말고 결제 상태를 확인해 주세요.';
    }
    _notify();
  }

  Future<bool> _endCheckout(_PointCheckout checkout) async {
    if (!_isCheckout(checkout)) return false;
    _checkouts.remove(checkout.owner);
    try {
      if (checkout.launched) await _persistCheckouts();
    } catch (_) {
      _checkouts.putIfAbsent(checkout.owner, () => checkout);
      _delayCheckout(checkout);
      return false;
    }
    checkout.timeout?.cancel();
    return true;
  }

  String? _nativeOwner(PurchaseDetails purchase) => switch (purchase) {
    GooglePlayPurchaseDetails p =>
      p.billingClientPurchase.obfuscatedAccountId?.trim().toLowerCase(),
    SK2PurchaseDetails p => p.appAccountToken?.trim().toLowerCase(),
    _ => null,
  };

  _PointCheckout? _checkoutFor(
    PurchaseDetails purchase,
    PendingPointPurchase? record, {
    bool terminal = false,
  }) {
    final nativeOwner = _nativeOwner(purchase);
    // A definite terminal event can settle its explicit owner's marker without
    // authenticating a purchase or touching the account currently on screen.
    final checkout = terminal && nativeOwner?.isNotEmpty == true
        ? _checkouts[nativeOwner]
        : _checkout;
    if (checkout == null ||
        !terminal && checkout.owner != currentUserId() ||
        checkout.product != purchase.productID)
      return null;
    if (nativeOwner?.trim().isNotEmpty == true &&
        nativeOwner!.trim().toLowerCase() != checkout.owner.toLowerCase()) {
      return null;
    }
    final rawDate = purchase.transactionDate;
    final milliseconds = int.tryParse(rawDate ?? '');
    final date = milliseconds == null
        ? DateTime.tryParse(rawDate ?? '')
        : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    if (date == null || date.isBefore(checkout.startedAt)) return null;
    PendingPointPurchase event;
    try {
      event = record ?? PendingPointPurchase.fromPurchase(purchase, '');
    } catch (_) {
      return null;
    }
    if (event.isGoogle && event.serverData.isEmpty) return null;
    if (checkout.receiptKey != null &&
        checkout.receiptKey != event.key &&
        (!terminal || checkout.receiptVerified))
      return null;
    if (checkout.existingReceipts.contains(event.key) ||
        _finished.contains(event.key))
      return null;
    return checkout;
  }

  _PointCheckout? _checkoutForRecord(PendingPointPurchase record) {
    final checkout = _checkout;
    if (checkout == null ||
        checkout.product != record.productId ||
        record.ownerId.isNotEmpty && record.ownerId != checkout.owner)
      return null;
    if (checkout.receiptKey != null) {
      return checkout.receiptKey == record.key ? checkout : null;
    }
    final milliseconds = int.tryParse(record.transactionDate ?? '');
    final date = milliseconds == null
        ? DateTime.tryParse(record.transactionDate ?? '')
        : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    if (date == null ||
        date.isBefore(checkout.startedAt) ||
        checkout.existingReceipts.contains(record.key) ||
        _finished.contains(record.key))
      return null;
    return checkout;
  }

  Future<void> _handle(PurchaseDetails purchase) async {
    // Play returns empty identifiers when a billing flow has no purchases. Such
    // a response cannot identify which checkout completed, even for userCancel.
    if (purchase.productID.isEmpty &&
        purchase.verificationData.source.toLowerCase().contains('google') &&
        (purchase.status == PurchaseStatus.canceled ||
            purchase.status == PurchaseStatus.error)) {
      final checkout = _checkout;
      if (checkout != null && checkout.owner == currentUserId()) {
        message = purchase.status == PurchaseStatus.canceled
            ? '스토어에서 취소 응답을 받았어요. 결제 상태를 확인할 때까지 새 결제를 시작하지 말고, 잠시 후 구매 복원으로 확인해 주세요.'
            : '스토어 응답을 확인하지 못했어요. 새 결제를 시작하지 말고, 잠시 후 구매 복원으로 결제 상태를 확인해 주세요.';
        _notify();
      }
      return;
    }
    // Old, already purchased point packs still need delivery after a catalog change.
    // The server authorizes the exact product against point_products.
    if (!Env.iapPointProductIds.contains(purchase.productID) &&
        !purchase.productID.startsWith('snapfit_points_'))
      return;
    await _ensureLoaded();
    if (purchase.status == PurchaseStatus.pending) {
      if (_checkout == null || _checkoutFor(purchase, null) != null) {
        message = '결제 승인 대기 중입니다.';
      }
      _notify();
      return;
    }
    if (purchase.status == PurchaseStatus.error ||
        purchase.status == PurchaseStatus.canceled) {
      final checkout = _checkoutFor(purchase, null, terminal: true);
      final nativeOwner = _nativeOwner(purchase);
      final belongsToCurrent =
          nativeOwner?.isNotEmpty != true || nativeOwner == currentUserId();
      if (checkout != null) await _endCheckout(checkout);
      if (_checkout == null && belongsToCurrent) {
        message = purchase.status == PurchaseStatus.canceled
            ? '결제가 취소되었습니다.'
            : billingPurchaseUpdateFailureMessage(
                code: purchase.error?.code,
                message: purchase.error?.message,
              );
      }
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
        await store
            .finish(failed, purchase)
            .timeout(const Duration(seconds: 30));
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
      // A checkout in flight does not prove that a replayed receipt belongs to
      // that checkout. Only native account metadata may pin recovery ownership.
      '',
    );
    if (_finished.contains(record.key)) {
      // A store may replay an older completed transaction while a different
      // checkout is open. That event must not unlock or disown the new purchase.
      _notify();
      return;
    }
    final checkout = _checkoutFor(purchase, record);
    final saved = _pending[record.key] ?? record;
    _pending[saved.key] = saved;
    // Persist before verification or completion; do not lose a charged transaction on process death.
    await _persist();
    await _deliver(saved, purchase, checkout);
  }

  Future<void> _deliver(
    PendingPointPurchase record, [
    PurchaseDetails? purchase,
    _PointCheckout? checkout,
  ]) async {
    final owner = currentUserId();
    if (owner == null ||
        (record.ownerId.isNotEmpty && owner != record.ownerId)) {
      if (_checkout == null) {
        message = '구매한 계정으로 로그인하면 미완료 결제를 다시 확인합니다.';
      }
      _notify();
      return;
    }
    checkout ??= _checkoutForRecord(record);
    final previouslyBound = checkout?.receiptKey == record.key;
    var verifiedNewPurchase = false;
    try {
      await _persist();
      if (checkout != null && checkout.receiptKey != record.key) {
        checkout.receiptKey = record.key;
        await _persistCheckouts();
      }
      final result = await verify(record).timeout(const Duration(seconds: 30));
      if (result.productId != record.productId)
        throw StateError('verified_product_mismatch');
      verifiedNewPurchase = !result.alreadyGranted;
      if (result.alreadyGranted && !previouslyBound) {
        // An unrelated credited replay cannot complete a newer store request.
        if (checkout != null) {
          checkout.receiptKey = null;
          checkout.receiptVerified = false;
          await _persistCheckouts();
        }
        checkout = null;
      }
      if (checkout != null) {
        checkout.receiptVerified = true;
        await _persistCheckouts();
      }
      await store.finish(record, purchase).timeout(const Duration(seconds: 30));
      if (checkout != null && !await _endCheckout(checkout)) {
        throw StateError('checkout_checkpoint_cleanup_failed');
      }
      _pending.remove(record.key);
      try {
        await _persist();
      } catch (_) {
        _pending[record.key] = record;
        rethrow;
      }
      _finished.add(record.key);
      // An already credited replay, including after process restart, is not
      // evidence that the currently open checkout has completed.

      if (currentUserId() == owner) {
        onBalanceChanged();
        if (_checkout == null) {
          _completion = PointPurchaseCompletion(
            ownerId: owner,
            productId: result.productId,
            grantedPoints: result.grantedPoints,
            remainingBalance: result.remainingBalance,
            alreadyGranted: result.alreadyGranted,
          );
          message = result.alreadyGranted
              ? '이미 반영된 구매입니다. 현재 잔액 ${result.remainingBalance}P'
              : '${result.grantedPoints}포인트가 충전되었습니다. 현재 잔액 ${result.remainingBalance}P';
          _completionMessage = message;
        }
      }
      _notify();
    } catch (error) {
      final foreignReceipt =
          error is PointPurchaseVerificationException &&
          !error.retryable &&
          const {
            'purchase_account_mismatch',
            'purchase_owner_mismatch',
            'purchase_ownership_invalid',
          }.contains(error.code);
      if (foreignReceipt &&
          checkout != null &&
          !checkout.receiptVerified &&
          checkout.receiptKey == record.key) {
        // Server ownership rejection disproves only this provisional receipt,
        // not the separate native request that is still waiting for its result.
        checkout.receiptKey = null;
        checkout.existingReceipts.add(record.key);
        try {
          await _persistCheckouts();
        } catch (_) {
          _delayCheckout(checkout);
        }
        _failed(error);
        return;
      }
      final attributable =
          verifiedNewPurchase ||
          (checkout != null && checkout.receiptKey == record.key);
      _failed(error, checkout: attributable ? checkout : null);
    }
  }

  void _failed(Object error, {_PointCheckout? checkout}) {
    if (checkout != null) _delayCheckout(checkout);
    if (_checkout == null) {
      message = billingVerificationFailureMessage(
        error,
        supportCode: snapfitSupportCode(
          scope: 'PAY',
          seed: error.runtimeType.toString(),
        ),
      );
    }
    _notify();
    _retry?.cancel();
    final retryable =
        error is! PointPurchaseVerificationException || error.retryable;
    if (!_disposed && _pending.isNotEmpty && retryable) {
      _retry = Timer(const Duration(seconds: 30), () => unawaited(recover()));
    }
  }

  Future<void> recover() async {
    if (_recovering || _processingReceipt || _disposed || busy) return;
    final owner = currentUserId();
    if (owner == null || owner.isEmpty) return;
    _recovering = true;
    message = '미완료 구매를 확인합니다.';
    _notify();
    final completedBefore = _finished.length;
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
      if (currentUserId() == owner &&
          _pending.isEmpty &&
          pending.isEmpty &&
          _finished.length == completedBefore)
        message = verificationDelayed
            ? '결제 상태를 아직 확정하지 못했어요. 다시 결제하지 말고 잠시 후 결제 상태를 확인해 주세요.'
            : '미완료 구매가 없습니다. 포인트 잔액을 새로 확인했어요.';
      if (currentUserId() == owner) onBalanceChanged();
    } catch (error) {
      _failed(error);
    } finally {
      _recovering = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    for (final checkout in _checkouts.values) {
      checkout.timeout?.cancel();
    }
    _subscription?.cancel();
    super.dispose();
  }
}

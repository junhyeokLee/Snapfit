import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// Kept in secure storage until server delivery and store completion succeed.
class PendingPointPurchase {
  const PendingPointPurchase({
    required this.ownerId,
    required this.productId,
    required this.transactionId,
    required this.source,
    required this.serverData,
    required this.localData,
    this.transactionDate,
  });

  factory PendingPointPurchase.fromPurchase(
    PurchaseDetails purchase,
    String ownerId,
  ) {
    final id = purchase.purchaseID?.trim() ?? '';
    final source = purchase.verificationData.source;
    final token = purchase.verificationData.serverVerificationData;
    final storeOwner = switch (purchase) {
      GooglePlayPurchaseDetails p =>
        p.billingClientPurchase.obfuscatedAccountId,
      SK2PurchaseDetails p => p.appAccountToken,
      _ => null,
    };
    if (id.isEmpty && !source.toLowerCase().contains('google')) {
      throw StateError('purchase_transaction_id_missing');
    }
    return PendingPointPurchase(
      // Native metadata helps route retries; the server independently verifies it.
      ownerId: (storeOwner?.isNotEmpty ?? false) ? storeOwner! : ownerId,
      productId: purchase.productID,
      transactionId: id.isEmpty ? token : id,
      source: source,
      serverData: token,
      localData: purchase.verificationData.localVerificationData,
      transactionDate: purchase.transactionDate,
    );
  }

  factory PendingPointPurchase.fromJson(Map<String, dynamic> json) =>
      PendingPointPurchase(
        ownerId: json['ownerId'] as String,
        productId: json['productId'] as String,
        transactionId: json['transactionId'] as String,
        source: json['source'] as String,
        serverData: json['serverData'] as String,
        localData: json['localData'] as String,
        transactionDate: json['transactionDate'] as String?,
      );

  final String ownerId;
  final String productId;
  final String transactionId;
  final String source;
  final String serverData;
  final String localData;
  final String? transactionDate;

  bool get isGoogle => source.toLowerCase().contains('google');
  String get key => '$source:${isGoogle ? serverData : transactionId}';
  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'productId': productId,
    'transactionId': transactionId,
    'source': source,
    'serverData': serverData,
    'localData': localData,
    'transactionDate': transactionDate,
  };
}

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/interceptors/token_storage.dart';
import '../domain/entities/billing_plan.dart';
import '../domain/entities/storage_preflight.dart';
import '../domain/entities/storage_quota.dart';
import '../domain/entities/subscription_status.dart';

typedef RecordAiAlbumDraftSuccessRpc =
    Future<Map<String, dynamic>> Function({
      required String draftId,
      required int pointCost,
    });

enum AiAlbumDraftPointUsageFailure { insufficientPoints, unavailable }

class AiAlbumDraftPointUsageException implements Exception {
  const AiAlbumDraftPointUsageException(this.failure, [this.message]);

  final AiAlbumDraftPointUsageFailure failure;
  final String? message;

  @override
  String toString() => message == null
      ? 'AiAlbumDraftPointUsageException($failure)'
      : 'AiAlbumDraftPointUsageException($failure, $message)';
}

class AiAlbumDraftPointUsageResult {
  const AiAlbumDraftPointUsageResult({
    required this.usedFreeCredit,
    required this.chargedPoints,
    required this.remainingBalance,
  });

  factory AiAlbumDraftPointUsageResult.fromJson(Map<String, dynamic> json) {
    return AiAlbumDraftPointUsageResult(
      usedFreeCredit: json['used_free_credit'] == true,
      chargedPoints: (json['charged_points'] as num?)?.toInt() ?? 0,
      remainingBalance: (json['remaining_balance'] as num?)?.toInt() ?? 0,
    );
  }

  final bool usedFreeCredit;
  final int chargedPoints;
  final int remainingBalance;
}

class StorePointPurchaseResult {
  const StorePointPurchaseResult({
    required this.productId,
    required this.grantedPoints,
    required this.remainingBalance,
  });

  factory StorePointPurchaseResult.fromJson(Map<String, dynamic> json) {
    return StorePointPurchaseResult(
      productId:
          json['productId']?.toString() ?? json['product_id']?.toString() ?? '',
      grantedPoints:
          (json['grantedPoints'] as num?)?.toInt() ??
          (json['granted_points'] as num?)?.toInt() ??
          0,
      remainingBalance:
          (json['remainingBalance'] as num?)?.toInt() ??
          (json['remaining_balance'] as num?)?.toInt() ??
          0,
    );
  }

  final String productId;
  final int grantedPoints;
  final int remainingBalance;
}

class BillingRepository {
  BillingRepository({
    required this.tokenStorage,
    this.supabase,
    this.recordAiAlbumDraftSuccessRpc,
  });

  final TokenStorage tokenStorage;
  final SupabaseClient? supabase;
  final RecordAiAlbumDraftSuccessRpc? recordAiAlbumDraftSuccessRpc;

  Future<String> _requireUserId() async {
    final userId = await tokenStorage.getUserId();
    if (userId == null || userId.trim().isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    return userId;
  }

  Map<String, dynamic> _camelBillingPlan(Map<String, dynamic> row) => {
    'planCode': row['plan_code'],
    'title': row['title'],
    'amount': row['amount'],
    'currency': row['currency'],
    'periodDays': row['period_days'],
    'provider': row['provider'],
  };

  Map<String, dynamic> _camelSubscription(
    Map<String, dynamic>? row,
    String userId,
  ) => {
    'userId': userId,
    'planCode': row?['plan_code'],
    'status': row?['status'] ?? 'INACTIVE',
    'startedAt': row?['started_at'],
    'expiresAt': row?['expires_at'],
    'nextBillingAt': row?['next_billing_at'],
    'isActive': row?['status'] == 'ACTIVE',
  };

  Map<String, dynamic> _camelQuota(Map<String, dynamic>? row, String userId) {
    final used = (row?['used_bytes'] as num?)?.toInt() ?? 0;
    final soft = (row?['soft_limit_bytes'] as num?)?.toInt() ?? 1073741824;
    final hard = (row?['hard_limit_bytes'] as num?)?.toInt() ?? 1073741824;
    return {
      'userId': userId,
      'planCode': row?['plan_code'] ?? 'FREE',
      'usedBytes': used,
      'softLimitBytes': soft,
      'hardLimitBytes': hard,
      'softExceeded': used > soft,
      'hardExceeded': used > hard,
      'usagePercent': hard > 0 ? ((used * 100) ~/ hard).clamp(0, 999) : 0,
      'measuredAt': row?['measured_at'],
    };
  }

  Future<List<BillingPlan>> getPlans() async {
    if (supabase != null) {
      final rows = await supabase!
          .from('billing_plans')
          .select()
          .eq('is_active', true)
          .order('amount');
      return rows
          .map<BillingPlan>(
            (e) => BillingPlan.fromJson(
              _camelBillingPlan(Map<String, dynamic>.from(e)),
            ),
          )
          .toList(growable: false);
    }
    throw Exception('Supabase 결제 플랜 환경이 준비되지 않았습니다.');
  }

  Future<SubscriptionStatusModel> getMySubscription() async {
    final userId = await _requireUserId();
    if (supabase != null) {
      final row = await supabase!
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return SubscriptionStatusModel.fromJson(_camelSubscription(row, userId));
    }
    throw Exception('Supabase 구독 조회 환경이 준비되지 않았습니다.');
  }

  String _storePlatformFromPurchase(PurchaseDetails purchase) {
    final source = purchase.verificationData.source.toLowerCase();
    if (source.contains('google') || source.contains('play')) {
      return 'GOOGLE_PLAY';
    }
    if (source.contains('app_store') ||
        source.contains('appstore') ||
        source.contains('storekit')) {
      return 'APP_STORE';
    }
    throw Exception('지원하지 않는 인앱결제 플랫폼입니다: ${purchase.verificationData.source}');
  }

  Future<StorePointPurchaseResult> verifyStorePointPurchase(
    PurchaseDetails purchase,
  ) async {
    if (supabase == null) {
      throw Exception('Supabase 포인트 구매 검증 환경이 준비되지 않았습니다.');
    }
    final transactionId =
        purchase.purchaseID ??
        '${purchase.productID}-${purchase.transactionDate ?? DateTime.now().millisecondsSinceEpoch}';
    final response = await supabase!.functions.invoke(
      'iap-verify',
      body: {
        'platform': _storePlatformFromPurchase(purchase),
        'productId': purchase.productID,
        'transactionId': transactionId,
        'originalTransactionId': transactionId,
        'purchaseToken': purchase.verificationData.serverVerificationData,
        'receiptData': purchase.verificationData.localVerificationData,
        'verificationSource': purchase.verificationData.source,
        'purchaseType': 'POINTS',
        'planCode': 'FREE',
      },
    );
    final data =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
    final pointPurchase =
        (data['pointPurchase'] as Map?)?.cast<String, dynamic>() ?? data;
    return StorePointPurchaseResult.fromJson(pointPurchase);
  }

  Future<SubscriptionStatusModel> verifyStorePurchase(
    PurchaseDetails purchase, {
    String planCode = 'SNAPFIT_PRO_MONTHLY',
  }) async {
    if (supabase == null) {
      throw Exception('Supabase 결제 검증 환경이 준비되지 않았습니다.');
    }
    final transactionId =
        purchase.purchaseID ??
        '${purchase.productID}-${purchase.transactionDate ?? DateTime.now().millisecondsSinceEpoch}';
    final response = await supabase!.functions.invoke(
      'iap-verify',
      body: {
        'platform': _storePlatformFromPurchase(purchase),
        'productId': purchase.productID,
        'transactionId': transactionId,
        'originalTransactionId': transactionId,
        'purchaseToken': purchase.verificationData.serverVerificationData,
        'receiptData': purchase.verificationData.localVerificationData,
        'verificationSource': purchase.verificationData.source,
        'planCode': planCode,
      },
    );
    final data =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
    return SubscriptionStatusModel.fromJson(data);
  }

  Future<AiAlbumDraftPointUsageResult> recordAiAlbumDraftSuccess({
    required String draftId,
    int pointCost = 300,
  }) async {
    final normalizedDraftId = draftId.trim();
    if (normalizedDraftId.isEmpty) {
      throw ArgumentError.value(draftId, 'draftId', 'draft id is required');
    }
    if (pointCost < 0) {
      throw ArgumentError.value(
        pointCost,
        'pointCost',
        'point cost must be zero or positive',
      );
    }

    try {
      final injectedRpc = recordAiAlbumDraftSuccessRpc;
      if (injectedRpc != null) {
        final row = await injectedRpc(
          draftId: normalizedDraftId,
          pointCost: pointCost,
        );
        return AiAlbumDraftPointUsageResult.fromJson(row);
      }

      if (supabase == null) {
        throw const AiAlbumDraftPointUsageException(
          AiAlbumDraftPointUsageFailure.unavailable,
          'Supabase 포인트 사용 환경이 준비되지 않았습니다.',
        );
      }

      final response = await supabase!.rpc(
        'record_ai_album_draft_success',
        params: {'p_draft_id': normalizedDraftId, 'p_point_cost': pointCost},
      );
      final row = response is List && response.isNotEmpty
          ? Map<String, dynamic>.from(response.first as Map)
          : Map<String, dynamic>.from(response as Map);
      return AiAlbumDraftPointUsageResult.fromJson(row);
    } on AiAlbumDraftPointUsageException {
      rethrow;
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (error.code == 'P0001' || message.contains('insufficient points')) {
        throw AiAlbumDraftPointUsageException(
          AiAlbumDraftPointUsageFailure.insufficientPoints,
          error.message,
        );
      }
      throw AiAlbumDraftPointUsageException(
        AiAlbumDraftPointUsageFailure.unavailable,
        error.message,
      );
    } catch (error) {
      throw AiAlbumDraftPointUsageException(
        AiAlbumDraftPointUsageFailure.unavailable,
        error.toString(),
      );
    }
  }

  Future<SubscriptionStatusModel> cancelSubscription() async {
    final userId = await _requireUserId();
    if (supabase != null) {
      final row = await supabase!
          .from('subscriptions')
          .update({'status': 'CANCELED'})
          .eq('user_id', userId)
          .select()
          .maybeSingle();
      return SubscriptionStatusModel.fromJson(_camelSubscription(row, userId));
    }
    throw Exception('Supabase 구독 취소 환경이 준비되지 않았습니다.');
  }

  Future<StorageQuotaStatus> getMyStorageQuota() async {
    final userId = await _requireUserId();
    if (supabase != null) {
      final row = await supabase!
          .from('storage_quotas')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return StorageQuotaStatus.fromJson(_camelQuota(row, userId));
    }
    throw Exception('Supabase 스토리지 할당량 환경이 준비되지 않았습니다.');
  }

  Future<StoragePreflightStatus> preflightStorage({
    required int incomingBytes,
  }) async {
    final userId = await _requireUserId();
    if (supabase != null) {
      final quota = await getMyStorageQuota();
      final projected = quota.usedBytes + incomingBytes;
      final remaining = quota.hardLimitBytes - quota.usedBytes;
      return StoragePreflightStatus(
        userId: userId,
        planCode: quota.planCode,
        incomingBytes: incomingBytes,
        usedBytes: quota.usedBytes,
        projectedBytes: projected,
        hardLimitBytes: quota.hardLimitBytes,
        remainingBytes: remaining < 0 ? 0 : remaining,
        allowed: projected <= quota.hardLimitBytes,
        reason: projected <= quota.hardLimitBytes
            ? 'OK'
            : 'HARD_LIMIT_EXCEEDED',
        measuredAt: quota.measuredAt,
      );
    }
    throw Exception('Supabase 스토리지 사전검사 환경이 준비되지 않았습니다.');
  }
}

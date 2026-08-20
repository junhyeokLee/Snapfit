import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/interceptors/token_storage.dart';
import '../domain/entities/billing_plan.dart';
import '../domain/entities/payment_prepare_result.dart';
import '../domain/entities/storage_preflight.dart';
import '../domain/entities/storage_quota.dart';
import '../domain/entities/subscription_status.dart';

class BillingRepository {
  BillingRepository({
    required this.dio,
    required this.tokenStorage,
    this.supabase,
  });

  final Dio dio;
  final TokenStorage tokenStorage;
  final SupabaseClient? supabase;

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
    final response = await dio.get('/api/billing/plans');
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => BillingPlan.fromJson(e.cast<String, dynamic>()))
        .toList();
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
    final response = await dio.get(
      '/api/billing/subscription',
      queryParameters: {'userId': userId},
    );
    return SubscriptionStatusModel.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<PaymentPrepareResult> prepareNaverPay({String? planCode}) async {
    return preparePayment(planCode: planCode, provider: 'TOSS_NAVERPAY');
  }

  Future<PaymentPrepareResult> preparePayment({
    String? planCode,
    String provider = 'TOSS_NAVERPAY',
  }) async {
    final userId = await _requireUserId();
    if (supabase != null) {
      final response = await supabase!.functions.invoke(
        'billing-prepare',
        body: {
          'planCode': planCode ?? 'SNAPFIT_PRO_MONTHLY',
          'provider': provider,
        },
      );
      return PaymentPrepareResult.fromJson(
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      );
    }
    final response = await dio.post(
      '/api/billing/prepare',
      data: {
        'userId': userId,
        'planCode': planCode ?? 'SNAPFIT_PRO_MONTHLY',
        'provider': provider,
      },
    );

    return PaymentPrepareResult.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<SubscriptionStatusModel> approveOrder({
    required String orderId,
    String? paymentKey,
    int? amount,
    String? transactionId,
  }) async {
    if (supabase != null) {
      final response = await supabase!.functions.invoke(
        'billing-approve',
        body: {
          'orderId': orderId,
          if (paymentKey != null) 'paymentKey': paymentKey,
          if (amount != null) 'amount': amount,
          if (transactionId != null) 'transactionId': transactionId,
        },
      );
      return SubscriptionStatusModel.fromJson(
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      );
    }
    final response = await dio.post(
      '/api/billing/approve',
      data: {
        'orderId': orderId,
        if (paymentKey != null) 'paymentKey': paymentKey,
        if (amount != null) 'amount': amount,
        if (transactionId != null) 'transactionId': transactionId,
      },
    );

    return SubscriptionStatusModel.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<void> cancelPayment({
    required String orderId,
    String reason = 'USER_REQUEST',
  }) async {
    await dio.post('/api/billing/$orderId/cancel', data: {'reason': reason});
  }

  Future<Map<String, dynamic>> runE2EFlow({
    String provider = 'TOSS_NAVERPAY',
    String? paymentKey,
  }) async {
    final userId = await _requireUserId();
    final response = await dio.post(
      '/api/billing/test/e2e-run',
      data: {
        'userId': userId,
        'provider': provider,
        if (paymentKey != null) 'paymentKey': paymentKey,
      },
    );

    return (response.data as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
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
    final response = await dio.post(
      '/api/billing/subscription/cancel',
      queryParameters: {'userId': userId},
    );

    return SubscriptionStatusModel.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
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
    final response = await dio.get(
      '/api/billing/storage/quota',
      queryParameters: {'userId': userId},
    );

    return StorageQuotaStatus.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
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
    final response = await dio.post(
      '/api/billing/storage/preflight',
      data: {'userId': userId, 'incomingBytes': incomingBytes},
    );
    return StoragePreflightStatus.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }
}

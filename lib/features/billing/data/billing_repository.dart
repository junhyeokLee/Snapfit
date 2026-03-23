import 'package:dio/dio.dart';

import '../../../core/interceptors/token_storage.dart';
import '../domain/entities/billing_plan.dart';
import '../domain/entities/payment_prepare_result.dart';
import '../domain/entities/storage_preflight.dart';
import '../domain/entities/storage_quota.dart';
import '../domain/entities/subscription_status.dart';

class BillingRepository {
  BillingRepository({required this.dio, required this.tokenStorage});

  final Dio dio;
  final TokenStorage tokenStorage;

  Future<String> _requireUserId() async {
    final userId = await tokenStorage.getUserId();
    if (userId == null || userId.trim().isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    return userId;
  }

  Future<List<BillingPlan>> getPlans() async {
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
    final response = await dio.post(
      '/api/billing/storage/preflight',
      data: {'userId': userId, 'incomingBytes': incomingBytes},
    );
    return StoragePreflightStatus.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }
}

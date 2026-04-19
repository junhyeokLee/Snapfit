import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/interceptors/token_storage.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../domain/entities/order_history_item.dart';

class OrderRepository {
  OrderRepository({required this.dio, required this.tokenStorage});

  final Dio dio;
  final TokenStorage tokenStorage;
  static const Set<String> _allowedPaymentMethods = {
    'TOSS_PAYMENTS',
    'NAVERPAY',
    'KG_INICIS',
  };
  static const _orderSeenInitPrefix = 'snapfit_order_seen_init_';
  static const _orderSeenPendingPrefix = 'snapfit_order_seen_pending_';
  static const _orderSeenCompletedPrefix = 'snapfit_order_seen_completed_';
  static const _orderSeenProductionPrefix = 'snapfit_order_seen_production_';
  static const _orderSeenShippingPrefix = 'snapfit_order_seen_shipping_';
  static const _orderSeenDeliveredPrefix = 'snapfit_order_seen_delivered_';
  static const _orderSeenLatestUpdatedAtPrefix =
      'snapfit_order_seen_latest_updated_at_';

  Future<String> _requireUserId() async {
    final id = await tokenStorage.getUserId();
    if (id == null || id.trim().isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    return id;
  }

  Future<List<OrderHistoryItem>> fetchMyOrders() async {
    final userId = await _requireUserId();
    final response = await dio.get(
      '/api/orders',
      queryParameters: {'userId': userId},
    );

    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => OrderHistoryItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<OrderPageResult> fetchMyOrdersPage({
    List<String>? statuses,
    int page = 0,
    int size = 20,
  }) async {
    final userId = await _requireUserId();
    final response = await dio.get(
      '/api/orders/paged',
      queryParameters: {
        'userId': userId,
        'page': page,
        'size': size,
        if (statuses != null && statuses.isNotEmpty) 'status': statuses,
      },
    );
    final map =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return OrderPageResult.fromJson(map);
  }

  Future<OrderSummaryResult> fetchMyOrderSummary() async {
    final userId = await _requireUserId();
    final response = await dio.get(
      '/api/orders/summary',
      queryParameters: {'userId': userId},
    );
    final map =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return OrderSummaryResult.fromJson(map);
  }

  Future<OrderHistoryItem> createTestOrder({
    String title = '스냅핏 테스트 주문',
    int amount = 34900,
  }) async {
    final userId = await _requireUserId();
    final response = await dio.post(
      '/api/orders/test/create',
      data: {'userId': userId, 'title': title, 'amount': amount},
    );

    return OrderHistoryItem.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<OrderHistoryItem> advanceStatus(String orderId) async {
    final response = await dio.post('/api/orders/$orderId/advance');
    return OrderHistoryItem.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<OrderHistoryItem> createPrintOrder({
    required int albumId,
    required String title,
    required int amount,
    required int pageCount,
    required String paymentMethod,
    required String recipientName,
    required String recipientPhone,
    required String zipCode,
    required String addressLine1,
    String? addressLine2,
    String? deliveryMemo,
  }) async {
    final normalizedPaymentMethod = paymentMethod.trim().toUpperCase();
    if (!_allowedPaymentMethods.contains(normalizedPaymentMethod)) {
      throw Exception('지원하지 않는 결제수단입니다.');
    }
    final normalizedPhone = recipientPhone.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{10,11}$').hasMatch(normalizedPhone)) {
      throw Exception('연락처 형식이 올바르지 않습니다.');
    }
    final normalizedZip = zipCode.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{5}$').hasMatch(normalizedZip)) {
      throw Exception('우편번호 형식이 올바르지 않습니다.');
    }

    final userId = await _requireUserId();
    final response = await dio.post(
      '/api/orders',
      data: {
        'userId': userId,
        'albumId': albumId,
        'title': title.trim(),
        'amount': amount,
        'pageCount': pageCount,
        'paymentMethod': normalizedPaymentMethod,
        'recipientName': recipientName.trim(),
        'recipientPhone': normalizedPhone,
        'zipCode': normalizedZip,
        'addressLine1': addressLine1.trim(),
        'addressLine2': addressLine2?.trim() ?? '',
        'deliveryMemo': deliveryMemo?.trim() ?? '',
      },
    );
    return OrderHistoryItem.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<OrderHistoryItem> confirmPayment(String orderId) async {
    final response = await dio.post('/api/orders/$orderId/payment/confirm');
    return OrderHistoryItem.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<OrderQuoteResult> fetchOrderQuote({
    required int albumId,
    int? pageCount,
  }) async {
    final response = await dio.get(
      '/api/orders/quote',
      queryParameters: {
        'albumId': albumId,
        if (pageCount != null) 'pageCount': pageCount,
      },
    );
    final map =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return OrderQuoteResult.fromJson(map);
  }

  Future<AddressSearchResult> searchAddress({
    required String keyword,
    int page = 1,
  }) async {
    final response = await dio.get(
      '/api/orders/address/search',
      queryParameters: {'keyword': keyword, 'page': page},
    );
    final map =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return AddressSearchResult.fromJson(map);
  }

  Future<String> buildOrderCheckoutUrl({
    required String orderId,
    required String paymentMethod,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedPaymentMethod = paymentMethod.trim().toUpperCase();
    if (normalizedOrderId.isEmpty ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(normalizedOrderId)) {
      throw Exception('주문번호 형식이 올바르지 않습니다.');
    }
    if (!_allowedPaymentMethods.contains(normalizedPaymentMethod)) {
      throw Exception('지원하지 않는 결제수단입니다.');
    }
    final base = dio.options.baseUrl.trim();
    final normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final provider = Uri.encodeQueryComponent(normalizedPaymentMethod);
    return '$normalized/api/orders/$normalizedOrderId/payment/checkout?provider=$provider';
  }

  Future<OrderHistoryItem> markShipping({
    required String orderId,
    required String courier,
    required String trackingNumber,
    required String adminKey,
  }) async {
    final response = await dio.post(
      '/api/orders/$orderId/shipping',
      data: {'courier': courier, 'trackingNumber': trackingNumber},
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
    return OrderHistoryItem.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<OrderHistoryItem> markDelivered({
    required String orderId,
    required String adminKey,
  }) async {
    final response = await dio.post(
      '/api/orders/$orderId/delivered',
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
    return OrderHistoryItem.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<OrderHistoryItem> preparePrintPackage({
    required String orderId,
    required String adminKey,
  }) async {
    final response = await dio.post(
      '/api/orders/admin/$orderId/print-package/prepare',
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
    return OrderHistoryItem.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  String buildAdminPrintPackageUrl(String printPackageJsonUrl) {
    final raw = printPackageJsonUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final base = dio.options.baseUrl.trim();
    final normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return raw.startsWith('/') ? '$normalized$raw' : '$normalized/$raw';
  }

  Future<OrderStatusBadges> computeUnreadStatusBadges({
    required String userId,
    required OrderSummaryResult summary,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return const OrderStatusBadges.zero();

    final initKey = '$_orderSeenInitPrefix$normalizedUserId';
    final pendingKey = '$_orderSeenPendingPrefix$normalizedUserId';
    final completedKey = '$_orderSeenCompletedPrefix$normalizedUserId';
    final productionKey = '$_orderSeenProductionPrefix$normalizedUserId';
    final shippingKey = '$_orderSeenShippingPrefix$normalizedUserId';
    final deliveredKey = '$_orderSeenDeliveredPrefix$normalizedUserId';
    final latestUpdatedAtKey =
        '$_orderSeenLatestUpdatedAtPrefix$normalizedUserId';

    final initialized = prefs.getBool(initKey) ?? false;
    if (!initialized) {
      await _saveSeenSummary(
        prefs: prefs,
        initKey: initKey,
        pendingKey: pendingKey,
        completedKey: completedKey,
        productionKey: productionKey,
        shippingKey: shippingKey,
        deliveredKey: deliveredKey,
        latestUpdatedAtKey: latestUpdatedAtKey,
        summary: summary,
      );
      return const OrderStatusBadges.zero();
    }

    int delta(int current, int seen) => current > seen ? current - seen : 0;
    final base = OrderStatusBadges(
      paymentPending: delta(
        summary.paymentPending,
        prefs.getInt(pendingKey) ?? 0,
      ),
      paymentCompleted: delta(
        summary.paymentCompleted,
        prefs.getInt(completedKey) ?? 0,
      ),
      inProduction: delta(
        summary.inProduction,
        prefs.getInt(productionKey) ?? 0,
      ),
      shipping: delta(summary.shipping, prefs.getInt(shippingKey) ?? 0),
      delivered: delta(summary.delivered, prefs.getInt(deliveredKey) ?? 0),
    );

    if (base.hasAny) return base;

    final currentLatest = _normalizeLatestUpdatedAt(summary.latestUpdatedAt);
    final seenLatest = prefs.getString(latestUpdatedAtKey) ?? '';
    if (currentLatest.isNotEmpty && currentLatest != seenLatest) {
      return _fallbackBadgesForStatusChange(summary);
    }
    return base;
  }

  Future<void> markOrderSummarySeen({
    required String userId,
    required OrderSummaryResult summary,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    await _saveSeenSummary(
      prefs: prefs,
      initKey: '$_orderSeenInitPrefix$normalizedUserId',
      pendingKey: '$_orderSeenPendingPrefix$normalizedUserId',
      completedKey: '$_orderSeenCompletedPrefix$normalizedUserId',
      productionKey: '$_orderSeenProductionPrefix$normalizedUserId',
      shippingKey: '$_orderSeenShippingPrefix$normalizedUserId',
      deliveredKey: '$_orderSeenDeliveredPrefix$normalizedUserId',
      latestUpdatedAtKey: '$_orderSeenLatestUpdatedAtPrefix$normalizedUserId',
      summary: summary,
    );
  }

  Future<void> _saveSeenSummary({
    required SharedPreferences prefs,
    required String initKey,
    required String pendingKey,
    required String completedKey,
    required String productionKey,
    required String shippingKey,
    required String deliveredKey,
    required String latestUpdatedAtKey,
    required OrderSummaryResult summary,
  }) async {
    await prefs.setBool(initKey, true);
    await prefs.setInt(pendingKey, summary.paymentPending);
    await prefs.setInt(completedKey, summary.paymentCompleted);
    await prefs.setInt(productionKey, summary.inProduction);
    await prefs.setInt(shippingKey, summary.shipping);
    await prefs.setInt(deliveredKey, summary.delivered);
    await prefs.setString(
      latestUpdatedAtKey,
      _normalizeLatestUpdatedAt(summary.latestUpdatedAt),
    );
  }

  String _normalizeLatestUpdatedAt(DateTime? value) {
    if (value == null) return '';
    return value.toUtc().toIso8601String();
  }

  OrderStatusBadges _fallbackBadgesForStatusChange(OrderSummaryResult summary) {
    if (summary.paymentPending > 0) {
      return const OrderStatusBadges(
        paymentPending: 1,
        paymentCompleted: 0,
        inProduction: 0,
        shipping: 0,
        delivered: 0,
      );
    }
    if (summary.paymentCompleted > 0) {
      return const OrderStatusBadges(
        paymentPending: 0,
        paymentCompleted: 1,
        inProduction: 0,
        shipping: 0,
        delivered: 0,
      );
    }
    if (summary.inProduction > 0) {
      return const OrderStatusBadges(
        paymentPending: 0,
        paymentCompleted: 0,
        inProduction: 1,
        shipping: 0,
        delivered: 0,
      );
    }
    if (summary.shipping > 0) {
      return const OrderStatusBadges(
        paymentPending: 0,
        paymentCompleted: 0,
        inProduction: 0,
        shipping: 1,
        delivered: 0,
      );
    }
    if (summary.delivered > 0) {
      return const OrderStatusBadges(
        paymentPending: 0,
        paymentCompleted: 0,
        inProduction: 0,
        shipping: 0,
        delivered: 1,
      );
    }
    return const OrderStatusBadges.zero();
  }
}

class OrderQuoteResult {
  final int pageCount;
  final int amount;
  final int basePages;
  final int basePrice;
  final int extraPageCount;
  final int extraPagePrice;

  const OrderQuoteResult({
    required this.pageCount,
    required this.amount,
    required this.basePages,
    required this.basePrice,
    required this.extraPageCount,
    required this.extraPagePrice,
  });

  factory OrderQuoteResult.fromJson(Map<String, dynamic> json) {
    int parse(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return OrderQuoteResult(
      pageCount: parse(json['pageCount'], fallback: 12),
      amount: parse(json['amount'], fallback: 0),
      basePages: parse(json['basePages'], fallback: 12),
      basePrice: parse(json['basePrice'], fallback: 0),
      extraPageCount: parse(json['extraPageCount'], fallback: 0),
      extraPagePrice: parse(json['extraPagePrice'], fallback: 0),
    );
  }
}

class AddressSearchResult {
  final int page;
  final int totalCount;
  final List<AddressSearchItem> items;

  const AddressSearchResult({
    required this.page,
    required this.totalCount,
    required this.items,
  });

  factory AddressSearchResult.fromJson(Map<String, dynamic> json) {
    final list =
        (json['items'] as List?)
            ?.whereType<Map>()
            .map((e) => AddressSearchItem.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const <AddressSearchItem>[];
    return AddressSearchResult(
      page: int.tryParse(json['page']?.toString() ?? '') ?? 1,
      totalCount: int.tryParse(json['totalCount']?.toString() ?? '') ?? 0,
      items: list,
    );
  }
}

class AddressSearchItem {
  final String zipCode;
  final String roadAddress;
  final String roadAddressPart1;
  final String roadAddressPart2;
  final String jibunAddress;

  const AddressSearchItem({
    required this.zipCode,
    required this.roadAddress,
    required this.roadAddressPart1,
    required this.roadAddressPart2,
    required this.jibunAddress,
  });

  factory AddressSearchItem.fromJson(Map<String, dynamic> json) {
    return AddressSearchItem(
      zipCode: json['zipCode']?.toString() ?? '',
      roadAddress: json['roadAddress']?.toString() ?? '',
      roadAddressPart1: json['roadAddressPart1']?.toString() ?? '',
      roadAddressPart2: json['roadAddressPart2']?.toString() ?? '',
      jibunAddress: json['jibunAddress']?.toString() ?? '',
    );
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    dio: ref.read(dioProvider),
    tokenStorage: ref.read(tokenStorageProvider),
  );
});

final myOrderHistoryProvider = FutureProvider<List<OrderHistoryItem>>((
  ref,
) async {
  return ref.read(orderRepositoryProvider).fetchMyOrders();
});

final myOrderSummaryProvider = FutureProvider<OrderSummaryResult>((ref) async {
  try {
    return await ref
        .read(orderRepositoryProvider)
        .fetchMyOrderSummary()
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    return const OrderSummaryResult(
      paymentPending: 0,
      paymentCompleted: 0,
      inProduction: 0,
      shipping: 0,
      delivered: 0,
      canceled: 0,
      latestUpdatedAt: null,
    );
  }
});

final myOrderStatusBadgesProvider = FutureProvider<OrderStatusBadges>((
  ref,
) async {
  final repo = ref.read(orderRepositoryProvider);
  final userId = await repo.tokenStorage.getUserId();
  if (userId == null || userId.trim().isEmpty) {
    return const OrderStatusBadges.zero();
  }
  try {
    final summary = await ref.watch(myOrderSummaryProvider.future);
    return repo.computeUnreadStatusBadges(userId: userId, summary: summary);
  } catch (_) {
    return const OrderStatusBadges.zero();
  }
});

class OrderPageResult {
  final List<OrderHistoryItem> items;
  final int page;
  final int size;
  final int totalPages;
  final int totalElements;
  final bool hasNext;

  const OrderPageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.totalPages,
    required this.totalElements,
    required this.hasNext,
  });

  factory OrderPageResult.fromJson(Map<String, dynamic> json) {
    int parse(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    final list =
        (json['items'] as List?)
            ?.whereType<Map>()
            .map((e) => OrderHistoryItem.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const <OrderHistoryItem>[];

    return OrderPageResult(
      items: list,
      page: parse(json['page']),
      size: parse(json['size']),
      totalPages: parse(json['totalPages']),
      totalElements: parse(json['totalElements']),
      hasNext: json['hasNext'] == true,
    );
  }
}

class OrderSummaryResult {
  final int paymentPending;
  final int paymentCompleted;
  final int inProduction;
  final int shipping;
  final int delivered;
  final int canceled;
  final DateTime? latestUpdatedAt;

  const OrderSummaryResult({
    required this.paymentPending,
    required this.paymentCompleted,
    required this.inProduction,
    required this.shipping,
    required this.delivered,
    required this.canceled,
    required this.latestUpdatedAt,
  });

  factory OrderSummaryResult.fromJson(Map<String, dynamic> json) {
    int parse(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return OrderSummaryResult(
      paymentPending: parse(json['paymentPending']),
      paymentCompleted: parse(json['paymentCompleted']),
      inProduction: parse(json['inProduction']),
      shipping: parse(json['shipping']),
      delivered: parse(json['delivered']),
      canceled: parse(json['canceled']),
      latestUpdatedAt: _parseServerDateTime(
        json['latestUpdatedAt']?.toString(),
      ),
    );
  }

  static DateTime? _parseServerDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    if (!text.endsWith('Z') && !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(text)) {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      ).add(const Duration(hours: 9));
    }
    return parsed.toLocal();
  }
}

class OrderStatusBadges {
  final int paymentPending;
  final int paymentCompleted;
  final int inProduction;
  final int shipping;
  final int delivered;

  const OrderStatusBadges({
    required this.paymentPending,
    required this.paymentCompleted,
    required this.inProduction,
    required this.shipping,
    required this.delivered,
  });

  const OrderStatusBadges.zero()
    : paymentPending = 0,
      paymentCompleted = 0,
      inProduction = 0,
      shipping = 0,
      delivered = 0;

  bool get hasAny =>
      paymentPending > 0 ||
      paymentCompleted > 0 ||
      inProduction > 0 ||
      shipping > 0 ||
      delivered > 0;
}

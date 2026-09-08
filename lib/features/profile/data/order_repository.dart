import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/interceptors/token_storage.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../domain/entities/order_history_item.dart';

class OrderRepository {
  OrderRepository({required this.tokenStorage, this.supabase});

  final TokenStorage tokenStorage;
  final SupabaseClient? supabase;
  static const _orderSeenInitPrefix = 'snapfit_order_seen_init_';
  static const _orderSeenPendingPrefix = 'snapfit_order_seen_pending_';
  static const _orderSeenCompletedPrefix = 'snapfit_order_seen_completed_';
  static const _orderSeenProductionPrefix = 'snapfit_order_seen_production_';
  static const _orderSeenShippingPrefix = 'snapfit_order_seen_shipping_';
  static const _orderSeenDeliveredPrefix = 'snapfit_order_seen_delivered_';
  static const _orderSeenLatestUpdatedAtPrefix =
      'snapfit_order_seen_latest_updated_at_';

  Future<String> _requireUserId() async {
    final id = await tokenStorage.getResolvedUserId();
    if (id == null || id.trim().isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    return id;
  }

  Map<String, dynamic> _orderRowToJson(Map<String, dynamic> row) {
    final status = row['status']?.toString() ?? 'PAYMENT_PENDING';
    return {
      'orderId': row['order_id']?.toString() ?? '',
      'title': row['title']?.toString() ?? '주문',
      'amount': (row['amount'] as num?)?.toInt() ?? 0,
      'pageCount': (row['page_count'] as num?)?.toInt(),
      'status': status,
      'statusLabel': _statusLabel(status),
      'progress': _statusProgress(status),
      'orderedAt':
          row['ordered_at']?.toString() ?? row['created_at']?.toString(),
      'albumId': (row['album_id'] as num?)?.toInt(),
      'recipientName': row['recipient_name']?.toString(),
      'recipientPhone': row['recipient_phone']?.toString(),
      'zipCode': row['zip_code']?.toString(),
      'addressLine1': row['address_line1']?.toString(),
      'addressLine2': row['address_line2']?.toString(),
      'deliveryMemo': row['delivery_memo']?.toString(),
      'paymentMethod': row['payment_method']?.toString(),
      'courier': row['courier']?.toString(),
      'trackingNumber': row['tracking_number']?.toString(),
      'printVendor': row['print_vendor']?.toString(),
      'printVendorOrderId': row['print_vendor_order_id']?.toString(),
      'printPackageJsonUrl': row['print_package_json_url']?.toString(),
      'printFilePdfUrl': row['print_file_pdf_url']?.toString(),
      'printFileZipUrl': row['print_file_zip_url']?.toString(),
      'printAssetCount': (row['print_asset_count'] as num?)?.toInt(),
      'paymentConfirmedAt': row['payment_confirmed_at']?.toString(),
      'printPackageGeneratedAt': row['print_package_generated_at']?.toString(),
      'printSubmittedAt': row['print_submitted_at']?.toString(),
      'shippedAt': row['shipped_at']?.toString(),
      'deliveredAt': row['delivered_at']?.toString(),
      'printFulfillmentStatus': row['print_fulfillment_status'],
      'printCoverPdfPath': row['print_cover_pdf_path'],
      'printInteriorPdfPath': row['print_interior_pdf_path'],
      'printManifest': row['print_manifest'],
      'printCostSnapshot': row['print_cost_snapshot'],
      'printProductSnapshot': row['print_product_snapshot'],
      'pricingVersion': row['pricing_version'],
      'actualPrintCost': row['actual_print_cost'],
      'actualShippingCost': row['actual_shipping_cost'],
      'actualPackagingCost': row['actual_packaging_cost'],
      'contributionMargin': row['contribution_margin'],
      'printAcceptedAt': row['print_accepted_at'],
      'fulfillmentMethod': row['fulfillment_method'],
      'fulfillmentConfirmation': row['fulfillment_confirmation'],
    };
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PAYMENT_COMPLETED':
        return '결제완료';
      case 'IN_PRODUCTION':
      case 'PRINTING':
        return '제작중';
      case 'SHIPPING':
        return '배송중';
      case 'DELIVERED':
        return '배송완료';
      case 'CANCELED':
      case 'CANCELLED':
        return '취소';
      default:
        return '결제대기';
    }
  }

  double _statusProgress(String status) {
    switch (status.toUpperCase()) {
      case 'PAYMENT_COMPLETED':
        return 0.25;
      case 'IN_PRODUCTION':
      case 'PRINTING':
        return 0.5;
      case 'SHIPPING':
        return 0.75;
      case 'DELIVERED':
        return 1.0;
      default:
        return 0.0;
    }
  }

  OrderSummaryResult _summaryFromOrders(List<OrderHistoryItem> items) {
    int count(String status) =>
        items.where((e) => e.status.toUpperCase() == status).length;
    DateTime? latest;
    for (final item in items) {
      if (latest == null || item.orderedAt.isAfter(latest))
        latest = item.orderedAt;
    }
    return OrderSummaryResult(
      paymentPending: count('PAYMENT_PENDING'),
      paymentCompleted: count('PAYMENT_COMPLETED'),
      inProduction: count('IN_PRODUCTION') + count('PRINTING'),
      shipping: count('SHIPPING'),
      delivered: count('DELIVERED'),
      canceled: count('CANCELED') + count('CANCELLED'),
      latestUpdatedAt: latest,
    );
  }

  Future<List<OrderHistoryItem>> fetchMyOrders() async {
    final userId = await _requireUserId();
    if (supabase != null) {
      final rows = await supabase!
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('ordered_at', ascending: false);
      return rows
          .map<OrderHistoryItem>(
            (e) => OrderHistoryItem.fromJson(
              _orderRowToJson(Map<String, dynamic>.from(e)),
            ),
          )
          .toList(growable: false);
    }
    throw Exception('Supabase 주문 목록 환경이 준비되지 않았습니다.');
  }

  Future<OrderPageResult> fetchMyOrdersPage({
    List<String>? statuses,
    int page = 0,
    int size = 20,
  }) async {
    final userId = await _requireUserId();
    if (supabase != null) {
      var query = supabase!.from('orders').select();
      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('status', statuses);
      }
      final rows = await query
          .eq('user_id', userId)
          .order('ordered_at', ascending: false)
          .range(page * size, page * size + size - 1);
      final items = rows
          .map<OrderHistoryItem>(
            (e) => OrderHistoryItem.fromJson(
              _orderRowToJson(Map<String, dynamic>.from(e)),
            ),
          )
          .toList(growable: false);
      return OrderPageResult(
        items: items,
        page: page,
        size: size,
        totalPages: items.length < size ? page + 1 : page + 2,
        totalElements: page * size + items.length,
        hasNext: items.length == size,
      );
    }
    throw Exception('Supabase 주문 페이지 환경이 준비되지 않았습니다.');
  }

  Future<OrderSummaryResult> fetchMyOrderSummary() async {
    final userId = await _requireUserId();
    if (supabase != null) {
      final rows = await supabase!
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('ordered_at', ascending: false);
      final items = rows
          .map<OrderHistoryItem>(
            (e) => OrderHistoryItem.fromJson(
              _orderRowToJson(Map<String, dynamic>.from(e)),
            ),
          )
          .toList(growable: false);
      return _summaryFromOrders(items);
    }
    throw Exception('Supabase 주문 요약 환경이 준비되지 않았습니다.');
  }

  Future<OrderQuoteResult> fetchOrderQuote({
    required int albumId,
    int? pageCount,
  }) async {
    await _requireUserId();
    if (supabase != null) {
      final quote = await supabase!.rpc(
        'get_print_order_quote',
        params: {'p_album_id': albumId, 'p_page_count': pageCount},
      );
      return OrderQuoteResult.fromJson(Map<String, dynamic>.from(quote as Map));
    }
    throw Exception('Supabase 주문 견적 환경이 준비되지 않았습니다.');
  }

  Future<Map<String, dynamic>> fetchPrintPreviewSnapshot({
    required int albumId,
  }) async {
    await _requireUserId();
    final client = supabase;
    if (client == null) throw StateError('앨범 서버 연결이 준비되지 않았습니다.');
    final album = Map<String, dynamic>.from(
      await client.from('albums').select().eq('id', albumId).single(),
    );
    final raw = album['cover_layers_json'];
    final document = raw is String ? jsonDecode(raw) : raw;
    final pages = document is Map && document['pages'] is List
        ? const <Map<String, dynamic>>[]
        : await client
              .from('album_pages')
              .select()
              .eq('album_id', albumId)
              .order('page_index');
    return {'album': album, 'pages': pages};
  }

  Future<AddressSearchResult> searchAddress({
    required String keyword,
    int page = 1,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.length < 2) {
      throw Exception('검색어를 2글자 이상 입력해주세요.');
    }
    if (supabase != null) {
      final response = await supabase!.functions.invoke(
        'address-search',
        body: {'keyword': normalizedKeyword, 'page': page},
      );
      final map =
          (response.data as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      if (map['error'] != null) {
        throw Exception(map['message'] ?? map['error']);
      }
      return AddressSearchResult.fromJson(map);
    }
    throw Exception('Supabase 주소검색 환경이 준비되지 않았습니다.');
  }

  String buildAdminPrintPackageUrl(String printPackageJsonUrl) {
    final raw = printPackageJsonUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    return raw;
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
  final int sourcePageCount;
  final int addedBlankPageCount;
  final String productCode;
  final String productName;
  final bool shippingIncluded;
  final int maxPages;
  final Map<String, dynamic> layoutPreview;
  final Map<String, dynamic> printSpec;
  final Map<String, dynamic> printProduct;
  final bool priceIsEstimate;
  final bool specMissing;

  const OrderQuoteResult({
    required this.pageCount,
    required this.amount,
    required this.basePages,
    required this.basePrice,
    required this.extraPageCount,
    required this.extraPagePrice,
    this.sourcePageCount = 0,
    this.addedBlankPageCount = 0,
    this.productCode = '',
    this.productName = '',
    this.shippingIncluded = false,
    this.maxPages = 80,
    this.layoutPreview = const {},
    this.printSpec = const {},
    this.printProduct = const {},
    this.priceIsEstimate = false,
    this.specMissing = false,
  });

  factory OrderQuoteResult.fromJson(Map<String, dynamic> json) {
    int parse(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return OrderQuoteResult(
      pageCount: parse(json['pageCount']),
      amount: parse(json['amount'], fallback: 0),
      basePages: parse(json['basePages']),
      basePrice: parse(json['basePrice'], fallback: 0),
      extraPageCount: parse(json['extraPageCount'], fallback: 0),
      extraPagePrice: parse(json['extraPagePrice'], fallback: 0),
      sourcePageCount: parse(json['sourcePageCount']),
      addedBlankPageCount: parse(json['addedBlankPageCount']),
      productCode: json['productCode']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      shippingIncluded: json['shippingIncluded'] == true,
      maxPages: parse(json['maxPages'], fallback: 80),
      layoutPreview:
          (json['layoutPreview'] as Map?)?.cast<String, dynamic>() ?? const {},
      printSpec: (json['spec'] as Map?)?.cast<String, dynamic>() ?? const {},
      printProduct:
          (json['printProduct'] as Map?)?.cast<String, dynamic>() ?? const {},
      priceIsEstimate: json['priceIsEstimate'] == true,
      specMissing: json['specMissing'] == true,
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
    tokenStorage: ref.read(tokenStorageProvider),
    supabase: ref.read(supabaseClientProvider),
  );
});

final myOrderHistoryProvider = FutureProvider<List<OrderHistoryItem>>((
  ref,
) async {
  return await ref.read(orderRepositoryProvider).fetchMyOrders();
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
  final userId = await repo.tokenStorage.getResolvedUserId();
  if (userId == null || userId.trim().isEmpty) {
    return const OrderStatusBadges.zero();
  }
  try {
    final summary = await ref.watch(myOrderSummaryProvider.future);
    return await repo.computeUnreadStatusBadges(
      userId: userId,
      summary: summary,
    );
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

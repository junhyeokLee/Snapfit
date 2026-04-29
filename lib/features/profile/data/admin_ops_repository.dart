import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'order_repository.dart';
import '../domain/entities/order_history_item.dart';

class AdminOpsRepository {
  AdminOpsRepository({required this.dio});

  final Dio dio;

  Future<AdminDashboardData> fetchDashboard({required String adminKey}) async {
    final response = await dio.get(
      '/api/ops/admin/dashboard',
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
    final map =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return AdminDashboardData.fromJson(map);
  }

  Future<List<AdminCsSignal>> fetchCsSignals({
    required String adminKey,
    int limit = 50,
  }) async {
    final response = await dio.get(
      '/api/ops/admin/cs-signals',
      queryParameters: {'limit': limit},
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
    final map =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final items = map['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => AdminCsSignal.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<OrderPageResult> fetchAdminOrders({
    required String adminKey,
    List<String>? statuses,
    String? keyword,
    int page = 0,
    int size = 20,
  }) async {
    final response = await dio.get(
      '/api/orders/admin/paged',
      queryParameters: {
        'page': page,
        'size': size,
        if (statuses != null && statuses.isNotEmpty) 'status': statuses,
        if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword,
      },
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
    final map =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return OrderPageResult.fromJson(map);
  }

  Future<OrderHistoryItem> markShipping({
    required String adminKey,
    required String orderId,
    required String courier,
    required String trackingNumber,
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
    required String adminKey,
    required String orderId,
  }) async {
    final response = await dio.post(
      '/api/orders/$orderId/delivered',
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
    return OrderHistoryItem.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<void> upsertTemplate({
    required String adminKey,
    required Map<String, dynamic> payload,
  }) async {
    await dio.post(
      '/api/templates/admin/upsert',
      data: payload,
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
  }

  Future<AdminTemplatePage> fetchAdminTemplates({
    required String adminKey,
    int page = 0,
    int size = 20,
  }) async {
    final response = await dio.get(
      '/api/templates/admin/paged',
      queryParameters: {'page': page, 'size': size},
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
    final map =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return AdminTemplatePage.fromJson(map);
  }

  Future<void> setTemplateActive({
    required String adminKey,
    required int templateId,
    required bool active,
  }) async {
    await dio.post(
      '/api/templates/admin/$templateId/active',
      data: {'active': active},
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
  }

  Future<Map<String, dynamic>> fetchAdminTemplateDetail({
    required String adminKey,
    required int templateId,
  }) async {
    final response = await dio.get(
      '/api/templates/admin/$templateId',
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
    return (response.data as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
  }
}

class AdminDashboardData {
  AdminDashboardData({
    required this.generatedAt,
    required this.usersTotal,
    required this.users24h,
    required this.templatesTotal,
    required this.templatesActive,
    required this.ordersTotal,
    required this.orders24h,
    required this.billingApproved24h,
    required this.billingFailed24h,
  });

  final String generatedAt;
  final int usersTotal;
  final int users24h;
  final int templatesTotal;
  final int templatesActive;
  final int ordersTotal;
  final int orders24h;
  final int billingApproved24h;
  final int billingFailed24h;

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    final users = (json['users'] as Map?)?.cast<String, dynamic>() ?? {};
    final templates =
        (json['templates'] as Map?)?.cast<String, dynamic>() ?? {};
    final orders = (json['orders'] as Map?)?.cast<String, dynamic>() ?? {};
    final billing = (json['billing'] as Map?)?.cast<String, dynamic>() ?? {};

    int readInt(Map<String, dynamic> src, String key) =>
        (src[key] as num?)?.toInt() ?? 0;

    return AdminDashboardData(
      generatedAt: json['generatedAt']?.toString() ?? '',
      usersTotal: readInt(users, 'total'),
      users24h: readInt(users, 'new24h'),
      templatesTotal: readInt(templates, 'total'),
      templatesActive: readInt(templates, 'active'),
      ordersTotal: readInt(orders, 'total'),
      orders24h: readInt(orders, 'new24h'),
      billingApproved24h: readInt(billing, 'approved24h'),
      billingFailed24h: readInt(billing, 'failed24h'),
    );
  }
}

class AdminCsSignal {
  AdminCsSignal({
    required this.type,
    required this.severity,
    required this.code,
    required this.title,
    required this.message,
    required this.orderId,
    required this.userId,
    required this.updatedAt,
  });

  final String type;
  final String severity;
  final String code;
  final String title;
  final String message;
  final String orderId;
  final String userId;
  final String updatedAt;

  factory AdminCsSignal.fromJson(Map<String, dynamic> json) {
    return AdminCsSignal(
      type: json['type']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

final adminOpsRepositoryProvider = Provider<AdminOpsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AdminOpsRepository(dio: dio);
});

class AdminTemplatePage {
  AdminTemplatePage({
    required this.items,
    required this.page,
    required this.hasNext,
  });

  final List<AdminTemplateSummary> items;
  final int page;
  final bool hasNext;

  factory AdminTemplatePage.fromJson(Map<String, dynamic> json) {
    final list =
        (json['items'] as List?)
            ?.whereType<Map>()
            .map(
              (e) => AdminTemplateSummary.fromJson(e.cast<String, dynamic>()),
            )
            .toList() ??
        const <AdminTemplateSummary>[];
    return AdminTemplatePage(
      items: list,
      page: (json['page'] as num?)?.toInt() ?? 0,
      hasNext: json['hasNext'] == true,
    );
  }
}

class AdminTemplateSummary {
  AdminTemplateSummary({
    required this.id,
    required this.title,
    required this.active,
    required this.pageCount,
    required this.category,
  });

  final int id;
  final String title;
  final bool active;
  final int pageCount;
  final String category;

  factory AdminTemplateSummary.fromJson(Map<String, dynamic> json) {
    return AdminTemplateSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      active: json['active'] != false,
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? '',
    );
  }
}

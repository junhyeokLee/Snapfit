import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import 'order_repository.dart';
import '../domain/entities/order_history_item.dart';
import '../../../core/network/legacy_backend_guard.dart';

class AdminOpsRepository {
  AdminOpsRepository({required this.dio, this.supabase});

  final Dio dio;
  final SupabaseClient? supabase;

  Future<Map<String, dynamic>> _invoke(
    String action, {
    required String adminKey,
    Map<String, dynamic>? body,
  }) async {
    if (supabase == null) return <String, dynamic>{};
    final response = await supabase!.functions.invoke(
      'admin-ops',
      body: {'action': action, 'adminKey': adminKey, ...?body},
      headers: {'X-Admin-Key': adminKey},
    );
    return (response.data as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
  }

  Future<AdminDashboardData> fetchDashboard({required String adminKey}) async {
    if (supabase != null) {
      return AdminDashboardData.fromJson(
        await _invoke('dashboard', adminKey: adminKey),
      );
    }
    assertLegacyBackendFallbackAllowed(feature: 'admin.dashboard');
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
    if (supabase != null) {
      final map = await _invoke(
        'csSignals',
        adminKey: adminKey,
        body: {'limit': limit},
      );
      final items = map['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((e) => AdminCsSignal.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    assertLegacyBackendFallbackAllowed(feature: 'admin.csSignals');
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
    if (supabase != null) {
      return OrderPageResult.fromJson(
        await _invoke(
          'orders',
          adminKey: adminKey,
          body: {
            'page': page,
            'size': size,
            if (statuses != null) 'statuses': statuses,
            if (keyword != null) 'keyword': keyword,
          },
        ),
      );
    }
    assertLegacyBackendFallbackAllowed(feature: 'admin.orders');
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

  Future<OrderHistoryItem> preparePrintPackage({
    required String adminKey,
    required String orderId,
  }) async {
    if (supabase != null) {
      return OrderHistoryItem.fromJson(
        await _invoke(
          'preparePrintPackage',
          adminKey: adminKey,
          body: {'orderId': orderId},
        ),
      );
    }
    assertLegacyBackendFallbackAllowed(feature: 'admin.printPackage');
    final response = await dio.post(
      '/api/orders/admin/$orderId/print-package/prepare',
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
    return OrderHistoryItem.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  Future<OrderHistoryItem> markShipping({
    required String adminKey,
    required String orderId,
    required String courier,
    required String trackingNumber,
  }) async {
    if (supabase != null) {
      return OrderHistoryItem.fromJson(
        await _invoke(
          'markShipping',
          adminKey: adminKey,
          body: {
            'orderId': orderId,
            'courier': courier,
            'trackingNumber': trackingNumber,
          },
        ),
      );
    }
    assertLegacyBackendFallbackAllowed(feature: 'admin.shipping');
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
    if (supabase != null) {
      return OrderHistoryItem.fromJson(
        await _invoke(
          'markDelivered',
          adminKey: adminKey,
          body: {'orderId': orderId},
        ),
      );
    }
    assertLegacyBackendFallbackAllowed(feature: 'admin.delivered');
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
    if (supabase != null) {
      await _invoke(
        'upsertTemplate',
        adminKey: adminKey,
        body: {'payload': payload},
      );
      return;
    }
    assertLegacyBackendFallbackAllowed(feature: 'admin.templates.upsert');
    await dio.post(
      '/api/admin/templates/upsert',
      data: payload,
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
  }

  Future<AdminTemplatePage> fetchAdminTemplates({
    required String adminKey,
    int page = 0,
    int size = 20,
  }) async {
    if (supabase != null) {
      return AdminTemplatePage.fromJson(
        await _invoke(
          'templates',
          adminKey: adminKey,
          body: {'page': page, 'size': size},
        ),
      );
    }
    assertLegacyBackendFallbackAllowed(feature: 'admin.templates');
    final response = await dio.get(
      '/api/admin/templates/paged',
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
    if (supabase != null) {
      await _invoke(
        'setTemplateActive',
        adminKey: adminKey,
        body: {'templateId': templateId, 'active': active},
      );
      return;
    }
    assertLegacyBackendFallbackAllowed(feature: 'admin.templates.active');
    await dio.post(
      '/api/admin/templates/$templateId/active',
      data: {'active': active},
      options: Options(headers: {'X-Admin-Key': adminKey}),
    );
  }

  Future<Map<String, dynamic>> fetchAdminTemplateDetail({
    required String adminKey,
    required int templateId,
  }) async {
    if (supabase != null) {
      return _invoke(
        'templateDetail',
        adminKey: adminKey,
        body: {'templateId': templateId},
      );
    }
    assertLegacyBackendFallbackAllowed(feature: 'admin.templates.detail');
    final response = await dio.get(
      '/api/admin/templates/$templateId',
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
  final supabase = ref.watch(supabaseClientProvider);
  return AdminOpsRepository(dio: dio, supabase: supabase);
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
    required this.likeCount,
    required this.userCount,
  });

  final int id;
  final String title;
  final bool active;
  final int pageCount;
  final String category;
  final int likeCount;
  final int userCount;

  factory AdminTemplateSummary.fromJson(Map<String, dynamic> json) {
    return AdminTemplateSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      active: json['active'] != false,
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? '',
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      userCount: (json['userCount'] as num?)?.toInt() ?? 0,
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/interceptors/token_storage.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../domain/entities/order_history_item.dart';

class OrderRepository {
  OrderRepository({required this.dio, required this.tokenStorage});

  final Dio dio;
  final TokenStorage tokenStorage;

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

import 'package:dio/dio.dart';

import '../../../core/interceptors/token_storage.dart';
import '../domain/entities/app_notification_item.dart';

class NotificationRepository {
  NotificationRepository({required this.dio, required this.tokenStorage});

  final Dio dio;
  final TokenStorage tokenStorage;

  Future<String> _requireUserId() async {
    final id = await tokenStorage.getUserId();
    if (id == null || id.trim().isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    return id;
  }

  Future<List<AppNotificationItem>> fetchInbox({int limit = 50}) async {
    final userId = await _requireUserId();
    try {
      final response = await dio.get(
        '/api/notifications/inbox',
        queryParameters: {'userId': userId, 'limit': limit},
      );

      final data = response.data;
      if (data is! List) return const [];

      return data
          .whereType<Map>()
          .map((e) => AppNotificationItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 404) {
        return const [];
      }
      rethrow;
    }
  }

  Future<int> fetchUnreadCount() async {
    final userId = await _requireUserId();
    try {
      final response = await dio.get(
        '/api/notifications/unread-count',
        queryParameters: {'userId': userId},
      );
      final raw = (response.data as Map?)?['unreadCount'];
      return (raw as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 404) {
        return 0;
      }
      rethrow;
    }
  }

  Future<void> markRead(int notificationId) async {
    final userId = await _requireUserId();
    try {
      await dio.post(
        '/api/notifications/$notificationId/read',
        queryParameters: {'userId': userId},
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 404) {
        return;
      }
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final userId = await _requireUserId();
    try {
      await dio.post(
        '/api/notifications/read-all',
        queryParameters: {'userId': userId},
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 404) {
        return;
      }
      rethrow;
    }
  }

  Future<int> fetchRetentionDays() async {
    try {
      final response = await dio.get('/api/notifications/policy');
      final data = response.data;
      if (data is Map) {
        final raw = data['retentionDays'];
        return (raw as num?)?.toInt() ?? 90;
      }
      return 90;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 404) {
        return 90;
      }
      rethrow;
    }
  }
}

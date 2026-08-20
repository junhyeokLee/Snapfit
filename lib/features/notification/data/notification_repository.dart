import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/interceptors/token_storage.dart';
import '../domain/entities/app_notification_item.dart';

class NotificationRepository {
  NotificationRepository({required this.dio, required this.tokenStorage, this.supabase});

  final Dio dio;
  final TokenStorage tokenStorage;
  final SupabaseClient? supabase;

  Future<String> _requireUserId() async {
    final id = await tokenStorage.getResolvedUserId();
    if (id == null || id.trim().isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    return id;
  }


  AppNotificationItem _fromInboxRow(Map<String, dynamic> row, Set<int> readIds) {
    final id = (row['id'] as num?)?.toInt() ?? -1;
    return AppNotificationItem.fromJson({
      'id': id,
      'type': row['type']?.toString() ?? 'general',
      'title': row['title']?.toString() ?? '알림',
      'body': row['body']?.toString() ?? '',
      'deeplink': row['deeplink']?.toString(),
      'createdAt': row['created_at']?.toString(),
      'isRead': readIds.contains(id),
    });
  }

  Future<List<AppNotificationItem>> fetchInbox({int limit = 50}) async {
    final userId = await _requireUserId();
    if (supabase != null) {
      final rows = await supabase!
          .from('notification_inbox')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      final readRows = await supabase!
          .from('notification_reads')
          .select('notification_id')
          .eq('user_id', userId);
      final readIds = readRows
          .map<int>((e) => (e['notification_id'] as num?)?.toInt() ?? -1)
          .where((e) => e >= 0)
          .toSet();
      return rows
          .map<AppNotificationItem>((e) => _fromInboxRow(Map<String, dynamic>.from(e), readIds))
          .toList(growable: false);
    }
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
    if (supabase != null) {
      final inbox = await supabase!.from('notification_inbox').select('id');
      final read = await supabase!
          .from('notification_reads')
          .select('notification_id')
          .eq('user_id', userId);
      final readIds = read.map<int>((e) => (e['notification_id'] as num?)?.toInt() ?? -1).toSet();
      return inbox.where((e) => !readIds.contains((e['id'] as num?)?.toInt() ?? -1)).length;
    }
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
    if (supabase != null) {
      await supabase!.from('notification_reads').upsert({
        'notification_id': notificationId,
        'user_id': userId,
      });
      return;
    }
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
    if (supabase != null) {
      final rows = await supabase!.from('notification_inbox').select('id');
      for (final row in rows) {
        final id = (row['id'] as num?)?.toInt();
        if (id != null) {
          await supabase!.from('notification_reads').upsert({
            'notification_id': id,
            'user_id': userId,
          });
        }
      }
      return;
    }
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
    if (supabase != null) return 90;
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

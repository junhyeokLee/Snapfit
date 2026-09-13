import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/interceptors/token_storage.dart';
import '../domain/entities/app_notification_item.dart';

class NotificationRepository {
  NotificationRepository({required this.tokenStorage, this.supabase});
  final TokenStorage tokenStorage;
  final SupabaseClient? supabase;

  String _requireUserId() {
    final id = supabase?.auth.currentUser?.id;
    if (id == null || id.isEmpty) throw Exception('로그인이 필요합니다.');
    return id;
  }

  String get _cutoff => DateTime.now()
      .toUtc()
      .subtract(const Duration(days: 90))
      .toIso8601String();

  Future<List<AppNotificationItem>> fetchInbox({int limit = 50}) async {
    final userId = _requireUserId();
    final rows = await supabase!
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .gte('created_at', _cutoff)
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 100));
    return rows
        .map(
          (row) => AppNotificationItem.fromJson({
            ...row,
            'createdAt': row['created_at'],
            'isRead': row['is_read'],
            'userId': row['user_id'],
          }),
        )
        .toList(growable: false);
  }

  Future<int> fetchUnreadCount() async {
    final userId = _requireUserId();
    return await supabase!
        .from('notifications')
        .count(CountOption.exact)
        .eq('user_id', userId)
        .eq('is_read', false)
        .gte('created_at', _cutoff);
  }

  Future<void> markRead(int notificationId) async {
    final userId = _requireUserId();
    await supabase!
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('id', notificationId)
        .eq('is_read', false);
  }

  Future<void> markAllRead() async {
    final userId = _requireUserId();
    // A single idempotent UPDATE: no client iteration or INSERT/UPSERT policy mismatch.
    await supabase!
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('is_read', false)
        .gte('created_at', _cutoff);
  }

  Future<int> fetchRetentionDays() async => 90;
}

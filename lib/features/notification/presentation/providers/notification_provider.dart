import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/notification_repository.dart';
import '../../domain/entities/app_notification_item.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    dio: ref.read(dioProvider),
    tokenStorage: ref.read(tokenStorageProvider),
  );
});

final notificationInboxProvider = FutureProvider<List<AppNotificationItem>>((
  ref,
) async {
  return ref.read(notificationRepositoryProvider).fetchInbox(limit: 60);
});

final notificationUnreadCountProvider = FutureProvider<int>((ref) async {
  return ref.read(notificationRepositoryProvider).fetchUnreadCount();
});

final notificationActionProvider = Provider<NotificationAction>((ref) {
  return NotificationAction(ref);
});

final notificationRetentionDaysProvider = FutureProvider<int>((ref) async {
  return ref.read(notificationRepositoryProvider).fetchRetentionDays();
});

class NotificationAction {
  NotificationAction(this.ref);

  final Ref ref;

  Future<void> markRead(int notificationId) async {
    await ref.read(notificationRepositoryProvider).markRead(notificationId);
    ref.invalidate(notificationInboxProvider);
    ref.invalidate(notificationUnreadCountProvider);
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref.invalidate(notificationInboxProvider);
    ref.invalidate(notificationUnreadCountProvider);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';
import '../../domain/entities/app_notification_item.dart';
import '../providers/notification_provider.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _didMarkAllOnEnter = false;
  bool _didMarkAllAfterDataLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_didMarkAllOnEnter) return;
      _didMarkAllOnEnter = true;
      await ref.read(notificationActionProvider).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(notificationInboxProvider);
    final retentionDaysAsync = ref.watch(notificationRetentionDaysProvider);
    final action = ref.read(notificationActionProvider);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        leading: const SnapFitAppBarBackButton(),
        title: Text(
          '알림',
          style: TextStyle(
            color: SnapFitColors.textPrimaryOf(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              await action.markAllRead();
            },
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: inboxAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  '알림을 불러오지 못했어요.',
                  style: TextStyle(
                    color: SnapFitColors.textSecondaryOf(context),
                  ),
                ),
              ),
              data: (items) {
                final hasUnread = items.any((e) => !e.isRead);
                if (hasUnread && !_didMarkAllAfterDataLoad) {
                  _didMarkAllAfterDataLoad = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await action.markAllRead();
                  });
                }

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      '알림이 없습니다.',
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ),
                  );
                }

                final grouped = _groupByDay(items);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final section = grouped[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Text(
                            section.$1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: SnapFitColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                        ...section.$2.map(
                          (item) => _NotificationCard(item: item, onTap: () {}),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _RetentionPolicyBar(retentionDaysAsync: retentionDaysAsync),
        ],
      ),
    );
  }

  List<(String, List<AppNotificationItem>)> _groupByDay(
    List<AppNotificationItem> items,
  ) {
    final byKey = <String, List<AppNotificationItem>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label(DateTime date) {
      final d = DateTime(date.year, date.month, date.day);
      if (d == today) return '오늘';
      if (d == yesterday) return '어제';
      return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    }

    for (final item in items) {
      final key = label(item.createdAt);
      byKey.putIfAbsent(key, () => <AppNotificationItem>[]).add(item);
    }

    return byKey.entries.map((e) => (e.key, e.value)).toList();
  }
}

class _RetentionPolicyBar extends StatelessWidget {
  const _RetentionPolicyBar({required this.retentionDaysAsync});

  final AsyncValue<int> retentionDaysAsync;

  @override
  Widget build(BuildContext context) {
    final days = retentionDaysAsync.maybeWhen(
      data: (value) => value,
      orElse: () => 90,
    );
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          border: Border(
            top: BorderSide(
              color: SnapFitColors.overlayLightOf(context),
              width: 1,
            ),
          ),
        ),
        child: Text(
          '알림은 실서비스 운영 기준에 맞춰 $days일 보관 후 자동 삭제됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SnapFitColors.textMutedOf(context),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = item.isRead;
    final time =
        '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? SnapFitColors.overlayLightOf(context)
                : const Color(0xFF9CEBFF),
            width: isRead ? 1 : 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 22,
                    height: 22,
                    color: const Color(0xFFEAF7FB),
                    padding: const EdgeInsets.all(3),
                    child: Image.asset(
                      'assets/snapfit_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isRead
                        ? Colors.transparent
                        : const Color(0xFF08B7DD),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _typeLabel(item.type),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SnapFitColors.textSecondaryOf(context),
                  ),
                ),
                const Spacer(),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.body,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SnapFitColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDateTime(item.createdAt),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: SnapFitColors.textMutedOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'template_new':
        return '새 템플릿';
      case 'order_status':
        return '주문 알림';
      case 'album_comment':
        return '댓글/반응';
      case 'album_invite':
        return '공유/초대';
      default:
        return '안내';
    }
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y.$m.$d $h:$min';
  }
}

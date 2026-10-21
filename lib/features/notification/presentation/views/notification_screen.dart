import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../core/notifications/fcm_notification_service.dart';
import '../../domain/entities/app_notification_item.dart';
import '../providers/notification_provider.dart';
import '../../../profile/presentation/widgets/customer_web_page.dart';
import '../../../profile/presentation/views/notification_settings_screen.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../../../shared/web/web_design.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _markingAll = false;
  bool _refreshing = false;
  bool _openingSettings = false;
  Future<List<AppNotificationItem>>? _manualRefresh;
  List<AppNotificationItem>? _retainedItems;
  int _inboxGeneration = 0;
  String? _webOwnerId;
  bool get _webOwnerCurrent =>
      _webOwnerId != null && ref.read(visibleOrderOwnerProvider) == _webOwnerId;

  Future<void> _markAllRead() async {
    if (!mounted ||
        _markingAll ||
        _refreshing ||
        _openingSettings ||
        (kIsWeb && !_webOwnerCurrent))
      return;
    final inbox = ref.read(notificationInboxProvider);
    if (inbox.isLoading ||
        inbox.hasError ||
        !(inbox.asData?.value.any((item) => !item.isRead) ?? false))
      return;
    setState(() => _markingAll = true);
    try {
      await ref.read(notificationActionProvider).markAllRead();
    } catch (_) {
      if (!mounted || (kIsWeb && !_webOwnerCurrent)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('읽음 처리를 완료하지 못했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _refreshInbox() async {
    if (!mounted ||
        _refreshing ||
        _markingAll ||
        _openingSettings ||
        (kIsWeb && !_webOwnerCurrent) ||
        ref.read(notificationInboxProvider).isLoading)
      return;
    final current = ref.read(notificationInboxProvider);
    final retained =
        current.asData?.value ??
        (identical(_manualRefresh, ref.read(notificationInboxProvider.future))
            ? _retainedItems
            : null);
    final generation = _inboxGeneration;
    setState(() {
      _refreshing = true;
      _manualRefresh = null;
      _retainedItems = retained;
    });
    final inbox = ref.refresh(notificationInboxProvider.future);
    _manualRefresh = inbox;
    try {
      await Future.wait<Object>([
        inbox,
        ref.refresh(notificationUnreadCountProvider.future),
      ]);
    } catch (_) {
      if (!mounted ||
          (kIsWeb && !_webOwnerCurrent) ||
          generation != _inboxGeneration ||
          !identical(ref.read(notificationInboxProvider.future), inbox))
        return;
      if (ModalRoute.of(context)?.isCurrent != false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림을 새로고침하지 못했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _openSettings() async {
    if (!mounted || _openingSettings || (kIsWeb && !_webOwnerCurrent)) return;
    setState(() => _openingSettings = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
      );
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final owner = ref.watch(visibleOrderOwnerProvider);
      if (owner != null && _webOwnerId == null) _webOwnerId = owner;
      if (owner == null || owner != _webOwnerId) {
        return const CustomerWebPage(
          title: '알림함',
          eyebrow: 'NOTIFICATIONS',
          child: Center(child: Text('로그인 계정을 확인하고 알림함을 다시 열어주세요.')),
        );
      }
    }
    ref.listen(notificationInboxProvider, (previous, next) {
      if (next.isReloading) {
        _inboxGeneration++;
        _retainedItems = null;
      }
    });
    final inboxAsync = ref.watch(notificationInboxProvider);
    final retentionDaysAsync = ref.watch(notificationRetentionDaysProvider);

    if (kIsWeb) return _webInbox(inboxAsync, retentionDaysAsync);
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: ExperienceHeader(
        title: '알림',
        themeAware: true,
        showNotifications: false,
        actions: [
          IconButton(
            key: const ValueKey('inbox-refresh'),
            tooltip: '알림 새로고침',
            onPressed:
                _refreshing ||
                    _markingAll ||
                    _openingSettings ||
                    inboxAsync.isLoading
                ? null
                : _refreshInbox,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const ExperienceIcon('RefreshCw'),
          ),
          IconButton(
            key: const ValueKey('inbox-settings'),
            tooltip: '알림 설정',
            onPressed: _openingSettings ? null : _openSettings,
            icon: const ExperienceIcon('Settings2'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, box) {
            final wide =
                box.maxWidth >= 540 &&
                MediaQuery.orientationOf(context) == Orientation.landscape;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1040 : 680),
                child: wide
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: (box.maxWidth * .32).clamp(180, 280),
                              child: SingleChildScrollView(
                                key: const PageStorageKey('inbox-summary'),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _overview(inboxAsync, wide: true),
                                    const SizedBox(height: 20),
                                    _RetentionPolicyBar(
                                      retentionDaysAsync: retentionDaysAsync,
                                      compact: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            VerticalDivider(
                              width: 1,
                              color: ExperienceFormStyle.line(context),
                            ),
                            const SizedBox(width: 20),
                            Expanded(child: _inbox(inboxAsync)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: _overview(inboxAsync, wide: false),
                          ),
                          Expanded(child: _inbox(inboxAsync)),
                          _RetentionPolicyBar(
                            retentionDaysAsync: retentionDaysAsync,
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _webInbox(
    AsyncValue<List<AppNotificationItem>> inbox,
    AsyncValue<int> retentionDays,
  ) {
    final items = inbox.asData?.value;
    final unread = items?.where((item) => !item.isRead).length;
    return CustomerWebPage(
      title: '알림함',
      eyebrow: 'NOTIFICATIONS',
      description: '앨범의 새 소식과 주문 진행 안내를 확인하세요.',
      actions: [
        OutlinedButton.icon(
          key: const ValueKey('inbox-refresh'),
          onPressed:
              _refreshing || _markingAll || _openingSettings || inbox.isLoading
              ? null
              : _refreshInbox,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('새로고침'),
        ),
      ],
      sidebar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerWebNote(
            title: '새로운 소식',
            message: inbox.hasError
                ? '알림을 다시 불러와주세요.'
                : unread == null
                ? '알림을 확인하고 있습니다.'
                : '읽지 않은 알림 $unread개',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items != null)
                  Text(
                    '전체 ${items.length}개',
                    style: TextStyle(
                      fontSize: 13,
                      color: WebPalette.of(context).muted,
                    ),
                  ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  key: const ValueKey('inbox-settings'),
                  onPressed: _openingSettings ? null : _openSettings,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('알림 설정'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _RetentionPolicyBar(retentionDaysAsync: retentionDays, compact: true),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _overview(inbox, wide: false),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(child: _inbox(inbox)),
        ],
      ),
    );
  }

  Widget _overview(
    AsyncValue<List<AppNotificationItem>> inbox, {
    required bool wide,
  }) {
    final title = Text(
      '새로운 소식',
      style: ExperienceFormStyle.text(
        context,
        wide ? 20 : 24,
        weight: FontWeight.w700,
      ),
    );
    final enabled =
        !_markingAll &&
        !_refreshing &&
        !_openingSettings &&
        !inbox.isLoading &&
        !inbox.hasError &&
        (inbox.asData?.value.any((item) => !item.isRead) ?? false);
    final action = TextButton.icon(
      key: const ValueKey('inbox-mark-all'),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: ExperienceFormStyle.ink(context),
        textStyle: ExperienceFormStyle.text(context, 14),
      ),
      onPressed: enabled ? _markAllRead : null,
      icon: _markingAll
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : ExperienceIcon(
              'Check',
              size: 18,
              color: enabled
                  ? ExperienceFormStyle.ink(context)
                  : Theme.of(context).disabledColor,
            ),
      label: Text(_markingAll ? '읽음 처리 중' : '모두 읽음'),
    );
    return wide
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), action],
          )
        : Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [title, action],
          );
  }

  AsyncValue<List<AppNotificationItem>> _visibleInbox(
    AsyncValue<List<AppNotificationItem>> inbox,
  ) {
    // Keep only the items visible when this manual refresh began. Dependency
    // reloads clear them even if Riverpod reuses an unfinished future.
    if (_retainedItems != null &&
        identical(
          _manualRefresh,
          ref.watch(notificationInboxProvider.future),
        ) &&
        (inbox.isLoading || inbox.hasError)) {
      return AsyncData(_retainedItems!);
    }
    return inbox;
  }

  Widget _inbox(
    AsyncValue<List<AppNotificationItem>> inbox,
  ) => _visibleInbox(inbox).when(
    skipLoadingOnRefresh: !_refreshing,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, __) => Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '알림을 불러오지 못했어요.',
              style: ExperienceFormStyle.text(context, 14, secondary: true),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('inbox-retry'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: ExperienceFormStyle.ink(context),
                side: BorderSide(color: ExperienceFormStyle.line(context)),
                textStyle: ExperienceFormStyle.text(context, 14),
                shape: const StadiumBorder(),
              ),
              onPressed:
                  _refreshing ||
                      _markingAll ||
                      _openingSettings ||
                      inbox.isLoading
                  ? null
                  : _refreshInbox,
              icon: const ExperienceIcon('RefreshCw', size: 18),
              label: const Text('다시 불러오기'),
            ),
          ],
        ),
      ),
    ),
    data: (items) {
      if (items.isEmpty) {
        return Center(
          child: Text(
            '알림이 없습니다.',
            style: ExperienceFormStyle.text(context, 14, secondary: true),
          ),
        );
      }
      final entries = <(String?, AppNotificationItem?)>[
        for (final section in _groupByDay(items)) ...[
          (section.$1, null),
          for (final item in section.$2) (null, item),
        ],
      ];
      return ListView.builder(
        key: const PageStorageKey('inbox-list'),
        padding: kIsWeb
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(16, 10, 16, 16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final (label, item) = entries[index];
          if (item == null) {
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                label!,
                style: ExperienceFormStyle.text(
                  context,
                  13,
                  weight: FontWeight.w600,
                  secondary: true,
                ),
              ),
            );
          }
          return _NotificationCard(
            key: ValueKey('inbox-item-${item.id}'),
            item: item,
            onTap: () async {
              if (kIsWeb && !_webOwnerCurrent) return;
              try {
                // The shared tap handler saves the read state independently.
                // A slow or failed read receipt must not block the destination.
                await FcmNotificationService.openNotification({
                  ...item.data,
                  'type': item.type,
                  'notificationId': item.id.toString(),
                  'userId': item.userId,
                  'deeplink': item.deeplink,
                });
              } catch (_) {
                if (!context.mounted || (kIsWeb && !_webOwnerCurrent)) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('알림을 열지 못했어요. 다시 시도해주세요.')),
                );
              }
            },
          );
        },
      );
    },
  );

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
  const _RetentionPolicyBar({
    required this.retentionDaysAsync,
    this.compact = false,
  });

  final AsyncValue<int> retentionDaysAsync;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final days = retentionDaysAsync.maybeWhen(
      data: (value) => value,
      orElse: () => 90,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: ExperienceFormStyle.surface(context),
        border: Border(
          top: BorderSide(
            color: SnapFitColors.overlayLightOf(context),
            width: 1,
          ),
        ),
      ),
      child: Text(
        '알림은 실서비스 운영 기준에 맞춰 $days일 보관 후 자동 삭제됩니다.',
        textAlign: compact ? TextAlign.left : TextAlign.center,
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({super.key, required this.item, required this.onTap});

  final AppNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    value: item.isRead ? '읽음' : '읽지 않음',
    child: kIsWeb ? _webRow(context) : _nativeRow(context),
  );

  Widget _nativeRow(BuildContext context) {
    final isRead = item.isRead;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ExperienceFormStyle.line(context)),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        leading: Badge(
          isLabelVisible: !isRead,
          smallSize: 5,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ExperienceFormStyle.surface(context),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              item.type == 'album_invite'
                  ? Icons.people_outline
                  : item.type == 'order_status'
                  ? Icons.inventory_2_outlined
                  : Icons.notifications_none,
              size: 19,
              color: ExperienceFormStyle.ink(context),
            ),
          ),
        ),
        title: Text(
          item.title,
          style: ExperienceFormStyle.text(
            context,
            14,
            weight: isRead ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.body,
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
            Text(
              '${_typeLabel(item.type)} · ${_formatDateTime(item.createdAt)}',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _webRow(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 700;
      final date =
          '${_typeLabel(item.type)} · ${_formatDateTime(item.createdAt)}';
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SnapFitRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: WebPalette.of(context).line),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: WebPalette.of(context).softBrand,
                    borderRadius: BorderRadius.circular(SnapFitRadius.md),
                  ),
                  child: Badge(
                    isLabelVisible: !item.isRead,
                    smallSize: 6,
                    alignment: Alignment.topRight,
                    child: Center(
                      child: Icon(
                        item.type == 'album_invite'
                            ? Icons.people_outline
                            : item.type == 'order_status'
                            ? Icons.inventory_2_outlined
                            : Icons.notifications_none,
                        size: 20,
                        color: WebPalette.of(context).brandInk,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: item.isRead
                              ? FontWeight.w400
                              : FontWeight.w600,
                          color: WebPalette.of(context).ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.body,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: WebPalette.of(context).muted,
                        ),
                      ),
                      if (!wide) ...[
                        const SizedBox(height: 12),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 12,
                            color: WebPalette.of(context).muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (wide) ...[
                  const SizedBox(width: 28),
                  SizedBox(
                    width: 176,
                    child: Text(
                      date,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.8,
                        color: WebPalette.of(context).muted,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 20),
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: WebPalette.of(context).muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

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

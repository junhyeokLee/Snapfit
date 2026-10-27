import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/album/data/bundled_creation_templates.dart';
import '../notifications/fcm_notification_service.dart';
import '../utils/app_logger.dart';

class TemplateUpdateNotificationService {
  TemplateUpdateNotificationService._();

  static const String _seenPublishedIds = 'seen_published_template_ids_v1';
  static Future<void>? _pendingCheck;

  static Future<void> checkAndNotifyIfUpdated() => _pendingCheck ??=
      _checkPublishedCatalog().whenComplete(() => _pendingCheck = null);

  static Future<void> _checkPublishedCatalog() async {
    try {
      await checkCatalogForUpdates(
        currentIds: publishedCreationTemplates.map((template) => template.id),
        preferences: await SharedPreferences.getInstance(),
        readSettings: FcmNotificationService.loadSettings,
        notify: (count) => FcmNotificationService.showLocalNotification(
          title: '새 템플릿 업데이트',
          body: '신규 템플릿 ${count}개가 추가되었어요. 지금 확인해보세요.',
          data: const {'type': 'template_update'},
        ),
      );
    } catch (e) {
      AppLogger.debug('[TemplateUpdate] skip notification: $e');
    }
  }

  /// The first published catalog is a silent baseline, including migration from
  /// the retired generated catalog. Artwork changes and removals are not new
  /// templates. Disabled notifications are not queued for a later opt-in.
  @visibleForTesting
  static Future<void> checkCatalogForUpdates({
    required Iterable<int> currentIds,
    required SharedPreferences preferences,
    required Future<NotificationSettingsState> Function() readSettings,
    required Future<void> Function(int count) notify,
  }) async {
    final current = currentIds.map((id) => id.toString()).toSet().toList()
      ..sort();
    if (current.isEmpty) return;
    final seen = preferences.getStringList(_seenPublishedIds);
    Future<void> remember() async {
      await preferences.setStringList(_seenPublishedIds, current);
    }

    if (seen == null) {
      await remember();
      return;
    }
    final seenSet = seen.toSet();
    final added = current.where((id) => !seenSet.contains(id)).toList();
    if (added.isEmpty) {
      if (!setEquals(seenSet, current.toSet())) await remember();
      return;
    }
    final settings = await readSettings();
    if (!settings.permissionGranted || !settings.all || !settings.newTemplate) {
      await remember();
      return;
    }
    await notify(added.length);
    await remember();
    AppLogger.debug('[TemplateUpdate] notified count=${added.length}');
  }
}

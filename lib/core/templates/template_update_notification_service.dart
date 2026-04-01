import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/fcm_notification_service.dart';
import '../utils/app_logger.dart';

class TemplateUpdateNotificationService {
  TemplateUpdateNotificationService._();

  static const String _kSeenGeneratedTemplateIds =
      'seen_generated_template_ids';
  static const String _kLastTemplateBatchToken = 'last_template_batch_token';

  static Future<void> checkAndNotifyIfUpdated() async {
    try {
      final settings = await FcmNotificationService.loadSettings();
      if (!settings.permissionGranted) return;
      if (!settings.all || !settings.newTemplate) return;

      final raw = await rootBundle.loadString(
        'assets/templates/generated/latest.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final currentIds = decoded
          .whereType<Map>()
          .map((e) => e['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      if (currentIds.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(_kSeenGeneratedTemplateIds) ?? const [];
      final seenSet = seen.toSet();
      final newlyAdded = currentIds
          .where((id) => !seenSet.contains(id))
          .toList();
      final currentBatchToken = await _readCurrentBatchToken();
      final lastBatchToken = prefs.getString(_kLastTemplateBatchToken) ?? '';
      final batchUpdated =
          currentBatchToken.isNotEmpty && currentBatchToken != lastBatchToken;
      if (newlyAdded.isEmpty && !batchUpdated) return;

      final count = newlyAdded.isNotEmpty
          ? newlyAdded.length
          : currentIds.length;

      await FcmNotificationService.showLocalNotification(
        title: '새 템플릿 업데이트',
        body: '신규 템플릿 ${count}개가 추가되었어요. 지금 확인해보세요.',
        data: const {'type': 'template_update'},
      );

      await prefs.setStringList(
        _kSeenGeneratedTemplateIds,
        currentIds.toList(),
      );
      if (currentBatchToken.isNotEmpty) {
        await prefs.setString(_kLastTemplateBatchToken, currentBatchToken);
      }
      AppLogger.debug(
        '[TemplateUpdate] notified count=$count ids=${newlyAdded.join(',')} batch=$currentBatchToken',
      );
    } catch (e) {
      AppLogger.debug('[TemplateUpdate] skip notification: $e');
    }
  }

  static Future<String> _readCurrentBatchToken() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/templates/generated/template_factory_registry.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return (decoded['generatedAt'] ?? '').toString();
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}

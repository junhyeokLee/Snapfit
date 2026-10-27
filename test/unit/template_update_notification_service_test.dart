import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:snap_fit/core/templates/template_update_notification_service.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';

const _seenKey = 'seen_published_template_ids_v1';
const _enabled = NotificationSettingsState(
  all: true,
  order: true,
  invite: true,
  comment: true,
  marketing: false,
  newTemplate: true,
  nightMute: true,
  permissionGranted: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'first published catalog silently replaces the retired notification baseline',
    () async {
      SharedPreferences.setMockInitialValues({
        'seen_generated_template_ids': ['figma_import_1775063050456'],
        'last_template_batch_token': 'retired-factory-batch',
      });
      final prefs = await SharedPreferences.getInstance();
      var settingsReads = 0;
      final notified = <int>[];
      await TemplateUpdateNotificationService.checkCatalogForUpdates(
        currentIds: publishedCreationTemplates.map((template) => template.id),
        preferences: prefs,
        readSettings: () async {
          settingsReads++;
          return _enabled;
        },
        notify: (count) async => notified.add(count),
      );
      expect(
        prefs.getStringList(_seenKey),
        hasLength(publishedCreationTemplates.length),
      );
      expect(prefs.getStringList(_seenKey)!.toSet(), {
        for (final template in publishedCreationTemplates) '${template.id}',
      });
      expect(settingsReads, 0);
      expect(notified, isEmpty);
    },
  );

  test(
    'only new published identities notify once, independent of order and duplicates',
    () async {
      SharedPreferences.setMockInitialValues({
        _seenKey: ['-1', '-2'],
      });
      final prefs = await SharedPreferences.getInstance();
      final notified = <int>[];
      for (final ids in [
        [-2, -1],
        [-3, -2, -1, -3],
        [-1, -3, -2],
      ]) {
        await TemplateUpdateNotificationService.checkCatalogForUpdates(
          currentIds: ids,
          preferences: prefs,
          readSettings: () async => _enabled,
          notify: (count) async => notified.add(count),
        );
      }
      expect(notified, [1]);
      expect(prefs.getStringList(_seenKey)!.toSet(), {'-1', '-2', '-3'});
    },
  );

  test(
    'removal updates the baseline without an update notification or settings read',
    () async {
      SharedPreferences.setMockInitialValues({
        _seenKey: ['-1', '-2'],
      });
      final prefs = await SharedPreferences.getInstance();
      await TemplateUpdateNotificationService.checkCatalogForUpdates(
        currentIds: [-2],
        preferences: prefs,
        readSettings: () async => throw StateError('not required for removals'),
        notify: (_) async => fail('a removal is not a new template'),
      );
      expect(prefs.getStringList(_seenKey), ['-2']);
    },
  );

  for (final disabled in ['permission', 'all', 'newTemplate']) {
    test(
      'disabled $disabled notifications are not queued for a later opt-in',
      () async {
        SharedPreferences.setMockInitialValues({
          _seenKey: ['-1'],
        });
        final prefs = await SharedPreferences.getInstance();
        final notified = <int>[];
        await TemplateUpdateNotificationService.checkCatalogForUpdates(
          currentIds: [-1, -2],
          preferences: prefs,
          readSettings: () async => NotificationSettingsState(
            all: disabled != 'all',
            order: true,
            invite: true,
            comment: true,
            marketing: false,
            newTemplate: disabled != 'newTemplate',
            nightMute: true,
            permissionGranted: disabled != 'permission',
          ),
          notify: (count) async => notified.add(count),
        );
        await TemplateUpdateNotificationService.checkCatalogForUpdates(
          currentIds: [-1, -2],
          preferences: prefs,
          readSettings: () async => _enabled,
          notify: (count) async => notified.add(count),
        );
        expect(notified, isEmpty);
        expect(prefs.getStringList(_seenKey)!.toSet(), {'-1', '-2'});
      },
    );
  }

  test('a failed notification does not acknowledge unseen templates', () async {
    SharedPreferences.setMockInitialValues({
      _seenKey: ['-1'],
    });
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
      TemplateUpdateNotificationService.checkCatalogForUpdates(
        currentIds: [-1, -2],
        preferences: prefs,
        readSettings: () async => _enabled,
        notify: (_) async => throw StateError('notification unavailable'),
      ),
      throwsStateError,
    );
    expect(prefs.getStringList(_seenKey), ['-1']);
  });

  test('an empty catalog never erases the last known baseline', () async {
    SharedPreferences.setMockInitialValues({
      _seenKey: ['-1'],
    });
    final prefs = await SharedPreferences.getInstance();
    await TemplateUpdateNotificationService.checkCatalogForUpdates(
      currentIds: [],
      preferences: prefs,
      readSettings: () async => throw StateError('empty catalog'),
      notify: (_) async => fail('empty catalog'),
    );
    expect(prefs.getStringList(_seenKey), ['-1']);
  });
}

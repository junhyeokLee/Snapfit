import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/notifications/browser_push_state.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/profile/presentation/views/notification_settings_screen.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

NotificationSettingsState _settings({
  bool all = true,
  bool permission = false,
}) => NotificationSettingsState(
  all: all,
  order: true,
  invite: true,
  comment: false,
  marketing: false,
  newTemplate: true,
  nightMute: true,
  permissionGranted: permission,
);

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  setUpAll(() async {
    if (!kIsWeb) await loadCreationFonts();
  });

  Future<void> mount(
    WidgetTester tester, {
    required NotificationSettingsState settings,
    Size size = const Size(390, 844),
    bool dark = false,
    double scale = 1,
    BrowserPushState? browser,
    void Function(String, bool)? onToggle,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: boundary, child: child!),
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('알림 설정')),
          body: Padding(
            padding: kIsWeb ? const EdgeInsets.all(20) : EdgeInsets.zero,
            child: NotificationSettingsContent(
              settings: settings,
              browserPush: browser,
              onToggle: onToggle ?? (_, __) {},
              onRequestPermission: () {},
              onEnableBrowser: () {},
              onDisableBrowser: () {},
              onRefreshBrowser: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    if (kIsWeb || !const bool.fromEnvironment('NOTIFICATION_STATES_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('output/all-screens-qa')
        ..createSync(recursive: true);
      File(
        '${dir.path}/notification-state-$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final dark in [false, true]) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      testWidgets(
        'denied permission is distinct from account opt-in at $size dark=$dark',
        (tester) async {
          await mount(
            tester,
            settings: _settings(),
            size: size,
            dark: dark,
            scale: 1.8,
          );
          expect(find.text('기기 알림이 꺼져 있어요'), findsOneWidget);
          expect(find.text('선택한 소식을 받아요'), findsNothing);
          final action = find.byKey(
            const ValueKey('notification-permission-action'),
          );
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          expect(tester.widget<OutlinedButton>(action).onPressed, isNotNull);
          expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
          await capture(
            tester,
            'permission-denied-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
        },
        skip: kIsWeb,
      );
    }
  }

  testWidgets(
    'turning all off preserves category values and disables their controls',
    (tester) async {
      final changes = <String, bool>{};
      await mount(
        tester,
        settings: _settings(all: false, permission: true),
        onToggle: (key, value) => changes[key] = value,
      );
      expect(find.text('알림 수신을 멈췄어요 · 개별 설정은 보관돼요'), findsOneWidget);
      final category = find.byKey(
        ValueKey('notification-setting-${FcmNotificationService.kInvite}'),
      );
      await tester.ensureVisible(category);
      final categorySwitch = tester.widget<Switch>(
        find.descendant(of: category, matching: find.byType(Switch)),
      );
      expect(categorySwitch.value, true);
      expect(categorySwitch.onChanged, isNull);
      expect(changes, isEmpty);
      await capture(tester, 'all-off');
    },
  );

  for (final scenario in ['denied', 'unregistered', 'all-off']) {
    testWidgets('browser $scenario does not falsely promise active delivery', (
      tester,
    ) async {
      await mount(
        tester,
        settings: _settings(all: scenario != 'all-off', permission: true),
        browser: BrowserPushState(
          environment: BrowserPushEnvironment(
            supported: true,
            configured: true,
            permission: scenario == 'denied' ? 'denied' : 'granted',
            message: '브라우저 설정에서 알림 권한을 확인할 수 있어요.',
          ),
          enabled: true,
          registered: scenario == 'all-off',
        ),
      );
      expect(find.text('현재 계정에 연결되어 있어요'), findsNothing);
      expect(
        find.text(switch (scenario) {
          'denied' => '브라우저 알림 권한이 차단됐어요',
          'unregistered' => '연결이 완료되지 않았어요',
          _ => '브라우저 연결됨 · 전체 알림은 꺼져 있어요',
        }),
        findsOneWidget,
      );
      expect(find.text('브라우저 알림 켜기'), findsNothing);
      if (scenario == 'unregistered') {
        expect(find.text('브라우저 다시 연결'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }, skip: !kIsWeb);
  }
}

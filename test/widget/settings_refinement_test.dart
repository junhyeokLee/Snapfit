import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_unavailable_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/notification_settings_screen.dart';
import 'package:snap_fit/features/profile/presentation/widgets/theme_settings_sheet.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'experience_detail_redesign_test.dart' show reviewApp;

NotificationSettingsState _settings({bool all = true}) =>
    NotificationSettingsState(
      all: all,
      order: true,
      invite: true,
      comment: true,
      marketing: false,
      newTemplate: true,
      nightMute: true,
      permissionGranted: false,
    );

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('SETTINGS_QA')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('output/settings-template-qa')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadCreationFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      final id = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
      testWidgets('notification preferences and system insets $id', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final changes = <String, bool>{};
        var permissionCalls = 0;
        var settings = _settings();
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(size.width == 320 ? 1.3 : 1),
                padding: size.width > size.height
                    ? const EdgeInsets.only(right: 48, bottom: 24)
                    : const EdgeInsets.only(bottom: 34),
              ),
              child: RepaintBoundary(
                key: key,
                child: Scaffold(
                  appBar: const ExperienceHeader(
                    title: '알림 설정',
                    themeAware: true,
                  ),
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      rebuild = setState;
                      return NotificationSettingsContent(
                        settings: settings,
                        onToggle: (key, value) => changes[key] = value,
                        onRequestPermission: () => permissionCalls++,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, key, 'notifications-$id');
        await tester.tap(find.text('기기 알림 설정'));
        expect(permissionCalls, 1);
        final master = find.byType(Switch).first;
        await tester.ensureVisible(master);
        await tester.tap(master);
        expect(changes[FcmNotificationService.kAll], false);
        rebuild(() => settings = _settings(all: false));
        await tester.pumpAndSettle();
        final switches = tester
            .widgetList<Switch>(find.byType(Switch))
            .toList();
        expect(switches.length, greaterThan(1));
        expect(switches.first.onChanged, isNotNull);
        expect(switches.skip(1).every((s) => s.onChanged == null), true);
        expect(switches[1].value, true);
        for (final title in [
          '앨범 초대와 참여',
          '새 댓글',
          '구매와 주문 소식',
          '새로운 컬렉션',
          '혜택과 이벤트',
          '야간 알림 끄기',
        ]) {
          await tester.scrollUntilVisible(
            find.text(title),
            160,
            scrollable: find
                .descendant(
                  of: find.byKey(
                    const PageStorageKey('notification-preferences'),
                  ),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          final row = find
              .ancestor(of: find.text(title), matching: find.byType(Row))
              .first;
          expect(
            tester
                .widget<Switch>(
                  find.descendant(of: row, matching: find.byType(Switch)),
                )
                .onChanged,
            isNull,
          );
        }
        await tester.scrollUntilVisible(
          find.text('야간 알림 끄기'),
          220,
          scrollable: find
              .descendant(
                of: find.byKey(
                  const PageStorageKey('notification-preferences'),
                ),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await _capture(tester, key, 'notifications-bottom-$id');
        expect(
          tester.getBottomRight(find.text('야간 알림 끄기')).dy,
          lessThan(size.height - 24),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('theme selection remains readable $id', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ThemeMode? selected;
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(1.3),
                padding: const EdgeInsets.only(bottom: 34),
              ),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: RepaintBoundary(
                    key: key,
                    child: Material(
                      child: SizedBox(
                        width: 520,
                        child: ThemeSettingsSheet(
                          selected: dark ? ThemeMode.dark : ThemeMode.light,
                          onSelected: (mode) => selected = mode,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, key, 'theme-$id');
        await tester.tap(find.text('다크'));
        expect(selected, ThemeMode.dark);
        await tester.tap(find.text('라이트'));
        expect(selected, ThemeMode.light);
        expect(tester.takeException(), isNull);
      });

      testWidgets('print notice does not inflate in landscape $id', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
                padding: size.width > size.height
                    ? const EdgeInsets.only(right: 48, bottom: 24)
                    : const EdgeInsets.only(bottom: 34),
              ),
              child: RepaintBoundary(
                key: key,
                child: const PrintOrderUnavailableScreen(
                  albumId: 7,
                  albumTitle: '우리가 함께 보낸 첫 번째 여름의 기록',
                  pageCount: 32,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, key, 'print-$id');
        await tester.scrollUntilVisible(find.text('기존 주문 내역 보기'), 180);
        await tester.pumpAndSettle();
        await _capture(tester, key, 'print-bottom-$id');
        await tester.scrollUntilVisible(find.text('결제 준비 중'), -160);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, '결제 준비 중'),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('visible theme entry saves selected preference', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(reviewApp(const MyPageScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('화면 테마'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('화면 테마'), findsOneWidget);
    await tester.tap(find.text('화면 테마'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다크'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeSettingsSheet), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString('theme_mode'),
      'dark',
    );
    expect(tester.takeException(), isNull);
  });
}

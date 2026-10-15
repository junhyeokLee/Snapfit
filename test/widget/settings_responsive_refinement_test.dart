import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/account_settings_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/notification_settings_screen.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'login_screen_test.dart' show FakeAuthViewModel;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const _user = UserInfo(
  id: 'settings-review',
  name: '스냅핏 사용자',
  email: 'snapfit@example.com',
  provider: 'EMAIL',
);

class _Auth extends AuthViewModel {
  _Auth({this.user = _user});
  final UserInfo user;
  int deletes = 0, logouts = 0;
  final resetEmails = <String>[];
  Future<void>? pendingDelete;
  @override
  FutureOr<UserInfo?> build() => user;
  void switchAccount() => state = AsyncData(user.copyWith(id: 'other-account'));
  @override
  Future<void> deleteAccount() async {
    deletes++;
    await pendingDelete;
  }

  @override
  Future<void> logout() async => logouts++;
  @override
  Future<void> requestPasswordReset(String email) async =>
      resetEmails.add(email);
}

class _NotificationHarness extends StatefulWidget {
  const _NotificationHarness({super.key});
  @override
  State<_NotificationHarness> createState() => _NotificationHarnessState();
}

class _NotificationHarnessState extends State<_NotificationHarness> {
  final values = <String, bool>{
    FcmNotificationService.kAll: true,
    FcmNotificationService.kOrder: true,
    FcmNotificationService.kInvite: true,
    FcmNotificationService.kComment: true,
    FcmNotificationService.kMarketing: false,
    FcmNotificationService.kNewTemplate: true,
    FcmNotificationService.kNightMute: false,
  };
  int permissionRequests = 0;
  bool permissionBusy = false;
  final changes = <String, bool>{};

  void setPermissionBusy(bool busy) => setState(() => permissionBusy = busy);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: const ExperienceHeader(title: '알림 설정', showNotifications: false),
    body: NotificationSettingsContent(
      settings: NotificationSettingsState(
        all: values[FcmNotificationService.kAll]!,
        order: values[FcmNotificationService.kOrder]!,
        invite: values[FcmNotificationService.kInvite]!,
        comment: values[FcmNotificationService.kComment]!,
        marketing: values[FcmNotificationService.kMarketing]!,
        newTemplate: values[FcmNotificationService.kNewTemplate]!,
        nightMute: values[FcmNotificationService.kNightMute]!,
        permissionGranted: false,
      ),
      onToggle: (key, value) => setState(() {
        values[key] = value;
        changes[key] = value;
      }),
      onRequestPermission: permissionBusy ? null : () => permissionRequests++,
    ),
  );
}

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List)
        loader.addFont(rootBundle.load(asset['asset'] as String));
      await loader.load();
    }
  });

  void metrics(WidgetTester tester, Size size, {double keyboard = 0}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = size.width > size.height
        ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
        : const FakeViewPadding(top: 24, bottom: 34);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    AuthViewModel? auth,
    bool dark = false,
    double scale = 1.3,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          if (auth != null) authViewModelProvider.overrideWith(() => auth),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder primary() => find.byKey(const ValueKey('account-sheet-primary'));
  Finder cancel() => find.byKey(const ValueKey('account-sheet-cancel'));
  Finder acknowledgement() =>
      find.byKey(const ValueKey('account-delete-acknowledgement'));
  Finder setting(String key) =>
      find.byKey(ValueKey('notification-setting-$key'));
  Finder toggle(String key) =>
      find.descendant(of: setting(key), matching: find.byType(Switch));

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark,
  ) async {
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('SETTINGS_RESPONSIVE_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('output/all-screens-qa')
        ..createSync(recursive: true);
      File(
        '${dir.path}/$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void footerSafe(WidgetTester tester, Size size) {
    for (final button in [
      primary(),
      cancel(),
      find.byKey(const ValueKey('account-sheet-close')),
    ]) {
      final rect = tester.getRect(button);
      expect(
        rect.left,
        greaterThanOrEqualTo(size.width > size.height ? 32 : 0),
      );
      expect(
        rect.right,
        lessThanOrEqualTo(size.width - (size.width > size.height ? 48 : 0)),
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(size.height - (size.width > size.height ? 24 : 34)),
      );
      expect(rect.height, greaterThanOrEqualTo(44));
    }
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'account and notification layouts stay safe at $size dark=$dark',
        (tester) async {
          reset(tester);
          metrics(tester, size);
          final auth = _Auth();
          var photoChanges = 0;
          await mount(
            tester,
            AccountSettingsScreen(
              onChangePhoto: (_, __, ___) async => photoChanges++,
            ),
            auth: auth,
            dark: dark,
          );
          await capture(tester, 'settings-account', size, dark);
          await tap(tester, find.byTooltip('프로필 사진 변경'));
          expect(photoChanges, 1);
          await tap(tester, find.text('비밀번호 재설정'));
          footerSafe(tester, size);
          await capture(tester, 'settings-account-reset', size, dark);
          await tap(tester, cancel());
          expect(auth.resetEmails, isEmpty);
          await tap(tester, find.text('회원 탈퇴'));
          expect(tester.widget<FilledButton>(primary()).onPressed, isNull);
          footerSafe(tester, size);
          await capture(tester, 'settings-account-delete', size, dark);
          await tap(tester, acknowledgement());
          expect(tester.widget<FilledButton>(primary()).onPressed, isNotNull);
          await tap(tester, cancel());
          expect(auth.deletes, 0);
          await tap(tester, find.widgetWithText(ExperienceRow, '로그아웃'));
          footerSafe(tester, size);
          await capture(tester, 'settings-account-logout', size, dark);
          await tap(tester, cancel());
          expect(auth.logouts, 0);
          await tester.pumpWidget(const SizedBox());
          final notifications = GlobalKey<_NotificationHarnessState>();
          await mount(
            tester,
            _NotificationHarness(key: notifications),
            dark: dark,
          );
          await capture(tester, 'settings-notifications', size, dark);
          await tap(
            tester,
            find.byKey(const ValueKey('notification-permission-action')),
          );
          expect(notifications.currentState!.permissionRequests, 1);
          await tap(tester, toggle(FcmNotificationService.kAll));
          expect(
            notifications.currentState!.values[FcmNotificationService.kInvite],
            isTrue,
          );
          expect(
            tester
                .widget<Switch>(toggle(FcmNotificationService.kInvite))
                .onChanged,
            isNull,
          );
          await capture(tester, 'settings-notifications-off', size, dark);
          await tap(tester, toggle(FcmNotificationService.kAll));
          await tap(tester, toggle(FcmNotificationService.kNightMute));
          final night = tester.getRect(
            toggle(FcmNotificationService.kNightMute),
          );
          expect(
            night.bottom,
            lessThanOrEqualTo(
              size.height - (size.width > size.height ? 24 : 34),
            ),
          );
          await capture(tester, 'settings-notifications-bottom', size, dark);
          expect(
            notifications.currentState!.changes[FcmNotificationService
                .kNightMute],
            isTrue,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets(
      'long account identity and large text do not hide sheet actions at $size',
      (tester) async {
        reset(tester);
        metrics(tester, size);
        final auth = _Auth(
          user: _user.copyWith(
            name: '아주 긴 이름의 스냅핏 사용자',
            email: 'snapfit.long.account.identity@example.com',
          ),
        );
        await mount(
          tester,
          const AccountSettingsScreen(),
          auth: auth,
          dark: true,
          scale: 1.8,
        );
        await tap(tester, find.text('회원 탈퇴'));
        footerSafe(tester, size);
        await tap(tester, acknowledgement());
        expect(tester.widget<FilledButton>(primary()).onPressed, isNotNull);
        await tap(tester, cancel());
        await tap(tester, find.text('비밀번호 재설정'));
        footerSafe(tester, size);
        await tap(tester, cancel());
        expect(auth.resetEmails, isEmpty);
        expect(auth.deletes, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'delete acknowledgement survives rotation and queued confirm rechecks the latest choice',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final auth = _Auth();
      await mount(tester, const AccountSettingsScreen(), auth: auth);
      await tap(tester, find.text('회원 탈퇴'));
      await tap(tester, acknowledgement());
      metrics(tester, const Size(648, 320));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(acknowledgement()).value, isTrue);
      footerSafe(tester, const Size(648, 320));
      final queued = tester.widget<FilledButton>(primary()).onPressed!;
      tester.widget<CheckboxListTile>(acknowledgement()).onChanged!(false);
      queued();
      await tester.pumpAndSettle();
      expect(auth.deletes, 0);
      expect(primary(), findsOneWidget);
      expect(tester.widget<FilledButton>(primary()).onPressed, isNull);
      await tap(tester, cancel());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dismissed or already-confirmed account sheet cannot pop the account route twice',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final auth = _Auth();
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              ),
              child: const Text('계정 열기'),
            ),
          ),
        ),
        auth: auth,
      );
      await tap(tester, find.text('계정 열기'));
      await tap(tester, find.text('회원 탈퇴'));
      await tap(tester, acknowledgement());
      final queued = tester.widget<FilledButton>(primary()).onPressed!;
      Navigator.of(tester.element(primary())).pop(false);
      queued();
      await tester.pumpAndSettle();
      queued();
      expect(find.byType(AccountSettingsScreen), findsOneWidget);
      expect(auth.deletes, 0);
      final pending = Completer<void>();
      auth.pendingDelete = pending.future;
      await tap(tester, find.text('회원 탈퇴'));
      await tap(tester, acknowledgement());
      final confirm = tester.widget<FilledButton>(primary()).onPressed!;
      confirm();
      confirm();
      await tester.pump(const Duration(milliseconds: 400));
      expect(auth.deletes, 1);
      expect(find.byType(AccountSettingsScreen), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AccountSettingsScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reset confirmation still blocks account changes and only sends the displayed identity',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(648, 320));
      final auth = _Auth();
      await mount(tester, const AccountSettingsScreen(), auth: auth);
      await tap(tester, find.text('비밀번호 재설정'));
      auth.switchAccount();
      await tester.pumpAndSettle();
      await tap(tester, primary());
      expect(auth.resetEmails, isEmpty);
      expect(find.textContaining('로그인 계정이 변경'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'individual notification values and disabled permission action survive rotation',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final key = GlobalKey<_NotificationHarnessState>();
      await mount(
        tester,
        _NotificationHarness(key: key),
        dark: true,
        scale: 1.8,
      );
      await tap(tester, toggle(FcmNotificationService.kMarketing));
      await tap(tester, toggle(FcmNotificationService.kAll));
      metrics(tester, const Size(648, 320));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Switch>(toggle(FcmNotificationService.kMarketing)).value,
        isTrue,
      );
      expect(
        tester
            .widget<Switch>(toggle(FcmNotificationService.kMarketing))
            .onChanged,
        isNull,
      );
      key.currentState!.setPermissionBusy(true);
      await tester.pumpAndSettle();
      final permission = find.byKey(
        const ValueKey('notification-permission-action'),
      );
      expect(tester.widget<OutlinedButton>(permission).onPressed, isNull);
      await tap(tester, toggle(FcmNotificationService.kAll));
      expect(
        tester
            .widget<Switch>(toggle(FcmNotificationService.kMarketing))
            .onChanged,
        isNotNull,
      );
      await tap(tester, toggle(FcmNotificationService.kNightMute));
      expect(
        key.currentState!.values[FcmNotificationService.kNightMute],
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets(
      'password recovery remains editable with keyboard and rotation at $size',
      (tester) async {
        reset(tester);
        metrics(tester, size, keyboard: 140);
        final auth = FakeAuthViewModel();
        await mount(
          tester,
          const LoginScreen(startInPasswordReset: true),
          auth: auth,
          dark: true,
          scale: 1.5,
        );
        final password = find.widgetWithText(TextFormField, '8자 이상, 영문+숫자');
        final confirmation = find.widgetWithText(TextFormField, '한 번 더 입력');
        await tester.ensureVisible(password);
        await tester.enterText(password, 'Album2026');
        await tester.ensureVisible(confirmation);
        await tester.enterText(confirmation, 'Album2026');
        metrics(
          tester,
          size.width > size.height
              ? const Size(390, 844)
              : const Size(648, 320),
          keyboard: 140,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextFormField>(password).controller!.text,
          'Album2026',
        );
        expect(
          tester.widget<TextFormField>(confirmation).controller!.text,
          'Album2026',
        );
        await tap(tester, find.widgetWithText(ElevatedButton, '비밀번호 변경하기'));
        expect(auth.passwordUpdated, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

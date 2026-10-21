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
import 'package:snap_fit/core/supabase/supabase_provider.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/domain/account_deletion_request.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/account_settings_screen.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'login_screen_test.dart' show FakeAuthViewModel, FakeTokenStorage;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const _user = UserInfo(
  id: 'account-access-review',
  name: '우리 가족의 사진과 여행을 오래 간직하는 지현',
  email: 'jihyun.family.album.records@example.com',
  provider: 'EMAIL',
);
const _guidance = '앨범을 만들 때 사용한 방법으로 로그인해 주세요.';

class _Auth extends FakeAuthViewModel {
  _Auth({super.user});
  final resetEmails = <String>[];
  int logouts = 0, deletionRequests = 0;
  Future<void>? pendingDeletion;

  @override
  Future<void> syncConsentIfPresent() async {}

  @override
  Future<void> requestPasswordReset(String email) async {
    resetEmails.add(email);
  }

  @override
  Future<void> logout() async => logouts++;

  @override
  Future<AccountDeletionRequest> requestAccountDeletion() async {
    deletionRequests++;
    await pendingDeletion;
    return const AccountDeletionRequest(
      reference: 'DEL-AUTH-QA',
      alreadyRequested: false,
    );
  }
}

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  final results = <AccountSettingsResult?>[];
  var photoChanges = 0;

  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await loadCreationFonts();
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  setUp(() {
    results.clear();
    photoChanges = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Finder key(String name) => find.byKey(ValueKey(name));
  Finder field(String label) => key('auth-field-$label');
  Finder input(String label) =>
      find.descendant(of: field(label), matching: find.byType(EditableText));
  Finder email() => find.widgetWithText(SelectableText, _user.email!);

  void metrics(WidgetTester tester, Size size, {double keyboard = 0}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = size.width > size.height
        ? FakeViewPadding(left: 32, right: 48, bottom: keyboard > 0 ? 0 : 24)
        : FakeViewPadding(top: 24, bottom: keyboard > 0 ? 0 : 34);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> tap(
    WidgetTester tester,
    Finder finder, {
    bool settle = true,
  }) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(field(label));
    await tester.pumpAndSettle();
    await tester.enterText(field(label), value);
    await tester.pumpAndSettle();
  }

  void safe(
    WidgetTester tester,
    Finder finder,
    Size size, {
    double keyboard = 0,
  }) {
    final rect = tester.getRect(finder);
    final wide = size.width > size.height;
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(wide ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (wide ? 48 : 0)));
    expect(rect.top, greaterThanOrEqualTo(wide ? 0 : 24));
    expect(
      rect.bottom,
      lessThanOrEqualTo(
        size.height - (keyboard > 0 ? keyboard : (wide ? 24 : 34)) + 1,
      ),
    );
    expect(finder.hitTestable(), findsOneWidget);
  }

  Future<void> mount(
    WidgetTester tester,
    _Auth auth, {
    bool account = false,
    bool dark = false,
    double scale = 1.3,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          authViewModelProvider.overrideWith(() => auth),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          authServiceProvider.overrideWith(
            (_) => throw StateError(
              'Real authentication is forbidden in design QA.',
            ),
          ),
          supabaseClientProvider.overrideWith(
            (_) =>
                throw StateError('Backend access is forbidden in design QA.'),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: account
                ? Scaffold(
                    key: const ValueKey('auth-account-origin'),
                    body: Builder(
                      builder: (context) => Center(
                        child: FilledButton(
                          onPressed: () async {
                            results.add(
                              await Navigator.push<AccountSettingsResult>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AccountSettingsScreen(
                                    onChangePhoto: (_, __, ___) async =>
                                        photoChanges++,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: const Text('계정 열기'),
                        ),
                      ),
                    ),
                  )
                : const LoginScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (account) await tap(tester, find.text('계정 열기'));
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark,
  ) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('AUTH_ACCOUNT_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'output/all-screens-qa/auth-account-$name-'
        '${size.width.toInt()}-${dark ? 'dark' : 'light'}'
        '${const String.fromEnvironment('DESIGN_SYSTEM_REVISION')}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void profile(WidgetTester tester) {
    final name = tester.widget<SelectableText>(key('accountProfileName'));
    expect(name.data, _user.name);
    expect(name.maxLines, isNull);
    expect(name.enableInteractiveSelection, true);
    expect(tester.widget<SelectableText>(email()).data, _user.email);
    expect(find.text('로그인 방식'), findsOneWidget);
    final provider = find
        .ancestor(of: find.text('로그인 방식'), matching: find.byType(Column))
        .first;
    expect(
      find.descendant(of: provider, matching: find.text('이메일')),
      findsOneWidget,
    );
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'native login guidance and complete account identity $size dark=$dark',
        (tester) async {
          reset(tester);
          metrics(tester, size);
          final auth = _Auth();
          await mount(tester, auth, dark: dark);
          expect(key('auth-login-guidance'), findsOneWidget);
          expect(find.text(_guidance), findsOneWidget);
          final welcomeCapture =
              (size.width == 390 && !dark) || (size.width == 844 && dark);
          final emailCapture =
              (size.width == 320 && !dark) || (size.width == 648 && dark);
          if (welcomeCapture) await capture(tester, 'welcome', size, dark);
          await tap(tester, find.text('이메일로 로그인'));
          await enter(tester, '이메일', _user.email!);
          await enter(tester, '비밀번호', 'album1234');
          await tester.ensureVisible(key('auth-email-submit'));
          await tester.pumpAndSettle();
          safe(tester, key('auth-email-submit'), size);
          if (emailCapture) await capture(tester, 'email-draft', size, dark);
          await tap(tester, find.text('비밀번호를 잊으셨나요?'));
          expect(
            tester.widget<TextFormField>(field('이메일')).controller!.text,
            _user.email,
          );
          await tester.ensureVisible(key('auth-reset-submit'));
          await tester.pumpAndSettle();
          safe(tester, key('auth-reset-submit'), size);
          expect(auth.resetEmails, isEmpty);
          expect(auth.emailLoginCalled, false);
          final account = _Auth(user: _user);
          await mount(tester, account, account: true, dark: dark);
          profile(tester);
          expect(find.text('비밀번호 재설정'), findsOneWidget);
          if (!welcomeCapture && !emailCapture) {
            await capture(tester, 'profile', size, dark);
          }
          expect(account.logouts, 0);
          expect(account.deletionRequests, 0);
          expect(photoChanges, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in [const Size(320, 568), const Size(648, 320)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'large text preserves the full name keyboard and confirmation actions $size dark=$dark',
        (tester) async {
          reset(tester);
          metrics(tester, size);
          await mount(tester, _Auth(), dark: dark, scale: 1.8);
          await tap(tester, find.text('이메일로 로그인'));
          await enter(tester, '이메일', _user.email!);
          await enter(tester, '비밀번호', 'album1234');
          final focused = tester.state<EditableTextState>(input('비밀번호'));
          final keyboard = size.width > size.height ? 140.0 : 260.0;
          metrics(tester, size, keyboard: keyboard);
          await tester.pumpAndSettle();
          expect(tester.state<EditableTextState>(input('비밀번호')), same(focused));
          expect(focused.widget.focusNode.hasFocus, true);
          expect(
            tester.getRect(input('비밀번호')).bottom,
            lessThanOrEqualTo(size.height - keyboard),
          );
          await tester.ensureVisible(key('auth-email-submit'));
          await tester.pumpAndSettle();
          safe(tester, key('auth-email-submit'), size, keyboard: keyboard);
          metrics(tester, size);
          final auth = _Auth(user: _user);
          await mount(tester, auth, account: true, dark: dark, scale: 1.8);
          profile(tester);
          expect(
            tester.getRect(key('accountProfileName')).top,
            greaterThanOrEqualTo(
              tester.getRect(find.byType(ClipOval).first).bottom,
            ),
          );
          await capture(tester, 'profile-large', size, dark);
          await tester.ensureVisible(email());
          await tester.pumpAndSettle();
          expect(email().hitTestable(), findsOneWidget);
          await tap(tester, find.text('로그아웃'));
          safe(tester, key('account-sheet-close'), size);
          safe(tester, key('account-sheet-cancel'), size);
          safe(tester, key('account-sheet-primary'), size);
          final rotated = size.width > size.height
              ? const Size(320, 568)
              : const Size(648, 320);
          metrics(tester, rotated);
          await tester.pumpAndSettle();
          safe(tester, key('account-sheet-close'), rotated);
          safe(tester, key('account-sheet-cancel'), rotated);
          await tap(tester, key('account-sheet-cancel'));
          profile(tester);
          expect(auth.logouts, 0);
          expect(auth.deletionRequests, 0);
          expect(results, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'password reset confirms the current recipient and social accounts keep their own password management',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final auth = _Auth(user: _user);
      await mount(tester, auth, account: true);
      await tap(tester, find.text('비밀번호 재설정'));
      final sheet = find.byKey(
        const PageStorageKey('account-confirmation-content'),
      );
      expect(find.descendant(of: sheet, matching: email()), findsOneWidget);
      await capture(tester, 'reset-recipient', const Size(390, 844), false);
      await tap(tester, key('account-sheet-cancel'));
      expect(auth.resetEmails, isEmpty);
      await tap(tester, find.text('비밀번호 재설정'));
      await tap(tester, key('account-sheet-primary'));
      expect(auth.resetEmails, [_user.email]);
      expect(find.textContaining('재설정 메일을 보냈어요'), findsOneWidget);
      await capture(tester, 'reset-sent', const Size(390, 844), false);
      await mount(
        tester,
        _Auth(user: _user.copyWith(provider: 'KAKAO', email: null)),
        account: true,
        dark: true,
      );
      expect(find.text('이메일 미제공'), findsOneWidget);
      expect(find.text('비밀번호 재설정'), findsNothing);
      expect(find.textContaining('카카오 계정의 비밀번호는 해당 서비스'), findsOneWidget);
      expect(photoChanges, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deletion remains an acknowledged review request and preserves the visible account',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final auth = _Auth(user: _user);
      await mount(tester, auth, account: true, dark: true);
      expect(
        tester.widget<Text>(key('account-delete-guidance')).data,
        '삭제 요청을 접수하면 담당자 확인 후 처리해요. 접수 즉시 계정이나 사진이 삭제되지는 않아요.',
      );
      expect(
        tester.getRect(key('account-delete-guidance')).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('회원 탈퇴')).top),
      );
      await tap(tester, find.text('회원 탈퇴'));
      expect(
        find.textContaining('이 단계에서는 계정·앨범·사진·거래 기록을 삭제하지 않고'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(key('account-sheet-primary')).onPressed,
        isNull,
      );
      await capture(tester, 'delete-review', const Size(390, 844), true);
      await tap(tester, key('account-sheet-cancel'));
      expect(auth.deletionRequests, 0);
      await tap(tester, find.text('회원 탈퇴'));
      await tap(tester, key('account-delete-acknowledgement'));
      final pending = Completer<void>();
      auth.pendingDeletion = pending.future;
      await tap(tester, key('account-sheet-primary'), settle: false);
      expect(auth.deletionRequests, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('접수번호 DEL-AUTH-QA'), findsOneWidget);
      expect(find.textContaining('로그인도 유지됩니다'), findsOneWidget);
      expect(find.byType(AccountSettingsScreen), findsOneWidget);
      expect(
        tester.widget<SelectableText>(key('accountProfileName')).data,
        _user.name,
      );
      expect(auth.logouts, 0);
      expect(results, isEmpty);
      await capture(tester, 'delete-requested', const Size(390, 844), true);
      expect(tester.takeException(), isNull);
    },
  );
}

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
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/domain/consent_policy.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/terms_policy_screen.dart';

import 'login_screen_test.dart'
    show FakeAuthViewModel, FakeTokenStorage, socialButton;

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Auth extends FakeAuthViewModel {
  int emails = 0, signups = 0, resets = 0, passwords = 0, resends = 0;
  int kakao = 0, google = 0, synced = 0;
  bool rejectLogin = false;
  Future<void>? pendingLogin;
  String? updatedPassword, requestedEmail;
  @override
  Future<void> loginWithKakao() async => kakao++;
  @override
  Future<void> loginWithGoogle() async => google++;
  @override
  Future<void> syncConsentIfPresent() async => synced++;
  @override
  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    emails++;
    await pendingLogin;
    if (rejectLogin) throw StateError('invalid credentials');
    await super.loginWithEmail(email: email, password: password);
  }

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required bool marketingOptIn,
  }) async {
    signups++;
    await super.signUpWithEmail(
      name: name,
      email: email,
      password: password,
      marketingOptIn: marketingOptIn,
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resets++;
    requestedEmail = email;
  }

  @override
  Future<void> updatePassword(String password) async {
    passwords++;
    updatedPassword = password;
  }

  @override
  Future<void> resendEmailConfirmation(String email) async {
    resends++;
    requestedEmail = email;
  }
}

class _Consent extends FakeTokenStorage {
  _Consent({this.agreed = true});
  bool agreed;
  int reads = 0;
  Completer<bool>? pendingRead;
  final saved = <({String terms, String privacy, bool marketing})>[];
  @override
  Future<bool> hasRequiredConsent({
    required String termsVersion,
    required String privacyVersion,
  }) async {
    reads++;
    return pendingRead == null ? agreed : await pendingRead!.future;
  }

  @override
  Future<void> saveConsent({
    required String termsVersion,
    required String privacyVersion,
    required bool marketingOptIn,
    required String agreedAtIso,
  }) async {
    saved.add((
      terms: termsVersion,
      privacy: privacyVersion,
      marketing: marketingOptIn,
    ));
  }
}

void main() {
  _Binding();
  final boundary = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List)
        loader.addFont(rootBundle.load(asset['asset'] as String));
      await loader.load();
    }
  });
  Finder key(String value) => find.byKey(ValueKey(value));
  Finder field(String label) => key('auth-field-$label');
  Finder editable(String label) =>
      find.descendant(of: field(label), matching: find.byType(EditableText));
  void metrics(WidgetTester tester, Size size, {double keyboard = 0}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
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

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.ensureVisible(field(label));
    await tester.pumpAndSettle();
    await tester.enterText(field(label), text);
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
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(wide ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (wide ? 48 : 0)));
    expect(
      rect.bottom,
      lessThanOrEqualTo(
        size.height -
            (keyboard > 0
                ? keyboard
                : wide
                ? 24
                : 34),
      ),
    );
    expect(finder.hitTestable(), findsOneWidget);
  }

  Future<void> mount(
    WidgetTester tester,
    _Auth auth, {
    _Consent? storage,
    bool dark = false,
    double scale = 1.3,
    bool password = false,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          authViewModelProvider.overrideWith(() => auth),
          tokenStorageProvider.overrideWithValue(storage ?? _Consent()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: LoginScreen(startInPasswordReset: password),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester tester,
    String id,
    Size size,
    bool dark,
  ) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate())
        await precacheImage((element.widget as Image).image, element);
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (!const bool.fromEnvironment('AUTH_ENTRY_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'output/all-screens-qa/$id-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> signup(WidgetTester tester) async {
    await enter(tester, '닉네임', '우리의 사진책');
    await enter(tester, '이메일', 'our.album@example.com');
    await enter(tester, '비밀번호', 'album1234');
    await enter(tester, '비밀번호 확인', 'album1234');
  }

  Future<void> requiredConsents(WidgetTester tester) async {
    for (var index = 0; index < 2; index++) {
      await tap(tester, find.byType(Checkbox).at(index));
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(index)).value,
        true,
      );
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
      testWidgets('native authentication flow $size dark=$dark', (
        tester,
      ) async {
        reset(tester);
        metrics(tester, size);
        final auth = _Auth();
        await mount(tester, auth, dark: dark);
        await capture(tester, 'access-welcome', size, dark);
        await tap(tester, find.text('이메일로 로그인'));
        await capture(tester, 'access-email', size, dark);
        await tap(tester, find.text('새 계정 만들기'));
        await capture(tester, 'access-signup', size, dark);
        await signup(tester);
        final keyboard = size.width > size.height ? 140.0 : 260.0;
        final input = tester.state<EditableTextState>(editable('비밀번호 확인'));
        metrics(tester, size, keyboard: keyboard);
        await tester.pumpAndSettle();
        expect(
          tester.state<EditableTextState>(editable('비밀번호 확인')),
          same(input),
        );
        expect(input.widget.focusNode.hasFocus, true);
        await capture(tester, 'access-signup-keyboard', size, dark);
        metrics(tester, size);
        await tester.pumpAndSettle();
        await requiredConsents(tester);
        await tester.ensureVisible(key('auth-signup-submit'));
        await tester.pumpAndSettle();
        safe(tester, key('auth-signup-submit'), size);
        await tap(tester, key('auth-signup-submit'));
        expect(auth.signups, 1);
        expect(auth.signedUpMarketing, false);
        await capture(tester, 'access-verify', size, dark);
        await tap(tester, key('auth-confirmation-login'));
        await tap(tester, find.text('비밀번호를 잊으셨나요?'));
        await capture(tester, 'access-recovery', size, dark);
        await tap(tester, key('auth-reset-submit'));
        expect(auth.resets, 1);
        expect(auth.requestedEmail, 'our.album@example.com');
        await capture(tester, 'access-recovery-sent', size, dark);
        await mount(tester, _Auth(), dark: dark, password: true);
        await capture(tester, 'access-password', size, dark);
        await mount(
          tester,
          _Auth(),
          dark: dark,
          storage: _Consent(agreed: false),
        );
        await tap(tester, socialButton('카카오로 계속하기'));
        safe(tester, key('auth-consent-close'), size);
        safe(tester, key('auth-consent-confirm'), size);
        await capture(tester, 'access-consent', size, dark);
        await tap(tester, key('auth-consent-close'));
        final rejected = _Auth()..rejectLogin = true;
        await mount(tester, rejected, dark: dark);
        await tap(tester, find.text('이메일로 로그인'));
        await enter(tester, '이메일', 'our.album@example.com');
        await enter(tester, '비밀번호', 'album1234');
        await tap(tester, key('auth-email-submit'));
        expect(rejected.emails, 1);
        expect(find.text('이메일 또는 비밀번호가 올바르지 않아요.'), findsOneWidget);
        await capture(tester, 'access-email-error', size, dark);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets(
      'large text and keyboard preserve usable signup and recovery controls $size',
      (tester) async {
        reset(tester);
        metrics(tester, size);
        final auth = _Auth();
        await mount(tester, auth, dark: true, scale: 1.8);
        await tap(tester, find.text('이메일로 새 계정 만들기'));
        await signup(tester);
        final keyboard = size.width > size.height ? 140.0 : 260.0;
        metrics(tester, size, keyboard: keyboard);
        await tester.pumpAndSettle();
        await requiredConsents(tester);
        await tester.ensureVisible(key('auth-signup-submit'));
        await tester.pumpAndSettle();
        safe(tester, key('auth-signup-submit'), size, keyboard: keyboard);
        await tap(tester, key('auth-signup-submit'));
        expect(auth.signups, 1);
        metrics(tester, size);
        await tester.pumpAndSettle();
        await tap(tester, key('auth-confirmation-login'));
        final recovery = _Auth();
        await mount(tester, recovery, dark: true, scale: 1.8, password: true);
        await enter(tester, '새 비밀번호', 'better1234');
        await enter(tester, '새 비밀번호 확인', 'better1234');
        metrics(tester, size, keyboard: keyboard);
        await tester.pumpAndSettle();
        await tester.ensureVisible(key('auth-password-submit'));
        await tester.pumpAndSettle();
        safe(tester, key('auth-password-submit'), size, keyboard: keyboard);
        await tap(tester, key('auth-password-submit'));
        expect(recovery.passwords, 1);
        expect(recovery.updatedPassword, 'better1234');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'focused signup input stays above keyboard without manual scrolling',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(320, 568));
      await mount(tester, _Auth(), scale: 1.8);
      await tap(tester, find.text('이메일로 새 계정 만들기'));
      await signup(tester);
      final input = tester.state<EditableTextState>(editable('비밀번호 확인'));
      metrics(tester, const Size(320, 568), keyboard: 260);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(editable('비밀번호 확인')).bottom,
        lessThanOrEqualTo(308),
      );
      expect(input.widget.focusNode.hasFocus, true);
      metrics(tester, const Size(648, 320), keyboard: 140);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(editable('비밀번호 확인')).bottom,
        lessThanOrEqualTo(180),
      );
      expect(tester.state<EditableTextState>(editable('비밀번호 확인')), same(input));
      expect(input.widget.focusNode.hasFocus, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long verification recipient stays complete across rotation', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(320, 568));
    final auth = _Auth();
    await mount(tester, auth, scale: 1.8, dark: true);
    await tap(tester, find.text('이메일로 새 계정 만들기'));
    await signup(tester);
    const address = 'our.family.photo.album.archive@long-example-domain.com';
    await enter(tester, '이메일', address);
    await requiredConsents(tester);
    await tap(tester, key('auth-signup-submit'));
    for (final size in [const Size(320, 568), const Size(648, 320)]) {
      metrics(tester, size);
      await tester.pumpAndSettle();
      final recipient = find.byKey(const Key('signup_confirmation_email'));
      await tester.ensureVisible(recipient);
      await tester.pumpAndSettle();
      expect(tester.widget<SelectableText>(recipient).data, address);
      final rect = tester.getRect(recipient);
      expect(
        rect.left,
        greaterThanOrEqualTo(size.width > size.height ? 32 : 0),
      );
      expect(
        rect.right,
        lessThanOrEqualTo(size.width - (size.width > size.height ? 48 : 0)),
      );
      await tester.ensureVisible(key('auth-confirmation-login'));
      await tester.pumpAndSettle();
      safe(tester, key('auth-confirmation-login'), size);
    }
    await tap(tester, key('auth-confirmation-login'));
    expect(
      tester.widget<TextFormField>(field('이메일')).controller!.text,
      address,
    );
    expect(auth.resends, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consent with small landscape keyboard keeps action reachable', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(648, 320));
    final auth = _Auth(), storage = _Consent(agreed: false);
    await mount(tester, auth, storage: storage, scale: 1.8);
    await tap(tester, socialButton('Google로 계속하기'));
    metrics(tester, const Size(648, 320), keyboard: 140);
    await tester.pumpAndSettle();
    await requiredConsents(tester);
    await tester.ensureVisible(key('auth-consent-confirm'));
    await tester.pumpAndSettle();
    safe(
      tester,
      key('auth-consent-confirm'),
      const Size(648, 320),
      keyboard: 140,
    );
    await tap(tester, key('auth-consent-confirm'));
    expect(auth.google, 1);
    expect(storage.saved.single.marketing, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup draft, consents and active input survive rotation', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(390, 844));
    final auth = _Auth();
    await mount(tester, auth);
    await tap(tester, find.text('이메일로 새 계정 만들기'));
    await signup(tester);
    await requiredConsents(tester);
    await enter(tester, '비밀번호 확인', 'album1234');
    final input = tester.state<EditableTextState>(editable('비밀번호 확인'));
    metrics(tester, const Size(390, 844), keyboard: 260);
    await tester.pumpAndSettle();
    metrics(tester, const Size(648, 320), keyboard: 140);
    await tester.pumpAndSettle();
    expect(tester.state<EditableTextState>(editable('비밀번호 확인')), same(input));
    expect(input.widget.focusNode.hasFocus, true);
    expect(
      tester.widget<TextFormField>(field('닉네임')).controller!.text,
      '우리의 사진책',
    );
    expect(
      tester.widget<TextFormField>(field('이메일')).controller!.text,
      'our.album@example.com',
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, true);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value, true);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, false);
    expect(auth.signups, 0);
    metrics(tester, const Size(390, 844));
    await tester.pumpAndSettle();
    await tap(tester, key('auth-signup-submit'));
    expect(auth.signups, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'social consent is single-flight across providers and cancelling never authenticates',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(648, 320));
      final storage = _Consent(agreed: false)..pendingRead = Completer<bool>();
      final auth = _Auth();
      await mount(tester, auth, storage: storage);
      final kakao = tester
          .widget<ElevatedButton>(socialButton('카카오로 계속하기'))
          .onPressed!;
      final google = tester
          .widget<ElevatedButton>(socialButton('Google로 계속하기'))
          .onPressed!;
      kakao();
      google();
      kakao();
      await tester.pump(const Duration(milliseconds: 300));
      expect(storage.reads, 1);
      expect(auth.kakao, 0);
      expect(auth.google, 0);
      storage.pendingRead!.complete(false);
      await tester.pumpAndSettle();
      expect(key('auth-social-consent'), findsOneWidget);
      final close = tester
          .widget<IconButton>(key('auth-consent-close'))
          .onPressed!;
      close();
      close();
      await tester.pumpAndSettle();
      expect(storage.saved, isEmpty);
      expect(auth.kakao, 0);
      expect(auth.google, 0);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(socialButton('카카오로 계속하기')).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'consent checks survive rotation and document review; stale confirm is rejected',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final auth = _Auth(), storage = _Consent(agreed: false);
      await mount(tester, auth, storage: storage, dark: true, scale: 1.8);
      await tap(tester, socialButton('Google로 계속하기'));
      await requiredConsents(tester);
      final confirm = tester
          .widget<ElevatedButton>(key('auth-consent-confirm'))
          .onPressed!;
      await tap(tester, find.byType(Checkbox).at(1));
      confirm();
      await tester.pumpAndSettle();
      expect(storage.saved, isEmpty);
      expect(auth.google, 0);
      await tap(tester, find.byType(Checkbox).at(1));
      metrics(tester, const Size(648, 320));
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('이용약관 동의 보기'));
      expect(find.byType(TermsPolicyScreen), findsOneWidget);
      confirm();
      await tester.pumpAndSettle();
      expect(find.byType(TermsPolicyScreen), findsOneWidget);
      expect(storage.saved, isEmpty);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value, true);
      await tap(tester, key('auth-consent-confirm'));
      expect(auth.google, 1);
      expect(auth.synced, 1);
      expect(storage.saved.single.terms, ConsentPolicy.termsVersion);
      expect(storage.saved.single.privacy, ConsentPolicy.privacyVersion);
      expect(storage.saved.single.marketing, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late verification resend after correcting email does not send to the old recipient',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(648, 320));
      final auth = _Auth();
      await mount(tester, auth);
      await tap(tester, find.text('이메일로 새 계정 만들기'));
      await signup(tester);
      await requiredConsents(tester);
      await tap(tester, key('auth-signup-submit'));
      await tester.pump(const Duration(seconds: 60));
      final resend = tester
          .widget<OutlinedButton>(key('auth-confirmation-resend'))
          .onPressed!;
      await tap(tester, find.text('이메일을 잘못 입력했어요'));
      await enter(tester, '이메일', 'corrected@example.com');
      resend();
      await tester.pumpAndSettle();
      expect(auth.resends, 0);
      expect(auth.signups, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('covered or disposed login actions cannot start authentication', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(390, 844));
    final auth = _Auth();
    await mount(tester, auth);
    await tap(tester, find.text('이메일로 로그인'));
    await enter(tester, '이메일', 'our.album@example.com');
    await enter(tester, '비밀번호', 'album1234');
    final action = tester
        .widget<ElevatedButton>(key('auth-email-submit'))
        .onPressed!;
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('검토 화면')),
      ),
    );
    await tester.pumpAndSettle();
    action();
    await tester.pumpAndSettle();
    expect(auth.emails, 0);
    await tester.pumpWidget(const SizedBox());
    action();
    await tester.pumpAndSettle();
    expect(auth.emails, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'auth system bars follow the page theme without a global orientation lock',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(844, 390));
      for (final dark in [false, true]) {
        await mount(tester, _Auth(), dark: dark);
        final context = tester.element(find.byType(LoginScreen));
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find
              .descendant(
                of: find.byType(LoginScreen),
                matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
              )
              .first,
        );
        expect(
          region.value.systemNavigationBarColor,
          SnapFitColors.backgroundOf(context),
        );
        expect(
          region.value.statusBarIconBrightness,
          dark ? Brightness.light : Brightness.dark,
        );
        expect(region.value.systemNavigationBarContrastEnforced, false);
      }
    },
  );
}

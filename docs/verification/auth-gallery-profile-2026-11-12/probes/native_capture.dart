// 개선된 실제 화면을 캡처한다. 사진·인증 요청은 메모리 대역으로 대체한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_edit_screen.dart';
import 'package:snap_fit/shared/widgets/album_bottom_sheet.dart';
import '../../../../test/support/auth_video_platform_fake.dart';
import '../../../../test/widget/auth_recovery_completion_test.dart'
    show
        RecoveryFlowFixture,
        RecoveryFlowAuth,
        recoveryAccount,
        recoveryTap,
        recoveryKey,
        preparePasswordChange;
import '../../../../test/widget/social_profile_exit_guard_test.dart'
    show ProfileExitFixture, mountProfileExit;

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Gallery extends Fake implements GalleryRepository {
  _Gallery({this.fail = false, this.permitted = true});
  bool fail;
  final bool permitted;
  int reads = 0;
  @override
  Future<bool> requestPermission() async => permitted;
  @override
  Future<List<AssetPathEntity>> loadAlbums() async {
    reads++;
    if (fail) throw StateError('fixture photo library unavailable');
    return const [];
  }
}

final _boundary = GlobalKey();

Widget _galleryApp(_Gallery repository) => ProviderScope(
  overrides: [galleryRepositoryProvider.overrideWithValue(repository)],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SnapFitTheme.light().copyWith(
        splashFactory: NoSplash.splashFactory,
      ),
      builder: (_, child) => RepaintBoundary(key: _boundary, child: child!),
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => Center(
            child: TextButton(
              onPressed: () =>
                  showPhotosSelectionSheet(context, ref, maxSelection: 10),
              child: const Text('사진 추가'),
            ),
          ),
        ),
      ),
    ),
  ),
);

void _repaint(RenderObject object) {
  object.visitChildren(_repaint);
  if (object.attached) object.markNeedsPaint();
}

Future<void> _capture(WidgetTester tester, String name) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  for (final view in tester.binding.renderViews) {
    _repaint(view);
  }
  await tester.pump(const Duration(milliseconds: 32));
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final directory = Platform.environment['RECOVERY_CAPTURE_DIR']!;
      final target = File('$directory/$name.png');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      picture.dispose();
    }
  });
}

void _size(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  _Binding();
  setUpAll(() async {
    for (final (family, assets) in [
      ('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']),
      (
        'NotoSans',
        [
          'assets/fonts/NotoSansKR-Regular.ttf',
          'assets/fonts/NotoSansKR-SemiBold.ttf',
          'assets/fonts/NotoSansKR-Bold.ttf',
        ],
      ),
      (
        'Pretendard',
        [
          'assets/fonts/NotoSansKR-Regular.ttf',
          'assets/fonts/NotoSansKR-Bold.ttf',
        ],
      ),
      (
        'Poppins',
        [
          'assets/fonts/Poppins-Regular.otf',
          'assets/fonts/Poppins-SemiBold.otf',
        ],
      ),
    ]) {
      final loader = FontLoader(family);
      for (final path in assets) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  });

  testWidgets('capture gallery query failure and retry to confirmed empty', (
    tester,
  ) async {
    _size(tester);
    final repository = _Gallery(fail: true);
    await tester.pumpWidget(_galleryApp(repository));
    await recoveryTap(tester, find.text('사진 추가'));
    expect(find.text('사진을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('사진 권한 열기'), findsNothing);
    await _capture(tester, '01-gallery-query-failed');
    repository.fail = false;
    await recoveryTap(tester, find.text('다시 시도'));
    expect(repository.reads, 2);
    expect(find.text('이미지 앨범이 비어 있어요'), findsOneWidget);
    await _capture(tester, '02-gallery-empty-after-retry');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('capture gallery confirmed permission denial', (tester) async {
    _size(tester);
    await tester.pumpWidget(_galleryApp(_Gallery(permitted: false)));
    await recoveryTap(tester, find.text('사진 추가'));
    expect(find.text('사진 접근 권한이 필요해요'), findsOneWidget);
    expect(find.text('사진 권한 열기'), findsOneWidget);
    await _capture(tester, '03-gallery-permission');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  for (final dark in [false, true]) {
    testWidgets('capture initialized video email/reset forms dark=$dark', (
      tester,
    ) async {
      final fixture = RecoveryFlowFixture(
        videoState: AuthVideoState.initialized,
      );
      await fixture.mount(
        tester,
        password: false,
        dark: dark,
        capture: _boundary,
      );
      expect(fixture.video.played, isNotEmpty);
      await recoveryTap(tester, find.text('이메일로 로그인'));
      expect(find.byType(VideoPlayer), findsNothing);
      await _capture(tester, dark ? '05-email-dark' : '04-email-light');
      await recoveryTap(tester, find.text('비밀번호를 잊으셨나요?'));
      expect(find.byType(VideoPlayer), findsNothing);
      await _capture(tester, dark ? '07-reset-dark' : '06-reset-light');
    });
  }

  testWidgets('capture password completion and confirmed route return', (
    tester,
  ) async {
    final fixture = RecoveryFlowFixture(
      auth: RecoveryFlowAuth(user: recoveryAccount),
    );
    await fixture.mount(tester, pushed: true, capture: _boundary);
    final submit = await preparePasswordChange(tester);
    await _capture(tester, '08-password-before-submit');
    submit();
    await tester.pumpAndSettle();
    expect(recoveryKey('auth-field-새 비밀번호'), findsNothing);
    expect(find.text('다시 변경하기'), findsNothing);
    await _capture(tester, '09-password-complete-return');
    await recoveryTap(tester, recoveryKey('auth-password-complete'));
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('복귀 기준 화면'), findsOneWidget);
  });

  testWidgets('capture guest completion and login return', (tester) async {
    final fixture = RecoveryFlowFixture();
    await fixture.mount(tester, capture: _boundary);
    (await preparePasswordChange(tester))();
    await tester.pumpAndSettle();
    await _capture(tester, '10-password-complete-login');
    await recoveryTap(tester, recoveryKey('auth-password-complete'));
    expect(find.text('이메일로 계속하기'), findsOneWidget);
  });

  testWidgets('capture edited reset recipient without stale success notice', (
    tester,
  ) async {
    final fixture = RecoveryFlowFixture();
    await fixture.mount(tester, password: false, capture: _boundary);
    await recoveryTap(tester, find.text('이메일로 로그인'));
    await recoveryTap(tester, find.text('비밀번호를 잊으셨나요?'));
    await tester.enterText(recoveryKey('auth-field-이메일'), 'first@example.test');
    await recoveryTap(tester, recoveryKey('auth-reset-submit'));
    await _capture(tester, '11-reset-email-sent');
    await tester.enterText(
      recoveryKey('auth-field-이메일'),
      'changed@example.test',
    );
    await tester.pumpAndSettle();
    expect(find.text('입력한 이메일로 재설정 링크를 보냈어요. 메일함을 확인해주세요.'), findsNothing);
    expect(fixture.auth.resetRecipients, ['first@example.test']);
    expect(
      tester.widget<ElevatedButton>(recoveryKey('auth-reset-submit')).onPressed,
      isNull,
    );
    await _capture(tester, '12-reset-recipient-edited');
  });

  testWidgets('capture profile confirmation continue and explicit discard', (
    tester,
  ) async {
    final fixture = ProfileExitFixture();
    await mountProfileExit(tester, fixture, capture: _boundary);
    final bio = find.byKey(const ValueKey('social-profile-bio'));
    const draft = '사진으로 남긴 하루를 나누고 싶어요. 아직 저장하지 않은 소개입니다.';
    await tester.enterText(bio, draft);
    await tester.ensureVisible(bio);
    await _capture(tester, '13-profile-unsaved-draft');
    await fixture.navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await _capture(tester, '14-profile-discard-confirmation');
    await recoveryTap(tester, find.text('계속 수정'));
    expect(tester.widget<TextFormField>(bio).controller!.text, draft);
    await _capture(tester, '15-profile-draft-preserved');
    await fixture.navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    await recoveryTap(tester, find.text('나가기'));
    expect(find.byType(SocialProfileEditScreen), findsNothing);
    await fixture.open(tester);
    expect(
      tester.widget<TextFormField>(bio).controller!.text,
      '공개한 소개만 표시합니다.',
    );
    await tester.ensureVisible(bio);
    await _capture(tester, '16-profile-after-explicit-discard');
  });

  testWidgets('capture narrow profile confirmation with large text', (
    tester,
  ) async {
    final fixture = ProfileExitFixture();
    await mountProfileExit(
      tester,
      fixture,
      size: const Size(320, 568),
      scale: 1.8,
      capture: _boundary,
    );
    final bio = find.byKey(const ValueKey('social-profile-bio'));
    await tester.ensureVisible(bio);
    await tester.enterText(bio, '좁은 화면에서도 작성한 소개를 보존해요.');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await fixture.navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    await _capture(tester, '17-profile-confirmation-large-text');
  });
}

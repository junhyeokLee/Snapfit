// 현재 화면의 남은 불편을 재현한다. 제품 코드나 실제 계정·사진은 변경하지 않는다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart' as video;
// 플랫폼 영상 상태를 재현하는 검증 전용 간접 의존성이다. 앱 의존성은 바꾸지 않는다.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/gallery_notifier.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_edit_screen.dart';
import 'package:snap_fit/shared/widgets/album_bottom_sheet.dart';

import '../../../../test/widget/login_screen_test.dart'
    show FakeAuthViewModel, FakeTokenStorage;

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Gallery extends Fake implements GalleryRepository {
  _Gallery(this.fail);
  final bool fail;
  int reads = 0;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<List<AssetPathEntity>> loadAlbums() async {
    reads++;
    if (fail) throw StateError('fixture photo library unavailable');
    return const [];
  }
}

// 실제 영상 프레임 없이 초기화 성공 상태를 만들어 폼 배경 조건만 검증한다.
class _InitializedVideo extends video_platform.VideoPlayerPlatform {
  int creates = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(
    video_platform.VideoCreationOptions options,
  ) async => ++creates;
  @override
  Stream<video_platform.VideoEvent> videoEventsFor(int playerId) =>
      Stream.value(
        video_platform.VideoEvent(
          eventType: video_platform.VideoEventType.initialized,
          duration: const Duration(minutes: 1),
          size: const Size(390, 844),
        ),
      );
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(video_platform.VideoViewOptions options) =>
      const ColoredBox(color: Color(0xFF164552));
}

final _boundary = GlobalKey();

Widget _app(Widget child, {GlobalKey<NavigatorState>? navigator}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        navigatorKey: navigator,
        debugShowCheckedModeBanner: false,
        theme: SnapFitTheme.light().copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        builder: (_, child) => RepaintBoundary(key: _boundary, child: child!),
        home: child,
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
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        '${Platform.environment['REMAINING_AUDIT_DIR']}/$name.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
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
  setUp(() {
    // 검증 자료 폴더에서 실행하는 위젯 테스트이므로 실제 기기 저장소를 사용하지 않는다.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  for (final fail in [true, false]) {
    testWidgets('gallery ${fail ? 'failure' : 'empty'} source audit', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final repository = _Gallery(fail);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [galleryRepositoryProvider.overrideWithValue(repository)],
          child: _app(
            Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Center(
                  child: TextButton(
                    onPressed: () => showPhotosSelectionSheet(
                      context,
                      ref,
                      maxSelection: 10,
                    ),
                    child: const Text('사진 추가'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('사진 추가')),
      );
      await _tap(tester, find.text('사진 추가'));
      expect(repository.reads, 1);
      if (fail)
        expect(container.read(galleryProvider).error, isA<StateError>());
      expect(find.text('이미지 앨범이 비어 있어요'), findsOneWidget);
      await _capture(
        tester,
        fail ? '01-gallery-query-failed' : '02-gallery-truly-empty',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('password update completion and return destination audit', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final fake = FakeAuthViewModel(
      user: const UserInfo(id: 'audit-owner', name: '검토 계정', provider: 'EMAIL'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => fake),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: _app(const LoginScreen(startInPasswordReset: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-field-새 비밀번호')),
      'auditpass123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-field-새 비밀번호 확인')),
      'auditpass123',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-password-submit')),
    );
    await _capture(tester, '03-password-before-submit');
    await _tap(tester, find.byKey(const ValueKey('auth-password-submit')));
    expect(fake.passwordUpdated, isTrue);
    expect(find.text('다시 변경하기'), findsOneWidget);
    await _capture(tester, '04-password-complete');
    await _tap(tester, find.text('이메일 로그인으로 돌아가기'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(fake.user, isNotNull);
    await _capture(tester, '05-password-return-shows-login');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'initialized video leaves light email forms on black background',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final originalVideo = video_platform.VideoPlayerPlatform.instance;
      final initializedVideo = _InitializedVideo();
      video_platform.VideoPlayerPlatform.instance = initializedVideo;
      addTearDown(() {
        video_platform.VideoPlayerPlatform.instance = originalVideo;
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
            tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          ],
          child: _app(const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(initializedVideo.creates, 1);
      final player = tester.widget<video.VideoPlayer>(
        find.byType(video.VideoPlayer),
      );
      expect(player.controller.value.isInitialized, isTrue);
      await _tap(tester, find.text('이메일로 로그인'));
      expect(find.byType(video.VideoPlayer), findsNothing);
      expect(
        Theme.of(tester.element(find.text('이메일로 계속하기'))).brightness,
        Brightness.light,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.black,
      );
      await _capture(tester, '10-initialized-video-email-form');
      await _tap(tester, find.text('비밀번호를 잊으셨나요?'));
      expect(find.byType(video.VideoPlayer), findsNothing);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.black,
      );
      await _capture(tester, '11-initialized-video-reset-form');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('reset email recipient changes while success copy remains', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final fake = FakeAuthViewModel();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => fake),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: _app(const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.text('이메일로 로그인'));
    await _tap(tester, find.text('비밀번호를 잊으셨나요?'));
    final email = find.byKey(const ValueKey('auth-field-이메일'));
    await tester.enterText(email, 'first@example.test');
    await _tap(tester, find.byKey(const ValueKey('auth-reset-submit')));
    expect(fake.passwordResetEmail, 'first@example.test');
    await _capture(tester, '06-reset-email-sent');
    await tester.enterText(email, 'changed@example.test');
    expect(find.text('입력한 이메일로 재설정 링크를 보냈어요. 메일함을 확인해주세요.'), findsOneWidget);
    expect(fake.passwordResetEmail, 'first@example.test');
    await _capture(tester, '07-reset-email-edited');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'profile text is discarded without a prompt on back and reentry',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
            socialCurrentUserIdProvider.overrideWithValue('me'),
            ownSocialProfileProvider.overrideWith(
              (_) async => const SocialProfile(
                userId: 'me',
                displayName: '나의 공개 기록',
                handle: 'my.public',
                bio: '공개한 소개만 표시합니다.',
              ),
            ),
          ],
          child: _app(
            const Scaffold(body: Text('검토용 시작 화면')),
            navigator: navigator,
          ),
        ),
      );
      await tester.pumpAndSettle();
      void open() => navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const SocialProfileEditScreen()),
      );
      open();
      await tester.pumpAndSettle();
      final bio = find.byKey(const ValueKey('social-profile-bio'));
      await tester.enterText(bio, '아직 저장하지 않은 새로운 소개입니다. 사진으로 남긴 하루를 나누고 싶어요.');
      await tester.ensureVisible(bio);
      await _capture(tester, '08-profile-unsaved-draft');
      expect(await navigator.currentState!.maybePop(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(SocialProfileEditScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      open();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(bio).controller!.text,
        '공개한 소개만 표시합니다.',
      );
      await tester.ensureVisible(bio);
      await _capture(tester, '09-profile-reentered');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

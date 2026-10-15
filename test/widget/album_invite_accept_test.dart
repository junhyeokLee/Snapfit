import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_accept_response.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_info_response.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_accept_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/album_invite_router.dart';
import 'package:snap_fit/features/album/service/pending_album_invite.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/features/splash/presentation/views/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_album.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _Members extends Mock implements AlbumMemberRepository {}

class _Albums extends Mock implements AlbumRepository {}

class _Auth extends AuthViewModel {
  _Auth(this.user);
  final UserInfo? user;
  @override
  FutureOr<UserInfo?> build() => user;
  void become(UserInfo? value) {
    state = const AsyncLoading();
    state = AsyncData(value);
  }
}

class _Home extends HomeViewModel {
  @override
  FutureOr<List<Album>> build() => const [];
}

const _user = UserInfo(id: 'one', name: '지현', provider: 'email');
const _info = InviteInfoResponse(
  albumId: 7,
  albumTitle: '우리의 여름, 오래 간직할 장면들',
  inviterName: '준혁',
  role: 'EDITOR',
);
const _accepted = InviteAcceptResponse(
  albumId: 7,
  role: 'EDITOR',
  success: true,
);
const _action = ValueKey('inviteAcceptAction');
Uri _link(String token) => Uri.parse('snapfit://invite?token=$token');

Future<void> _viewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Members members, {
  UserInfo? user = _user,
  bool routed = false,
  bool splash = false,
  bool dark = false,
  double scale = 1,
  GlobalKey? capture,
  _Albums? albums,
  InvitedAlbumOpen? onOpen,
}) async {
  final container = ProviderContainer(
    overrides: [
      albumMemberRepositoryProvider.overrideWithValue(members),
      if (albums != null) albumRepositoryProvider.overrideWithValue(albums),
      authViewModelProvider.overrideWith(() => _Auth(user)),
      homeViewModelProvider.overrideWith(_Home.new),
      invitedAlbumOpenProvider.overrideWithValue(
        onOpen ?? (_, __, ___) async {},
      ),
    ],
  );
  addTearDown(container.dispose);
  final pending = container.read(pendingAlbumInviteProvider.notifier);
  pending.receive(_link('one'));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: capture, child: child!),
          ),
          home: splash
              ? const SplashScreen()
              : routed
              ? const AlbumInviteRouter(
                  child: Scaffold(body: Center(child: Text('기존 작업 화면'))),
                )
              : AlbumInviteAcceptScreen(
                  invite: container.read(pendingAlbumInviteProvider)!,
                ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('INVITE_ACCEPT_QA')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/editor-flow-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadCreationFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'accept is explicit, single-flight, and opens the actual accepted album',
    (tester) async {
      final members = _Members(), albums = _Albums();
      final pending = Completer<InviteAcceptResponse>();
      when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
      when(() => members.acceptInvite('one')).thenAnswer((_) => pending.future);
      when(
        () => albums.fetchAlbum('7'),
      ).thenAnswer((_) async => fakeAlbum(id: 7));
      Album? opened;
      final container = await _pump(
        tester,
        members,
        albums: albums,
        onOpen: (_, __, album) async {
          opened = album;
        },
      );
      await tester.pumpAndSettle();
      verifyNever(() => members.acceptInvite(any()));
      await tester.tap(find.byKey(_action));
      await tester.pump();
      await tester.tap(find.byKey(_action));
      await tester.pump();
      expect(find.text('참여하는 중'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(_action)).onPressed,
        isNull,
      );
      pending.complete(_accepted);
      await tester.pumpAndSettle();
      expect(container.read(pendingAlbumInviteProvider), isNull);
      expect(find.text('앨범 열기'), findsOneWidget);
      await tester.tap(find.byKey(_action));
      await tester.pumpAndSettle();
      expect(opened?.id, 7);
      verify(() => members.acceptInvite('one')).called(1);
    },
  );

  testWidgets('login keeps the invitation and never auto-accepts it', (
    tester,
  ) async {
    final members = _Members();
    when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
    final container = await _pump(tester, members, user: null, routed: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(container.read(pendingAlbumInviteProvider)?.token, 'one');
    (container.read(authViewModelProvider.notifier) as _Auth).become(_user);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text(_info.albumTitle), findsOneWidget);
    expect(find.text('초대 수락하기'), findsOneWidget);
    verifyNever(() => members.acceptInvite(any()));
  });

  testWidgets(
    'cold invitation waits for splash replacement and stays above login',
    (tester) async {
      final members = _Members();
      when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
      final container = await _pump(tester, members, user: null, splash: true);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(AlbumInviteAcceptScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();
      expect(find.text(_info.albumTitle), findsOneWidget);
      expect(find.byType(AlbumInviteAcceptScreen), findsOneWidget);
      expect(container.read(pendingAlbumInviteProvider)?.token, 'one');
      verifyNever(() => members.acceptInvite(any()));
    },
  );

  testWidgets(
    'expired login opens reauthentication and returns to the same preview',
    (tester) async {
      final members = _Members();
      when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
      when(
        () => members.acceptInvite('one'),
      ).thenThrow(const FunctionException(status: 401));
      final container = await _pump(tester, members, routed: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_action));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      (container.read(authViewModelProvider.notifier) as _Auth).become(_user);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text(_info.albumTitle), findsOneWidget);
      expect(find.text('초대 수락하기'), findsOneWidget);
      expect(container.read(pendingAlbumInviteProvider)?.token, 'one');
    },
  );

  testWidgets('dismissing a warm link preserves the underlying work route', (
    tester,
  ) async {
    final members = _Members();
    when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
    final container = await _pump(tester, members, routed: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('초대 닫기'));
    await tester.pumpAndSettle();
    expect(find.text('기존 작업 화면'), findsOneWidget);
    expect(container.read(pendingAlbumInviteProvider), isNull);
    expect(find.byType(AlbumInviteAcceptScreen), findsNothing);
  });

  testWidgets(
    'new links reuse one route and late old acceptance cannot clear the new invitation',
    (tester) async {
      final members = _Members();
      final old = Completer<InviteAcceptResponse>();
      when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
      when(
        () => members.getInviteInfo('two'),
      ).thenAnswer((_) async => _info.copyWith(albumId: 8, albumTitle: '새 초대'));
      when(() => members.acceptInvite('one')).thenAnswer((_) => old.future);
      final container = await _pump(tester, members, routed: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_action));
      await tester.pump();
      container.read(pendingAlbumInviteProvider.notifier).receive(_link('two'));
      await tester.pumpAndSettle();
      old.complete(_accepted);
      await tester.pumpAndSettle();
      expect(container.read(pendingAlbumInviteProvider)?.token, 'two');
      expect(find.text('새 초대'), findsOneWidget);
      expect(find.text('앨범 열기'), findsNothing);
      expect(find.byType(AlbumInviteAcceptScreen), findsOneWidget);
      await tester.tap(find.text('초대 닫기'));
      await tester.pumpAndSettle();
      expect(find.text('기존 작업 화면'), findsOneWidget);
    },
  );

  testWidgets(
    'account change during acceptance never opens album in another account',
    (tester) async {
      final members = _Members();
      final pending = Completer<InviteAcceptResponse>();
      when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
      when(() => members.acceptInvite('one')).thenAnswer((_) => pending.future);
      final container = await _pump(tester, members);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_action));
      await tester.pump();
      (container.read(authViewModelProvider.notifier) as _Auth).become(
        _user.copyWith(id: 'two'),
      );
      pending.complete(_accepted);
      await tester.pumpAndSettle();
      expect(find.text('계정이 변경되었어요'), findsOneWidget);
      expect(container.read(pendingAlbumInviteProvider)?.token, 'one');
      expect(find.text('앨범 열기'), findsNothing);
    },
  );

  testWidgets(
    'a new link during route dismissal is not discarded with the old invite',
    (tester) async {
      final members = _Members();
      when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
      when(
        () => members.getInviteInfo('two'),
      ).thenAnswer((_) async => _info.copyWith(albumTitle: '새 초대'));
      final container = await _pump(tester, members, routed: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('초대 닫기'));
      container.read(pendingAlbumInviteProvider.notifier).receive(_link('two'));
      await tester.pumpAndSettle();
      expect(container.read(pendingAlbumInviteProvider)?.token, 'two');
      expect(find.text('새 초대'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [404, 409, 410]) {
    testWidgets('terminal invitation $status never offers acceptance', (
      tester,
    ) async {
      final members = _Members();
      when(
        () => members.getInviteInfo('one'),
      ).thenThrow(FunctionException(status: status));
      await _pump(tester, members);
      await tester.pumpAndSettle();
      expect(find.text('초대 수락하기'), findsNothing);
      expect(find.text('초대 닫기'), findsOneWidget);
      expect(find.text('다시 확인하기'), findsNothing);
      verifyNever(() => members.acceptInvite(any()));
    });
  }

  testWidgets(
    'network errors retry; false acceptance is not reported as success',
    (tester) async {
      final members = _Members();
      var reads = 0, accepts = 0;
      when(() => members.getInviteInfo('one')).thenAnswer((_) async {
        if (++reads == 1) throw Exception('fixture connection');
        return _info;
      });
      when(() => members.acceptInvite('one')).thenAnswer((_) async {
        accepts++;
        return accepts == 1 ? _accepted.copyWith(success: false) : _accepted;
      });
      final container = await _pump(tester, members);
      await tester.pumpAndSettle();
      await tester.tap(find.text('다시 확인하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_action));
      await tester.pumpAndSettle();
      expect(find.text('앨범 열기'), findsNothing);
      expect(container.read(pendingAlbumInviteProvider), isNotNull);
      await tester.tap(find.byKey(_action));
      await tester.pumpAndSettle();
      expect(find.text('앨범 열기'), findsOneWidget);
      expect(accepts, 2);
    },
  );

  testWidgets('album load retry does not accept a second time', (tester) async {
    final members = _Members(), albums = _Albums();
    when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
    when(() => members.acceptInvite('one')).thenAnswer((_) async => _accepted);
    var fetches = 0, opens = 0;
    when(() => albums.fetchAlbum('7')).thenAnswer((_) async {
      if (++fetches == 1) throw Exception('fixture connection');
      return fakeAlbum(id: 7);
    });
    await _pump(
      tester,
      members,
      albums: albums,
      onOpen: (_, __, ___) async {
        opens++;
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('참여는 완료되었어요.'),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('inviteAcceptContent')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('참여는 완료되었어요.'), findsOneWidget);
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    expect(opens, 1);
    verify(() => members.acceptInvite('one')).called(1);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('invitation layout ${size.width} dark=$dark scale=$scale', (
          tester,
        ) async {
          await _viewport(tester, size);
          final members = _Members();
          when(
            () => members.getInviteInfo('one'),
          ).thenAnswer((_) async => _info.copyWith(role: 'VIEWER'));
          final capture = GlobalKey();
          await _pump(
            tester,
            members,
            dark: dark,
            scale: scale,
            capture: capture,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(find.byKey(_action));
          expect(
            rect.bottom,
            lessThan(size.height - (size.width > size.height ? 24 : 34)),
          );
          expect(
            rect.left,
            greaterThanOrEqualTo(size.width > size.height ? 32 : 0),
          );
          if (scale == 1)
            await _capture(
              tester,
              capture,
              'invite-accept-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
            );
        });
      }
      for (final stage in ['loading', 'expired', 'joined']) {
        testWidgets('invitation $stage QA ${size.width} dark=$dark', (
          tester,
        ) async {
          await _viewport(tester, size);
          final members = _Members();
          final pending = Completer<InviteInfoResponse>();
          when(() => members.getInviteInfo('one')).thenAnswer(
            (_) => stage == 'loading'
                ? pending.future
                : stage == 'expired'
                ? Future.error(const FunctionException(status: 410))
                : Future.value(_info),
          );
          when(
            () => members.acceptInvite('one'),
          ).thenAnswer((_) async => _accepted);
          final capture = GlobalKey();
          await _pump(tester, members, dark: dark, capture: capture);
          if (stage == 'loading') {
            await tester.pump(const Duration(milliseconds: 200));
          } else {
            await tester.pumpAndSettle();
          }
          if (stage == 'joined') {
            await tester.tap(find.byKey(_action));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            capture,
            'invite-accept-$stage-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
          if (stage == 'loading') {
            pending.complete(_info);
            await tester.pumpAndSettle();
          }
        });
      }
    }
  }
}

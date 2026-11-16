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
import 'package:snap_fit/features/album/data/dto/album_member_response.dart';
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
  bool nestedRouter = false,
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
              ? AlbumInviteRouter(
                  child: nestedRouter
                      ? const AlbumInviteRouter(
                          child: Scaffold(
                            body: Center(child: Text('기존 작업 화면')),
                          ),
                        )
                      : const Scaffold(body: Center(child: Text('기존 작업 화면'))),
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

  testWidgets('nested login gates present only one warm invitation', (
    tester,
  ) async {
    final members = _Members();
    when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
    final container = await _pump(
      tester,
      members,
      routed: true,
      nestedRouter: true,
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(AlbumInviteAcceptScreen, skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.text('초대 닫기'));
    await tester.pumpAndSettle();
    expect(container.read(pendingAlbumInviteProvider), isNull);
    expect(find.text('기존 작업 화면'), findsOneWidget);
    expect(
      find.byType(AlbumInviteAcceptScreen, skipOffstage: false),
      findsNothing,
    );
  });

  for (final status in [401, 409, 410]) {
    testWidgets('late old-account $status cannot override a new acceptance', (
      tester,
    ) async {
      final members = _Members();
      final old = Completer<InviteAcceptResponse>();
      final current = Completer<InviteAcceptResponse>();
      var calls = 0;
      when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
      when(
        () => members.acceptInvite('one'),
      ).thenAnswer((_) => calls++ == 0 ? old.future : current.future);
      final container = await _pump(tester, members);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_action));
      await tester.pump();
      (container.read(authViewModelProvider.notifier) as _Auth).become(
        _user.copyWith(id: 'two'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_action));
      await tester.pump();
      expect(calls, 2);
      old.completeError(FunctionException(status: status));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LoginScreen), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(_action)).onPressed,
        isNull,
      );
      current.complete(_accepted);
      await tester.pumpAndSettle();
      expect(find.text('앨범 열기'), findsOneWidget);
      expect(container.read(pendingAlbumInviteProvider), isNull);
      expect(tester.takeException(), isNull);
    });
  }

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

  testWidgets('used anonymous invite keeps token for authenticated recheck', (
    tester,
  ) async {
    final members = _Members();
    const used = FunctionException(
      status: 409,
      details: {'error': 'invite_used'},
    );
    var reads = 0;
    when(() => members.getInviteInfo('one')).thenAnswer((_) async {
      if (++reads == 1) throw used;
      return _info.copyWith(role: 'VIEWER');
    });
    when(
      () => members.acceptInvite('one'),
    ).thenAnswer((_) async => _accepted.copyWith(role: 'VIEWER'));
    final container = await _pump(tester, members, user: null, routed: true);
    await tester.pumpAndSettle();
    expect(find.text(_info.albumTitle), findsNothing);
    expect(find.textContaining('다른 사람이'), findsNothing);
    expect(find.text('로그인하고 확인하기'), findsOneWidget);
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(container.read(pendingAlbumInviteProvider)?.token, 'one');

    (container.read(authViewModelProvider.notifier) as _Auth).become(_user);
    await tester.pumpAndSettle();
    expect(reads, greaterThanOrEqualTo(2));
    expect(find.text(_info.albumTitle), findsOneWidget);
    expect(find.textContaining('편집 권한은 포함되지'), findsOneWidget);
    verifyNever(() => members.acceptInvite(any()));
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    expect(find.text('앨범 열기'), findsOneWidget);
    expect(container.read(pendingAlbumInviteProvider), isNull);
    verify(() => members.acceptInvite('one')).called(1);
  });

  testWidgets('used invite rejected after login remains close-only', (
    tester,
  ) async {
    final members = _Members();
    when(() => members.getInviteInfo('one')).thenThrow(
      const FunctionException(status: 409, details: {'error': 'invite_used'}),
    );
    final container = await _pump(tester, members, user: null, routed: true);
    await tester.pumpAndSettle();
    expect(find.text('로그인하고 확인하기'), findsOneWidget);
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    (container.read(authViewModelProvider.notifier) as _Auth).become(_user);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('이미 사용된 초대예요'), findsOneWidget);
    expect(find.text('로그인하고 확인하기'), findsNothing);
    expect(find.text('초대 닫기'), findsOneWidget);
    expect(find.text(_info.albumTitle), findsNothing);
    verifyNever(() => members.acceptInvite(any()));
  });

  testWidgets('delayed acceptance rechecks membership without resubmitting', (
    tester,
  ) async {
    final members = _Members();
    final accepted = Completer<InviteAcceptResponse>();
    final checked = Completer<InviteInfoResponse>();
    var reads = 0;
    when(() => members.getInviteInfo('one')).thenAnswer((_) {
      return ++reads == 1 ? Future.value(_info) : checked.future;
    });
    when(() => members.acceptInvite('one')).thenAnswer((_) => accepted.future);
    when(() => members.fetchMembers(7)).thenAnswer(
      (_) async => const [
        AlbumMemberResponse(
          id: 1,
          userId: 1,
          userUuid: 'one',
          role: 'VIEWER',
          status: 'ACCEPTED',
        ),
      ],
    );
    final container = await _pump(tester, members, routed: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_action));
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.text('참여 확인이 늦어지고 있어요'), findsOneWidget);
    expect(find.text('참여 상태 다시 확인'), findsOneWidget);
    expect(find.byKey(const ValueKey('inviteAcceptDismiss')), findsOneWidget);
    await tester.tap(find.byKey(_action));
    await tester.pump();
    await tester.tap(find.byKey(_action));
    await tester.pump();
    expect(reads, 2);
    checked.complete(_info.copyWith(role: 'VIEWER'));
    await tester.pumpAndSettle();
    expect(find.text('앨범 열기'), findsOneWidget);
    expect(find.textContaining('편집 권한은 포함되지'), findsOneWidget);
    expect(container.read(pendingAlbumInviteProvider), isNull);
    accepted.complete(_accepted);
    await tester.pumpAndSettle();
    expect(find.textContaining('편집 권한은 포함되지'), findsOneWidget);
    verify(() => members.acceptInvite('one')).called(1);
    verify(() => members.fetchMembers(7)).called(1);
  });

  testWidgets(
    'leaving delayed acceptance ignores a late success and stays closed',
    (tester) async {
      final members = _Members();
      final accepted = Completer<InviteAcceptResponse>();
      when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
      when(
        () => members.acceptInvite('one'),
      ).thenAnswer((_) => accepted.future);
      final container = await _pump(tester, members, routed: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_action));
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(find.byKey(const ValueKey('inviteAcceptDismiss')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('inviteAcceptDismiss')));
      await tester.pump();
      accepted.complete(_accepted);
      await tester.pumpAndSettle();
      expect(container.read(pendingAlbumInviteProvider), isNull);
      expect(find.text('기존 작업 화면'), findsOneWidget);
      expect(find.byType(AlbumInviteAcceptScreen), findsNothing);
      verify(() => members.acceptInvite('one')).called(1);
    },
  );

  testWidgets(
    'failed delayed recheck keeps recovery actions without accepting again',
    (tester) async {
      final members = _Members();
      final accepted = Completer<InviteAcceptResponse>();
      var reads = 0;
      when(() => members.getInviteInfo('one')).thenAnswer((_) async {
        if (++reads > 1) throw Exception('fixture connection');
        return _info;
      });
      when(
        () => members.acceptInvite('one'),
      ).thenAnswer((_) => accepted.future);
      await _pump(tester, members, routed: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_action));
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(find.text('참여 상태 다시 확인'), findsOneWidget);
      await tester.tap(find.byKey(_action));
      await tester.pumpAndSettle();
      expect(find.text('참여 상태 다시 확인'), findsOneWidget);
      expect(find.byKey(const ValueKey('inviteAcceptDismiss')), findsOneWidget);
      expect(find.text('초대 수락하기'), findsNothing);
      verify(() => members.acceptInvite('one')).called(1);
      accepted.completeError(Exception('fixture connection'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('account change discards a delayed membership check', (
    tester,
  ) async {
    final members = _Members();
    final accepted = Completer<InviteAcceptResponse>();
    final checked = Completer<List<AlbumMemberResponse>>();
    when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
    when(() => members.acceptInvite('one')).thenAnswer((_) => accepted.future);
    when(() => members.fetchMembers(7)).thenAnswer((_) => checked.future);
    final container = await _pump(tester, members);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_action));
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.text('참여 상태 다시 확인'), findsOneWidget);
    await tester.tap(find.byKey(_action));
    await tester.pump();
    (container.read(authViewModelProvider.notifier) as _Auth).become(
      _user.copyWith(id: 'two'),
    );
    checked.complete(const [
      AlbumMemberResponse(
        id: 1,
        userId: 1,
        userUuid: 'one',
        role: 'EDITOR',
        status: 'ACCEPTED',
      ),
    ]);
    accepted.complete(_accepted);
    await tester.pumpAndSettle();
    expect(find.text('앨범 열기'), findsNothing);
    expect(container.read(pendingAlbumInviteProvider)?.token, 'one');
    verify(() => members.acceptInvite('one')).called(1);
  });

  testWidgets(
    'acceptance timeout requires a state check before another acceptance',
    (tester) async {
      final members = _Members();
      when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
      when(
        () => members.acceptInvite('one'),
      ).thenThrow(TimeoutException('fixture'));
      await _pump(tester, members, routed: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_action));
      await tester.pumpAndSettle();
      expect(find.text('참여 상태 다시 확인'), findsOneWidget);
      expect(find.text('초대 수락하기'), findsNothing);
      expect(find.byKey(const ValueKey('inviteAcceptDismiss')), findsOneWidget);
      verify(() => members.acceptInvite('one')).called(1);
    },
  );

  testWidgets(
    'cold invitation survives first-visit introduction and stays above login',
    (tester) async {
      final members = _Members();
      when(() => members.getInviteInfo('one')).thenAnswer((_) async => _info);
      final container = await _pump(tester, members, user: null, splash: true);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(AlbumInviteAcceptScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();
      expect(container.read(pendingAlbumInviteProvider)?.token, 'one');
      // New installations legitimately visit the introduction before AuthGate.
      // The invite must survive that route and open after the user continues.
      await tester.tap(find.text('건너뛰기'));
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

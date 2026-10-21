import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_accept_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import 'package:snap_fit/features/album/service/album_invite_service.dart';
import 'package:snap_fit/features/album/service/pending_album_invite.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Members extends Mock implements AlbumMemberRepository {}

class _Albums extends Mock implements AlbumRepository {}

class _Auth extends AuthViewModel {
  _Auth(this.user);
  final UserInfo? user;

  @override
  FutureOr<UserInfo?> build() => user;

  void become(UserInfo? user) => state = AsyncData(user);
}

class _Home extends HomeViewModel {
  @override
  FutureOr<List<Album>> build() => [_book()];
}

const _user = UserInfo(
  id: 'sharing-review-owner',
  name: '지현',
  email: 'jihyun.family.album.records@example.com',
  provider: 'EMAIL',
);
const _userWithoutEmail = UserInfo(
  id: 'sharing-review-owner',
  name: '지현',
  provider: 'EMAIL',
);
const _title = '우리의 여름, 오래 간직할 장면들';
const _token = 'sharing-design-review';
const _editor = InviteLinkResponse(
  albumId: 7,
  token: 'sharing-editor',
  link: 'https://snapfit.example/invite/sharing-editor',
);
const _viewer = InviteLinkResponse(
  albumId: 7,
  token: 'sharing-viewer',
  link: 'https://snapfit.example/invite/sharing-viewer',
);

Album _book() => Album(
  id: 7,
  userId: _user.id,
  title: _title,
  ratio: '0.75',
  totalPages: 24,
  targetPages: 24,
  createdAt: '2026-10-14T10:00:00',
  coverLayersJson: jsonEncode({
    'pages': [
      {
        'index': 0,
        'isCover': true,
        'backgroundColor': 0xFFF2F1EB,
        'layers': [
          {
            'id': 'sharing-ocean-cover',
            'type': 'image',
            'x': 0.0,
            'y': 0.0,
            'width': 1.0,
            'height': 1.0,
            'rotation': 0.0,
            'payload': {
              'originalUrl': 'asset:assets/frame_preview/ocean_shore.jpg',
            },
            'zIndex': 0,
          },
        ],
      },
    ],
  }),
);

InviteInfoResponse _info(String role) => InviteInfoResponse(
  albumId: 7,
  albumTitle: _title,
  inviterName: '준혁',
  role: role,
);

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  late _Members members;
  late _Albums albums;
  final copied = <String>[];
  final shares = <({String link, String title, String? description})>[];
  final opened = <Album>[];

  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await loadCreationFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    copied.clear();
    shares.clear();
    opened.clear();
    members = _Members();
    albums = _Albums();
    when(
      () => members.invite(7, role: 'EDITOR'),
    ).thenAnswer((_) async => _editor);
    when(
      () => members.invite(7, role: 'VIEWER'),
    ).thenAnswer((_) async => _viewer);
    when(
      () => members.getInviteInfo(_token),
    ).thenAnswer((_) async => _info('VIEWER'));
    when(() => members.acceptInvite(_token)).thenAnswer(
      (_) async =>
          const InviteAcceptResponse(albumId: 7, role: 'VIEWER', success: true),
    );
    when(() => albums.fetchAlbum('7')).thenAnswer((_) async => _book());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Finder key(String name) => find.byKey(ValueKey(name));
  Finder cover() => find.byWidgetPredicate(
    (widget) => widget is HomeAlbumCoverThumbnail && widget.album.id == 7,
  );

  void metrics(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = size.width > size.height
        ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
        : const FakeViewPadding(top: 24, bottom: 34);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
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

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    bool accept = false,
    bool editor = true,
    bool dark = false,
    double scale = 1.3,
    UserInfo? user = _user,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [
        albumMemberRepositoryProvider.overrideWithValue(members),
        albumRepositoryProvider.overrideWithValue(albums),
        authViewModelProvider.overrideWith(() => _Auth(user)),
        homeViewModelProvider.overrideWith(_Home.new),
        kakaoInviteShareProvider.overrideWithValue(({
          required inviteLink,
          required albumTitle,
          description,
        }) async {
          shares.add((
            link: inviteLink,
            title: albumTitle,
            description: description,
          ));
          return true;
        }),
        invitedAlbumOpenProvider.overrideWithValue((_, __, album) async {
          opened.add(album);
        }),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(pendingAlbumInviteProvider.notifier)
        .receive(Uri.parse('snapfit://invite?token=$_token'));
    final invite = container.read(pendingAlbumInviteProvider)!;
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
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: accept
                ? AlbumInviteAcceptScreen(invite: invite)
                : AlbumInviteScreen(
                    albumId: 7,
                    albumTitle: _title,
                    album: _book(),
                    initialAllowEditing: editor,
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
    return container;
  }

  void safe(WidgetTester tester, Finder finder, Size size) {
    final rect = tester.getRect(finder);
    final wide = size.width > size.height;
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(wide ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (wide ? 48 : 0)));
    expect(rect.top, greaterThanOrEqualTo(wide ? 0 : 24));
    expect(rect.bottom, lessThanOrEqualTo(size.height - (wide ? 24 : 34) + 1));
    expect(finder.hitTestable(), findsOneWidget);
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark, {
    bool pending = false,
  }) async {
    if (pending) {
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('ALBUM_SHARING_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'output/all-screens-qa/album-sharing-$name-'
        '${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'album sharing displays its real cover and role at $size dark=$dark',
        (tester) async {
          reset(tester);
          metrics(tester, size);
          final editor = size.width < size.height;
          await mount(tester, dark: dark, editor: editor);
          expect(cover(), findsOneWidget);
          final artwork = tester.widget<HomeAlbumCoverThumbnail>(cover());
          expect(artwork.album.ratio, '0.75');
          expect(artwork.album.coverLayersJson, contains('ocean_shore.jpg'));
          expect(artwork.showBookDepth, true);
          expect(find.text(_title), findsOneWidget);
          expect(
            tester.widget<Switch>(find.byType(Switch).first).value,
            editor,
          );
          safe(tester, key('inviteCopy'), size);
          safe(tester, key('inviteShare'), size);
          await capture(
            tester,
            editor ? 'send-editor' : 'send-viewer',
            size,
            dark,
          );
          final link = editor ? _editor.link : _viewer.link;
          await tap(tester, key('inviteCopy'));
          expect(copied, [link]);
          expect(find.text('링크 복사 완료'), findsOneWidget);
          await tap(tester, key('inviteShare'));
          expect(shares.single.link, link);
          expect(shares.single.title, _title);
          expect(shares.single.description, contains(editor ? '편집' : '감상'));
          verify(
            () => members.invite(7, role: editor ? 'EDITOR' : 'VIEWER'),
          ).called(1);

          final role = dark ? 'VIEWER' : 'EDITOR';
          when(
            () => members.getInviteInfo(_token),
          ).thenAnswer((_) async => _info(role));
          when(() => members.acceptInvite(_token)).thenAnswer(
            (_) async =>
                InviteAcceptResponse(albumId: 7, role: role, success: true),
          );
          final container = await mount(tester, accept: true, dark: dark);
          expect(find.text(_title), findsOneWidget);
          expect(
            find.text(role == 'VIEWER' ? '앨범 보기' : '함께 편집'),
            findsOneWidget,
          );
          expect(
            tester.widget<SelectableText>(key('inviteAcceptAccountEmail')).data,
            _user.email,
          );
          safe(tester, key('inviteAcceptAction'), size);
          safe(tester, key('inviteAcceptDismiss'), size);
          verifyNever(() => members.acceptInvite(_token));
          if ((size.width == 390 && !dark) || (size.width == 844 && dark)) {
            await capture(
              tester,
              role == 'VIEWER' ? 'accept-viewer' : 'accept-editor',
              size,
              dark,
            );
          }
          await tap(tester, key('inviteAcceptAction'));
          expect(find.text('앨범 열기'), findsOneWidget);
          expect(container.read(pendingAlbumInviteProvider), isNull);
          expect(opened, isEmpty);
          verify(() => members.acceptInvite(_token)).called(1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in [const Size(320, 568), const Size(648, 320)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'large text sharing keeps artwork and actions reachable at $size dark=$dark',
        (tester) async {
          reset(tester);
          metrics(tester, size);
          await mount(tester, editor: false, dark: dark, scale: 1.8);
          expect(cover(), findsOneWidget);
          safe(tester, key('inviteCopy'), size);
          safe(tester, key('inviteShare'), size);
          await tap(tester, key('inviteCopy'));
          expect(copied, [_viewer.link]);
          if (dark) await capture(tester, 'send-viewer-large', size, dark);
          await mount(
            tester,
            accept: true,
            user: dark ? _user : null,
            dark: dark,
            scale: 1.8,
          );
          expect(find.text(dark ? '초대 수락하기' : '로그인하고 참여하기'), findsOneWidget);
          if (dark) {
            expect(
              tester
                  .widget<SelectableText>(key('inviteAcceptAccountEmail'))
                  .data,
              _user.email,
            );
            await tester.ensureVisible(key('inviteAcceptAccountEmail'));
            await tester.pumpAndSettle();
            expect(
              key('inviteAcceptAccountEmail').hitTestable(),
              findsOneWidget,
            );
          } else {
            expect(key('inviteAcceptAccountEmail'), findsNothing);
          }
          safe(tester, key('inviteAcceptAction'), size);
          safe(tester, key('inviteAcceptDismiss'), size);
          if (!dark && size.width == 320) {
            await capture(tester, 'accept-logged-out-large', size, dark);
          }
          await tester.ensureVisible(find.text('앨범 보기'));
          await tester.pumpAndSettle();
          expect(find.text('앨범 보기').hitTestable(), findsOneWidget);
          verifyNever(() => members.acceptInvite(_token));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'regenerating a role through rotation never exposes a stale share link',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester, dark: true);
      await tap(tester, key('inviteCopy'));
      final viewer = Completer<InviteLinkResponse>();
      when(
        () => members.invite(7, role: 'VIEWER'),
      ).thenAnswer((_) => viewer.future);
      await tap(tester, find.byType(Switch).first, settle: false);
      expect(find.text(_editor.link), findsNothing);
      expect(find.text('링크 복사 완료'), findsNothing);
      expect(
        tester.widget<OutlinedButton>(key('inviteCopy')).onPressed,
        isNull,
      );
      expect(tester.widget<FilledButton>(key('inviteShare')).onPressed, isNull);
      metrics(tester, const Size(648, 320));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Switch>(find.byType(Switch).first).value, false);
      safe(tester, key('inviteCopy'), const Size(648, 320));
      safe(tester, key('inviteShare'), const Size(648, 320));
      await capture(
        tester,
        'link-regenerating',
        const Size(648, 320),
        true,
        pending: true,
      );
      viewer.completeError(StateError('fixture network unavailable'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('초대 링크 다시 만들기'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<OutlinedButton>(key('inviteCopy')).onPressed,
        isNull,
      );
      expect(find.textContaining('fixture'), findsNothing);
      await capture(tester, 'link-retry', const Size(648, 320), true);
      when(
        () => members.invite(7, role: 'VIEWER'),
      ).thenAnswer((_) async => _viewer);
      await tap(tester, find.byTooltip('초대 링크 다시 만들기'));
      await tap(tester, key('inviteCopy'));
      expect(copied, [_editor.link, _viewer.link]);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login returns to the same viewer invitation without accepting automatically',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final container = await mount(tester, accept: true, user: null);
      expect(key('inviteAcceptAccountEmail'), findsNothing);
      await capture(
        tester,
        'login-before-joining',
        const Size(390, 844),
        false,
      );
      await tap(tester, key('inviteAcceptAction'));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(container.read(pendingAlbumInviteProvider)?.token, _token);
      metrics(tester, const Size(844, 390));
      await tester.pumpAndSettle();
      (container.read(authViewModelProvider.notifier) as _Auth).become(_user);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text(_title), findsOneWidget);
      expect(find.text('앨범 보기'), findsOneWidget);
      expect(find.text('초대 수락하기'), findsOneWidget);
      expect(container.read(pendingAlbumInviteProvider)?.token, _token);
      verifyNever(() => members.acceptInvite(_token));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'joined permissions and retry remain intact when the accepted album cannot open',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      when(
        () => members.getInviteInfo(_token),
      ).thenAnswer((_) async => _info('EDITOR'));
      when(
        () => albums.fetchAlbum('7'),
      ).thenThrow(StateError('fixture unavailable'));
      final container = await mount(tester, accept: true, dark: true);
      expect(find.text('함께 편집'), findsOneWidget);
      await tap(tester, key('inviteAcceptAction'));
      expect(find.text('앨범 보기'), findsOneWidget);
      expect(find.text('함께 편집'), findsNothing);
      await tap(tester, key('inviteAcceptAction'));
      expect(find.textContaining('참여는 완료되었어요'), findsOneWidget);
      expect(find.textContaining('fixture'), findsNothing);
      expect(container.read(pendingAlbumInviteProvider), isNull);
      metrics(tester, const Size(844, 390));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('참여는 완료되었어요'));
      await tester.pumpAndSettle();
      safe(tester, key('inviteAcceptAction'), const Size(844, 390));
      await capture(tester, 'joined-open-retry', const Size(844, 390), true);
      when(() => albums.fetchAlbum('7')).thenAnswer((_) async => _book());
      await tap(tester, key('inviteAcceptAction'));
      expect(opened.single.id, 7);
      verify(() => members.acceptInvite(_token)).called(1);
      verify(() => albums.fetchAlbum('7')).called(2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expired and retryable invitation failures offer the matching recovery',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(320, 568));
      when(
        () => members.getInviteInfo(_token),
      ).thenAnswer((_) async => _info('EDITOR'));
      when(
        () => members.acceptInvite(_token),
      ).thenThrow(const FunctionException(status: 410));
      await mount(tester, accept: true, dark: true, scale: 1.8);
      await tester.ensureVisible(key('inviteAcceptAccountEmail'));
      await tester.pumpAndSettle();
      expect(key('inviteAcceptAccountEmail').hitTestable(), findsOneWidget);
      await tap(tester, key('inviteAcceptAction'));
      expect(find.text('초대 기간이 지났어요'), findsOneWidget);
      final viewport = tester.getRect(key('inviteAcceptContent'));
      for (final error in [
        find.text('초대 기간이 지났어요'),
        find.text('앨범을 만든 사람에게 새 초대 링크를 요청해 주세요.'),
      ]) {
        expect(
          error.hitTestable(),
          findsOneWidget,
          reason: '수락 전에 계정까지 스크롤했어도 만료 사유가 바로 보여야 합니다.',
        );
        final rect = tester.getRect(error);
        expect(rect.top, greaterThanOrEqualTo(viewport.top));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(rect.left, greaterThanOrEqualTo(viewport.left));
        expect(rect.right, lessThanOrEqualTo(viewport.right));
      }
      expect(
        tester.getTopLeft(find.text('초대 기간이 지났어요')).dy,
        lessThan(tester.getTopLeft(find.text('함께 편집')).dy),
      );
      expect(
        tester.getTopLeft(find.text('초대 기간이 지났어요')).dy,
        lessThan(tester.getTopLeft(key('inviteAcceptAccountEmail')).dy),
      );
      expect(find.text('초대 닫기'), findsOneWidget);
      expect(key('inviteAcceptDismiss'), findsNothing);
      safe(tester, key('inviteAcceptAction'), const Size(320, 568));
      await tester.ensureVisible(find.text('초대 기간이 지났어요'));
      await tester.pumpAndSettle();
      await capture(tester, 'expired-large', const Size(320, 568), true);
      verify(() => members.acceptInvite(_token)).called(1);
      clearInteractions(members);

      when(
        () => members.getInviteInfo(_token),
      ).thenThrow(StateError('fixture offline'));
      await mount(
        tester,
        accept: true,
        dark: true,
        scale: 1.8,
        user: _userWithoutEmail,
      );
      expect(key('inviteAcceptAccountEmail'), findsNothing);
      expect(find.text('잠시 연결이 어려워요'), findsOneWidget);
      expect(find.text('다시 확인하기'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(key('inviteAcceptAction')).onPressed,
        isNull,
      );
      when(
        () => members.getInviteInfo(_token),
      ).thenAnswer((_) async => _info('VIEWER'));
      await tap(tester, find.text('다시 확인하기'));
      expect(find.text(_title), findsOneWidget);
      expect(find.text('앨범 보기'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(key('inviteAcceptAction')).onPressed,
        isNotNull,
      );
      verifyNever(() => members.acceptInvite(_token));
      expect(tester.takeException(), isNull);
    },
  );
}

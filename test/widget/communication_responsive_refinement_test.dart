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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/commerce/commerce_policy.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_accept_response.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_info_response.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_accept_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_screen.dart';
import 'package:snap_fit/features/album/service/album_invite_service.dart';
import 'package:snap_fit/features/album/service/pending_album_invite.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/notification/domain/entities/app_notification_item.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/notification/presentation/views/notification_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/terms_policy_screen.dart';

import '../helpers/fake_album.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Members extends Mock implements AlbumMemberRepository {}

class _Action extends Mock implements NotificationAction {}

class _Auth extends AuthViewModel {
  _Auth(this.user);
  final UserInfo? user;
  @override
  FutureOr<UserInfo?> build() => user;
}

class _Home extends HomeViewModel {
  @override
  FutureOr<List<Album>> build() => const [];
}

const _user = UserInfo(
  id: 'communication-review',
  name: '지현',
  provider: 'EMAIL',
);
const _title = '우리의 여름, 오래 간직할 장면들';
final _privacyDocument = CommercePolicy.document(CommercePolicyKind.privacy);
const _link = InviteLinkResponse(
  albumId: 7,
  token: 'review-editor',
  link: 'https://snapfit.example/invite/review-editor',
);
const _info = InviteInfoResponse(
  albumId: 7,
  albumTitle: _title,
  inviterName: '준혁',
  role: 'VIEWER',
);
const _accepted = InviteAcceptResponse(
  albumId: 7,
  role: 'VIEWER',
  success: true,
);
final _invite = PendingAlbumInvite('communication-review', DateTime.now());

_Members _members() {
  final members = _Members();
  when(() => members.invite(7, role: 'EDITOR')).thenAnswer((_) async => _link);
  when(() => members.invite(7, role: 'VIEWER')).thenAnswer(
    (_) async => _link.copyWith(
      token: 'review-viewer',
      link: 'https://snapfit.example/invite/review-viewer',
    ),
  );
  when(
    () => members.getInviteInfo(_invite.token),
  ).thenAnswer((_) async => _info);
  when(
    () => members.acceptInvite(_invite.token),
  ).thenAnswer((_) async => _accepted);
  return members;
}

_Action _action() {
  final action = _Action();
  when(action.markAllRead).thenAnswer((_) async {});
  when(() => action.markRead(any())).thenAnswer((_) async {});
  return action;
}

Album _book() => fakeAlbum(
  id: 7,
  ratio: '1',
  coverLayersJson: jsonEncode({
    'pages': [
      {
        'index': 0,
        'isCover': true,
        'layers': [
          {
            'id': 'communication-cover',
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

List<AppNotificationItem> _items({int count = 8, bool sameDay = false}) =>
    List.generate(count, (index) {
      const titles = [
        '함께 남긴 여름 기록',
        '앨범에 새 댓글이 남았어요',
        '새로운 여행 컬렉션',
        '주문한 앨범의 제작 소식',
      ];
      const types = [
        'album_invite',
        'album_comment',
        'template_new',
        'order_status',
      ];
      return AppNotificationItem(
        id: index + 1,
        type: types[index % 4],
        title: '${titles[index % 4]} ${index + 1}',
        body: '오래 간직할 장면을 한 권에 모았어요. 함께한 기록의 새로운 소식을 확인해 보세요.',
        createdAt: sameDay
            ? DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
                12,
              ).subtract(Duration(seconds: index))
            : DateTime.now().subtract(Duration(minutes: index * 20)),
        isRead: index.isOdd,
        userId: _user.id,
      );
    });

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  setUpAll(loadCreationFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  void metrics(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = size.width > size.height
        ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
        : const FakeViewPadding(top: 24, bottom: 34);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
  }

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    _Members? members,
    _Action? action,
    Future<List<AppNotificationItem>> Function()? inbox,
    UserInfo? user = _user,
    bool dark = false,
    double scale = 1.3,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          albumMemberRepositoryProvider.overrideWithValue(
            members ?? _members(),
          ),
          kakaoInviteShareProvider.overrideWithValue(
            ({required inviteLink, required albumTitle, description}) async =>
                true,
          ),
          authViewModelProvider.overrideWith(() => _Auth(user)),
          homeViewModelProvider.overrideWith(_Home.new),
          invitedAlbumOpenProvider.overrideWithValue((_, __, ___) async {}),
          notificationInboxProvider.overrideWith(
            (ref) => inbox?.call() ?? Future.value(_items()),
          ),
          notificationRetentionDaysProvider.overrideWith((ref) async => 90),
          notificationActionProvider.overrideWithValue(action ?? _action()),
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

  void safe(WidgetTester tester, Finder finder, Size size) {
    final rect = tester.getRect(finder);
    final landscape = size.width > size.height;
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(landscape ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (landscape ? 48 : 0)));
    expect(rect.bottom, lessThanOrEqualTo(size.height - (landscape ? 24 : 34)));
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark,
  ) async {
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('COMMUNICATION_RESPONSIVE_QA')) return;
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

  Finder key(String value) => find.byKey(ValueKey(value));
  Finder inboxScroll() => find
      .descendant(
        of: find.byKey(const PageStorageKey('inbox-list')),
        matching: find.byType(Scrollable),
      )
      .first;

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('invite and inbox layouts remain safe at $size dark=$dark', (
        tester,
      ) async {
        reset(tester);
        metrics(tester, size);
        final members = _members();
        await mount(
          tester,
          AlbumInviteScreen(albumId: 7, albumTitle: _title, album: _book()),
          members: members,
          dark: dark,
        );
        safe(tester, key('inviteCopy'), size);
        safe(tester, key('inviteShare'), size);
        expect(tester.getSize(key('inviteContent')).height, greaterThan(80));
        await capture(tester, 'communication-invite', size, dark);
        when(
          () => members.invite(7, role: 'VIEWER'),
        ).thenThrow(Exception('private network details'));
        await tap(tester, find.byType(Switch));
        expect(
          tester.widget<OutlinedButton>(key('inviteCopy')).onPressed,
          isNull,
        );
        expect(find.textContaining('private network'), findsNothing);
        await tester.ensureVisible(find.byTooltip('초대 링크 다시 만들기'));
        await tester.pumpAndSettle();
        await capture(tester, 'communication-invite-error', size, dark);

        await mount(
          tester,
          AlbumInviteAcceptScreen(invite: _invite),
          members: members,
          dark: dark,
        );
        safe(tester, key('inviteAcceptAction'), size);
        safe(tester, key('inviteAcceptDismiss'), size);
        verifyNever(() => members.acceptInvite(_invite.token));
        await capture(tester, 'communication-accept', size, dark);
        await tap(tester, key('inviteAcceptAction'));
        expect(find.text('앨범 열기'), findsOneWidget);
        expect(find.text('함께 편집'), findsNothing);
        await capture(tester, 'communication-joined', size, dark);
        when(
          () => members.getInviteInfo(_invite.token),
        ).thenThrow(const FunctionException(status: 410));
        await mount(
          tester,
          AlbumInviteAcceptScreen(invite: _invite),
          members: members,
          dark: dark,
        );
        expect(find.text('초대 기간이 지났어요'), findsOneWidget);
        safe(tester, key('inviteAcceptAction'), size);
        await capture(tester, 'communication-expired', size, dark);

        await mount(tester, const NotificationScreen(), dark: dark);
        safe(tester, key('inbox-mark-all'), size);
        await capture(tester, 'communication-inbox', size, dark);
        await tester.scrollUntilVisible(
          key('inbox-item-8'),
          150,
          scrollable: inboxScroll(),
        );
        await tester.pumpAndSettle();
        await capture(tester, 'communication-inbox-bottom', size, dark);
        await mount(
          tester,
          const NotificationScreen(),
          dark: dark,
          inbox: () async => throw Exception('private request failed'),
        );
        await tester.ensureVisible(key('inbox-retry'));
        await tester.pumpAndSettle();
        safe(tester, key('inbox-retry'), size);
        expect(
          tester.widget<TextButton>(key('inbox-mark-all')).onPressed,
          isNull,
        );
        await capture(tester, 'communication-inbox-error', size, dark);
        await mount(
          tester,
          const NotificationScreen(),
          dark: dark,
          inbox: () async => [],
        );
        expect(
          tester.widget<TextButton>(key('inbox-mark-all')).onPressed,
          isNull,
        );
        await capture(tester, 'communication-inbox-empty', size, dark);

        await mount(
          tester,
          const TermsPolicyScreen(initialDocType: TermsPolicyDocType.privacy),
          dark: dark,
        );
        await capture(tester, 'communication-policy', size, dark);
        await tester.scrollUntilVisible(
          find.text(_privacyDocument.sections.last.heading),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text(_privacyDocument.sections.last.content),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets(
      'large text and long invite titles retain usable content at $size',
      (tester) async {
        reset(tester);
        metrics(tester, size);
        final members = _members();
        await mount(
          tester,
          AlbumInviteScreen(
            albumId: 7,
            albumTitle: '아주 긴 제목을 가진 우리의 여름, 오래 간직할 장면들',
            album: _book(),
          ),
          members: members,
          dark: true,
          scale: 1.8,
        );
        await tap(tester, key('inviteCopy'));
        expect(find.text('링크 복사 완료'), findsOneWidget);
        safe(tester, key('inviteCopy'), size);
        safe(tester, key('inviteShare'), size);
        expect(tester.getSize(key('inviteContent')).height, greaterThan(80));
        await mount(
          tester,
          AlbumInviteAcceptScreen(invite: _invite),
          members: members,
          user: null,
          dark: true,
          scale: 1.8,
        );
        safe(tester, key('inviteAcceptAction'), size);
        safe(tester, key('inviteAcceptDismiss'), size);
        await mount(tester, const NotificationScreen(), dark: true, scale: 1.8);
        safe(tester, key('inbox-mark-all'), size);
        await tester.scrollUntilVisible(
          key('inbox-item-8'),
          150,
          scrollable: inboxScroll(),
        );
        await tester.pumpAndSettle();
        await mount(
          tester,
          const TermsPolicyScreen(initialDocType: TermsPolicyDocType.privacy),
          dark: true,
          scale: 1.8,
        );
        await tester.scrollUntilVisible(
          find.text(_privacyDocument.sections.last.heading),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'copy result, permission and accepted viewer state survive rotation',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final members = _members();
      await mount(
        tester,
        AlbumInviteScreen(albumId: 7, albumTitle: _title, album: _book()),
        members: members,
      );
      await tap(tester, find.byType(Switch));
      await tap(tester, key('inviteCopy'));
      metrics(tester, const Size(648, 320));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text('링크 복사 완료'), findsOneWidget);
      await mount(
        tester,
        AlbumInviteAcceptScreen(invite: _invite),
        members: members,
      );
      await tap(tester, key('inviteAcceptAction'));
      metrics(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(find.text('앨범 열기'), findsOneWidget);
      expect(find.text('앨범 보기'), findsOneWidget);
      expect(find.text('함께 편집'), findsNothing);
      verify(() => members.invite(7, role: 'VIEWER')).called(1);
      verify(() => members.acceptInvite(_invite.token)).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inbox lazily builds one date group and preserves scroll through rotation',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(648, 320));
      await mount(
        tester,
        const NotificationScreen(),
        inbox: () async => _items(count: 80, sameDay: true),
      );
      expect(key('inbox-item-80'), findsNothing);
      expect(find.text('오늘'), findsOneWidget);
      expect(find.byType(ListTile).evaluate().length, lessThan(15));
      await tester.scrollUntilVisible(
        key('inbox-item-80'),
        250,
        scrollable: inboxScroll(),
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      expect(key('inbox-item-80'), findsOneWidget);
      metrics(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(inboxScroll()).position.pixels,
        greaterThan(1000),
      );
      expect(key('inbox-item-1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all-read is single-flight across rotation and failure offers another attempt',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final action = _action();
      final pending = Completer<void>();
      when(action.markAllRead).thenAnswer((_) => pending.future);
      await mount(tester, const NotificationScreen(), action: action);
      final queued = tester
          .widget<TextButton>(key('inbox-mark-all'))
          .onPressed!;
      queued();
      queued();
      await tester.pump();
      metrics(tester, const Size(648, 320));
      await tester.pump();
      expect(
        tester.widget<TextButton>(key('inbox-mark-all')).onPressed,
        isNull,
      );
      verify(action.markAllRead).called(1);
      pending.completeError(Exception('fixture offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('읽음 처리를 완료하지 못했어요'), findsOneWidget);
      when(action.markAllRead).thenAnswer((_) async {});
      await tap(tester, key('inbox-mark-all'));
      verify(action.markAllRead).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closed inbox rejects a late all-read callback and empty inbox stays disabled',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final action = _action();
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationScreen(),
                ),
              ),
              child: const Text('알림 열기'),
            ),
          ),
        ),
        action: action,
      );
      await tap(tester, find.text('알림 열기'));
      final queued = tester
          .widget<TextButton>(key('inbox-mark-all'))
          .onPressed!;
      Navigator.of(tester.element(key('inbox-mark-all'))).pop();
      await tester.pumpAndSettle();
      queued();
      await tester.pump();
      verifyNever(action.markAllRead);
      await mount(
        tester,
        const NotificationScreen(),
        action: action,
        inbox: () async =>
            _items().map((item) => item.copyWith(isRead: true)).toList(),
      );
      expect(
        tester.widget<TextButton>(key('inbox-mark-all')).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

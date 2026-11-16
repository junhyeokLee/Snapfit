// 현재 초대 UI만 재현한다. 저장소·계정은 모두 로컬 대역이며 외부 요청은 없다.
import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'audit_support.dart';

class _Members extends Mock implements AlbumMemberRepository {}

class _Albums extends Mock implements AlbumRepository {}

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

const _token = 'previously-accepted-local-fixture';
const _user = UserInfo(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'jihyun@example.invalid',
  name: '지현',
  provider: 'email',
);
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
const _dismiss = ValueKey('inviteAcceptDismiss');

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Members members, {
  UserInfo? user = _user,
}) async {
  final container = ProviderContainer(
    overrides: [
      albumMemberRepositoryProvider.overrideWithValue(members),
      // 이번 probe에서는 실제 앨범 열기를 누르지 않는다. 우발적 접근도 SDK로 흐르지 않는다.
      albumRepositoryProvider.overrideWithValue(_Albums()),
      authViewModelProvider.overrideWith(() => _Auth(user)),
      homeViewModelProvider.overrideWith(_Home.new),
      invitedAlbumOpenProvider.overrideWithValue((_, __, ___) async {}),
    ],
  );
  container
      .read(pendingAlbumInviteProvider.notifier)
      .receive(Uri.parse('snapfit://invite?token=$_token'));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: SnapFitTheme.light(),
          builder: (context, child) => auditFrame(child!),
          home: const AlbumInviteRouter(
            child: Scaffold(body: Center(child: Text('로컬 감사 이전 화면'))),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _unmount(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  container.dispose();
}

void main() {
  setUpAll(auditFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('consumed invite has no signed-out login recovery', (
    tester,
  ) async {
    auditViewport(tester);
    final anonymous = _Members();
    when(() => anonymous.getInviteInfo(_token)).thenThrow(
      const FunctionException(status: 409, details: {'error': 'invite_used'}),
    );
    final signedOut = await _mount(tester, anonymous, user: null);
    try {
      expect(find.text('이미 사용된 초대예요'), findsOneWidget);
      expect(find.text('다른 사람이 참여한 링크예요. 새 초대 링크를 요청해 주세요.'), findsOneWidget);
      expect(find.text('초대 닫기'), findsOneWidget);
      expect(find.text('로그인하고 참여하기'), findsNothing);
      expect(find.text('다시 확인하기'), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byKey(_dismiss), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(_action)).onPressed,
        isNotNull,
      );
      verifyNever(() => anonymous.acceptInvite(any()));
      await auditCapture(tester, '10-invite-used-signed-out-no-login');
    } finally {
      await _unmount(tester, signedOut);
    }

    // 11번은 10번의 버튼으로 전환한 화면이 아니다. 서버가 원래 수락자의
    // 로그인 상태에서 정보를 정상 반환하는 별도 fixture임을 구분한다.
    final originalMember = _Members();
    when(() => originalMember.getInviteInfo(_token))
        .thenAnswer((_) async => _info);
    final signedIn = await _mount(tester, originalMember);
    try {
      expect(find.text(_info.albumTitle), findsOneWidget);
      expect(find.text('지현 계정으로 참여'), findsOneWidget);
      expect(find.text('초대 수락하기'), findsOneWidget);
      expect(find.text('이미 사용된 초대예요'), findsNothing);
      verifyNever(() => originalMember.acceptInvite(any()));
      await auditCapture(
        tester,
        '11-invite-original-member-signed-in-separate-fixture',
      );
    } finally {
      await _unmount(tester, signedIn);
    }
  });

  testWidgets('pending acceptance still traps navigation after 31 seconds', (
    tester,
  ) async {
    auditViewport(tester);
    final members = _Members();
    final pending = Completer<InviteAcceptResponse>();
    when(() => members.getInviteInfo(_token)).thenAnswer((_) async => _info);
    when(() => members.acceptInvite(_token)).thenAnswer((_) => pending.future);
    final container = await _mount(tester, members);
    try {
      await tester.tap(find.byKey(_action));
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      expect(pending.isCompleted, isFalse);
      expect(find.text('참여하는 중'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(_action)).onPressed,
        isNull,
      );
      expect(find.byKey(_dismiss), findsNothing);
      expect(find.text('초대 닫기'), findsNothing);
      final screen = find.byType(AlbumInviteAcceptScreen);
      final screenContext = tester.element(screen);
      final route = ModalRoute.of(screenContext)!;
      expect(route.isCurrent, isTrue);

      // maybePop은 veto된 요청에도 true(처리됨)를 반환한다. 반환값 대신
      // 실제 초대 route가 그대로인지 확인해야 뒤로가기 차단을 검증할 수 있다.
      await Navigator.of(screenContext).maybePop();
      await tester.pump();
      expect(screen, findsOneWidget);
      expect(route.isCurrent, isTrue);
      expect(
        find
            .descendant(
              of: screen,
              matching: find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .evaluate()
            .map((element) => (element.widget as PopScope).canPop),
        contains(false),
      );
      tester.widget<ExperienceHeader>(find.byType(ExperienceHeader)).onBack!();
      await tester.pump();
      expect(screen, findsOneWidget);
      expect(route.isCurrent, isTrue);
      expect(pending.isCompleted, isFalse);
      expect(container.read(pendingAlbumInviteProvider)?.token, _token);
      verify(() => members.acceptInvite(_token)).called(1);
      await auditCapture(
        tester,
        '12-invite-accept-pending-31s-no-dismiss',
        settle: false,
      );
    } finally {
      // 가짜 future를 해소한 뒤 화면을 정리해 다음 직렬 캡처에 영향을 남기지 않는다.
      if (!pending.isCompleted) pending.complete(_accepted);
      await tester.pumpAndSettle();
      await _unmount(tester, container);
    }
  });
}

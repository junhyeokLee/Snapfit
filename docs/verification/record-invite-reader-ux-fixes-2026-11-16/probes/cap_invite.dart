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

import 'capture_support.dart';
import 'package:snap_fit/features/album/data/dto/album_member_response.dart';

class _Members extends Mock implements AlbumMemberRepository {}

class _Albums extends Mock implements AlbumRepository {}

class _Auth extends AuthViewModel {
  _Auth(this.user);
  final UserInfo? user;

  @override
  FutureOr<UserInfo?> build() => user;
  void become(UserInfo? value) => state = AsyncData(value);
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
  testWidgets('capture used invite login and recheck', (tester) async {
    auditViewport(tester);
    final members=_Members(); var reads=0;
    when(()=>members.getInviteInfo(_token)).thenAnswer((_) async {
      if (++reads==1) throw const FunctionException(status:409,details:{'error':'invite_used'});
      return _info.copyWith(role:'VIEWER');
    });
    final c=await _mount(tester,members,user:null);
    try {
      expect(find.text('로그인하고 확인하기'),findsOneWidget);
      expect(find.textContaining('다른 사람이'),findsNothing);
      await auditCapture(tester,'04-invite-used-offers-login-recheck');
      await tester.tap(find.byKey(_action));await tester.pumpAndSettle();
      expect(find.byType(LoginScreen),findsOneWidget);
      (c.read(authViewModelProvider.notifier) as _Auth).become(_user);
      await tester.pumpAndSettle();
      expect(reads,greaterThanOrEqualTo(2));
      expect(find.text(_info.albumTitle),findsOneWidget);
      verifyNever(()=>members.acceptInvite(any()));
      await auditCapture(tester,'05-invite-authenticated-rechecked-details');
    } finally {await _unmount(tester,c);}
  });
  testWidgets('capture delayed invite and verified participation', (tester) async {
    auditViewport(tester);
    final members=_Members();final pending=Completer<InviteAcceptResponse>();
    when(()=>members.getInviteInfo(_token)).thenAnswer((_) async=>_info);
    when(()=>members.acceptInvite(_token)).thenAnswer((_)=>pending.future);
    when(()=>members.fetchMembers(7)).thenAnswer((_) async=>const [
      AlbumMemberResponse(id:1,userId:1,userUuid:'11111111-1111-4111-8111-111111111111',role:'VIEWER',status:'ACCEPTED'),
    ]);
    final c=await _mount(tester,members);
    try {
      await tester.tap(find.byKey(_action)); await tester.pump(const Duration(seconds:31)); await tester.pump();
      expect(find.text('참여 상태 다시 확인'),findsOneWidget);
      expect(find.byKey(_dismiss),findsOneWidget);
      await auditCapture(tester,'06-invite-delayed-recheck-and-leave');
      await tester.tap(find.byKey(_action));await tester.pumpAndSettle();
      expect(find.text('앨범 열기'),findsOneWidget);
      expect(c.read(pendingAlbumInviteProvider),isNull);
      await auditCapture(tester,'07-invite-participation-confirmed');
      verify(()=>members.acceptInvite(_token)).called(1);
    } finally {
      if (!pending.isCompleted) pending.complete(_accepted);
      await tester.pumpAndSettle();await _unmount(tester,c);
    }
  });
}

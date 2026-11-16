// REPRO의 PASS는 초대 복귀 시 자동 갱신 없음의 재현이며 개선 완료가 아니다.
// 짧은 목록과 긴 목록 모두 실제 당김 새로고침이 정상인지 함께 확인한다.
// 저장소와 계정은 메모리 대역이며 실제 초대·공유·운영 요청은 실행하지 않는다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/album_member_response.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_members_screen.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';

import 'audit_support.dart';

const _album = Album(
  id: 7,
  userId: 'owner-uuid',
  title: '함께 남긴 여행 기록',
  ratio: '1:1',
  memberRole: 'OWNER',
);

const _owner = AlbumMemberResponse(
  id: 1,
  userId: 11,
  userUuid: 'owner-uuid',
  userName: '소유자',
  isOwner: true,
  role: 'OWNER',
  status: 'ACCEPTED',
);

const _editor = AlbumMemberResponse(
  id: 2,
  userId: 22,
  userUuid: 'editor-uuid',
  userName: '함께 편집하는 친구',
  role: 'EDITOR',
  status: 'ACCEPTED',
);

const _newMember = AlbumMemberResponse(
  id: 3,
  userId: 33,
  userUuid: 'new-member-uuid',
  userName: '방금 참여한 친구',
  role: 'VIEWER',
  status: 'ACCEPTED',
);

class _Members extends Fake implements AlbumMemberRepository {
  _Members(this.rows);

  List<AlbumMemberResponse> rows;
  int fetchCount = 0;
  int inviteCount = 0;

  @override
  Future<List<AlbumMemberResponse>> fetchMembers(int albumId) async {
    expect(albumId, 7);
    fetchCount++;
    // 조회 당시 스냅샷을 반환해 이후 가짜 서버 변경이 화면에 직접 새지 않게 한다.
    return List<AlbumMemberResponse>.unmodifiable(rows);
  }

  @override
  Future<InviteLinkResponse> invite(
    int albumId, {
    String role = 'EDITOR',
  }) async {
    expect(albumId, 7);
    expect(role, 'EDITOR');
    inviteCount++;
    return const InviteLinkResponse(
      albumId: 7,
      token: 'audit-local-invite',
      link: 'snapfit://invite?token=audit-local-invite',
    );
  }
}

class _Home extends HomeViewModel {
  @override
  FutureOr<List<Album>> build() => const [];
}

Future<void> _pumpMembers(WidgetTester tester, _Members repository) async {
  final container = ProviderContainer(
    overrides: [
      albumMemberRepositoryProvider.overrideWithValue(repository),
      albumCollaborationActorProvider.overrideWith((_) => 'owner-uuid'),
      homeViewModelProvider.overrideWith(_Home.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: SnapFitTheme.light().copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          builder: (_, child) => auditFrame(child!),
          home: const AlbumMembersScreen(album: _album),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollPosition _memberPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

void _record(WidgetTester tester, _Members repository, String stage) {
  final position = _memberPosition(tester);
  final platform = Theme.of(
    tester.element(find.byType(AlbumMembersScreen)),
  ).platform;
  debugPrint(
    'MEMBERS_AUDIT stage=$stage platform=${platform.name} '
    'maxScrollExtent=${position.maxScrollExtent} pixels=${position.pixels} '
    'fetchCount=${repository.fetchCount} inviteCount=${repository.inviteCount} '
    'fakeServerRows=${repository.rows.length}',
  );
}

void main() {
  // 폰트와 테스트 바인딩은 공통 실행 진입점에서 한 번만 준비한다.
  testWidgets(
    'REPRO: invite return stays stale while short-list manual refresh works',
    (tester) async {
      auditViewport(tester);
      final repository = _Members([_owner, _editor]);
      await _pumpMembers(tester, repository);
      expect(repository.fetchCount, 1);
      expect(find.text('소유자 · 나'), findsOneWidget);
      expect(find.text(_editor.userName!), findsOneWidget);
      expect(find.text(_newMember.userName!), findsNothing);
      expect(_memberPosition(tester).maxScrollExtent, 0);
      _record(tester, repository, 'short-initial');
      await auditCapture(tester, 'members/01-two-members-initial');

      // 짧은 목록의 실제 당김 갱신은 정상이다. 기존 2명 응답으로 먼저 확인한다.
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(repository.fetchCount, 2, reason: '정상 동작: 짧은 목록도 실제 당김으로 재조회된다.');
      expect(find.text(_newMember.userName!), findsNothing);
      _record(tester, repository, 'short-after-drag');
      await auditCapture(tester, 'members/02-after-short-list-drag');

      // 실제 초대 화면 진입·뒤로가기를 사용해 복귀 시 자동 갱신 여부도 확인한다.
      await tester.tap(find.text('멤버 초대'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumInviteScreen), findsOneWidget);
      expect(repository.inviteCount, 1);
      // 초대 화면이 멤버 명단을 덮은 동안 외부 참여가 발생한 상황만 합성한다.
      // UI 상태·새로고침 콜백을 직접 바꾸거나 실제 서버로 요청하지 않는다.
      repository.rows = [_owner, _editor, _newMember];
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumMembersScreen), findsOneWidget);
      expect(
        repository.fetchCount,
        2,
        reason: '문제 재현: 초대 화면에서 돌아와도 새 명단을 조회하지 않는다.',
      );
      expect(find.text(_newMember.userName!), findsNothing);
      _record(tester, repository, 'short-after-invite-return');
      await auditCapture(tester, 'members/03-after-invite-return');

      // 수동 당김으로 즉시 복구되므로 '갱신 불가'나 '참여 실패'로 해석하지 않는다.
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(
        repository.fetchCount,
        3,
        reason: '정상 복구: 수동 당김 후 새로 참여한 멤버를 조회한다.',
      );
      expect(find.text(_newMember.userName!), findsOneWidget);
      _record(tester, repository, 'short-after-manual-recovery');
      await auditCapture(tester, 'members/06-after-manual-refresh-recovery');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CONTROL: long member list refreshes through the same real drag',
    (tester) async {
      auditViewport(tester);
      final repository = _Members([
        _owner,
        _editor,
        for (var index = 3; index <= 20; index++)
          AlbumMemberResponse(
            id: index,
            userId: index * 11,
            userUuid: 'long-list-member-$index',
            userName: '여행 친구 $index',
            role: 'VIEWER',
            status: 'ACCEPTED',
          ),
      ]);
      await _pumpMembers(tester, repository);
      expect(repository.fetchCount, 1);
      expect(_memberPosition(tester).maxScrollExtent, greaterThan(0));
      _record(tester, repository, 'long-initial');
      await auditCapture(tester, 'members/04-long-list-before-drag');

      // 같은 저장소와 제스처에서 목록 길이만 바꾼 대조군이다.
      repository.rows = [
        _owner,
        _editor.copyWith(userName: '최신 명단의 친구'),
        ...repository.rows.skip(2),
      ];
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(
        repository.fetchCount,
        greaterThan(1),
        reason: '대조군: 긴 목록은 같은 당김 제스처로 재조회된다.',
      );
      expect(find.text('최신 명단의 친구'), findsOneWidget);
      expect(find.text(_editor.userName!), findsNothing);
      _record(tester, repository, 'long-after-drag');
      await auditCapture(tester, 'members/05-long-list-after-drag');
      expect(tester.takeException(), isNull);
    },
  );
}

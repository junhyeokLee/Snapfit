import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/album_member_response.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_members_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_category_screen.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';

class _Members extends Mock implements AlbumMemberRepository {}

class _Albums extends Mock implements AlbumRepository {}

class _Home extends HomeViewModel {
  @override
  FutureOr<List<Album>> build() => [];
}

const _album = Album(
  id: 7,
  userId: 'owner-uuid',
  title: '함께 남긴 비공개 기록',
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
  userName: '참여자',
  role: 'EDITOR',
  status: 'ACCEPTED',
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Members repository, {
  String Function()? actor,
  Widget? screen,
}) async {
  final container = ProviderContainer(
    overrides: [
      albumMemberRepositoryProvider.overrideWithValue(repository),
      albumCollaborationActorProvider.overrideWith(
        (_) => actor?.call() ?? 'owner-uuid',
      ),
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
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        screen ?? const AlbumMembersScreen(album: _album),
                  ),
                ),
                child: const Text('앨범 목록'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('앨범 목록'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'invite return refreshes members without dropping existing rows',
    (tester) async {
      final repository = _Members();
      final refreshed = Completer<List<AlbumMemberResponse>>();
      var fetches = 0;
      when(() => repository.fetchMembers(7)).thenAnswer((_) {
        fetches++;
        return fetches == 1
            ? Future.value([_owner, _editor])
            : refreshed.future;
      });
      when(() => repository.invite(7, role: 'EDITOR')).thenAnswer(
        (_) async => const InviteLinkResponse(
          albumId: 7,
          token: 'local-return-fixture',
          link: 'snapfit://invite?token=local-return-fixture',
        ),
      );
      await _pump(tester, repository);
      await tester.tap(find.text('멤버 초대'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumInviteScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(AlbumInviteScreen))).pop();
      await tester.pumpAndSettle();
      expect(fetches, 2);
      expect(find.text('참여자'), findsOneWidget);
      refreshed.complete([
        _owner,
        _editor,
        _editor.copyWith(id: 3, userUuid: 'joined-user', userName: '새로 참여한 멤버'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('새로 참여한 멤버'), findsOneWidget);
      expect(fetches, 2);
      verify(() => repository.invite(7, role: 'EDITOR')).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('repeated invite entry opens only one route and refreshes once', (
    tester,
  ) async {
    final repository = _Members();
    var fetches = 0;
    when(() => repository.fetchMembers(7)).thenAnswer((_) async {
      fetches++;
      return [_owner, _editor];
    });
    when(() => repository.invite(7, role: 'EDITOR')).thenAnswer(
      (_) async => const InviteLinkResponse(
        albumId: 7,
        token: 'local-repeat-fixture',
        link: 'snapfit://invite?token=local-repeat-fixture',
      ),
    );
    await _pump(tester, repository);
    final enter = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '멤버 초대'))
        .onPressed!;
    enter();
    enter();
    await tester.pumpAndSettle();
    expect(find.byType(AlbumInviteScreen, skipOffstage: false), findsOneWidget);
    verify(() => repository.invite(7, role: 'EDITOR')).called(1);
    Navigator.of(tester.element(find.byType(AlbumInviteScreen))).pop();
    await tester.pumpAndSettle();
    expect(fetches, 2);
    expect(find.byType(AlbumMembersScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invite return after an account change starts no extra refresh', (
    tester,
  ) async {
    final repository = _Members();
    var actor = 'owner-uuid';
    var fetches = 0;
    when(() => repository.fetchMembers(7)).thenAnswer((_) async {
      fetches++;
      return [_owner, _editor];
    });
    when(() => repository.invite(7, role: 'EDITOR')).thenAnswer(
      (_) async => const InviteLinkResponse(
        albumId: 7,
        token: 'local-account-fixture',
        link: 'snapfit://invite?token=local-account-fixture',
      ),
    );
    final container = await _pump(tester, repository, actor: () => actor);
    await tester.tap(find.text('멤버 초대'));
    await tester.pumpAndSettle();
    actor = 'another-account';
    container.invalidate(albumCollaborationActorProvider);
    await tester.pumpAndSettle();
    final beforeReturn = fetches;
    Navigator.of(tester.element(find.byType(AlbumInviteScreen))).pop();
    await tester.pumpAndSettle();
    expect(fetches, beforeReturn);
    expect(find.text('계정이 변경되었어요'), findsOneWidget);
    expect(find.text('참여자'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing members together with invite starts no hidden refresh', (
    tester,
  ) async {
    final repository = _Members();
    var fetches = 0;
    when(() => repository.fetchMembers(7)).thenAnswer((_) async {
      fetches++;
      return [_owner, _editor];
    });
    when(() => repository.invite(7, role: 'EDITOR')).thenAnswer(
      (_) async => const InviteLinkResponse(
        albumId: 7,
        token: 'local-close-fixture',
        link: 'snapfit://invite?token=local-close-fixture',
      ),
    );
    await _pump(tester, repository);
    await tester.tap(find.text('멤버 초대'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byType(AlbumInviteScreen)),
    ).popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    expect(fetches, 1);
    expect(find.byType(AlbumMembersScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed invite-return refresh can retry and enter invite again', (
    tester,
  ) async {
    final repository = _Members();
    var fetches = 0;
    when(() => repository.fetchMembers(7)).thenAnswer((_) async {
      if (++fetches == 2) throw StateError('fixture_refresh_failure');
      return [_owner, _editor];
    });
    when(() => repository.invite(7, role: 'EDITOR')).thenAnswer(
      (_) async => const InviteLinkResponse(
        albumId: 7,
        token: 'local-retry-fixture',
        link: 'snapfit://invite?token=local-retry-fixture',
      ),
    );
    await _pump(tester, repository);
    await tester.tap(find.text('멤버 초대'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(AlbumInviteScreen))).pop();
    await tester.pumpAndSettle();
    expect(fetches, 2);
    expect(find.text('멤버를 확인할 수 없어요'), findsOneWidget);
    await tester.tap(find.text('다시 확인'));
    await tester.pumpAndSettle();
    expect(fetches, 3);
    expect(find.text('참여자'), findsOneWidget);
    await tester.tap(find.text('멤버 초대'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumInviteScreen), findsOneWidget);
    verify(() => repository.invite(7, role: 'EDITOR')).called(2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'only the owner can confirm revoking unused links while members remain',
    (tester) async {
      final repository = _Members();
      when(
        () => repository.fetchMembers(7),
      ).thenAnswer((_) async => [_owner, _editor]);
      when(() => repository.revokeInvites(7)).thenAnswer((_) async => 2);
      await _pump(tester, repository);
      await tester.tap(find.text('미사용 초대 링크 취소'));
      await tester.pumpAndSettle();
      expect(find.textContaining('현재 멤버의 참여와 권한은 유지'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      verifyNever(() => repository.revokeInvites(7));
      await tester.tap(find.text('미사용 초대 링크 취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('링크 취소하기'));
      await tester.pumpAndSettle();
      verify(() => repository.revokeInvites(7)).called(1);
      expect(find.textContaining('미사용 초대 링크 2개를 취소'), findsOneWidget);
      expect(find.text('참여자'), findsOneWidget);
      verifyNever(() => repository.removeMember(any(), any()));
    },
  );
  testWidgets('account change hides a shared collection and its late refresh', (
    tester,
  ) async {
    var actor = 'owner-uuid';
    final repository = _Albums();
    final pending = Completer<List<Album>>();
    when(() => repository.fetchMyAlbums()).thenAnswer((_) => pending.future);
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(repository),
        albumCollaborationActorProvider.overrideWith((_) => actor),
      ],
    );
    addTearDown(container.dispose);
    final shared = _album.copyWith(userId: 'other-owner', memberRole: 'VIEWER');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            home: AlbumCategoryScreen(
              category: AlbumCategory.shared,
              initialAlbums: [shared],
              currentUserId: 'owner-uuid',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_album.title), findsOneWidget);
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    unawaited(refresh.onRefresh());
    await tester.pump();
    actor = 'another-account';
    container.invalidate(albumCollaborationActorProvider);
    await tester.pumpAndSettle();
    pending.complete([shared.copyWith(title: '이전 계정의 늦은 앨범')]);
    await tester.pumpAndSettle();
    expect(find.text(_album.title), findsNothing);
    expect(find.text('이전 계정의 늦은 앨범'), findsNothing);
    expect(find.textContaining('계정이 변경되었어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'owner role changes target raw UUID and reconcile a lost response',
    (tester) async {
      final repository = _Members();
      var rows = [_owner, _editor];
      when(() => repository.fetchMembers(7)).thenAnswer((_) async => rows);
      when(
        () => repository.setMemberRole(7, 'editor-uuid', 'VIEWER'),
      ).thenAnswer((_) async {
        rows = [_owner, _editor.copyWith(role: 'VIEWER')];
        throw StateError('committed; response lost');
      });
      await _pump(tester, repository);
      expect(find.byTooltip('멤버 관리'), findsOneWidget);
      expect(find.text('멤버 초대'), findsOneWidget);
      await tester.tap(find.byTooltip('멤버 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('보기 전용으로 변경'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('변경하기'));
      await tester.pumpAndSettle();
      verify(
        () => repository.setMemberRole(7, 'editor-uuid', 'VIEWER'),
      ).called(1);
      expect(find.text('보기 전용'), findsOneWidget);
      expect(find.textContaining('최신 멤버 상태'), findsOneWidget);
      expect(find.text('공유 앨범에서 나가기'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('viewer can cancel then confirm leaving without owner controls', (
    tester,
  ) async {
    final repository = _Members();
    when(
      () => repository.fetchMembers(7),
    ).thenAnswer((_) async => [_owner, _editor.copyWith(role: 'VIEWER')]);
    when(() => repository.leave(7)).thenAnswer((_) async {});
    await _pump(tester, repository, actor: () => 'editor-uuid');
    expect(find.text('멤버 초대'), findsNothing);
    expect(find.text('미사용 초대 링크 취소'), findsNothing);
    expect(find.byTooltip('멤버 관리'), findsNothing);
    await tester.tap(find.text('공유 앨범에서 나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.leave(7));
    await tester.tap(find.text('공유 앨범에서 나가기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('원본 앨범은 삭제되지'), findsOneWidget);
    await tester.tap(find.text('앨범에서 나가기'));
    await tester.pumpAndSettle();
    verify(() => repository.leave(7)).called(1);
    expect(find.text('앨범 목록'), findsOneWidget);
    expect(_album.title, '함께 남긴 비공개 기록');
  });

  testWidgets(
    'late previous-account member response cannot restore private rows',
    (tester) async {
      final repository = _Members();
      var actor = 'owner-uuid';
      final pending = Completer<void>();
      when(
        () => repository.fetchMembers(7),
      ).thenAnswer((_) async => [_owner, _editor]);
      when(
        () => repository.removeMember(7, 'editor-uuid'),
      ).thenAnswer((_) => pending.future);
      final container = await _pump(tester, repository, actor: () => actor);
      await tester.tap(find.byTooltip('멤버 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('멤버 내보내기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('내보내기'));
      await tester.pump();
      actor = 'another-account';
      container.invalidate(albumCollaborationActorProvider);
      await tester.pumpAndSettle();
      pending.completeError(StateError('old account failure'));
      await tester.pumpAndSettle();
      expect(find.text('계정이 변경되었어요'), findsOneWidget);
      expect(find.text(_album.title), findsNothing);
      expect(find.text('참여자'), findsNothing);
      expect(find.textContaining('요청 결과'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late invite creation cannot expose the previous account link', (
    tester,
  ) async {
    final repository = _Members();
    var actor = 'owner-uuid';
    final pending = Completer<InviteLinkResponse>();
    when(
      () => repository.invite(7, role: 'EDITOR'),
    ).thenAnswer((_) => pending.future);
    // Leave the initial RPC unresolved without pumpAndSettle's spinner wait.
    final container = ProviderContainer(
      overrides: [
        albumMemberRepositoryProvider.overrideWithValue(repository),
        albumCollaborationActorProvider.overrideWith((_) => actor),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => const MaterialApp(
            home: AlbumInviteScreen(albumId: 7, albumTitle: '이전 계정 앨범'),
          ),
        ),
      ),
    );
    await tester.pump();
    actor = 'another-account';
    container.invalidate(albumCollaborationActorProvider);
    await tester.pumpAndSettle();
    pending.complete(
      const InviteLinkResponse(
        albumId: 7,
        token: 'one',
        link: 'https://snapfit-c719d.web.app/invite/one',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('계정이 변경되었어요'), findsOneWidget);
    expect(find.text('이전 계정 앨범'), findsNothing);
    expect(find.textContaining('/invite/one'), findsNothing);
    expect(find.byKey(const ValueKey('inviteCopy')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

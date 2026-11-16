// 디자인 점검용 로컬 fixture. 실제 초대·공유·멤버 변경 요청은 보내지 않는다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/album_member_response.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_members_screen.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';

import 'capture_support.dart';

class _Members extends Mock implements AlbumMemberRepository {}

const _owner = AlbumMemberResponse(
  id: 1,
  userId: 11,
  userUuid: 'audit-owner',
  userName: '준혁',
  isOwner: true,
  role: 'OWNER',
  status: 'ACCEPTED',
);
const _editor = AlbumMemberResponse(
  id: 2,
  userId: 22,
  userUuid: 'audit-editor',
  userName: '민서',
  role: 'EDITOR',
  status: 'ACCEPTED',
);
const _viewer = AlbumMemberResponse(
  id: 3,
  userId: 33,
  userUuid: 'audit-viewer',
  userName: '지우',
  role: 'VIEWER',
  status: 'ACCEPTED',
);
const _longName = AlbumMemberResponse(
  id: 4,
  userId: 44,
  userUuid: 'audit-long',
  userName: '우리의 여행을 함께 기록하는 수빈',
  role: 'EDITOR',
  status: 'ACCEPTED',
);

// 기존 album_invite_journey_test.dart와 같은 번들 사진을 사용한다.
final _album = Album(
  id: 7,
  userId: 'audit-owner',
  title: '함께 남긴 여름 여행',
  ratio: '0.75',
  memberRole: 'OWNER',
  coverLayersJson: jsonEncode({
    'pages': [
      {
        'index': 0,
        'isCover': true,
        'layers': [
          {
            'id': 'audit-cover-photo',
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

_Members _repository() {
  final repository = _Members();
  when(() => repository.fetchMembers(7)).thenAnswer(
    (_) async => [_owner, _editor, _viewer, _longName],
  );
  for (final role in ['EDITOR', 'VIEWER']) {
    // 진입 시 생성하는 링크도 전부 메모리의 응답으로 대체한다.
    when(() => repository.invite(7, role: role)).thenAnswer(
      (_) async => InviteLinkResponse(
        albumId: 7,
        token: 'local-audit-${role.toLowerCase()}',
        link: 'https://snapfit.example/invite/local-audit-${role.toLowerCase()}',
      ),
    );
  }
  return repository;
}

Future<void> _mount(
  WidgetTester tester,
  Widget screen,
  _Members repository, {
  String actor = 'audit-owner',
  bool dark = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        albumMemberRepositoryProvider.overrideWithValue(repository),
        albumCollaborationActorProvider.overrideWithValue(actor),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: auditFrame(child!),
          ),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    await auditFonts();
    // 테스트 fake clock 밖에서 번들 파일을 미리 읽는다.
    await rootBundle.load('assets/frame_preview/ocean_shore.jpg');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('audit owner members and role menu without changes', (tester) async {
    auditViewport(tester);
    final repository = _repository();
    await _mount(tester, AlbumMembersScreen(album: _album), repository);
    expect(find.text('준혁 · 나'), findsOneWidget);
    expect(find.text('멤버 초대'), findsOneWidget);
    await auditCapture(tester, 'members-owner-390');

    await tester.tap(find.byTooltip('멤버 관리').first);
    await tester.pumpAndSettle();
    expect(find.text('보기 전용으로 변경'), findsOneWidget);
    expect(find.text('멤버 내보내기'), findsOneWidget);
    await auditCapture(tester, 'members-owner-role-menu-390');
    // 메뉴를 닫을 때도 선택하지 않아 권한/참여 상태가 변하지 않는다.
    Navigator.of(tester.element(find.text('멤버 내보내기'))).pop();
    await tester.pumpAndSettle();
    verifyNever(() => repository.setMemberRole(any(), any(), any()));
    verifyNever(() => repository.removeMember(any(), any()));
    await _unmount(tester);
  });

  testWidgets('audit viewer normal and large dark members', (tester) async {
    auditViewport(tester);
    final repository = _repository();
    await _mount(
      tester,
      AlbumMembersScreen(album: _album.copyWith(memberRole: 'VIEWER')),
      repository,
      actor: 'audit-viewer',
    );
    expect(find.text('지우 · 나'), findsOneWidget);
    expect(find.text('멤버 초대'), findsNothing);
    expect(find.byTooltip('멤버 관리'), findsNothing);
    await auditCapture(tester, 'members-viewer-390');

    tester.view.physicalSize = const Size(320, 740);
    await _mount(
      tester,
      AlbumMembersScreen(album: _album.copyWith(memberRole: 'VIEWER')),
      repository,
      actor: 'audit-viewer',
      dark: true,
      scale: 1.6,
    );
    await auditCapture(tester, 'members-viewer-320-large-dark');
    // ListView는 화면 밖 항목을 아직 만들지 않으므로 먼저 스크롤해서 찾는다.
    await tester.scrollUntilVisible(
      find.text('공유 앨범에서 나가기'),
      240,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first,
      maxScrolls: 8,
    );
    await auditCapture(tester, 'members-viewer-320-large-dark-bottom');
    verifyNever(() => repository.leave(any()));
    await _unmount(tester);
  });

  testWidgets('audit invite editor and viewer large dark without sharing', (tester) async {
    auditViewport(tester);
    final repository = _repository();
    await _mount(
      tester,
      AlbumInviteScreen(albumId: 7, albumTitle: _album.title, album: _album),
      repository,
    );
    expect(find.byKey(const ValueKey('inviteAlbumArtwork')), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    await auditCapture(tester, 'invite-editor-390');

    tester.view.physicalSize = const Size(320, 740);
    await _mount(
      tester,
      AlbumInviteScreen(
        albumId: 7,
        albumTitle: _album.title,
        album: _album,
        initialAllowEditing: false,
      ),
      repository,
      dark: true,
      scale: 1.6,
    );
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    await auditCapture(tester, 'invite-viewer-320-large-dark');
    await tester.ensureVisible(find.byKey(const ValueKey('inviteLinkSurface')));
    await tester.drag(
      find.byKey(const ValueKey('inviteContent')),
      const Offset(0, -320),
    );
    await auditCapture(tester, 'invite-viewer-320-large-dark-bottom');
    verify(() => repository.invite(7, role: 'EDITOR')).called(1);
    verify(() => repository.invite(7, role: 'VIEWER')).called(1);
    await _unmount(tester);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_screen.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';

class MockAlbumMemberRepository extends Mock implements AlbumMemberRepository {}

Widget _wrap(Widget child, AlbumMemberRepository repository) {
  return ProviderScope(
    overrides: [
      albumMemberRepositoryProvider.overrideWithValue(repository),
      albumCollaborationActorProvider.overrideWithValue('invite-test-owner'),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(home: child),
    ),
  );
}

void main() {
  for (final role in ['EDITOR', 'VIEWER']) {
    testWidgets('new invite keeps $role and blocks reuse while preparing', (
      tester,
    ) async {
      final repository = MockAlbumMemberRepository();
      final next = Completer<InviteLinkResponse>();
      var requests = 0;
      InviteLinkResponse response(String token) => InviteLinkResponse(
        albumId: 7,
        token: token,
        link: 'https://snapfit.example/invite/$token',
      );
      when(() => repository.invite(7, role: role)).thenAnswer((_) async {
        requests++;
        return requests == 1 ? response('first') : next.future;
      });
      await tester.pumpWidget(
        _wrap(
          AlbumInviteScreen(
            albumId: 7,
            albumTitle: '여행',
            initialAllowEditing: role == 'EDITOR',
          ),
          repository,
        ),
      );
      await tester.pumpAndSettle();
      final create = find.byKey(const ValueKey('inviteNewLink'));
      expect(create, findsOneWidget);
      await tester.ensureVisible(create);
      final start = tester.widget<TextButton>(create).onPressed!;
      await tester.tap(create);
      start(); // 빠르게 연속 요청해도 새 링크는 한 번만 생성한다.
      await tester.pump();
      expect(requests, 2);
      expect(tester.widget<TextButton>(create).onPressed, isNull);
      expect(find.textContaining('/first'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('inviteCopy')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('inviteShare')))
            .onPressed,
        isNull,
      );
      next.complete(response('next'));
      await tester.pumpAndSettle();
      expect(find.text('https://snapfit.example/invite/next'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        role == 'EDITOR',
      );
      expect(tester.widget<TextButton>(create).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('failed new invite keeps the existing retry path', (
    tester,
  ) async {
    final repository = MockAlbumMemberRepository();
    var requests = 0;
    when(() => repository.invite(7, role: 'EDITOR')).thenAnswer((_) async {
      requests++;
      if (requests == 2) throw StateError('offline');
      return InviteLinkResponse(
        albumId: 7,
        token: 'request-$requests',
        link: 'https://snapfit.example/invite/request-$requests',
      );
    });
    await tester.pumpWidget(
      _wrap(const AlbumInviteScreen(albumId: 7, albumTitle: '여행'), repository),
    );
    await tester.pumpAndSettle();
    final create = find.byKey(const ValueKey('inviteNewLink'));
    expect(create, findsOneWidget);
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.textContaining('/request-1'), findsNothing);
    final retry = find.byTooltip('초대 링크 다시 만들기');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(requests, 3);
    expect(
      find.text('https://snapfit.example/invite/request-3'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('invite screen does not leak raw invite creation errors', (
    tester,
  ) async {
    final repository = MockAlbumMemberRepository();
    when(
      () => repository.invite(7, role: any(named: 'role')),
    ).thenThrow(Exception('JWT token abc123 internal stack'));

    await tester.pumpWidget(
      _wrap(const AlbumInviteScreen(albumId: 7, albumTitle: '여행'), repository),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('JWT token abc123'), findsNothing);
    expect(find.textContaining('internal stack'), findsNothing);
    expect(find.text('로그인이 만료되었어요. 다시 로그인한 뒤 초대 링크를 만들어주세요.'), findsOneWidget);
  });
}

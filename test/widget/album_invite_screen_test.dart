import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_screen.dart';

class MockAlbumMemberRepository extends Mock implements AlbumMemberRepository {}

Widget _wrap(Widget child, AlbumMemberRepository repository) {
  return ProviderScope(
    overrides: [albumMemberRepositoryProvider.overrideWithValue(repository)],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(home: child),
    ),
  );
}

void main() {
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

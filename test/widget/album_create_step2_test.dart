import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step2.dart';

class MockAlbumMemberRepository extends Mock implements AlbumMemberRepository {}

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('creates invite link and shows it', (tester) async {
    final mockRepo = MockAlbumMemberRepository();
    when(() => mockRepo.invite(1, role: any(named: 'role')))
        .thenAnswer((_) async => const InviteLinkResponse(
              albumId: 1,
              token: 't',
              link: 'https://example.com/invite/token',
            ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumMemberRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: _wrap(
          AlbumCreateStep2(
            albumTitle: '앨범',
            selectedCover: coverSizes.first,
            selectedPageCount: 10,
            albumId: 1,
            onNext: () {},
            onBack: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('https://example.com/invite'), findsOneWidget);
  });

  testWidgets('toggle allow editing switch', (tester) async {
    final mockRepo = MockAlbumMemberRepository();
    when(() => mockRepo.invite(1, role: any(named: 'role')))
        .thenAnswer((_) async => const InviteLinkResponse(
              albumId: 1,
              token: 't',
              link: 'link',
            ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumMemberRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: _wrap(
          AlbumCreateStep2(
            albumTitle: '앨범',
            selectedCover: coverSizes.first,
            selectedPageCount: 10,
            albumId: 1,
            allowEditing: true,
            onNext: () {},
            onBack: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(switchFinder).value, isFalse);
  });
}

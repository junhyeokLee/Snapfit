import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step2.dart';

class MockAlbumMemberRepository extends Mock implements AlbumMemberRepository {}

Future<void> _loadKoreanFonts() async {
  final loader = FontLoader('Noto Sans KR')
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));
  await loader.load();
}

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      theme: ThemeData(fontFamily: 'Noto Sans KR'),
      home: Scaffold(body: child),
    ),
  );
}

MockAlbumMemberRepository _mockInviteRepository({
  String link = 'https://example.com/invite/token',
}) {
  final mockRepo = MockAlbumMemberRepository();
  when(() => mockRepo.invite(1, role: any(named: 'role'))).thenAnswer(
    (_) async => InviteLinkResponse(albumId: 1, token: 't', link: link),
  );
  return mockRepo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadKoreanFonts();
  });

  testWidgets('creates invite link and shows it', (tester) async {
    final mockRepo = _mockInviteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [albumMemberRepositoryProvider.overrideWithValue(mockRepo)],
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
    final mockRepo = _mockInviteRepository(link: 'link');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [albumMemberRepositoryProvider.overrideWithValue(mockRepo)],
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

  testWidgets('renders renewed invite cockpit without losing invite controls', (
    tester,
  ) async {
    final mockRepo = _mockInviteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [albumMemberRepositoryProvider.overrideWithValue(mockRepo)],
        child: _wrap(
          AlbumCreateStep2(
            albumTitle: '제주 가족 여행 룩북',
            selectedCover: coverSizes.first,
            selectedPageCount: 24,
            albumId: 1,
            onNext: () {},
            onBack: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('INVITE COCKPIT'), findsOneWidget);
    expect(find.textContaining('함께 만드는'), findsOneWidget);
    expect(find.text('카카오톡으로 초대'), findsOneWidget);
    expect(find.text('링크 복사하기'), findsOneWidget);
    expect(find.text('편집 권한 허용'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
    expect(find.text('이전'), findsOneWidget);
  });

  testWidgets('matches renewed invite cockpit golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockRepo = _mockInviteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [albumMemberRepositoryProvider.overrideWithValue(mockRepo)],
        child: _wrap(
          AlbumCreateStep2(
            albumTitle: '제주 가족 여행 룩북',
            selectedCover: coverSizes.first,
            selectedPageCount: 24,
            albumId: 1,
            onNext: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AlbumCreateStep2),
      matchesGoldenFile('goldens/album_invite_cockpit_390x844.png'),
    );
  });
}

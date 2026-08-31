import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_slider.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';

import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel(this.user);

  final UserInfo? user;

  @override
  Future<UserInfo?> build() => Future.value(user);
}

Future<void> _setLargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  late MockAlbumRepository mockRepo;

  setUp(() {
    mockRepo = MockAlbumRepository();
  });

  testWidgets('앨범 목록 로딩 후 비어있으면 빈 상태 문구 표시', (WidgetTester tester) async {
    await _setLargeSurface(tester);
    stubFetchMyAlbums(mockRepo, []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          templateListProvider.overrideWith((ref) async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('아직 만든 앨범이 없어요'), findsOneWidget);
    expect(find.textContaining('지금은 참여 중인 앨범이 없어요.'), findsNothing);
    expect(find.text('앨범 만들기'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('앨범이 있으면 앨범 슬라이더 표시', (WidgetTester tester) async {
    await _setLargeSurface(tester);
    final album = fakeAlbum(id: 42, ratio: '0.75');
    stubFetchMyAlbums(mockRepo, [album]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          templateListProvider.overrideWith((ref) async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byType(HomeAlbumSlider), findsOneWidget);
    expect(find.text('나의 앨범'), findsNothing);
    expect(find.textContaining('앨범에만'), findsNothing);
    expect(find.textContaining('가장 최근 앨범부터'), findsNothing);
    expect(find.text('앨범 만들기'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('홈 앨범 캐러셀은 화면 중앙에 가깝게 배치되고 FAB는 메인 컬러를 쓴다', (
    WidgetTester tester,
  ) async {
    await _setLargeSurface(tester);
    final album = fakeAlbum(id: 43, ratio: '0.75');
    stubFetchMyAlbums(mockRepo, [album]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          templateListProvider.overrideWith((ref) async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    final sliderCenter = tester.getCenter(find.byType(HomeAlbumSlider));
    expect(sliderCenter.dy, greaterThan(390));
    expect(sliderCenter.dy, lessThan(610));

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const Key('homeCreateAlbumFab')),
    );
    expect(fab.backgroundColor, SnapFitColors.accent);
  });

  testWidgets('앨범 탭 FAB 액션은 생성 플로우로 이동', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    stubFetchMyAlbums(mockRepo, []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          templateListProvider.overrideWith((ref) async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(Navigator), findsOneWidget);
  });

  testWidgets('앨범 탭은 올드한 서재 카피와 대형 생성 CTA 없이 앨범/필터만 보여준다', (
    WidgetTester tester,
  ) async {
    await _setLargeSurface(tester);
    stubFetchMyAlbums(mockRepo, []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          templateListProvider.overrideWith((ref) async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    await tester.tap(find.text('앨범'));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('추억이 쌓이는 서재'), findsNothing);
    expect(find.textContaining('첫 번째 포토북을 꽂아볼까요'), findsNothing);
    expect(find.text('새 포토북 만들기'), findsNothing);
    expect(find.text('포토북 시작하기'), findsNothing);
    expect(find.text('앨범 만들기'), findsNothing);
    expect(find.text('전체'), findsOneWidget);
    expect(find.byKey(const Key('homeCreateAlbumFab')), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_tab_screen.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
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
    expect(find.text('앨범 만들기'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const ValueKey('empty-home-create')), findsOneWidget);
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
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('새 앨범'), findsOneWidget);
  });

  testWidgets('홈 앨범 캐러셀은 화면 중앙에 가깝게 배치되고 기존 생성 액션을 유지한다', (
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

    expect(find.byTooltip('새 앨범'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('빈 홈의 생성 액션은 실제 생성 플로우로 이동', (WidgetTester tester) async {
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

    await tester.tap(find.byKey(const ValueKey('empty-home-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(AlbumCreateFlowScreen), findsOneWidget);
  });

  testWidgets('앨범 탭은 올드한 서재 카피와 대형 생성 CTA 없이 앨범/필터만 보여준다', (
    WidgetTester tester,
  ) async {
    await _setLargeSurface(tester);
    stubFetchMyAlbums(mockRepo, [fakeAlbum(id: 44, ratio: '0.75')]);
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

    await tester.tap(find.byTooltip('앨범 목록'));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('추억이 쌓이는 서재'), findsNothing);
    expect(find.textContaining('첫 번째 포토북을 꽂아볼까요'), findsNothing);
    expect(find.text('새 포토북 만들기'), findsNothing);
    expect(find.text('포토북 시작하기'), findsNothing);
    expect(find.text('앨범 만들기'), findsNothing);
    expect(find.text('전체'), findsOneWidget);
    expect(find.byKey(const Key('homeCreateAlbumFab')), findsNothing);
    expect(find.byType(HomeAlbumTabScreen), findsOneWidget);
  });

  testWidgets('home timeout retry reloads the real album provider', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requests = 0;
    when(() => mockRepo.fetchMyAlbums()).thenAnswer((_) async {
      if (++requests == 1) {
        throw DioException(
          requestOptions: RequestOptions(path: '/albums'),
          type: DioExceptionType.receiveTimeout,
        );
      }
      return [fakeAlbum(id: 45, ratio: '1')];
    });
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          notificationUnreadCountProvider.overrideWith((ref) async => 0),
          templateListProvider.overrideWith((ref) async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => const MaterialApp(home: HomeScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('앨범을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('아직 만든 앨범이 없어요'), findsNothing);
    await tester.tap(find.text('다시 불러오기'));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byType(HomeAlbumSlider), findsOneWidget);
    expect(requests, 2);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final ratio in ['0.75', '1', '1.333333']) {
      testWidgets('populated home $ratio stays valid on $size and rotation', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        stubFetchMyAlbums(mockRepo, [fakeAlbum(id: 46, ratio: ratio)]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              albumRepositoryProvider.overrideWithValue(mockRepo),
              authViewModelProvider.overrideWith(
                () => FakeAuthViewModel(
                  const UserInfo(id: '1', name: 'User', provider: 'kakao'),
                ),
              ),
              notificationUnreadCountProvider.overrideWith((ref) async => 0),
              templateListProvider.overrideWith((ref) async => const []),
            ],
            child: ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (_, __) => const MaterialApp(home: HomeScreen()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.byType(HomeAlbumSlider), findsOneWidget);
        expect(tester.takeException(), isNull);
        final state = tester.state(find.byType(HomeAlbumSlider));
        tester.view.physicalSize = Size(size.height, size.width);
        await tester.pump(const Duration(milliseconds: 1200));
        expect(tester.takeException(), isNull);
        expect(tester.state(find.byType(HomeAlbumSlider)), same(state));
      });
    }
  }

  testWidgets('empty home inherits dark mode instead of forcing light', (
    tester,
  ) async {
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
          notificationUnreadCountProvider.overrideWith((ref) async => 0),
          templateListProvider.overrideWith((ref) async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) =>
              MaterialApp(theme: ThemeData.dark(), home: const HomeScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    final title = find.text('아직 만든 앨범이 없어요');
    expect(Theme.of(tester.element(title)).brightness, Brightness.dark);
    expect(tester.widget<Text>(title).style!.color, const Color(0xFFF2F6F5));
    expect(tester.takeException(), isNull);
  });
}

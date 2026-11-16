import 'dart:async';

import 'package:flutter/material.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_tab_screen.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_slider.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_header.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_summary_card.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/features/moments/presentation/widgets/first_book_next_step_card.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_empty_state.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_error_state.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/shared/widgets/snapfit_shimmer.dart';

import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';
import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../helpers/memory_moment_draft_store.dart';

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

ScrollController _expectOwnedScroll(WidgetTester tester, Finder owner) {
  final scroll = tester.widget<SingleChildScrollView>(
    find.descendant(of: owner, matching: find.byType(SingleChildScrollView)),
  );
  expect(scroll.primary, isFalse);
  final controller = scroll.controller!;
  expect(controller.positions, hasLength(1));
  expect(PrimaryScrollController.of(tester.element(owner)), same(controller));
  return controller;
}

void _expectVisibleCoverTarget(WidgetTester tester, Finder cover) {
  final scroll = find
      .ancestor(of: cover, matching: find.byType(SingleChildScrollView))
      .first;
  var viewport = tester.getRect(scroll);
  final navigation = find.byType(HomeBottomNavigationBar);
  final rail = tester.widget<HomeBottomNavigationBar>(navigation).rail;
  if (!rail) {
    // extendBody allows painting under navigation, which is not a usable tap area.
    viewport = viewport.intersect(
      Rect.fromLTRB(
        viewport.left,
        viewport.top,
        viewport.right,
        tester.getRect(navigation).top,
      ),
    );
  }
  final bounds = tester.getRect(cover);
  final visible = bounds.intersect(viewport);
  expect(visible.width, greaterThanOrEqualTo(44));
  expect(visible.height, greaterThanOrEqualTo(44));
  // A large cover intentionally exceeds the short landscape viewport. Verify
  // its visible portion receives gestures instead of testing its hidden center.
  final point = visible.center;
  final alignment = Alignment(
    (point.dx - bounds.left) / bounds.width * 2 - 1,
    (point.dy - bounds.top) / bounds.height * 2 - 1,
  );
  expect(cover.hitTestable(at: alignment), findsOneWidget);
}

void main() {
  late MockAlbumRepository mockRepo;

  setUp(() {
    mockRepo = MockAlbumRepository();
  });

  testWidgets('slow albums show a skeleton and never delay store navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final albums = Completer<List<Album>>();
    var catalogReads = 0;
    when(() => mockRepo.fetchMyAlbums()).thenAnswer((_) => albums.future);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumEditorOwnerReaderProvider.overrideWith(
            (_) =>
                () => '1',
          ),
          momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
          albumCreationDraftStoreProvider.overrideWithValue(
            MemoryCreationDraftStore(),
          ),
          homeUiStateProvider.overrideWith(
            () => HomeUiStateNotifier(initialIndex: 0),
          ),
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          notificationUnreadCountProvider.overrideWith((_) async => 0),
          pointShopCatalogProvider.overrideWith((_) async => []),
          mockTemplateList(() {
            catalogReads++;
            return [];
          }),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.byType(SnapFitShimmerHomeSlider), findsOneWidget);
    _expectOwnedScroll(tester, find.byType(SnapFitShimmerHomeSlider));
    expect(find.text('아직 만든 앨범이 없어요'), findsNothing);
    await tester.pump();
    expect(find.byType(SnapFitShimmerHomeSlider), findsOneWidget);
    expect(catalogReads, 0);
    await tester.tap(find.byTooltip('스토어'));
    await tester.pump();
    expect(find.byTooltip('스토어 검색'), findsOneWidget);
    expect(find.byType(StoreScreen), findsNothing);
    expect(catalogReads, 0);
    await tester.pump();
    expect(find.byType(StoreScreen), findsOneWidget);
    expect(catalogReads, 1);
    final storeState = tester.state(find.byType(StoreScreen));
    expect(albums.isCompleted, isFalse);
    await tester.tap(find.byTooltip('내 앨범'));
    await tester.pump();
    expect(find.byType(SnapFitShimmerHomeSlider), findsOneWidget);
    albums.complete([fakeAlbum(id: 100, ratio: '1')]);
    await tester.pump();
    await tester.pump();
    expect(find.byType(HomeAlbumSlider), findsOneWidget);
    final albumState = tester.state(find.byType(HomeAlbumSlider));
    await tester.tap(find.byTooltip('스토어'));
    await tester.pump();
    expect(tester.state(find.byType(StoreScreen)), same(storeState));
    expect(catalogReads, 1);
    await tester.tap(find.byTooltip('내 앨범'));
    await tester.pump();
    expect(tester.state(find.byType(HomeAlbumSlider)), same(albumState));
    verify(() => mockRepo.fetchMyAlbums()).called(1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('앨범 목록 로딩 후 비어있으면 빈 상태 문구 표시', (WidgetTester tester) async {
    await _setLargeSurface(tester);
    stubFetchMyAlbums(mockRepo, []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumEditorOwnerReaderProvider.overrideWith(
            (_) =>
                () => '1',
          ),
          momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
          albumCreationDraftStoreProvider.overrideWithValue(
            MemoryCreationDraftStore(),
          ),
          homeUiStateProvider.overrideWith(
            () => HomeUiStateNotifier(initialIndex: 0),
          ),
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          mockTemplateList(() async => const []),
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
    await tester.pumpAndSettle();

    expect(find.text('아직 만든 앨범이 없어요'), findsOneWidget);
    expect(find.textContaining('지금은 참여 중인 앨범이 없어요.'), findsNothing);
    expect(find.text('앨범 만들기'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const ValueKey('empty-home-create')), findsOneWidget);
    final coverScroll = _expectOwnedScroll(tester, find.byType(HomeEmptyState));
    await tester.tap(find.byTooltip('앨범 목록'));
    await tester.pumpAndSettle();
    final collectionScroll = tester
        .widget<CustomScrollView>(
          find.descendant(
            of: find.byType(HomeAlbumTabScreen),
            matching: find.byType(CustomScrollView),
          ),
        )
        .controller!;
    expect(collectionScroll, isNot(same(coverScroll)));
    await tester.binding.setSurfaceSize(const Size(844, 390));
    await tester.pumpAndSettle();
    expect(coverScroll.positions, hasLength(1));
    expect(collectionScroll.positions, hasLength(1));
    await tester.tap(find.byTooltip('표지로 보기'));
    await tester.pumpAndSettle();
    expect(
      _expectOwnedScroll(tester, find.byType(HomeEmptyState)),
      same(coverScroll),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('앨범이 있으면 앨범 슬라이더 표시', (WidgetTester tester) async {
    await _setLargeSurface(tester);
    final album = fakeAlbum(id: 42, ratio: '0.75');
    stubFetchMyAlbums(mockRepo, [album]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumEditorOwnerReaderProvider.overrideWith(
            (_) =>
                () => '1',
          ),
          momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
          albumCreationDraftStoreProvider.overrideWithValue(
            MemoryCreationDraftStore(),
          ),
          homeUiStateProvider.overrideWith(
            () => HomeUiStateNotifier(initialIndex: 0),
          ),
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          mockTemplateList(() async => const []),
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
    await tester.pumpAndSettle();

    expect(find.byType(HomeAlbumSlider), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-album-section-title')),
      findsOneWidget,
    );
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
          albumEditorOwnerReaderProvider.overrideWith(
            (_) =>
                () => '1',
          ),
          momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
          albumCreationDraftStoreProvider.overrideWithValue(
            MemoryCreationDraftStore(),
          ),
          homeUiStateProvider.overrideWith(
            () => HomeUiStateNotifier(initialIndex: 0),
          ),
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          mockTemplateList(() async => const []),
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
    await tester.pumpAndSettle();

    final slider = find.byType(HomeAlbumSlider);
    final sliderBounds = tester.getRect(slider);
    final viewport = tester.getRect(
      find.ancestor(of: slider, matching: find.byType(Stack)).first,
    );
    expect(sliderBounds.center.dy, closeTo(viewport.center.dy, 1));
    expect(
      sliderBounds.top,
      greaterThanOrEqualTo(tester.getRect(find.byType(HomeAlbumHeader)).bottom),
    );
    expect(find.byType(FirstBookNextStepCard), findsNothing);
    // Journal loading/guest states keep their entry while album layout stays usable.
    expect(find.byType(HomeMomentSummaryCard), findsOneWidget);
    final navigation = tester.widget<HomeBottomNavigationBar>(
      find.byType(HomeBottomNavigationBar),
    );
    final usableBottom = navigation.rail
        ? tester.getRect(find.byType(HomeScreen)).bottom
        : tester.getRect(find.byType(HomeBottomNavigationBar)).top;
    expect(sliderBounds.bottom, lessThanOrEqualTo(usableBottom));
    final artwork = tester.getRect(
      find.byKey(const ValueKey('home-bookshelf-stage')),
    );
    expect(artwork.height, greaterThan(180));
    expect(artwork.top, greaterThanOrEqualTo(sliderBounds.top));
    expect(artwork.bottom, lessThanOrEqualTo(sliderBounds.bottom));

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
          albumEditorOwnerReaderProvider.overrideWith(
            (_) =>
                () => '1',
          ),
          momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
          albumCreationDraftStoreProvider.overrideWithValue(
            MemoryCreationDraftStore(),
          ),
          homeUiStateProvider.overrideWith(
            () => HomeUiStateNotifier(initialIndex: 0),
          ),
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          mockTemplateList(() async => const []),
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
    await tester.pumpAndSettle();

    final create = find.byKey(const ValueKey('empty-home-create'));
    await Scrollable.ensureVisible(tester.element(create), alignment: .2);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.byType(AlbumCreateFlowScreen), findsNothing);
    await tester.tap(find.byKey(const ValueKey('album-creation-start-manual')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(AlbumCreateFlowScreen), findsOneWidget);
  });

  testWidgets('앨범 목록은 작품 수와 검색·관리 행동을 보여준다', (WidgetTester tester) async {
    await _setLargeSurface(tester);
    stubFetchMyAlbums(mockRepo, [fakeAlbum(id: 44, ratio: '0.75')]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumEditorOwnerReaderProvider.overrideWith(
            (_) =>
                () => '1',
          ),
          momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
          albumCreationDraftStoreProvider.overrideWithValue(
            MemoryCreationDraftStore(),
          ),
          homeUiStateProvider.overrideWith(
            () => HomeUiStateNotifier(initialIndex: 0),
          ),
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          mockTemplateList(() async => const []),
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
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('앨범 목록'));
    await tester.pumpAndSettle();

    expect(find.text('추억이 쌓이는 서재'), findsNothing);
    expect(find.textContaining('첫 번째 포토북을 꽂아볼까요'), findsNothing);
    expect(find.text('새 포토북 만들기'), findsNothing);
    expect(find.text('포토북 시작하기'), findsNothing);
    expect(find.text('앨범 만들기'), findsNothing);
    expect(find.text('앨범 1권'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-collection-album-44')),
      findsOneWidget,
    );
    expect(find.byTooltip('앨범 검색 및 관리').hitTestable(), findsOneWidget);
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
          albumEditorOwnerReaderProvider.overrideWith(
            (_) =>
                () => '1',
          ),
          momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
          albumCreationDraftStoreProvider.overrideWithValue(
            MemoryCreationDraftStore(),
          ),
          homeUiStateProvider.overrideWith(
            () => HomeUiStateNotifier(initialIndex: 0),
          ),
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          notificationUnreadCountProvider.overrideWith((ref) async => 0),
          mockTemplateList(() async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => const MaterialApp(home: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('앨범을 불러오지 못했어요'), findsOneWidget);
    _expectOwnedScroll(tester, find.byType(HomeErrorState));
    expect(find.text('아직 만든 앨범이 없어요'), findsNothing);
    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();
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
        stubFetchMyAlbums(mockRepo, [
          fakeAlbum(
            id: 46,
            ratio: ratio,
          ).copyWith(userId: '1', targetPages: 20),
        ]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              albumEditorOwnerReaderProvider.overrideWith(
                (_) =>
                    () => '1',
              ),
              momentDraftStoreProvider.overrideWithValue(
                MemoryMomentDraftStore(),
              ),
              albumCreationDraftStoreProvider.overrideWithValue(
                MemoryCreationDraftStore(),
              ),
              homeUiStateProvider.overrideWith(
                () => HomeUiStateNotifier(initialIndex: 0),
              ),
              albumRepositoryProvider.overrideWithValue(mockRepo),
              authViewModelProvider.overrideWith(
                () => FakeAuthViewModel(
                  const UserInfo(id: '1', name: 'User', provider: 'kakao'),
                ),
              ),
              notificationUnreadCountProvider.overrideWith((ref) async => 0),
              mockTemplateList(() async => const []),
            ],
            child: ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (_, __) => const MaterialApp(home: HomeScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HomeAlbumSlider), findsOneWidget);
        expect(
          find.byKey(const ValueKey('first-book-next-step')),
          findsNothing,
        );
        final cover = find.byKey(const ValueKey('home-bookshelf-open'));
        await tester.ensureVisible(cover);
        await tester.pumpAndSettle();
        _expectVisibleCoverTarget(tester, cover);
        expect(tester.getSize(cover).height, greaterThanOrEqualTo(180));
        expect(tester.takeException(), isNull);
        final state = tester.state(find.byType(HomeAlbumSlider));
        tester.view.physicalSize = Size(size.height, size.width);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.state(find.byType(HomeAlbumSlider)), same(state));
        await tester.ensureVisible(cover);
        await tester.pumpAndSettle();
        _expectVisibleCoverTarget(tester, cover);
        expect(tester.getSize(cover).height, greaterThanOrEqualTo(180));
        expect(
          find.byKey(const ValueKey('first-book-next-step')),
          findsNothing,
        );
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
          albumEditorOwnerReaderProvider.overrideWith(
            (_) =>
                () => '1',
          ),
          momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
          albumCreationDraftStoreProvider.overrideWithValue(
            MemoryCreationDraftStore(),
          ),
          homeUiStateProvider.overrideWith(
            () => HomeUiStateNotifier(initialIndex: 0),
          ),
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: '1', name: 'User', provider: 'kakao'),
            ),
          ),
          notificationUnreadCountProvider.overrideWith((ref) async => 0),
          mockTemplateList(() async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) =>
              MaterialApp(theme: ThemeData.dark(), home: const HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = find.text('아직 만든 앨범이 없어요');
    expect(Theme.of(tester.element(title)).brightness, Brightness.dark);
    expect(tester.widget<Text>(title).style!.color, const Color(0xFFF2F6F5));
    expect(tester.takeException(), isNull);
  });
}

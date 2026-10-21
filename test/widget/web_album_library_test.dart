import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/web/web_album_library_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/shared/web/web_design.dart';

const _albums = [
  Album(
    id: 1,
    title: '제주의 여름',
    coverTheme: 'classic',
    userId: 'owner',
    ratio: '1',
    totalPages: 20,
    targetPages: 20,
    updatedAt: '2026-10-18T10:00:00',
  ),
  Album(
    id: 2,
    title: '우리의 가을',
    coverTheme: 'classic',
    userId: 'owner',
    ratio: '1',
    totalPages: 2,
    targetPages: 24,
    updatedAt: '2026-10-17T10:00:00',
  ),
];

class _Albums extends HomeViewModel {
  _Albums(this.items);
  final List<Album> items;
  @override
  Future<List<Album>> build() async => items;
}

class _Auth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async =>
      const UserInfo(id: 'owner', name: '테스트', provider: 'google');
}

Future<void> mountWebLibraryFixture(
  WidgetTester tester, {
  Size size = const Size(1440, 1000),
  List<Album> items = _albums,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeViewModelProvider.overrideWith(() => _Albums(items)),
        authViewModelProvider.overrideWith(_Auth.new),
        albumCreationDraftProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        theme: SnapFitWebTheme.from(
          ThemeData(
            brightness: brightness,
            splashFactory: NoSplash.splashFactory,
          ),
        ),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('web-library-layout-proof'),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: WebNavigationScope(
              onNavigate: (_) {},
              onNotifications: () {},
              child: child!,
            ),
          ),
        ),
        home: const WebAlbumLibraryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'albums appear before discovery shortcuts with a single primary creation action',
    (tester) async {
      await mountWebLibraryFixture(tester);
      expect(find.text('소중한 순간을 한 권으로'), findsNothing);
      expect(find.text('새 앨범 만들기'), findsOneWidget);
      final card = find.byKey(const ValueKey('web-album-card-1'));
      expect(card, findsOneWidget);
      expect(tester.getTopLeft(card).dy, lessThan(500));
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.text('다음 앨범을 위한 아이디어')).dy),
      );
      expect(find.text('AI로 만들기'), findsOneWidget);
      expect(find.text('내 디자인 보관함'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'an empty favorite filter is recoverable without claiming the account has no albums',
    (tester) async {
      await mountWebLibraryFixture(tester);
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 앨범이 없습니다'), findsOneWidget);
      expect(find.text('첫 이야기를 담아보세요'), findsNothing);
      await tester.tap(find.text('검색·필터 초기화'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-album-card-1')), findsOneWidget);
      expect(find.text('앨범 2개'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'list and grid preserve query, favorite actions and result counts',
    (tester) async {
      await mountWebLibraryFixture(tester);
      await tester.enterText(
        find.byKey(const ValueKey('web-library-search')),
        '제주',
      );
      await tester.pumpAndSettle();
      expect(find.text('전체 2개 중 1개'), findsOneWidget);
      await tester.tap(find.byTooltip('앨범 목록 보기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-album-row-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('web-album-row-2')), findsNothing);
      await tester.tap(find.byTooltip('즐겨찾기 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-album-row-1')), findsOneWidget);
      await tester.tap(find.byTooltip('검색어 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('전체 2개 중 1개'), findsOneWidget);
      await tester.tap(find.byTooltip('앨범 카드 보기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-album-card-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'search with no results can be reset and true first-time state remains distinct',
    (tester) async {
      await mountWebLibraryFixture(tester, items: []);
      expect(find.text('첫 이야기를 담아보세요'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('web-library-search')),
        '없는 이름',
      );
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 앨범이 없습니다'), findsOneWidget);
      await tester.tap(find.text('검색·필터 초기화'));
      await tester.pumpAndSettle();
      expect(find.text('첫 이야기를 담아보세요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 768.0, 1024.0]) {
    testWidgets('library controls fit a $width px browser in both views', (
      tester,
    ) async {
      await mountWebLibraryFixture(
        tester,
        size: Size(width, 1000),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('앨범 목록 보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('다음 앨범을 위한 아이디어'),
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('web-album-library-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'narrow browser supports double-size text and wrapping row actions',
    (tester) async {
      await mountWebLibraryFixture(
        tester,
        size: const Size(320, 1000),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('앨범 목록 보기'));
      await tester.tap(find.byTooltip('앨범 목록 보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

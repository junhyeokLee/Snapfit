// 실제 리더 → 내지 상세 → 메뉴를 재현한다. 계정·인쇄 서버 요청은 실행하지 않는다.
import 'package:book_page_flip/book_page_flip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_reader_inner_detail_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_reader_screen.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_preview_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_more_options_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_single_page_view.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/reader_page_gallery.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';

import 'audit_support.dart';

// reader_navigation_continuity_test의 상태 대역을 그대로 사용한다.
// 사진은 reader_paper_motion_test에서 검증에 쓰는 로컬 번들로만 채운다.
class _ReaderModel extends AlbumEditorViewModel {
  final document = const Album(
    id: 73,
    userId: 'owner',
    memberRole: 'OWNER',
    title: '우리의 여름, 오래 간직할 장면들',
  );
  final documentPages = List.generate(
    7,
    (index) => AlbumPage(
      id: 'reader-audit-page-$index',
      pageIndex: index,
      isCover: index == 0,
      backgroundColor: 0xfff7f3ec,
      layers: [
        LayerModel(
          id: 'reader-audit-photo-$index',
          type: LayerType.image,
          position: const Offset(30, 40),
          width: 440,
          height: 360,
          imageUrl: 'asset:assets/snapfit_home_square.jpg',
        ),
        LayerModel(
          id: 'reader-audit-caption-$index',
          type: LayerType.text,
          position: const Offset(40, 420),
          width: 400,
          height: 50,
          text: index == 0 ? '우리의 여름' : '오래 간직할 장면 $index',
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            color: Color(0xff263e37),
          ),
        ),
      ],
    ),
  );
  final Object session = Object();

  @override
  AlbumEditorState build() => const AlbumEditorState();
  @override
  Album get album => document;
  @override
  List<AlbumPage> get pages => documentPages;
  @override
  Object get editSessionIdentity => session;
  @override
  void ensureCoverPage() {}
  @override
  void loadPendingEditAlbumIfNeeded(Size canvasSize) {}
  @override
  void setCoverCanvasSize(Size? size, {bool isCover = true}) {}
}

class _ReaderRoutes extends NavigatorObserver {
  final pages = <PageRoute<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // 팝업 시트는 제외한다. 원래 리더와 상세 두 화면만 있어야 한다.
    if (route is PageRoute<dynamic>) pages.add(route);
  }
}

Future<void> _paint(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> _readyBook(WidgetTester tester) async {
  // 책의 로컬 이미지 캡처는 테스트의 가상 시계 밖에서 완료된다.
  for (var frame = 0; frame < 100; frame++) {
    final book = find.byType(BookFlip);
    if (book.evaluate().isNotEmpty &&
        tester.widget<BookFlip>(book).controller!.isReady) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  throw TestFailure(
    'The reader did not finish capturing its local book pages.',
  );
}

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await auditFonts();
  });

  testWidgets('capture reader detail book action returns only an instruction', (
    tester,
  ) async {
    auditViewport(tester);
    final model = _ReaderModel();
    final routes = _ReaderRoutes();
    final container = ProviderContainer(
      overrides: [
        albumEditorViewModelProvider.overrideWith(() => model),
        albumEditorOwnerReaderProvider.overrideWithValue(() => 'owner'),
        albumCollaborationActorProvider.overrideWith((_) => 'owner'),
      ],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => auditFrame(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: SnapFitTheme.light().copyWith(
                  splashFactory: NoSplash.splashFactory,
                ),
                navigatorObservers: [routes],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: child!,
                ),
                home: const AlbumReaderScreen(initialSpreadIndex: 2),
              ),
            ),
          ),
        ),
      );
      await _paint(tester);
      await _readyBook(tester);
      expect(routes.pages, hasLength(1));
      final mainReaderRoute = routes.pages.single;

      // 실제 읽기 화면의 현재 페이지를 눌러 상세로 들어간다.
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('reader-page-viewport'))),
      );
      await _paint(tester);
      final detail = find.byType(AlbumReaderInnerDetailScreen);
      expect(detail, findsOneWidget);
      expect(find.byType(ReaderPageGallery), findsOneWidget);
      expect(routes.pages, hasLength(2));
      final detailRoute = routes.pages.last;
      final detailState = tester.state(detail);
      final viewedPage = tester
          .widget<ReaderPageGallery>(find.byType(ReaderPageGallery))
          .currentPage;
      expect(mainReaderRoute.isCurrent, isFalse);
      expect(detailRoute.isCurrent, isTrue);
      await auditCapture(tester, '20-reader-inner-detail');

      await tester.tap(
        find.descendant(of: detail, matching: find.byTooltip('페이지 메뉴')),
      );
      await _paint(tester);
      expect(find.byType(AlbumReaderMoreOptionsSheet), findsOneWidget);
      expect(find.text('책으로 만들기').hitTestable(), findsOneWidget);
      await auditCapture(tester, '21-reader-detail-book-menu');

      await tester.tap(find.text('책으로 만들기'));
      await _paint(tester);
      expect(find.byType(AlbumReaderMoreOptionsSheet), findsNothing);
      // 뒤의 리더 Scaffold에도 등록되는 동일 안내를 현재 상세 범위에서 확인한다.
      expect(
        find
            .descendant(
              of: detail,
              matching: find.text('제작 확정은 메인 리더 화면에서 진행해주세요.'),
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(
        find.descendant(of: detail, matching: find.byType(SnackBar)),
        findsOneWidget,
      );
      expect(find.byType(PrintOrderPreviewScreen), findsNothing);
      expect(routes.pages, hasLength(2));
      expect(detailRoute.isCurrent, isTrue);
      expect(mainReaderRoute.isCurrent, isFalse);
      expect(tester.state(detail), same(detailState));
      expect(
        tester
            .widget<ReaderPageGallery>(find.byType(ReaderPageGallery))
            .currentPage,
        viewedPage,
      );
      // 스낵바의 대기 시간을 진행시키지 않고 안내와 원래 상세를 함께 담는다.
      await auditCapture(
        tester,
        '22-reader-book-action-instruction',
        settle: false,
      );
      expect(
        find.byType(AlbumReaderScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(AlbumReaderSinglePageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  });
}

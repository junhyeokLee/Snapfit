import 'dart:async';
import 'capture_support.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';

import 'package:book_page_flip/book_page_flip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_reader_inner_detail_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_reader_screen.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_preview_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_completion_confirmation.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_single_page_view.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_thumbnail_strip.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/reader_page_gallery.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';

class _PrintOrders extends Mock implements OrderRepository {}

class _ReaderModel extends AlbumEditorViewModel {
  Album document = const Album(id: 73, userId: 'owner', memberRole: 'OWNER', title: '우리의 여름, 오래 간직할 장면들');
  final documentPages = List.generate(
    7,
    (index) => AlbumPage(
      id: 'page-$index',
      pageIndex: index,
      isCover: index == 0,
      backgroundColor: 0xfff7f3ec,
      layers: [
        LayerModel(id: 'capture-photo-$index', type: LayerType.image,
          position: const Offset(30,40), width:440, height:360,
          imageUrl:'asset:assets/snapfit_home_square.jpg'),
        LayerModel(id: 'capture-text-$index', type: LayerType.text,
          position: const Offset(40,420), width:400, height:50,
          text:'오래 간직할 장면 $index', textStyle: const TextStyle(
            fontFamily:'Pretendard',fontSize:20,color:Color(0xff263e37))),
      ],
    ),
  );
  Object session = Object();

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

  void removePreviousPage() {
    documentPages.removeAt(1);
    state = const AsyncData(AlbumEditorState());
  }
}

class _EditorRoutes extends NavigatorObserver {
  final opened = <PageEditorScreen>[];
  final pages = <PageRoute<dynamic>>[];
  VoidCallback? duringEdit;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) pages.add(route);
    if (previousRoute == null || route is! MaterialPageRoute) return;
    final screen = route.builder(navigator!.context);
    if (screen is! PageEditorScreen) return;
    opened.add(screen);
    // Only the navigation contract matters here; do not mount the full editor.
    scheduleMicrotask(() {
      duringEdit?.call();
      navigator!.removeRoute(route);
    });
  }
}

class _Fixture {
  final model = _ReaderModel();
  final routes = _EditorRoutes();
  final navigator = GlobalKey<NavigatorState>();
  final orders = _PrintOrders();
  late ProviderContainer container;
  var owner = 'owner';
  var actor = 'owner';

  AlbumReaderSinglePageView get reader =>
      testerWidget<AlbumReaderSinglePageView>();
  late WidgetTester tester;
  T testerWidget<T extends Widget>() => tester.widget<T>(find.byType(T));

  Future<void> mount(WidgetTester tester) async {
    this.tester = tester;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 인쇄 진입은 실제 화면으로 확인하고 외부 주문 서버 요청만 차단한다.
    when(
      () => orders.fetchPrintCheckoutReadiness(albumId: any(named: 'albumId')),
    ).thenAnswer((_) async => throw StateError('offline reader fixture'));
    when(
      () => orders.fetchPrintPreviewSnapshot(albumId: any(named: 'albumId')),
    ).thenAnswer((_) async => throw StateError('offline reader fixture'));
    container = ProviderContainer(
      overrides: [
        albumEditorViewModelProvider.overrideWith(() => model),
        albumEditorOwnerReaderProvider.overrideWithValue(() => owner),
        albumCollaborationActorProvider.overrideWith((_) => actor),
        orderRepositoryProvider.overrideWithValue(orders),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SnapFitTheme.light(),
            navigatorKey: navigator,
            navigatorObservers: [routes],
            builder: (context, child) => auditFrame(MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )),
            home: const AlbumReaderScreen(initialSpreadIndex: 2),
          ),
        ),
      ),
    );
    await _paint(tester);
  }

  Future<void> inspectRightPage() async {
    await readyBook();
    await tester.tap(find.byTooltip('다음 페이지'));
    await _paint(tester);
    expect(reader.requestedFocusPageIndex, 4);
    // The clipped viewport, rather than the offscreen half-book, owns taps.
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('reader-page-viewport'))),
    );
    await _paint(tester);
    expect(find.byType(AlbumReaderInnerDetailScreen), findsOneWidget);
    expect(testerWidget<ReaderPageGallery>().currentPage, 3);
  }

  Future<void> makeBookFromDetail() async {
    final detail = find.byType(AlbumReaderInnerDetailScreen);
    await tester.tap(
      find.descendant(of: detail, matching: find.byTooltip('페이지 메뉴')),
    );
    await _paint(tester);
    await tester.tap(find.text('책으로 만들기'));
    await _paint(tester);
  }

  void changeContext(String change) {
    switch (change) {
      case 'session':
        model.session = Object();
      case 'document':
        model.document = model.document.copyWith(id: 99);
      case 'account':
        owner = 'another-owner';
      case 'actor':
        actor = 'another-owner';
        container.invalidate(albumCollaborationActorProvider);
      case 'permission':
        model.document = model.document.copyWith(memberRole: 'VIEWER');
    }
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    expect(tester.takeException(), isNull);
  }

  Future<BookFlipController> readyBook() async {
    // Raster capture completes outside the fake widget-test clock.
    for (var frame = 0; frame < 100; frame++) {
      final book = find.byType(BookFlip);
      if (book.evaluate().isNotEmpty) {
        final controller = testerWidget<BookFlip>().controller!;
        if (controller.isReady) return controller;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    throw TestFailure('The reader did not finish capturing its book pages.');
  }
}

Future<void> _paint(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  setUpAll(auditFonts);
  testWidgets('capture detail to existing print confirmation', (tester) async {
    final f=_Fixture(); await f.mount(tester);
    try {
      await f.inspectRightPage();
      await auditCapture(tester,'07-reader-detail-before-book-action');
      final detail=find.byType(AlbumReaderInnerDetailScreen);
      await tester.tap(find.descendant(of:detail,matching:find.byTooltip('페이지 메뉴')));
      await _paint(tester);
      await auditCapture(tester,'08-reader-detail-book-menu');
      await tester.tap(find.text('책으로 만들기')); await _paint(tester);
      expect(find.byType(AlbumReaderInnerDetailScreen),findsNothing);
      expect(find.byType(AlbumCompletionConfirmation),findsOneWidget);
      await auditCapture(tester,'09-reader-continues-to-print-confirmation');
      await tester.tap(find.text('취소')); await _paint(tester);
      expect(f.reader.requestedFocusPageIndex,4);
    } finally {await f.close();}
  });
}

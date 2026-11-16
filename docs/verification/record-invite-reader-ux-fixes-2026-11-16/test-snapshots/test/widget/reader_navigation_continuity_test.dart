import 'dart:async';

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
  Album document = const Album(id: 73, userId: 'owner', memberRole: 'OWNER');
  final documentPages = List.generate(
    7,
    (index) => AlbumPage(
      id: 'page-$index',
      pageIndex: index,
      isCover: index == 0,
      layers: const [],
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
            navigatorKey: navigator,
            navigatorObservers: [routes],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
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
  for (final role in ['OWNER', 'EDITOR']) {
    testWidgets(
      'detail book action resumes main print review and retains page for $role',
      (tester) async {
        final fixture = _Fixture();
        fixture.model.document = fixture.model.document.copyWith(
          memberRole: role,
        );
        await fixture.mount(tester);
        try {
          final mainState = tester.state(find.byType(AlbumReaderScreen));
          await fixture.inspectRightPage();
          await tester.tap(
            find.descendant(
              of: find.byType(AlbumReaderInnerDetailScreen),
              matching: find.byTooltip('다음 페이지'),
            ),
          );
          await _paint(tester);
          await fixture.makeBookFromDetail();

          expect(find.byType(AlbumReaderInnerDetailScreen), findsNothing);
          expect(find.byType(AlbumCompletionConfirmation), findsOneWidget);
          expect(find.byType(PrintOrderPreviewScreen), findsNothing);
          expect(fixture.reader.requestedFocusPageIndex, 5);
          expect(fixture.routes.pages, hasLength(2));
          verifyNever(
            () => fixture.orders.fetchPrintCheckoutReadiness(albumId: 73),
          );

          await tester.tap(find.text('취소'));
          await _paint(tester);
          expect(find.byType(AlbumCompletionConfirmation), findsNothing);
          expect(tester.state(find.byType(AlbumReaderScreen)), same(mainState));
          expect(fixture.reader.requestedFocusPageIndex, 5);

          await fixture.readyBook();
          await tester.tapAt(
            tester.getCenter(
              find.byKey(const ValueKey('reader-page-viewport')),
            ),
          );
          await _paint(tester);
          expect(fixture.testerWidget<ReaderPageGallery>().currentPage, 4);
          await fixture.makeBookFromDetail();
          await tester.tap(
            find.byKey(const ValueKey('album-completion-confirm')),
          );
          await _paint(tester);

          final preview = tester.widget<PrintOrderPreviewScreen>(
            find.byType(PrintOrderPreviewScreen),
          );
          expect(preview.albumId, 73);
          expect(find.byType(AlbumReaderInnerDetailScreen), findsNothing);
          expect(
            find.byType(AlbumReaderScreen, skipOffstage: false),
            findsOneWidget,
          );
          expect(fixture.routes.pages, hasLength(4));
          fixture.navigator.currentState!.pop();
          await _paint(tester);
          expect(tester.state(find.byType(AlbumReaderScreen)), same(mainState));
          expect(fixture.reader.requestedFocusPageIndex, 5);
        } finally {
          await fixture.close();
        }
      },
    );
  }

  for (final change in [
    'session',
    'document',
    'account',
    'actor',
    'permission',
  ]) {
    testWidgets('stale detail book action ignores changed $change', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.mount(tester);
      try {
        await fixture.inspectRightPage();
        await tester.tap(
          find.descendant(
            of: find.byType(AlbumReaderInnerDetailScreen),
            matching: find.byTooltip('페이지 메뉴'),
          ),
        );
        await _paint(tester);
        fixture.changeContext(change);
        await tester.tap(find.text('책으로 만들기'));
        await _paint(tester);
        expect(find.byType(AlbumCompletionConfirmation), findsNothing);
        expect(find.byType(PrintOrderPreviewScreen), findsNothing);
        verifyNever(
          () => fixture.orders.fetchPrintCheckoutReadiness(
            albumId: any(named: 'albumId'),
          ),
        );
        if (change != 'actor') {
          expect(fixture.reader.requestedFocusPageIndex, 4);
        }
      } finally {
        await fixture.close();
      }
    });
  }

  for (final change in [
    'session',
    'document',
    'account',
    'actor',
    'permission',
  ]) {
    testWidgets('print review confirmation ignores changed $change', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.mount(tester);
      try {
        await fixture.inspectRightPage();
        await fixture.makeBookFromDetail();
        expect(find.byType(AlbumCompletionConfirmation), findsOneWidget);
        fixture.changeContext(change);
        await tester.tap(
          find.byKey(const ValueKey('album-completion-confirm')),
        );
        await _paint(tester);
        expect(find.byType(PrintOrderPreviewScreen), findsNothing);
        verifyNever(
          () => fixture.orders.fetchPrintCheckoutReadiness(
            albumId: any(named: 'albumId'),
          ),
        );
      } finally {
        await fixture.close();
      }
    });
  }

  testWidgets('portrait always shows page thumbnails and the current page', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.mount(tester);
    try {
      await fixture.readyBook();
      expect(find.byType(AlbumReaderThumbnailStrip), findsOneWidget);
      expect(find.byKey(const ValueKey('reader-album-title')), findsOneWidget);
      expect(find.byTooltip('쪽 목록 열기'), findsNothing);
      expect(find.byTooltip('쪽 목록 닫기'), findsNothing);
      expect(find.text('전체 쪽'), findsNothing);
      expect(
        find.byKey(const ValueKey('reader-page-position')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('3 / 6쪽'), findsOneWidget);
      expect(fixture.reader.requestedFocusPageIndex, 3);
      await tester.tap(find.byTooltip('다음 페이지'));
      await _paint(tester);
      expect(find.byType(AlbumReaderThumbnailStrip), findsOneWidget);
      expect(find.text('4 / 6쪽'), findsOneWidget);
    } finally {
      await fixture.close();
    }
  });

  testWidgets('portrait reader shows one full-size page at its album ratio', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.mount(tester);
    try {
      await fixture.readyBook();
      final page = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('reader-live-spread')),
          matching: find.byKey(const ValueKey('book_flip_album_page_3')),
        ),
      );
      expect(
        page.width,
        greaterThanOrEqualTo(312),
        reason:
            'One album page must occupy at least 80% of the 390px viewport.',
      );
      expect(
        page.width / page.height,
        closeTo(fixture.reader.selectedCover.ratio, .001),
      );
    } finally {
      await fixture.close();
    }
  });

  testWidgets('portrait next reads the right page before turning the sheet', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.mount(tester);
    try {
      final controller = await fixture.readyBook();
      expect(fixture.reader.requestedFocusPageIndex, 3);
      expect(controller.currentSpread, 2);

      await tester.tap(find.byTooltip('다음 페이지'));
      await _paint(tester);

      expect(fixture.reader.requestedFocusPageIndex, 4);
      expect(
        controller.currentSpread,
        2,
        reason: 'Pages 3 and 4 share the same open spread.',
      );
      await tester.tap(find.byTooltip('앨범 메뉴'));
      await _paint(tester);
      expect(find.text('4쪽 편집'), findsOneWidget);
    } finally {
      await fixture.close();
    }
  });

  testWidgets('reader menu edits the page currently being viewed', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.mount(tester);
    try {
      await tester.tap(find.byTooltip('앨범 메뉴'));
      await _paint(tester);
      await tester.tap(find.text('3쪽 편집'));
      await _paint(tester);
      expect(fixture.routes.opened.single.initialPageIndex, 3);
      expect(fixture.routes.opened.single.returnToPreviousOnSave, isTrue);
      await tester.tap(find.byTooltip('다음 페이지'));
      await _paint(tester);
      expect(fixture.reader.requestedFocusPageIndex, 4);
    } finally {
      await fixture.close();
    }
  });

  testWidgets('detail navigation resumes at the last viewed page after back', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.mount(tester);
    try {
      await fixture.inspectRightPage();
      await tester.tap(
        find.descendant(
          of: find.byType(AlbumReaderInnerDetailScreen),
          matching: find.byTooltip('다음 페이지'),
        ),
      );
      await _paint(tester);
      expect(fixture.testerWidget<ReaderPageGallery>().currentPage, 4);
      expect(fixture.reader.requestedFocusPageIndex, 4);
      fixture.navigator.currentState!.pop();
      await _paint(tester);
      expect(fixture.reader.requestedFocusPageIndex, 5);
      await tester.tap(find.byTooltip('앨범 메뉴'));
      await _paint(tester);
      await tester.tap(find.text('5쪽 편집'));
      await _paint(tester);
      expect(fixture.routes.opened.single.initialPageIndex, 5);
    } finally {
      await fixture.close();
    }
  });

  testWidgets(
    'editing keeps the viewed page ID after an earlier page is deleted',
    (tester) async {
      final fixture = _Fixture();
      fixture.routes.duringEdit = fixture.model.removePreviousPage;
      await fixture.mount(tester);
      try {
        await tester.tap(find.byTooltip('앨범 메뉴'));
        await _paint(tester);
        await tester.tap(find.text('3쪽 편집'));
        await _paint(tester);
        expect(fixture.routes.opened.single.initialPageIndex, 3);
        expect(fixture.reader.requestedFocusPageIndex, 2);
        expect(fixture.model.pages[2].id, 'page-3');
        fixture.routes.duringEdit = null;
        // Rebuilding the raster renderer must retain a right-hand page focus.
        tester.view.physicalSize = const Size(844, 390);
        await _paint(tester);
        await tester.tap(find.byTooltip('현재 페이지 편집'));
        await _paint(tester);
        expect(fixture.routes.opened.last.initialPageIndex, 2);
      } finally {
        await fixture.close();
      }
    },
  );

  testWidgets(
    'viewer cannot edit and stale detail results cannot move a new document',
    (tester) async {
      final fixture = _Fixture();
      fixture.model.document = fixture.model.document.copyWith(
        memberRole: 'VIEWER',
      );
      await fixture.mount(tester);
      try {
        await tester.tap(find.byTooltip('앨범 메뉴'));
        await _paint(tester);
        expect(find.textContaining('보기 전용 앨범이에요.'), findsOneWidget);
        expect(fixture.routes.opened, isEmpty);
        ScaffoldMessenger.of(
          tester.element(find.byType(AlbumReaderScreen)),
        ).hideCurrentSnackBar();
        await _paint(tester);
        await fixture.inspectRightPage();
        expect(fixture.testerWidget<ReaderPageGallery>().onEdit, isNull);
        await tester.tap(
          find.descendant(
            of: find.byType(AlbumReaderInnerDetailScreen),
            matching: find.byTooltip('페이지 메뉴'),
          ),
        );
        await _paint(tester);
        expect(find.text('책으로 만들기'), findsNothing);
        expect(find.byType(AlbumCompletionConfirmation), findsNothing);
        expect(find.byType(PrintOrderPreviewScreen), findsNothing);
        ScaffoldMessenger.of(
          tester.element(find.byType(AlbumReaderInnerDetailScreen)),
        ).hideCurrentSnackBar();
        await _paint(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(AlbumReaderInnerDetailScreen),
            matching: find.byTooltip('다음 페이지'),
          ),
        );
        await _paint(tester);
        fixture.model.session = Object();
        fixture.model.document = fixture.model.document.copyWith(id: 99);
        fixture.owner = 'another-owner';
        fixture.navigator.currentState!.pop();
        await _paint(tester);
        expect(fixture.reader.requestedFocusPageIndex, 4);
        expect(fixture.routes.opened, isEmpty);
      } finally {
        await fixture.close();
      }
    },
  );
}

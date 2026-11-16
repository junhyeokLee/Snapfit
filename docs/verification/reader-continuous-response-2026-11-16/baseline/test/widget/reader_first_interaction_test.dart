import 'dart:async';

import 'package:book_page_flip/book_page_flip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_single_page_view.dart';

const _viewport = Size(390, 844);
const _innerPages = 40;

class _Editor extends AlbumEditorViewModel {
  @override
  FutureOr<AlbumEditorState> build() => const AlbumEditorState();
}

Future<void> _coldReader(WidgetTester tester) async {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final pageController = PageController();
  final canvas = coverCanvasBaseSize(defaultCoverSize);
  final interaction = LayerInteractionManager.printPreview(() => canvas);
  addTearDown(pageController.dispose);
  addTearDown(interaction.dispose);
  addTearDown(() async {
    // 실패한 첫 입력도 진행 중인 래스터화/애니메이션을 남기지 않는다.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  final pages = List.generate(
    _innerPages + 1,
    (index) => AlbumPage(
      id: 'cold-page-$index',
      pageIndex: index,
      isCover: index == 0,
      backgroundColor: index.isEven ? 0xffe8f0e9 : 0xfff7f3ec,
      layers: [
        LayerModel(
          id: 'cold-caption-$index',
          type: LayerType.text,
          position: Offset(canvas.width * .1, canvas.height * .4),
          width: canvas.width * .8,
          height: canvas.height * .2,
          text: 'PAGE $index',
          textStyle: const TextStyle(fontSize: 24, color: Color(0xff263e37)),
        ),
      ],
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [albumEditorViewModelProvider.overrideWith(_Editor.new)],
      child: ScreenUtilInit(
        designSize: _viewport,
        builder: (_, child) => MaterialApp(home: Scaffold(body: child)),
        child: AlbumReaderSinglePageView(
          allPages: pages,
          selectedCover: defaultCoverSize,
          coverTheme: CoverTheme.classic,
          pageController: pageController,
          interaction: interaction,
          layerBuilder: LayerBuilder(interaction, () => canvas),
          canvasKey: GlobalKey(),
          onCanvasSizeChanged: (_) {},
          onPageChanged: (_) {},
          onStateChanged: () {},
          focusMode: true,
          singlePageFocus: true,
        ),
      ),
    ),
  );
  // 준비 완료를 기다리면 최초 진입에서 유실되는 입력을 숨기게 된다.
}

BookFlipController? _controller(WidgetTester tester) {
  final book = find.byType(BookFlip);
  // 첫 프레임에는 실제 BookFlip 대신 페이지 래스터화 위젯만 있을 수 있다.
  return book.evaluate().isEmpty
      ? null
      : tester.widget<BookFlip>(book.first).controller;
}

double _cameraX(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('reader-focus-transform')))
    .transform
    .storage[12];

String _position(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('reader-page-position')))
    .data!;

Future<void> _frame(WidgetTester tester) async {
  // toImage 완료가 실제 이벤트 루프로 돌아올 기회를 주되 준비는 기다리지 않는다.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 2)),
  );
  await tester.pump(const Duration(milliseconds: 16));
}

Future<bool> _firstMotion(WidgetTester tester, double startX) async {
  final pageWidth =
      tester.getSize(find.byKey(const ValueKey('reader-focus-book'))).width / 2;
  final endX = pageWidth / 2;
  var moved = false;
  int? firstResponseFrame;
  for (var frame = 0; frame < 8; frame++) {
    await _frame(tester);
    final controller = _controller(tester);
    final x = _cameraX(tester);
    // 최종 위치로 순간 이동하는 폴백은 종이 모션으로 인정하지 않는다.
    final moving =
        (x > startX + .5 && x < endX - .5) ||
        (controller != null &&
            controller.isAnimating &&
            controller.flipProgress > 0 &&
            controller.flipProgress < 1);
    moved |= moving;
    if (moving) firstResponseFrame ??= frame + 1;
  }
  debugPrint('READER_FIRST_RESPONSE frames=$firstResponseFrame budget=8');
  return moved;
}

Future<void> _expectFirstPage(WidgetTester tester) async {
  for (var frame = 0; frame < 80; frame++) {
    if (_position(tester) == '1 / ${_innerPages}쪽' &&
        _controller(tester)?.isAnimating != true) {
      break;
    }
    await _frame(tester);
  }
  expect(_position(tester), '1 / ${_innerPages}쪽');
  expect(_controller(tester)?.isAnimating, isNot(true));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('a quick cold-entry swipe is retained after the finger lifts', (
    tester,
  ) async {
    await _coldReader(tester);
    final startX = _cameraX(tester);
    final viewport = tester.getRect(
      find.byKey(const ValueKey('reader-page-viewport')),
    );
    final gesture = await tester.startGesture(viewport.center);
    await gesture.moveBy(Offset(-viewport.width * .45, 0));
    await gesture.up();
    expect(await _firstMotion(tester, startX), isTrue);
    await _expectFirstPage(tester);
  });

  for (final cancel in [false, true]) {
    testWidgets('an aborted cold swipe restores the cover cancel=$cancel', (
      tester,
    ) async {
      await _coldReader(tester);
      final startX = _cameraX(tester);
      final viewport = tester.getRect(
        find.byKey(const ValueKey('reader-page-viewport')),
      );
      final gesture = await tester.startGesture(viewport.center);
      await gesture.moveBy(const Offset(-10, 0));
      if (cancel) {
        await gesture.cancel();
      } else {
        await gesture.up();
      }
      for (var frame = 0; frame < 14; frame++) {
        await _frame(tester);
      }
      expect(_position(tester), '표지 / ${_innerPages}쪽');
      expect(_cameraX(tester), closeTo(startX, .1));
      await tester.tap(find.byTooltip('다음 페이지'));
      expect(await _firstMotion(tester, startX), isTrue);
      await _expectFirstPage(tester);
    });
  }

  testWidgets('the first cold-entry swipe moves without waiting for the book', (
    tester,
  ) async {
    await _coldReader(tester);
    final startX = _cameraX(tester);
    final viewport = tester.getRect(
      find.byKey(const ValueKey('reader-page-viewport')),
    );
    final gesture = await tester.startGesture(
      Offset(viewport.left + viewport.width * .85, viewport.center.dy),
    );
    var moved = false;
    try {
      await gesture.moveBy(Offset(-viewport.width * .45, 0));
      moved = await _firstMotion(tester, startX);
    } finally {
      await gesture.up();
    }
    expect(
      moved,
      isTrue,
      reason: 'The first held swipe must move before distant pages are ready.',
    );
    await _expectFirstPage(tester);
  });

  testWidgets('the first cold-entry button starts a turn instead of jumping', (
    tester,
  ) async {
    await _coldReader(tester);
    final startX = _cameraX(tester);
    await tester.tap(find.byTooltip('다음 페이지'));
    expect(
      await _firstMotion(tester, startX),
      isTrue,
      reason: 'The first button press must animate while the long book warms.',
    );
    await _expectFirstPage(tester);
  });
}

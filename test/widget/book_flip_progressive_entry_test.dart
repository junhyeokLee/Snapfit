import 'dart:async';
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _paintFrames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame++) {
    // Raster image completion needs the real event loop in a widget test.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100 && !ready(); frame++) {
    await _paintFrames(tester, 1);
  }
  expect(ready(), isTrue);
}

Widget _book(
  BookFlipController controller,
  Future<void> Function(BuildContext, int) prepare, {
  GlobalKey? captureKey,
  bool preparationPaused = false,
}) => MaterialApp(
  home: Center(
    child: RepaintBoundary(
      key: captureKey,
      child: SizedBox(
        width: 320,
        height: 240,
        child: ColoredBox(
          color: Colors.green,
          child: BookFlip.builder(
            progressive: true,
            preparationPaused: preparationPaused,
            controller: controller,
            pageCount: 40,
            pageSize: const Size(160, 240),
            pixelRatio: 1,
            curl: BookFlipCurl.albumPreview,
            transparentPages: const {0},
            effects: const BookFlipEffects(
              gloss: false,
              grain: false,
              castShadow: false,
              spineShadow: false,
              edge: false,
              translucency: false,
            ),
            preparePage: prepare,
            pageBuilder: (_, page) => ColoredBox(
              color: page == 4 ? Colors.red : const Color(0xff0000ff),
            ),
          ),
        ),
      ),
    ),
  ),
);

void _releaseAtTearDown(Completer<void> gate) {
  addTearDown(() {
    if (!gate.isCompleted) gate.complete();
  });
}

void main() {
  testWidgets('a distant photo does not block the first turn of a long book', (
    tester,
  ) async {
    final distantPhoto = Completer<void>();
    final controller = BookFlipController();
    addTearDown(controller.dispose);
    addTearDown(() {
      if (!distantPhoto.isCompleted) distantPhoto.complete();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 240,
            child: BookFlip.builder(
              progressive: true,
              controller: controller,
              pageCount: 40,
              pageSize: const Size(160, 240),
              pixelRatio: 1,
              curl: BookFlipCurl.albumPreview,
              preparePage: (_, index) =>
                  index == 39 ? distantPhoto.future : Future<void>.value(),
              pageBuilder: (_, index) =>
                  ColoredBox(color: index.isEven ? Colors.orange : Colors.blue),
            ),
          ),
        ),
      ),
    );

    await _paintFrames(tester, 100);
    expect(distantPhoto.isCompleted, isFalse);
    expect(
      controller.isReady,
      isTrue,
      reason: 'The current spread must be usable before distant photos finish.',
    );
    expect(controller.totalSpreads, 20);
    expect(controller.nextSpread(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.flipProgress, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the next spread turns while the following photo stays pending', (
    tester,
  ) async {
    final nextSpreadPhotos = Completer<void>();
    final laterPhoto = Completer<void>();
    _releaseAtTearDown(nextSpreadPhotos);
    _releaseAtTearDown(laterPhoto);
    final controller = BookFlipController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _book(
        controller,
        (_, page) => page == 4 || page == 5
            ? nextSpreadPhotos.future
            : page == 6
            ? laterPhoto.future
            : Future<void>.value(),
      ),
    );
    await _until(tester, () => controller.isReady);
    expect(controller.nextSpread(), isTrue);
    await _until(tester, () => !controller.isAnimating);
    expect(controller.currentSpread, 1);
    expect(controller.isSpreadReady(2), isFalse);
    controller.requestSpread(2);
    nextSpreadPhotos.complete();
    await _until(tester, () => controller.isSpreadReady(2));
    expect(laterPhoto.isCompleted, isFalse);
    expect(controller.nextSpread(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.flipProgress, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 501));
    expect(controller.currentSpread, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a requested captured spread can bypass a blocked background page',
    (tester) async {
      final backgroundPhoto = Completer<void>();
      _releaseAtTearDown(backgroundPhoto);
      final controller = BookFlipController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _book(
          controller,
          (_, page) =>
              page == 10 ? backgroundPhoto.future : Future<void>.value(),
        ),
      );
      await _until(tester, () => controller.isReady);
      // Pages 4..9 finish behind the book while page 10 still awaits its photo.
      await _paintFrames(tester, 30);
      expect(controller.isSpreadReady(3), isFalse);
      controller.requestSpread(3);
      await _until(tester, () => controller.isSpreadReady(3));
      expect(backgroundPhoto.isCompleted, isFalse);
      controller.goToSpread(3);
      expect(controller.currentSpread, 3);
      expect(controller.isReady, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('moving leaf pauses distant preparation until settling', (
    tester,
  ) async {
    final backgroundPhoto = Completer<void>();
    _releaseAtTearDown(backgroundPhoto);
    final preparedPages = <int>[];
    final controller = BookFlipController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _book(controller, (_, page) {
        preparedPages.add(page);
        return page == 4 ? backgroundPhoto.future : Future<void>.value();
      }),
    );
    await _until(tester, () => controller.isReady && preparedPages.contains(4));
    await tester.pump(); // The first ready texture can precede canvas layout.
    expect(controller.dragStart(const Offset(250, 100)), isTrue);
    expect(
      controller.dragToDistance(
        localPosition: const Offset(200, 100),
        direction: FlipDirection.forward,
        distance: 64,
      ),
      isTrue,
    );
    await tester.pump();
    backgroundPhoto.complete();
    await _paintFrames(tester, 20);
    expect(controller.isAnimating, isTrue);
    expect(
      preparedPages.where((page) => page >= 5),
      isEmpty,
      reason: 'Hidden photo preparation must yield to the moving leaf.',
    );
    controller.dragEndWithDecision(0, commit: true);
    await _until(tester, () => !controller.isAnimating);
    await _until(tester, () => preparedPages.any((page) => page >= 5));
    expect(controller.currentSpread, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a host pause leaves the book animation running', (tester) async {
    final backgroundPhoto = Completer<void>();
    _releaseAtTearDown(backgroundPhoto);
    final preparedPages = <int>[];
    final paused = ValueNotifier(false);
    addTearDown(paused.dispose);
    final controller = BookFlipController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: paused,
        builder: (_, isPaused, _) => _book(controller, (_, page) {
          preparedPages.add(page);
          return page == 4 ? backgroundPhoto.future : Future<void>.value();
        }, preparationPaused: isPaused),
      ),
    );
    await _until(tester, () => controller.isReady && preparedPages.contains(4));
    paused.value = true;
    await tester.pump();
    backgroundPhoto.complete();
    await _paintFrames(tester, 20);
    expect(preparedPages.where((page) => page >= 5), isEmpty);
    expect(controller.nextSpread(), isTrue);
    await _until(tester, () => !controller.isAnimating);
    expect(controller.currentSpread, 1);
    expect(preparedPages.where((page) => page >= 5), isEmpty);
    paused.value = false;
    await _until(tester, () => preparedPages.any((page) => page >= 5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background snapshots keep the same held leaf and renderer', (
    tester,
  ) async {
    final backgroundPhoto = Completer<void>();
    _releaseAtTearDown(backgroundPhoto);
    final controller = BookFlipController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _book(
        controller,
        (_, page) => page == 4 ? backgroundPhoto.future : Future<void>.value(),
      ),
    );
    await _until(tester, () => controller.isReady);
    await tester
        .pump(); // Attach the canvas before testing an already-held leaf.
    final renderer = tester.state(find.byType(BookFlip));
    final pages = tester.widget<BookFlip>(find.byType(BookFlip)).pages;
    expect(controller.dragStart(const Offset(250, 100)), isTrue);
    expect(
      controller.dragToDistance(
        localPosition: const Offset(200, 100),
        direction: FlipDirection.forward,
        distance: 64,
      ),
      isTrue,
    );
    final progress = controller.flipProgress;
    backgroundPhoto.complete();
    await _paintFrames(tester, 100);

    expect(controller.isAnimating, isTrue);
    expect(controller.flipProgress, closeTo(progress, .00001));
    expect(tester.state(find.byType(BookFlip)), same(renderer));
    expect(tester.widget<BookFlip>(find.byType(BookFlip)).pages, same(pages));
    controller.dragEndWithDecision(0, commit: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.currentSpread, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'hidden capture pixels retain their colour without leaking through the cover',
    (tester) async {
      final backgroundPhoto = Completer<void>();
      _releaseAtTearDown(backgroundPhoto);
      final controller = BookFlipController();
      addTearDown(controller.dispose);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        _book(
          controller,
          (_, page) =>
              page == 4 ? backgroundPhoto.future : Future<void>.value(),
          captureKey: captureKey,
        ),
      );
      await _until(tester, () => controller.isReady);
      await _paintFrames(tester, 4);
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final screen = (await tester.runAsync(() => boundary.toImage()))!;
      final screenPixels = (await tester.runAsync(
        () => screen.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final leftCentre = (120 * screen.width + 80) * 4;
      expect(screenPixels.getUint8(leftCentre), Colors.green.red);
      expect(screenPixels.getUint8(leftCentre + 1), Colors.green.green);
      expect(screenPixels.getUint8(leftCentre + 2), Colors.green.blue);
      screen.dispose();
      final page = tester.widget<BookFlip>(find.byType(BookFlip)).pages[1];
      final pagePixels = (await tester.runAsync(
        () => page.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final centre = ((page.height ~/ 2) * page.width + page.width ~/ 2) * 4;
      expect(pagePixels.getUint8(centre + 2), 255);
      expect(pagePixels.getUint8(centre + 3), 255);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

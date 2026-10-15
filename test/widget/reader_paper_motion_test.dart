import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:book_page_flip/src/engine.dart' as engine;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_single_page_view.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_cover_frame.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

const _curl = BookFlipCurl(bend: .55, foldTilt: .82, droop: .14, roll: 1);
const _noSagCurl = BookFlipCurl(bend: .55, foldTilt: .82, roll: 1);
const _background = Color(0xffeff2f1);

class _ReaderRole extends AlbumEditorViewModel {
  _ReaderRole(this.role);
  final String role;
  @override
  Album? get album => Album(id: 7, memberRole: role);
  @override
  FutureOr<AlbumEditorState> build() => const AlbumEditorState();
}

Future<void> _ready(WidgetTester tester, BookFlipController controller) async {
  for (var i = 0; i < 100 && !controller.isReady; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(controller.isReady, isTrue);
  await tester.pump();
}

Future<void> _settle(WidgetTester tester, BookFlipController controller) async {
  for (var i = 0; i < 100 && controller.isAnimating; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(controller.isAnimating, isFalse);
  await tester.pump();
}

Future<ui.Image> _capture(WidgetTester tester, GlobalKey key) async {
  await tester.pump();
  return (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return boundary.toImage(pixelRatio: 1);
  }))!;
}

Future<void> _save(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('READER_MOTION_QA')) return;
  final image = await _capture(tester, key);
  await tester.runAsync(() async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/reader-motion-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

List<AlbumPage> _album(CoverSize cover) {
  final canvas = coverCanvasBaseSize(cover);
  const photos = [
    'assets/snapfit_home_portrait.jpg',
    'assets/snapfit_home_square.jpg',
    'assets/snapfit_home_landscape.jpg',
  ];
  return List.generate(
    9,
    (index) => AlbumPage(
      id: 'motion-$index',
      pageIndex: index,
      isCover: index == 0,
      backgroundColor: index.isEven ? 0xffe8f0e9 : 0xfff7f3ec,
      layers: [
        LayerModel(
          id: 'photo-$index',
          type: LayerType.image,
          position: Offset(canvas.width * .06, canvas.height * .08),
          width: canvas.width * .88,
          height: canvas.height * .72,
          imageUrl: 'asset:${photos[index % photos.length]}',
        ),
        LayerModel(
          id: 'caption-$index',
          type: LayerType.text,
          position: Offset(canvas.width * .08, canvas.height * .84),
          width: canvas.width * .8,
          height: canvas.height * .1,
          text: 'SNAPFIT / ${index.toString().padLeft(2, '0')}',
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            color: Color(0xff263e37),
          ),
        ),
      ],
    ),
  );
}

Future<BookFlipController> _reader(
  WidgetTester tester, {
  required Size viewport,
  required CoverSize cover,
  required GlobalKey captureKey,
  int spread = 2,
  ValueNotifier<List<AlbumPage>>? pagesNotifier,
  String? memberRole,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final pageController = PageController(initialPage: spread);
  addTearDown(pageController.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (memberRole != null)
          albumEditorViewModelProvider.overrideWith(
            () => _ReaderRole(memberRole),
          ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, child) => MaterialApp(
          home: Scaffold(backgroundColor: _background, body: child),
        ),
        child: Consumer(
          builder: (context, ref, child) {
            final size = coverCanvasBaseSize(cover);
            final interaction = LayerInteractionManager.preview(
              ref,
              () => size,
            );
            Widget buildReader(List<AlbumPage> pages) => RepaintBoundary(
              key: captureKey,
              child: ColoredBox(
                color: _background,
                child: AlbumReaderSinglePageView(
                  allPages: pages,
                  selectedCover: cover,
                  coverTheme: CoverTheme.classic,
                  pageController: pageController,
                  interaction: interaction,
                  layerBuilder: LayerBuilder(interaction, () => size),
                  canvasKey: GlobalKey(),
                  onCanvasSizeChanged: (_) {},
                  onPageChanged: (_) {},
                  onStateChanged: () {},
                  focusMode: true,
                ),
              ),
            );
            return pagesNotifier == null
                ? buildReader(_album(cover))
                : ValueListenableBuilder<List<AlbumPage>>(
                    valueListenable: pagesNotifier,
                    builder: (_, pages, _) => buildReader(pages),
                  );
          },
        ),
      ),
    ),
  );
  for (var i = 0; i < 100 && find.byType(BookFlip).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  final controller = tester.widget<BookFlip>(find.byType(BookFlip)).controller!;
  await _ready(tester, controller);
  return controller;
}

void main() {
  setUpAll(loadCreationFonts);

  test('curl option survives copying, interpolation and equality', () {
    expect(_curl.copyWith(), _curl);
    expect(_curl.copyWith(roll: 0), isNot(_curl));
    expect(BookFlipCurl.lerp(_curl.copyWith(roll: 0), _curl, .5).roll, .5);
  });

  test(
    'travelling fold leaves the unturned paper flat and the spine attached',
    () {
      final mesh = engine.BookFlipMesh(nu: 81, nv: 21);
      mesh.computeWorld(600, 400, .24, .5, 1, curl: _noSagCurl);
      final row = mesh.nv ~/ 2;
      for (var i = 0; i <= 30; i++) {
        final index = row * mesh.nu + i;
        expect(mesh.wz[index], closeTo(0, .0001));
        expect(mesh.wx[index], closeTo(300 + i / 80 * 300, .0001));
      }
      expect(mesh.maxAbsZ(), greaterThan(25));
      for (var j = 0; j < mesh.nv; j++) {
        expect(mesh.wx[j * mesh.nu], closeTo(300, .0001));
        expect(mesh.wz[j * mesh.nu], closeTo(0, .0001));
      }
      // Each row keeps its paper length through the curved and flat sections.
      var length = 0.0;
      for (var i = 1; i < mesh.nu; i++) {
        final a = row * mesh.nu + i - 1, b = a + 1;
        length += math.sqrt(
          math.pow(mesh.wx[b] - mesh.wx[a], 2) +
              math.pow(mesh.wz[b] - mesh.wz[a], 2),
        );
      }
      expect(length, closeTo(300, 1));
    },
  );

  test('grip height changes which part of the page turns first', () {
    final top = engine.BookFlipMesh(nu: 41, nv: 21);
    final bottom = engine.BookFlipMesh(nu: 41, nv: 21);
    top.computeWorld(600, 400, .4, .1, 1, curl: _curl);
    bottom.computeWorld(600, 400, .4, .9, 1, curl: _curl);
    final topEdge = 2 * top.nu + top.nu - 1;
    expect((top.wx[topEdge] - bottom.wx[topEdge]).abs(), greaterThan(20));
  });

  for (final viewport in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('viewer keeps page turns but cannot edit at $viewport', (
      tester,
    ) async {
      final controller = await _reader(
        tester,
        viewport: viewport,
        cover: defaultCoverSize,
        captureKey: GlobalKey(),
        memberRole: 'VIEWER',
      );
      expect(find.text('편집'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '보기 전용 앨범' &&
              w.properties.enabled == false,
        ),
        findsOneWidget,
      );
      final spread = controller.currentSpread;
      await tester.tap(find.bySemanticsLabel('다음 페이지'));
      await tester.pump();
      await _settle(tester, controller);
      expect(controller.currentSpread, spread + 1);
    });
  }

  for (final ratio in [.75, 1.0, 4 / 3]) {
    test('curl is finite, mirrored and lands exactly flat at ratio $ratio', () {
      final forward = engine.BookFlipMesh(nu: 35, nv: 25);
      final backward = engine.BookFlipMesh(nu: 35, nv: 25);
      const w = 600.0;
      final h = 300 / ratio;
      for (final grab in [0.0, .5, 1.0]) {
        for (var frame = 0; frame <= 100; frame++) {
          final t = frame / 100;
          forward.computeWorld(w, h, t, grab, 1, curl: _curl);
          backward.computeWorld(w, h, t, grab, -1, curl: _curl);
          forward.project(w, h, engine.kFovY);
          backward.project(w, h, engine.kFovY);
          expect(forward.lastBadCount + backward.lastBadCount, 0);
          for (var i = 0; i < forward.n; i++) {
            expect(forward.wx[i] + backward.wx[i], closeTo(w, .0001));
            expect(forward.wz[i], greaterThanOrEqualTo(-.0001));
            if (frame == 0 || frame == 100) {
              final sign = frame == 0 ? 1 : -1;
              expect(
                forward.wx[i],
                closeTo(w / 2 + sign * forward.uNorm[i] * w / 2, .0001),
              );
              expect(forward.wz[i], closeTo(0, .0001));
            }
          }
        }
      }
    });
  }

  for (final viewport in [const Size(390, 844), const Size(844, 390)]) {
    for (final cover in legacyCoverSizes) {
      final name =
          '${viewport.width.toInt()}-${cover.ratio.toStringAsFixed(2)}';
      testWidgets('reader swipe, cancel, reverse and re-grab $name', (
        tester,
      ) async {
        final key = GlobalKey();
        final controller = await _reader(
          tester,
          viewport: viewport,
          cover: cover,
          captureKey: key,
        );
        final book = find.byType(BookFlip);
        final rect = tester.getRect(book);
        final start = Offset(
          rect.right - rect.width * .12,
          rect.top + rect.height * .26,
        );
        await _save(tester, key, '$name-idle');
        final gesture = await tester.startGesture(start);
        await gesture.moveBy(Offset(-rect.width * .12, 18));
        await tester.pump();
        expect(controller.flipProgress, greaterThan(.08));
        expect(controller.flipDirection, FlipDirection.forward);
        await _save(tester, key, '$name-early');
        await gesture.moveBy(Offset(-rect.width * .29, 22));
        await tester.pump();
        final held = controller.flipProgress;
        expect(held, greaterThan(.44));
        await _save(tester, key, '$name-middle');
        await tester.pump(const Duration(milliseconds: 160));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.isAnimating, isTrue);
        final beforeGrab = controller.flipProgress;
        final regrab = await tester.startGesture(
          start.translate(-rect.width * .2, 0),
        );
        await regrab.moveBy(const Offset(10, 0));
        await tester.pump();
        expect(
          controller.flipProgress,
          closeTo(beforeGrab - 10 * .64 / (rect.width / 2), .005),
        );
        await tester.pump(const Duration(milliseconds: 120));
        expect(
          controller.flipProgress,
          closeTo(beforeGrab - 10 * .64 / (rect.width / 2), .005),
        );
        await regrab.up();
        await _settle(tester, controller);
        expect(controller.currentSpread, 3);

        final reverse = await tester.startGesture(
          Offset(rect.left + rect.width * .12, rect.bottom - rect.height * .2),
        );
        await reverse.moveBy(Offset(rect.width * .41, -22));
        await tester.pump();
        expect(controller.flipDirection, FlipDirection.backward);
        await _save(tester, key, '$name-backward');
        await reverse.up();
        await _settle(tester, controller);
        expect(controller.currentSpread, 2);

        final cancel = await tester.startGesture(start);
        await cancel.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 200));
        await cancel.up();
        await _settle(tester, controller);
        expect(controller.currentSpread, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('cover still opens and closes without a second static sheet', (
    tester,
  ) async {
    final key = GlobalKey();
    final controller = await _reader(
      tester,
      viewport: const Size(844, 390),
      cover: defaultCoverSize,
      captureKey: key,
      spread: 0,
    );
    final book = find.byType(BookFlip);
    final originalRenderer = tester.state(book);
    final rect = tester.getRect(book);
    final gesture = await tester.startGesture(
      Offset(rect.right - rect.width * .15, rect.center.dy),
    );
    await gesture.moveBy(Offset(-rect.width * .42, 0));
    await tester.pump();
    expect(controller.flipDirection, FlipDirection.forward);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is AlbumBookDepthPainter,
      ),
      findsNothing,
    );
    await gesture.up();
    await _settle(tester, controller);
    expect(controller.currentSpread, 1);
    expect(tester.state(book), same(originalRenderer));
    final spreadRect = tester.getRect(book);
    final close = await tester.startGesture(
      Offset(spreadRect.left + spreadRect.width * .12, spreadRect.center.dy),
    );
    await close.moveBy(Offset(spreadRect.width * .43, 0));
    await tester.pump();
    expect(controller.flipDirection, FlipDirection.backward);
    await close.up();
    await _settle(tester, controller);
    expect(controller.currentSpread, 0);
    expect(tester.state(book), same(originalRenderer));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is AlbumBookDepthPainter,
      ),
      findsOneWidget,
    );
    await _save(tester, key, 'closed-cover');
    final coverImage = await _capture(tester, key);
    final pixels = await tester.runAsync(() => coverImage.toByteData());
    final sample = (175 * coverImage.width + 100) * 4;
    expect(pixels!.getUint8(sample), 0xef);
    expect(pixels.getUint8(sample + 1), 0xf2);
    expect(pixels.getUint8(sample + 2), 0xf1);
    coverImage.dispose();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'vertical finger travel reshapes the held paper without advancing it',
    (tester) async {
      final key = GlobalKey();
      final controller = await _reader(
        tester,
        viewport: const Size(844, 390),
        cover: defaultCoverSize,
        captureKey: key,
      );
      final rect = tester.getRect(find.byType(BookFlip));
      final gesture = await tester.startGesture(
        Offset(rect.right - 30, rect.top + rect.height * .12),
      );
      await gesture.moveBy(Offset(-rect.width * .23, 0));
      await tester.pump();
      final progress = controller.flipProgress;
      final topImage = await _capture(tester, key);
      await gesture.moveBy(Offset(0, rect.height * .65));
      await tester.pump();
      expect(controller.flipProgress, closeTo(progress, .0001));
      final bottomImage = await _capture(tester, key);
      final topPixels = await tester.runAsync(() => topImage.toByteData());
      final bottomPixels = await tester.runAsync(
        () => bottomImage.toByteData(),
      );
      var changed = 0;
      for (var i = 0; i < topPixels!.lengthInBytes; i += 4) {
        if (topPixels.getUint32(i) != bottomPixels!.getUint32(i)) changed++;
      }
      expect(changed, greaterThan(1000));
      topImage.dispose();
      bottomImage.dispose();
      await gesture.cancel();
      await _settle(tester, controller);
      expect(controller.currentSpread, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'editing refreshes cached page artwork only after returning and keeps the spread',
    (tester) async {
      final pages = ValueNotifier(_album(defaultCoverSize));
      addTearDown(pages.dispose);
      final controller = await _reader(
        tester,
        viewport: const Size(844, 390),
        cover: defaultCoverSize,
        captureKey: GlobalKey(),
        pagesNotifier: pages,
      );
      final book = find.byType(BookFlip, skipOffstage: false);
      final captureWrapper = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            RegExp(
              r'^book_flip_\d+_',
            ).hasMatch((widget.key! as ValueKey<String>).value),
        skipOffstage: false,
      );
      final renderer = tester.state(book);
      final originalKey = tester.widget(captureWrapper).key;
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Editor'))),
      );
      await tester.pumpAndSettle();
      pages.value = [
        for (final page in pages.value)
          page.copyWith(backgroundColor: 0xffdacfe8),
      ];
      await tester.pump();
      expect(tester.widget(captureWrapper).key, originalKey);
      expect(tester.state(book), same(renderer));

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _ready(tester, controller);
      expect(tester.widget(captureWrapper).key, isNot(originalKey));
      expect(tester.state(book), isNot(same(renderer)));
      expect(controller.currentSpread, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reader controls use the same paper curl and settle at the next spread',
    (tester) async {
      final key = GlobalKey();
      final controller = await _reader(
        tester,
        viewport: const Size(844, 390),
        cover: defaultCoverSize,
        captureKey: key,
      );
      final buttons = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.chevron_right_rounded,
      );
      expect(buttons, findsOneWidget);
      await tester.tap(buttons);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(controller.isAnimating, isTrue);
      expect(controller.flipProgress, inExclusiveRange(.1, .95));
      expect(tester.widget<BookFlip>(find.byType(BookFlip)).curl!.roll, 1);
      await _save(tester, key, 'button-turn');
      await _settle(tester, controller);
      expect(controller.currentSpread, 3);
      await tester.pumpWidget(const SizedBox());
    },
  );

  if (const bool.fromEnvironment('READER_MOTION_QA')) {
    testWidgets('capture native swipe and release sequence', (tester) async {
      final key = GlobalKey();
      final controller = await _reader(
        tester,
        viewport: const Size(844, 390),
        cover: defaultCoverSize,
        captureKey: key,
      );
      final rect = tester.getRect(find.byType(BookFlip));
      final start = Offset(rect.right - 25, rect.top + rect.height * .2);
      var frame = 0;
      Future<void> record() => _save(
        tester,
        key,
        'motion/frame-${(frame++).toString().padLeft(3, '0')}',
      );
      for (var i = 0; i < 4; i++) await record();
      final gesture = await tester.startGesture(start);
      for (var i = 1; i <= 24; i++) {
        await gesture.moveTo(
          start +
              Offset(-rect.width * .53 * i / 24, rect.height * .28 * i / 24),
          timeStamp: Duration(milliseconds: i * 30),
        );
        await tester.pump(const Duration(milliseconds: 30));
        await record();
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 750));
      for (var i = 0; i < 28; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        await record();
      }
      expect(controller.currentSpread, 3);
      expect(controller.isAnimating, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

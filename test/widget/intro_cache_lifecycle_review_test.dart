import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:snap_fit/features/onboarding/presentation/app_introduction_screen.dart';

import '../helpers/intro_artwork_review_fixtures.dart';

void _expectPainted(WidgetTester tester) {
  final images = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
  expect(images, isNotEmpty);
  expect(images.every((image) => image.image != null), isTrue);
}

Future<void> _closeAll(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  final cache = PaintingBinding.instance.imageCache;
  expect(cache.currentSizeBytes, 0);
  expect(cache.liveImageCount, 0);
  expect(cache.pendingImageCount, 0);
  expect(tester.binding.transientCallbackCount, 0);
  expect(tester.binding.hasScheduledFrame, isFalse);
  expect(tester.takeException(), isNull);
}

Future<void> _openIntro(WidgetTester tester, NavigatorState nav) async {
  unawaited(
    nav.push(
      MaterialPageRoute<void>(builder: (_) => const AppIntroductionScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withIgnored(
    createdByTestHelpers: true,
  );

  setUp(() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  });

  testWidgets(
    'warm page returns paint without loading helpers or extra decoding',
    (tester) async {
      final bundle = IntroReviewAssetBundle();
      final cache = PaintingBinding.instance.imageCache;
      await tester.pumpWidget(
        introReviewApp(bundle: bundle, home: const AppIntroductionScreen()),
      );
      await tester.pumpAndSettle();
      for (var page = 0; page < 3; page++) {
        await showIntroReviewPage(tester, page);
        await loadIntroReviewImages(tester);
      }
      final loaded = Map<String, int>.of(bundle.bufferLoads);
      final bytes = cache.currentSizeBytes;
      expect(bytes, greaterThan(0));
      expect(bytes, lessThanOrEqualTo(2 * 1024 * 1024));
      for (var cycle = 0; cycle < 12; cycle++) {
        for (final page in [1, 0, 2, 1]) {
          // Do not precache here: inspect what the actual page paints as it
          // returns to previously visited covers.
          await tester.tap(find.byKey(ValueKey('intro-page-$page')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 40));
          _expectPainted(tester);
          await tester.pumpAndSettle();
          _expectPainted(tester);
          expect(bundle.bufferLoads, loaded);
          expect(cache.currentSizeBytes, bytes);
          expect(cache.pendingImageCount, 0);
        }
      }
      await _closeAll(tester);
    },
  );

  testWidgets(
    'same-frame close and reopen keeps warm covers across route exits',
    (tester) async {
      final bundle = IntroReviewAssetBundle();
      await tester.pumpWidget(
        introReviewApp(bundle: bundle, home: const Scaffold()),
      );
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      await _openIntro(tester, nav);
      await loadIntroReviewImages(tester);
      await showIntroReviewPage(tester, 1);
      await loadIntroReviewImages(tester);
      final loaded = Map<String, int>.of(bundle.bufferLoads);
      final bytes = PaintingBinding.instance.imageCache.currentSizeBytes;
      for (var cycle = 0; cycle < 10; cycle++) {
        nav.pop();
        // Reacquire P2 in the new intro before the old route finishes exiting.
        // Covers not visited in the new intro are correctly released on exit;
        // this case specifically checks images already owned by the new route.
        unawaited(
          nav.push(
            MaterialPageRoute<void>(
              builder: (_) => const AppIntroductionScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final currentIntro = find.byType(AppIntroductionScreen).last;
        final pages = tester.widget<PageView>(
          find.descendant(of: currentIntro, matching: find.byType(PageView)),
        );
        pages.controller!.jumpToPage(1);
        await tester.pump();
        await tester.pumpAndSettle();
        _expectPainted(tester);
        for (final page in [1, 2, 0, 1]) {
          await showIntroReviewPage(tester, page);
          _expectPainted(tester);
        }
        expect(bundle.bufferLoads, loaded);
        expect(PaintingBinding.instance.imageCache.currentSizeBytes, bytes);
        expect(tester.takeException(), isNull);
      }
      nav.pop();
      await tester.pumpAndSettle();
      await _closeAll(tester);
    },
  );

  testWidgets(
    'late buffered images cannot blank or leak into a reopened intro',
    (tester) async {
      final bundle = IntroReviewAssetBundle();
      addTearDown(bundle.releaseAll);
      await tester.pumpWidget(
        introReviewApp(bundle: bundle, home: const Scaffold()),
      );
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      for (var cycle = 0; cycle < 4; cycle++) {
        for (final name in ['travel', 'family', 'daily']) {
          bundle.block('assets/onboarding/intro_$name.png');
        }
        await _openIntro(tester, nav);
        await showIntroReviewPage(tester, 1);
        nav.pop();
        await _openIntro(tester, nav);
        bundle.releaseAll();
        await loadIntroReviewImages(tester);
        for (final page in [1, 2, 0]) {
          await showIntroReviewPage(tester, page);
          await loadIntroReviewImages(tester);
          _expectPainted(tester);
        }
        nav.pop();
        await tester.pumpAndSettle();
        expect(PaintingBinding.instance.imageCache.currentSizeBytes, 0);
        expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
        expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      }
      await _closeAll(tester);
    },
  );

  testWidgets(
    'rotation and memory pressure recover images then release the cache',
    (tester) async {
      final bundle = IntroReviewAssetBundle();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        introReviewApp(bundle: bundle, home: const AppIntroductionScreen()),
      );
      await tester.pumpAndSettle();
      for (var page = 0; page < 3; page++) {
        await showIntroReviewPage(tester, page);
        await loadIntroReviewImages(tester);
      }
      final loaded = Map<String, int>.of(bundle.bufferLoads);
      for (final size in [
        const Size(844, 390),
        const Size(320, 568),
        const Size(390, 844),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        for (final page in [0, 1, 2]) {
          await showIntroReviewPage(tester, page);
          _expectPainted(tester);
        }
        expect(bundle.bufferLoads, loaded);
      }
      tester.binding.handleMemoryPressure();
      for (final page in [0, 1, 2]) {
        await showIntroReviewPage(tester, page);
        await loadIntroReviewImages(tester);
        _expectPainted(tester);
      }
      expect(tester.takeException(), isNull);
      await _closeAll(tester);
    },
  );
}

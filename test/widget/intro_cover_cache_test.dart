import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/onboarding/presentation/app_introduction_screen.dart';
import 'package:snap_fit/features/onboarding/presentation/widgets/intro_artwork_cache.dart';

import '../helpers/intro_artwork_review_fixtures.dart';

class _DelayedKeyImage extends ResizeImage {
  const _DelayedKeyImage(this.ready)
    : super(const AssetImage('assets/onboarding/intro_family.png'), width: 256);
  final Completer<void> ready;

  @override
  Future<ResizeImageKey> obtainKey(ImageConfiguration configuration) async {
    await ready.future;
    return super.obtainKey(configuration);
  }
}

class _RetryKeyImage extends ResizeImage {
  const _RetryKeyImage(this.shouldFail)
    : super(const AssetImage('assets/onboarding/intro_family.png'), width: 256);
  final bool Function() shouldFail;

  @override
  Future<ResizeImageKey> obtainKey(ImageConfiguration configuration) {
    if (shouldFail()) {
      throw StateError('Transient key lookup failure');
    }
    return super.obtainKey(configuration);
  }
}

void main() {
  testWidgets('returning P3 to P2 reuses already decoded cover artwork', (
    tester,
  ) async {
    final bundle = IntroReviewAssetBundle();
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    await tester.pumpWidget(
      introReviewApp(bundle: bundle, home: const AppIntroductionScreen()),
    );
    await tester.pumpAndSettle();
    await loadIntroReviewImages(tester);
    await showIntroReviewPage(tester, 1);
    await loadIntroReviewImages(tester);
    const family = 'assets/onboarding/intro_family.png';
    final firstLoads = bundle.bufferLoads[family];
    expect(firstLoads, 1);
    for (var cycle = 0; cycle < 5; cycle++) {
      for (final page in [2, 3, 2, 1, 0, 1]) {
        await showIntroReviewPage(tester, page);
        await loadIntroReviewImages(tester);
      }
      expect(bundle.bufferLoads[family], firstLoads);
      for (final name in ['travel', 'family', 'daily']) {
        expect(bundle.bufferLoads['assets/onboarding/intro_$name.png'], 1);
      }
      expect(cache.pendingImageCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    // P4's two existing reader-photo keys are deliberately outside this cache.
    expect(cache.currentSize, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first entry does not preload unvisited cover artwork', (
    tester,
  ) async {
    final bundle = IntroReviewAssetBundle();
    await tester.pumpWidget(
      introReviewApp(bundle: bundle, home: const AppIntroductionScreen()),
    );
    await tester.pumpAndSettle();
    await loadIntroReviewImages(tester);
    expect(bundle.bufferLoads['assets/onboarding/intro_travel.png'], 1);
    expect(bundle.bufferLoads['assets/onboarding/intro_family.png'], isNull);
    expect(bundle.bufferLoads['assets/onboarding/intro_daily.png'], isNull);
    expect(bundle.bufferLoads.length, 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('closing an overlapping intro keeps the newer route cache', (
    tester,
  ) async {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    final bundle = IntroReviewAssetBundle();
    await tester.pumpWidget(
      introReviewApp(bundle: bundle, home: const Scaffold()),
    );
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    final older = MaterialPageRoute<void>(
      builder: (_) => const AppIntroductionScreen(),
    );
    unawaited(nav.push(older));
    await tester.pumpAndSettle();
    await showIntroReviewPage(tester, 1);
    await loadIntroReviewImages(tester);
    final familyImage = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            introReviewImagePath(widget) ==
                'assets/onboarding/intro_family.png',
      ),
    );
    final context = tester.element(find.byType(AppIntroductionScreen));
    final key = await familyImage.image.obtainKey(
      createLocalImageConfiguration(context),
    );
    unawaited(
      nav.push(
        MaterialPageRoute<void>(builder: (_) => const AppIntroductionScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await showIntroReviewPage(tester, 1);
    await loadIntroReviewImages(tester);
    await showIntroReviewPage(tester, 2);
    await loadIntroReviewImages(tester);
    nav.removeRoute(older);
    await tester.pumpAndSettle();
    expect(cache.statusForKey(key).keepAlive, isTrue);
    await showIntroReviewPage(tester, 1);
    await loadIntroReviewImages(tester);
    expect(bundle.bufferLoads['assets/onboarding/intro_family.png'], 1);
    await tester.tap(find.byKey(const ValueKey('intro-skip')));
    await tester.pumpAndSettle();
    expect(cache.currentSizeBytes, 0);
    expect(cache.liveImageCount, 0);
    expect(cache.pendingImageCount, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late key lookup from a closed intro cannot evict a new owner', (
    tester,
  ) async {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));
    final configuration = createLocalImageConfiguration(context);
    final release = Completer<void>();
    final older = IntroArtworkCacheSession();
    older.remember(_DelayedKeyImage(release), configuration);
    older.dispose();
    final newer = IntroArtworkCacheSession();
    const provider = ResizeImage(
      AssetImage('assets/onboarding/intro_family.png'),
      width: 256,
    );
    newer.remember(provider, configuration);
    await tester.runAsync(() => precacheImage(provider, context));
    await tester.pumpAndSettle();
    final key = await provider.obtainKey(configuration);
    expect(cache.statusForKey(key).keepAlive, isTrue);
    release.complete();
    await tester.pumpAndSettle();
    expect(cache.statusForKey(key).keepAlive, isTrue);
    newer.dispose();
    newer.dispose();
    await tester.pumpAndSettle();
    expect(cache.statusForKey(key).tracked, isFalse);
    expect(cache.currentSizeBytes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'memory pressure drops reusable images without retaining them after exit',
    (tester) async {
      final bundle = IntroReviewAssetBundle();
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
      await tester.pumpWidget(
        introReviewApp(bundle: bundle, home: const AppIntroductionScreen()),
      );
      await tester.pumpAndSettle();
      await showIntroReviewPage(tester, 1);
      await loadIntroReviewImages(tester);
      await showIntroReviewPage(tester, 2);
      cache.clear();
      await showIntroReviewPage(tester, 1);
      await loadIntroReviewImages(tester);
      expect(
        tester
            .widgetList<RawImage>(find.byType(RawImage))
            .every((image) => image.image != null),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(cache.currentSizeBytes, 0);
      expect(cache.liveImageCount, 0);
      expect(cache.pendingImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retrying a failed key lookup still registers exit cleanup', (
    tester,
  ) async {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));
    final configuration = createLocalImageConfiguration(context);
    final session = IntroArtworkCacheSession();
    var attempts = 0;
    final provider = _RetryKeyImage(() => attempts++ == 0);
    session.remember(provider, configuration);
    await tester.pumpAndSettle();
    expect(attempts, 1);
    session.remember(provider, configuration);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final loaded = Completer<void>();
      final stream = provider.resolve(configuration);
      final listener = ImageStreamListener((image, _) {
        image.dispose();
        if (!loaded.isCompleted) loaded.complete();
      });
      stream.addListener(listener);
      await loaded.future;
      stream.removeListener(listener);
    });
    await tester.pumpAndSettle();
    final key = await provider.obtainKey(configuration);
    expect(cache.statusForKey(key).keepAlive, isTrue);
    session.dispose();
    await tester.pumpAndSettle();
    expect(
      cache.statusForKey(key).tracked,
      isFalse,
      reason:
          'After retry cleanup: ${cache.statusForKey(key)}; attempts=$attempts',
    );
    expect(cache.currentSizeBytes, 0);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_header.dart';
import 'package:snap_fit/features/onboarding/presentation/app_introduction_screen.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/onboarding/presentation/widgets/first_home_guide.dart';

import '../helpers/first_visit_fixtures.dart';

void main() {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withIgnored(
    createdByTestHelpers: true,
  );

  testWidgets(
    'reopening intro releases private cover decodes and keeps existing photo cache',
    (tester) async {
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstVisitStoreProvider.overrideWithValue(MemoryFirstVisitStore(3)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppIntroductionScreen(),
                      ),
                    ),
                    child: const Text('소개 다시 보기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final asset in ['ocean_shore', 'spring_flowers', 'alpine_lake']) {
          await precacheImage(
            ResizeImage(
              AssetImage('assets/frame_preview/$asset.jpg'),
              width: 512,
            ),
            tester.element(find.text('소개 다시 보기')),
          );
        }
      });
      await tester.pumpAndSettle();
      final warmedBytes = cache.currentSizeBytes;
      expect(warmedBytes, greaterThan(0));
      for (var attempt = 0; attempt < 8; attempt++) {
        await tester.tap(find.text('소개 다시 보기'));
        await tester.pumpAndSettle();
        for (var chapter = 0; chapter < 3; chapter++) {
          await tester.tap(find.byKey(ValueKey('intro-page-$chapter')));
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(AppIntroductionScreen));
          final providers = tester
              .widgetList<Image>(find.byType(Image))
              .map((image) => image.image)
              .toSet();
          await tester.runAsync(() async {
            for (final provider in providers) {
              await precacheImage(provider, context);
            }
          });
          await tester.pumpAndSettle();
          expect(
            cache.currentSizeBytes - warmedBytes,
            lessThanOrEqualTo(2 * 1024 * 1024),
          );
        }
        await tester.tap(find.byKey(const ValueKey('intro-page-3')));
        await tester.pump(const Duration(milliseconds: 30));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AppIntroductionScreen), findsNothing);
        expect(cache.currentSize, lessThanOrEqualTo(3));
        expect(cache.currentSizeBytes, lessThanOrEqualTo(warmedBytes));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(cache.liveImageCount, 0);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // The three shared decoded photos are an intentional bounded cache.
      // Dispose that test-owned cache before leak tracking checks resources.
      cache.clear();
      cache.clearLiveImages();
      await tester.pump();
    },
  );

  testWidgets(
    'replayed guides detach their overlays and leave no ongoing frame work',
    (tester) async {
      final active = ValueNotifier(true);
      final store = MemoryFirstVisitStore(3);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [firstVisitStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, visible, _) => TickerMode(
                  enabled: visible,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: HomeAlbumHeader(
                      collection: false,
                      onCreateAlbum: () {},
                      createButtonBuilder: (button) =>
                          FirstHomeGuide(onCreate: () {}, child: button),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeAlbumHeader)),
      );
      for (var attempt = 0; attempt < 12; attempt++) {
        container.read(firstVisitProvider.notifier).requestHomeGuide();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('first-home-guide')), findsOneWidget);
        active.value = false;
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('first-home-guide')), findsNothing);
        active.value = true;
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('first-home-guide')), findsNothing);
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
      expect(store.reads, 1);
      expect(store.writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      active.dispose();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

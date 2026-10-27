import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/onboarding/presentation/app_introduction_screen.dart';
import 'package:snap_fit/features/onboarding/presentation/widgets/intro_cover_artwork.dart';

import '../helpers/intro_artwork_review_fixtures.dart';

const _copy = [
  (
    'YOUR MOMENTS, YOUR BOOK',
    '사진이,\n한 권의 기억으로.',
    '흩어져 있던 소중한 순간을\n나만의 앨범으로 간직해요.',
  ),
  (
    'FIND YOUR DESIGN',
    '마음에 드는\n디자인부터 골라요.',
    '표지부터 내지까지 둘러보고\n우리의 이야기에 어울리는 디자인을 찾아요.',
  ),
  (
    'MAKE IT YOURS',
    '내 사진을 채우고,\n취향대로 다듬어요.',
    '사진과 글을 더하고, 재배치하며\n나만의 한 페이지를 만들어요.',
  ),
  (
    'ALWAYS CLOSE TO YOU',
    '언제든 펼쳐보고,\n이어서 만들어가요.',
    '완성한 앨범은 책처럼 감상하고\n만들던 앨범은 저장한 곳에서 이어가요.',
  ),
];

void main() {
  testWidgets('rapid forward, reversal and cancellation preserve copy and P4', (
    tester,
  ) async {
    final bundle = IntroReviewAssetBundle();
    await tester.pumpWidget(
      introReviewApp(bundle: bundle, home: const AppIntroductionScreen()),
    );
    await tester.pumpAndSettle();
    for (var cycle = 0; cycle < 5; cycle++) {
      for (final page in [0, 1, 2, 3, 2, 1, 0]) {
        await showIntroReviewPage(tester, page);
        for (final expected in [
          _copy[page].$1,
          _copy[page].$2,
          _copy[page].$3,
        ]) {
          expect(find.text(expected), findsOneWidget);
        }
        await tester.tap(
          find.byKey(ValueKey(page < 3 ? 'intro-next' : 'intro-previous')),
        );
        await tester.pump(const Duration(milliseconds: 24));
        final swipe = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('intro-pages'))),
        );
        await swipe.moveBy(const Offset(60, 0));
        await tester.pump(const Duration(milliseconds: 8));
        await swipe.cancel();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
    }
    await showIntroReviewPage(tester, 3);
    await loadIntroReviewImages(tester);
    expect(find.byType(IntroCoverArtwork), findsNothing);
    expect(find.text('우리가 함께한 여름'), findsOneWidget);
    expect(find.text('다시, 이 계절에.'), findsOneWidget);
    expect(
      tester.widgetList<Image>(find.byType(Image)).map(introReviewImagePath),
      [
        'assets/frame_preview/ocean_shore.jpg',
        'assets/frame_preview/alpine_lake.jpg',
      ],
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final dark in [false, true]) {
    testWidgets('close and reopen while image buffers are pending dark=$dark', (
      tester,
    ) async {
      final bundle = IntroReviewAssetBundle();
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
      for (final name in ['travel', 'family', 'daily']) {
        bundle.block('assets/onboarding/intro_$name.png');
      }
      await tester.pumpWidget(
        introReviewApp(
          bundle: bundle,
          dark: dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const AppIntroductionScreen(),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 6; attempt++) {
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('intro-page-${attempt % 3}')));
        await tester.pump(const Duration(milliseconds: 12));
        await tester.tap(find.byKey(const ValueKey('intro-skip')));
        await tester.pumpAndSettle();
        expect(find.byType(AppIntroductionScreen), findsNothing);
        expect(cache.pendingImageCount, 0);
        expect(tester.takeException(), isNull);
      }
      bundle.releaseAll();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      for (var page = 0; page < 3; page++) {
        await showIntroReviewPage(tester, page);
        await loadIntroReviewImages(tester);
        expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .every((image) => image.image != null),
          isTrue,
        );
        expect(cache.pendingImageCount, 0);
      }
      await tester.tap(find.byKey(const ValueKey('intro-skip')));
      await tester.pumpAndSettle();
      expect(cache.currentSizeBytes, 0);
      expect(cache.liveImageCount, 0);
      expect(cache.pendingImageCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}

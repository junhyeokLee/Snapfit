import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_empty_state.dart';
import 'package:snap_fit/features/onboarding/presentation/widgets/intro_cover_artwork.dart';
import 'package:snap_fit/features/onboarding/presentation/widgets/story_album_artwork.dart';

Widget _art(int chapter) => SizedBox(
  width: 340,
  height: 320,
  child: StoryAlbumArtwork(chapter: chapter),
);

String _asset(Image image) =>
    ((image.image as ResizeImage).imageProvider as AssetImage).assetName;

Future<void> _loadImages(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
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
}

Image _travel(WidgetTester tester, Finder within) => tester.widget<Image>(
  find.descendant(
    of: within,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          _asset(widget) == 'assets/onboarding/intro_travel.png',
    ),
  ),
);

void main() {
  testWidgets('only P1 to P3 mount the new cover art; P4 keeps its reader', (
    tester,
  ) async {
    final expected = [
      {'intro_travel.png'},
      {'intro_travel.png', 'intro_family.png', 'intro_daily.png'},
      {'intro_daily.png'},
    ];
    for (var chapter = 0; chapter < 4; chapter++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: _art(chapter))),
        ),
      );
      await _loadImages(tester);
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      final coverNames = images
          .map(_asset)
          .where((name) => name.startsWith('assets/onboarding/'))
          .map((name) => name.split('/').last)
          .toSet();
      if (chapter < 3) {
        expect(find.byType(IntroCoverArtwork), findsOneWidget);
        expect(coverNames, expected[chapter]);
        expect(images.length, lessThanOrEqualTo(3));
        for (final image in images) {
          expect((image.image as ResizeImage).width, lessThanOrEqualTo(384));
        }
      } else {
        expect(find.byType(IntroCoverArtwork), findsNothing);
        expect(coverNames, isEmpty);
        expect(images.map(_asset).toSet(), {
          'assets/frame_preview/ocean_shore.jpg',
          'assets/frame_preview/alpine_lake.jpg',
        });
        expect(find.text('우리가 함께한 여름'), findsOneWidget);
        expect(find.text('다시, 이 계절에.'), findsOneWidget);
        expect(
          images.every((image) => (image.image as ResizeImage).width == 512),
          isTrue,
        );
      }
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
  });

  testWidgets('home keeps its original covers and original photo decode keys', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeEmptyState(onCreate: () {})),
      ),
    );
    await _loadImages(tester);
    expect(find.byType(StoryAlbumCover), findsNWidgets(3));
    expect(find.byType(IntroCoverArtwork), findsNothing);
    expect(find.text('여름이\n머문 자리'), findsOneWidget);
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images.map(_asset).toSet(), {
      'assets/frame_preview/ocean_shore.jpg',
      'assets/frame_preview/spring_flowers.jpg',
      'assets/frame_preview/alpine_lake.jpg',
    });
    expect(
      images.every((image) => (image.image as ResizeImage).width == 512),
      isTrue,
    );
  });

  testWidgets(
    'adjacent pages share the cover while a departing page is removed',
    (tester) async {
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
      final first = ValueNotifier(true);
      await tester.binding.setSurfaceSize(const Size(700, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: first,
              builder: (_, showFirst, _) => Row(
                children: [
                  if (showFirst)
                    KeyedSubtree(key: const ValueKey('first'), child: _art(0)),
                  KeyedSubtree(key: const ValueKey('second'), child: _art(1)),
                ],
              ),
            ),
          ),
        ),
      );
      await _loadImages(tester);
      final firstProvider = _travel(
        tester,
        find.byKey(const ValueKey('first')),
      ).image;
      final secondProvider = _travel(
        tester,
        find.byKey(const ValueKey('second')),
      ).image;
      expect(firstProvider, secondProvider);
      final context = tester.element(find.byKey(const ValueKey('second')));
      final key = await secondProvider.obtainKey(
        createLocalImageConfiguration(context),
      );
      expect(cache.statusForKey(key).live, isTrue);
      first.value = false;
      await tester.pumpAndSettle();
      expect(cache.statusForKey(key).live, isTrue);
      final remainingImage = find.descendant(
        of: find.byWidget(
          _travel(tester, find.byKey(const ValueKey('second'))),
        ),
        matching: find.byType(RawImage),
      );
      expect(tester.widget<RawImage>(remainingImage).image, isNotNull);
      expect(cache.pendingImageCount, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      first.dispose();
      expect(cache.statusForKey(key).tracked, isFalse);
      expect(cache.currentSizeBytes, 0);
      expect(cache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/onboarding/presentation/app_introduction_screen.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/onboarding/presentation/widgets/story_album_artwork.dart';

import '../helpers/first_visit_fixtures.dart';

Widget _app({
  required MemoryFirstVisitStore store,
  VoidCallback? onFinished,
  bool firstVisit = true,
  bool dark = false,
  double scale = 1,
  bool reducedMotion = false,
}) => ProviderScope(
  overrides: [firstVisitStoreProvider.overrideWithValue(store)],
  child: MaterialApp(
    theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reducedMotion,
      ),
      child: child!,
    ),
    home: AppIntroductionScreen(firstVisit: firstVisit, onFinished: onFinished),
  ),
);

Future<void> _fonts() async {
  for (final (family, asset) in [
    ('NotoSans', 'assets/fonts/NotoSansKR-Regular.ttf'),
    ('Poppins', 'assets/fonts/Poppins-Regular.otf'),
    ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}

Future<void> _loadVisibleArtwork(WidgetTester tester) async {
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
}

void main() {
  setUpAll(_fonts);

  testWidgets(
    'four story pages support next, previous, swipe and one completion',
    (tester) async {
      final store = MemoryFirstVisitStore();
      var finished = 0;
      await tester.pumpWidget(_app(store: store, onFinished: () => finished++));
      await tester.pumpAndSettle();
      expect(find.text('사진이,\n한 권의 기억으로.'), findsOneWidget);
      expect(find.byType(StoryAlbumArtwork), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('intro-next')));
      await tester.pumpAndSettle();
      expect(find.text('마음에 드는\n디자인부터 골라요.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('intro-previous')));
      await tester.pumpAndSettle();
      expect(find.text('사진이,\n한 권의 기억으로.'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('intro-pages')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('마음에 드는\n디자인부터 골라요.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('intro-page-3')));
      await tester.pumpAndSettle();
      expect(find.text('시작하기'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('intro-next')));
      await tester.tap(find.byKey(const ValueKey('intro-next')));
      await tester.pumpAndSettle();
      expect(finished, 1);
      expect(store.flags, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppIntroductionScreen)),
      );
      expect(
        container.read(firstVisitProvider).requireValue.shouldShowHomeGuide,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('skip opts out without forcing the next tutorial', (
    tester,
  ) async {
    final store = MemoryFirstVisitStore();
    var finished = 0;
    await tester.pumpWidget(_app(store: store, onFinished: () => finished++));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('intro-skip')));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(store.flags, 3);
  });

  testWidgets('replaying does not clear or rewrite first-visit decisions', (
    tester,
  ) async {
    final store = MemoryFirstVisitStore(3);
    var finished = 0;
    await tester.pumpWidget(
      _app(store: store, firstVisit: false, onFinished: () => finished++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('intro-page-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('intro-next')));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(store.flags, 3);
    expect(store.writes, isEmpty);
  });

  testWidgets(
    'system back skips first visit safely instead of reopening splash',
    (tester) async {
      final store = MemoryFirstVisitStore();
      var finished = 0;
      await tester.pumpWidget(_app(store: store, onFinished: () => finished++));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(finished, 1);
      expect(store.flags, 3);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('story stays usable with large text at $size dark=$dark', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(
            store: MemoryFirstVisitStore(),
            dark: dark,
            scale: 1.8,
            reducedMotion: true,
            onFinished: () {},
          ),
        );
        await tester.pumpAndSettle();
        for (var page = 0; page < 4; page++) {
          await tester.tap(find.byKey(ValueKey('intro-page-$page')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('intro-next')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('intro-skip')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          expect(tester.binding.hasScheduledFrame, isFalse);
        }
        await tester.binding.setSurfaceSize(Size(size.height, size.width));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'leaving during a page transition disposes its controller safely',
    (tester) async {
      await tester.pumpWidget(
        _app(store: MemoryFirstVisitStore(), onFinished: () {}),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('intro-next')));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('intro covers use bounded images without another runtime font', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(store: MemoryFirstVisitStore(), onFinished: () {}),
    );
    await tester.pumpAndSettle();
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(images.length, lessThanOrEqualTo(3));
    expect(images.map((image) => (image.image as ResizeImage).width).toSet(), {
      192,
      224,
      384,
    });
    for (final image in images) {
      final provider = image.image as ResizeImage;
      expect(provider.imageProvider, isA<AssetImage>());
    }
    expect(
      images.any(
        (image) =>
            ((image.image as ResizeImage).imageProvider as AssetImage)
                .assetName ==
            'assets/onboarding/intro_travel.png',
      ),
      isTrue,
    );
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .any((text) => text.style?.fontFamily == 'Cormorant'),
      isFalse,
    );
    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('intro-pages')),
    );
    expect(pageView.allowImplicitScrolling, isFalse);
  });

  testWidgets('approved story composition', (tester) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(store: MemoryFirstVisitStore(), onFinished: () {}),
      );
      await tester.pumpAndSettle();
      for (final (page, golden) in [
        (0, 'onboarding_story'),
        (1, 'onboarding_designs'),
        (2, 'onboarding_editor'),
      ]) {
        await tester.tap(find.byKey(ValueKey('intro-page-$page')));
        await tester.pumpAndSettle();
        await _loadVisibleArtwork(tester);
        await expectLater(
          find.byKey(const ValueKey('app-introduction')),
          matchesGoldenFile('goldens/${golden}_390x844.png'),
        );
      }
    } finally {
      debugDisableShadows = previousShadows;
    }
  });

  testWidgets('iOS intro pages never attach to the parent scroll controller', (
    tester,
  ) async {
    final parentScroll = ScrollController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstVisitStoreProvider.overrideWithValue(MemoryFirstVisitStore()),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: PrimaryScrollController(
            controller: parentScroll,
            child: AppIntroductionScreen(onFinished: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(parentScroll.hasClients, isFalse);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('intro-pages'))),
    );
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    expect(parentScroll.hasClients, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(parentScroll.hasClients, isFalse);
    parentScroll.dispose();
    expect(tester.takeException(), isNull);
  });
}

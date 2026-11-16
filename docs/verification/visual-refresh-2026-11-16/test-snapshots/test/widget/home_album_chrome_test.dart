import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_header.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_empty_state.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_error_state.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_slider.dart';
import 'package:snap_fit/shared/widgets/catalog_cover_skeleton.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'package:snap_fit/shared/widgets/snapfit_shimmer.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moments_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_entry_card.dart';
import 'package:snap_fit/features/moments/presentation/moments_navigation.dart';

import '../helpers/fake_album.dart';

class _GuestMoments extends Fake implements MomentsRepository {
  @override
  String? get currentUserId => null;
  @override
  Stream<String?> get authChanges => const Stream.empty();
}

Widget _journalLeading({double sectionHeight = 80}) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final section in ['today', 'archive', 'next-step'])
      SizedBox(
        key: ValueKey('leading-$section'),
        height: sectionHeight,
        width: double.infinity,
        child: Text(section),
      ),
  ],
);

Widget _chromeHost(Widget child) => ProviderScope(
  child: MaterialApp(
    builder: (context, body) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: body!,
    ),
    home: Scaffold(body: child),
  ),
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectLeadingOrder(WidgetTester tester, Finder body) {
  final today = tester.getRect(find.byKey(const ValueKey('leading-today')));
  final archive = tester.getRect(find.byKey(const ValueKey('leading-archive')));
  final next = tester.getRect(find.byKey(const ValueKey('leading-next-step')));
  expect(today.top, lessThan(48));
  expect(archive.top, greaterThanOrEqualTo(today.bottom));
  expect(next.top, greaterThanOrEqualTo(archive.bottom));
  expect(tester.getRect(body).top, greaterThanOrEqualTo(next.bottom));
}

void _expectOwnedVerticalScroll(
  WidgetTester tester,
  Finder owner,
  ScrollController controller,
) {
  final vertical = tester
      .widgetList<SingleChildScrollView>(
        find.descendant(
          of: owner,
          matching: find.byType(SingleChildScrollView),
        ),
      )
      .where((scroll) => scroll.scrollDirection == Axis.vertical)
      .toList();
  expect(vertical, hasLength(1));
  expect(vertical.single.controller, same(controller));
  expect(vertical.single.primary, isFalse);
  expect(controller.positions, hasLength(1));
}

void main() {
  for (final scene in [
    (width: 390.0, scale: 1.0),
    (width: 320.0, scale: 2.0),
  ]) {
    testWidgets(
      'album heading opens the full library at ${scene.width} with text scale ${scene.scale}',
      (tester) async {
        _viewport(tester, Size(scene.width, 568));
        var opened = 0;
        await tester.pumpWidget(
          _chromeHost(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scene.scale)),
                child: HomeAlbumSlider(
                  albums: [fakeAlbum(id: 801), fakeAlbum(id: 802)],
                  showHeader: false,
                  leadingContent: const SizedBox(height: 8),
                  onOpenAlbumTab: () => opened++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final heading = find.byKey(const ValueKey('home-album-section'));
        final action = find.byKey(const ValueKey('home-album-section-open'));
        expect(
          find.descendant(of: heading, matching: find.text('2권')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: action, matching: find.text('전체보기')),
          findsOneWidget,
        );
        final bounds = tester.getRect(heading);
        final button = tester.getRect(action);
        expect(button.width, greaterThanOrEqualTo(48));
        expect(button.height, greaterThanOrEqualTo(48));
        expect(bounds.inflate(.5).contains(button.topLeft), isTrue);
        expect(bounds.inflate(.5).contains(button.bottomRight), isTrue);
        final title = find.byKey(const ValueKey('home-album-section-title'));
        expect(tester.getRect(title).left, closeTo(24, .5));
        expect(
          tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
          isFalse,
        );
        if (scene.scale > 1) {
          // 제목과 액션을 한 줄에 압축하지 않고 읽을 공간을 확보해야 한다.
          expect(
            button.top,
            greaterThanOrEqualTo(tester.getRect(title).bottom),
          );
        }
        await tester.tap(action);
        expect(opened, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('hidden supporting sections retain the footer scroll position', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    final controller = ScrollController();
    var active = true;
    late StateSetter update;
    await tester.pumpWidget(
      _chromeHost(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return TickerMode(
              enabled: active,
              child: HomeAlbumSlider(
                albums: [fakeAlbum(id: 1, ratio: '1')],
                showHeader: false,
                scrollController: controller,
                leadingContent: const SizedBox(height: 600),
                footer: Builder(
                  builder: (context) =>
                      SizedBox(height: TickerMode.of(context) ? 500 : 0),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final offset = controller.offset;
    final extent = controller.position.maxScrollExtent;
    update(() => active = false);
    await tester.pumpAndSettle();
    expect(controller.position.maxScrollExtent, closeTo(extent, .01));
    expect(controller.offset, closeTo(offset, .01));
    update(() => active = true);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(offset, .01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'labelled daily entry opens the private journal without a header icon',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            momentsRepositoryProvider.overrideWithValue(_GuestMoments()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    const HomeAlbumHeader(collection: false),
                    MomentsEntryCard(
                      compact: true,
                      onTap: () => openMoments(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('home-moments-entry')), findsNothing);
      expect(find.text('오늘의 한 장'), findsOneWidget);
      expect(find.textContaining('사진 한 장과 한 줄'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('moments-entry')));
      await tester.pumpAndSettle();
      expect(find.byType(MomentsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.8, 2.0]) {
      testWidgets(
        'complete album title and three actions fit $width at $scale',
        (tester) async {
          var collection = false;
          var created = 0;
          var resumed = 0;
          int? destination;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: ExperienceNavigationScope(
                    onNavigate: (index) => destination = index,
                    onBack: () {},
                    child: Center(
                      child: SizedBox(
                        width: width,
                        child: StatefulBuilder(
                          builder: (_, setState) => HomeAlbumHeader(
                            collection: collection,
                            onToggleView: () =>
                                setState(() => collection = !collection),
                            onCreateAlbum: () => created++,
                            onResumeDraft: () => resumed++,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final plus = find.byKey(const ValueKey('home-create-album'));
          expect(
            find.byKey(const ValueKey('home-moments-entry')),
            findsNothing,
          );
          final title = find.byKey(const ValueKey('home-album-title'));
          final paragraph = tester.renderObject<RenderParagraph>(title);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            tester.widget<Text>(title).overflow,
            isNot(TextOverflow.ellipsis),
          );
          for (final box in paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
          )) {
            expect(box.right, lessThanOrEqualTo(paragraph.size.width + .5));
          }
          expect(
            tester.widget<IconButton>(plus).style?.backgroundColor,
            isNull,
          );
          await tester.tap(plus);
          expect(created, 1);
          final notifications = find.byKey(
            const ValueKey('home-album-notifications'),
          );
          final position = tester.getTopLeft(notifications);
          await tester.tap(find.byTooltip('앨범 목록'));
          await tester.pump();
          expect(find.byTooltip('표지로 보기'), findsOneWidget);
          expect(tester.getTopLeft(notifications), position);
          await tester.tap(notifications);
          expect(destination, 3);
          await tester.tap(find.text('이어서 만들기'));
          expect(resumed, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('normal header reserves all remaining width for the title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 390,
              child: HomeAlbumHeader(
                collection: false,
                onToggleView: () {},
                onCreateAlbum: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final header = find.byType(HomeAlbumHeader);
    final title = find.byKey(const ValueKey('home-album-title'));
    expect(find.byKey(const ValueKey('home-moments-entry')), findsNothing);
    expect(tester.getSize(header).height, lessThan(100));
    expect(tester.getSize(title).width, greaterThan(190));
    expect(
      tester.getTopLeft(title).dx,
      closeTo(tester.getTopLeft(header).dx + 24, .01),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty state keeps album creation separate from the resume card',
    (tester) async {
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomeEmptyState(onCreate: () => created++)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('아직 만든 앨범이 없어요'), findsOneWidget);
      expect(find.text('이어서 만들기'), findsNothing);
      await tester.ensureVisible(find.text('앨범 만들기'));
      await tester.tap(find.text('앨범 만들기'));
      expect(created, 1);
    },
  );

  for (final state in ['empty', 'error', 'loading']) {
    testWidgets('journal leads the $state body in its owned scroll', (
      tester,
    ) async {
      _viewport(tester, const Size(390, 844));
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var actions = 0;
      final leading = _journalLeading();
      const footer = SizedBox(
        key: ValueKey('home-fallback-footer'),
        height: 520,
        child: Text('footer'),
      );
      final Widget child;
      final Finder owner, body;
      switch (state) {
        case 'empty':
          child = HomeEmptyState(
            onCreate: () => actions++,
            scrollController: controller,
            leadingContent: leading,
            footer: footer,
          );
          owner = find.byType(HomeEmptyState);
          body = find.text('이렇게 담아보세요');
          break;
        case 'error':
          child = HomeErrorState(
            error: StateError('offline fixture'),
            onRetry: () => actions++,
            scrollController: controller,
            leadingContent: leading,
            footer: footer,
          );
          owner = find.byType(HomeErrorState);
          body = find.byIcon(Icons.cloud_off_outlined);
          break;
        default:
          child = SnapFitShimmerHomeSlider(
            scrollController: controller,
            leadingContent: leading,
            footer: footer,
          );
          owner = find.byType(SnapFitShimmerHomeSlider);
          body = find.descendant(
            of: owner,
            matching: find.byType(SnapFitShimmer),
          );
      }
      await tester.pumpWidget(_chromeHost(child));
      await tester.pumpAndSettle();
      _expectLeadingOrder(tester, body);
      _expectOwnedVerticalScroll(tester, owner, controller);
      expect(controller.position.maxScrollExtent, greaterThan(0));
      expect(
        tester.getRect(find.byKey(const ValueKey('home-fallback-footer'))).top,
        greaterThanOrEqualTo(tester.getRect(body).bottom),
      );
      if (state == 'loading') {
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('leading-today')),
            matching: find.byType(SnapFitShimmer),
          ),
          findsNothing,
        );
      } else {
        final action = state == 'empty'
            ? find.byKey(const ValueKey('empty-home-create'))
            : find.text('다시 불러오기');
        await tester.ensureVisible(action);
        await tester.tap(action);
        expect(actions, 1);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final state in ['empty', 'error']) {
    testWidgets('leading $state content does not add a blank viewport', (
      tester,
    ) async {
      _viewport(tester, const Size(390, 1000));
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final leading = _journalLeading(sectionHeight: 60);
      final child = state == 'empty'
          ? HomeEmptyState(
              onCreate: () {},
              scrollController: controller,
              leadingContent: leading,
            )
          : HomeErrorState(
              error: StateError('offline fixture'),
              onRetry: () {},
              scrollController: controller,
              leadingContent: leading,
            );
      await tester.pumpWidget(_chromeHost(child));
      await tester.pumpAndSettle();
      expect(
        controller.position.maxScrollExtent,
        closeTo(0, .5),
        reason:
            'The small journal and album body fit without a second full-height spacer',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('journal precedes the large album on $size', (tester) async {
      _viewport(tester, size);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final album = fakeAlbum(id: 9901, ratio: '1').copyWith(title: '나의 한 권');
      await tester.pumpWidget(
        _chromeHost(
          HomeAlbumSlider(
            albums: [album],
            showHeader: false,
            scrollController: controller,
            leadingContent: _journalLeading(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final section = find.byKey(const ValueKey('home-album-section-title'));
      final cover = find.byKey(const ValueKey('home_album_9901'));
      _expectLeadingOrder(tester, section);
      expect(
        tester.getRect(cover).top,
        greaterThan(tester.getRect(section).bottom),
      );
      _expectOwnedVerticalScroll(
        tester,
        find.byType(HomeAlbumSlider),
        controller,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-focused-album-open')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-focused-album-open')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final side in [0.0, 40.0, 200.0]) {
    testWidgets('cover skeleton is bounded and needs no ticker at $side', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: side,
              child: const CatalogCoverSkeleton(),
            ),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_header.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/onboarding/presentation/widgets/first_home_guide.dart';

import '../helpers/first_visit_fixtures.dart';

final _guide = find.byKey(const ValueKey('first-home-guide'));

class _Harness extends StatefulWidget {
  const _Harness({this.scale = 1, this.dark = false});
  final double scale;
  final bool dark;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool active = true;
  int recorded = 0, created = 0, generation = 0;
  bool? visibleOnAction;
  void setActive(bool value) => setState(() => active = value);
  void remountAnchor() => setState(() => generation++);
  void _create() {
    visibleOnAction = ProviderScope.containerOf(
      context,
    ).read(firstHomeGuideVisibleProvider);
    created++;
  }

  void _record() {
    visibleOnAction = ProviderScope.containerOf(
      context,
    ).read(firstHomeGuideVisibleProvider);
    recorded++;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: widget.dark ? ThemeData.dark() : ThemeData.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(widget.scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SafeArea(
        child: TickerMode(
          enabled: active,
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeAlbumHeader(collection: false, onCreateAlbum: _create),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('11월의 기록'),
                      FirstHomeGuide(
                        key: ValueKey(generation),
                        onRecord: _record,
                        onCreate: _create,
                      ),
                      const SizedBox(
                        key: ValueKey('calendar-content'),
                        height: 1000,
                        child: Text('달력과 기록'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('replay reveals its inline target after retained scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstVisitStoreProvider.overrideWithValue(MemoryFirstVisitStore(3)),
        ],
        child: const _Harness(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_Harness)),
    );
    container.read(firstVisitProvider.notifier).requestHomeGuide();
    await tester.pumpAndSettle();
    expect(_guide, findsOneWidget);
    expect(_guide.hitTestable(), findsOneWidget);
    expect(find.byTooltip('안내 닫기').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['record', 'create']) {
    testWidgets(
      'the guide $action action runs once and closes before navigation',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firstVisitStoreProvider.overrideWithValue(
                MemoryFirstVisitStore(1),
              ),
            ],
            child: const _Harness(),
          ),
        );
        await tester.pumpAndSettle();
        final harness = tester.state<_HarnessState>(find.byType(_Harness));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(_Harness)),
        );
        expect(harness.recorded, 0);
        expect(harness.created, 0);
        final button = find.byKey(ValueKey('first-home-guide-$action'));
        expect(button, findsOneWidget);
        await tester.tap(button);
        // A second tap before rebuilding must not navigate twice.
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(harness.recorded, action == 'record' ? 1 : 0);
        expect(harness.created, action == 'create' ? 1 : 0);
        expect(harness.visibleOnAction, isFalse);
        expect(_guide, findsNothing);
        expect(container.read(firstHomeGuideVisibleProvider), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'disposing the visible guide clears its visibility without an action',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          firstVisitStoreProvider.overrideWithValue(MemoryFirstVisitStore(1)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _Harness(),
        ),
      );
      await tester.pumpAndSettle();
      final harness = tester.state<_HarnessState>(find.byType(_Harness));
      expect(container.read(firstHomeGuideVisibleProvider), isTrue);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();
      expect(container.read(firstHomeGuideVisibleProvider), isFalse);
      expect(harness.recorded, 0);
      expect(harness.created, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('guide appears once; closing and remounting cannot repeat it', (
    tester,
  ) async {
    final store = MemoryFirstVisitStore(1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firstVisitStoreProvider.overrideWithValue(store)],
        child: const _Harness(),
      ),
    );
    await tester.pumpAndSettle();
    expect(_guide, findsOneWidget);
    expect(find.text('오늘의 한 장부터 시작해요'), findsOneWidget);
    expect(find.text('오늘 기록하기'), findsOneWidget);
    expect(find.text('앨범 바로 만들기'), findsOneWidget);
    expect(
      find.ancestor(of: _guide, matching: find.byType(HomeAlbumHeader)),
      findsNothing,
    );
    expect(
      tester.getRect(_guide).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('calendar-content'))).top,
      ),
    );
    expect(store.flags, 3);
    await tester.tap(find.byTooltip('안내 닫기'));
    await tester.pumpAndSettle();
    expect(_guide, findsNothing);
    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    harness.remountAnchor();
    await tester.pumpAndSettle();
    expect(_guide, findsNothing);
    expect(store.reads, 1);
    expect(store.writes, [3]);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'hidden destination waits, then closes its guide when hidden again',
    (tester) async {
      final store = MemoryFirstVisitStore(1);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [firstVisitStoreProvider.overrideWithValue(store)],
          child: const _Harness(),
        ),
      );
      final harness = tester.state<_HarnessState>(find.byType(_Harness));
      harness.setActive(false);
      await tester.pumpAndSettle();
      expect(_guide, findsNothing);
      expect(store.flags, 1);
      harness.setActive(true);
      await tester.pumpAndSettle();
      expect(_guide, findsOneWidget);
      harness.setActive(false);
      await tester.pumpAndSettle();
      expect(_guide, findsNothing);
      harness.setActive(true);
      await tester.pumpAndSettle();
      expect(_guide, findsNothing);
    },
  );

  testWidgets('replay waits for an active target and is consumed once', (
    tester,
  ) async {
    final store = MemoryFirstVisitStore(3);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firstVisitStoreProvider.overrideWithValue(store)],
        child: const _Harness(),
      ),
    );
    await tester.pumpAndSettle();
    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_Harness)),
    );
    harness.setActive(false);
    await tester.pump();
    container.read(firstVisitProvider.notifier).requestHomeGuide();
    await tester.pumpAndSettle();
    expect(_guide, findsNothing);
    harness.setActive(true);
    await tester.pumpAndSettle();
    expect(_guide, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('first-home-guide-create')));
    await tester.pumpAndSettle();
    expect(harness.created, 1);
    expect(_guide, findsNothing);
    harness.remountAnchor();
    await tester.pumpAndSettle();
    expect(_guide, findsNothing);
  });

  testWidgets('pushing and popping a route does not leave a floating guide', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstVisitStoreProvider.overrideWithValue(MemoryFirstVisitStore(1)),
        ],
        child: const _Harness(),
      ),
    );
    await tester.pumpAndSettle();
    final nav = Navigator.of(tester.element(find.byType(HomeAlbumHeader)));
    nav.push<void>(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('other route')),
      ),
    );
    await tester.pumpAndSettle();
    expect(_guide, findsNothing);
    nav.pop();
    await tester.pumpAndSettle();
    expect(_guide, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('guide fits dark large text and rotation at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstVisitStoreProvider.overrideWithValue(MemoryFirstVisitStore(1)),
          ],
          child: const _Harness(scale: 1.8, dark: true),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(_guide);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      await tester.binding.setSurfaceSize(Size(size.height, size.width));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('안내 닫기'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

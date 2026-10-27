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
  int created = 0, generation = 0;
  void setActive(bool value) => setState(() => active = value);
  void remountAnchor() => setState(() => generation++);
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
          child: Align(
            alignment: Alignment.topCenter,
            child: HomeAlbumHeader(
              collection: false,
              onCreateAlbum: () => created++,
              createButtonBuilder: (button) => FirstHomeGuide(
                key: ValueKey(generation),
                onCreate: () => created++,
                child: button,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
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

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
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

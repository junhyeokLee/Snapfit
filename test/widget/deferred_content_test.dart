import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/widgets/deferred_content.dart';
import 'package:snap_fit/shared/widgets/snapfit_shimmer.dart';

void main() {
  testWidgets(
    'screen header and skeleton paint before expensive content mounts',
    (tester) async {
      var mounts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('스토어')),
            body: DeferredContent(
              placeholder: const Text('디자인 불러오는 중'),
              builder: (_) {
                mounts++;
                return const Text('디자인 목록');
              },
            ),
          ),
        ),
      );
      expect(find.text('스토어'), findsOneWidget);
      expect(find.text('디자인 불러오는 중'), findsOneWidget);
      expect(mounts, 0);
      await tester.pump();
      expect(find.text('디자인 목록'), findsOneWidget);
      expect(mounts, 1);
    },
  );

  testWidgets('an inactive department does not mount before being opened', (
    tester,
  ) async {
    var mounts = 0;
    Widget page(bool active) => MaterialApp(
      home: DeferredContent(
        active: active,
        placeholder: const Text('준비 중'),
        builder: (_) {
          mounts++;
          return const Text('내용');
        },
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pump();
    expect(mounts, 0);
    await tester.pumpWidget(page(true));
    expect(mounts, 0);
    await tester.pump();
    expect(mounts, 1);
  });

  testWidgets('visited tab preserves scroll and stops tickers while hidden', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    Widget page(bool active) => MaterialApp(
      home: Stack(
        children: [
          RetainedDestination(
            active: active,
            builder: (_) => ListView.builder(
              key: const ValueKey('retained-list'),
              controller: scroll,
              itemExtent: 60,
              itemCount: 100,
              itemBuilder: (_, i) => Text('디자인 $i'),
            ),
          ),
        ],
      ),
    );
    await tester.pumpWidget(page(true));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(Scrollable));
    final offset = scroll.offset;
    await tester.pumpWidget(page(false));
    expect(find.byType(ListView), findsNothing);
    final hiddenContext = tester.element(
      find.byType(ListView, skipOffstage: false),
    );
    expect(TickerMode.of(hiddenContext), isFalse);
    expect(
      tester
          .widget<HeroMode>(find.byType(HeroMode, skipOffstage: false))
          .enabled,
      isFalse,
    );
    await tester.pumpWidget(page(true));
    expect(tester.state(find.byType(Scrollable)), same(state));
    expect(scroll.offset, offset);
  });

  testWidgets(
    'reduced motion skeleton does not keep scheduling animation frames',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SnapFitShimmer(child: SnapFitShimmerBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}

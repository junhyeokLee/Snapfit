import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/widgets/catalog_artwork_visibility.dart';

class _Artwork extends StatefulWidget {
  const _Artwork(this.onMount, this.onDispose);
  final VoidCallback onMount, onDispose;

  @override
  State<_Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends State<_Artwork> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('Artwork');
}

void main() {
  testWidgets('hidden departments and background release artwork subtrees', (
    tester,
  ) async {
    var mounts = 0;
    var disposals = 0;
    Widget page(bool visible) => MaterialApp(
      home: TickerMode(
        enabled: visible,
        child: CatalogArtworkVisibility(
          child: _Artwork(() => mounts++, () => disposals++),
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    expect(mounts, 0);
    await tester.pumpWidget(page(true));
    expect(mounts, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(disposals, 1);
    expect(find.text('Artwork'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(mounts, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(mounts, 2);
    await tester.pumpWidget(page(false));
    expect(disposals, 2);
    await tester.pumpWidget(page(true));
    expect(mounts, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(disposals, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new art waits for both axes; loaded art stays during scroll', (
    tester,
  ) async {
    final vertical = ScrollController();
    final horizontal = ScrollController();
    addTearDown(vertical.dispose);
    addTearDown(horizontal.dispose);
    var mounts = 0;
    var disposals = 0;
    Widget page(bool visible) => MaterialApp(
      home: ListView(
        controller: vertical,
        children: [
          SizedBox(
            height: 200,
            child: ListView(
              controller: horizontal,
              scrollDirection: Axis.horizontal,
              children: [
                SizedBox(
                  width: 200,
                  child: TickerMode(
                    enabled: visible,
                    child: CatalogArtworkVisibility(
                      child: _Artwork(() => mounts++, () => disposals++),
                    ),
                  ),
                ),
                const SizedBox(width: 1000),
              ],
            ),
          ),
          const SizedBox(height: 1800),
        ],
      ),
    );
    await tester.pumpWidget(page(false));
    vertical.position.isScrollingNotifier.value = true;
    horizontal.position.isScrollingNotifier.value = true;
    await tester.pumpWidget(page(true));
    expect(mounts, 0);
    vertical.position.isScrollingNotifier.value = false;
    await tester.pump();
    expect(mounts, 0);
    horizontal.position.isScrollingNotifier.value = false;
    await tester.pump();
    expect(mounts, 1);
    vertical.position.isScrollingNotifier.value = true;
    horizontal.position.isScrollingNotifier.value = true;
    await tester.pump();
    expect(mounts, 1);
    expect(disposals, 0);
    expect(find.text('Artwork'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    // Removed listeners must not attempt to rebuild the disposed widget.
    expect(tester.takeException(), isNull);
    expect(disposals, 1);
  });
}

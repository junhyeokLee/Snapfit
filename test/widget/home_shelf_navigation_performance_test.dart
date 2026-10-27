import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_shelf.dart';

Future<void> _frames(WidgetTester tester, [int count = 20]) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _show(
  WidgetTester tester,
  ValueNotifier<int> selected, {
  bool grid = false,
  bool reduced = false,
  bool accessible = false,
}) async {
  final albums = List.generate(
    201,
    (index) => Album(
      id: index,
      title: 'Album $index',
      ratio: '1',
      coverLayersJson:
          '{"pages":[{"index":0,"backgroundColor":"#123456","layers":[]}]}',
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)).copyWith(
            disableAnimations: reduced,
            accessibleNavigation: accessible,
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                height: grid ? 380 : 110,
                child: ValueListenableBuilder<int>(
                  valueListenable: selected,
                  builder: (_, index, _) => HomeAlbumShelf(
                    albums: albums,
                    selectedIndex: index,
                    onSelected: (index) => selected.value = index,
                    grid: grid,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _frames(tester);
}

ScrollController _scroll(WidgetTester tester, bool grid) => grid
    ? tester
          .widget<GridView>(find.byKey(const ValueKey('home-bookshelf-grid')))
          .controller!
    : tester
          .widget<ListView>(find.byKey(const ValueKey('home-bookshelf-strip')))
          .controller!;

void main() {
  for (final grid in [false, true]) {
    testWidgets('far shelf selection skips intermediate covers grid=$grid', (
      tester,
    ) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _show(tester, selected, grid: grid);
      selected.value = 160;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final first = _scroll(tester, grid).offset;
      final intermediate = <int>{};
      for (var frame = 0; frame < 22; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        for (final preview in tester.widgetList<HomeAlbumCoverThumbnail>(
          find.byType(HomeAlbumCoverThumbnail),
        )) {
          final id = preview.album.id;
          if (id >= 20 && id <= 130) intermediate.add(id);
        }
      }
      expect(intermediate, isEmpty);
      expect(first, closeTo(_scroll(tester, grid).offset, .01));
      expect(
        find.byKey(const ValueKey('home-shelf-album-160')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byType(HomeAlbumCoverThumbnail).evaluate().length,
        lessThan(20),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, 3);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid shelf return cancels an unmoved animation grid=$grid', (
      tester,
    ) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _show(tester, selected, grid: grid);
      selected.value = grid ? 4 : 3;
      await tester.pump();
      selected.value = 0;
      await tester.pump();
      await _frames(tester);
      expect(_scroll(tester, grid).offset, closeTo(0, .01));
      expect(_scroll(tester, grid).position.isScrollingNotifier.value, isFalse);
      expect(
        find.byKey(const ValueKey('home-shelf-album-0')).hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, 3);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nearby shelf selection keeps natural motion grid=$grid', (
      tester,
    ) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _show(tester, selected, grid: grid);
      selected.value = grid ? 8 : 3;
      await tester.pump();
      final offsets = <double>[];
      for (var frame = 0; frame < 22; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        offsets.add(_scroll(tester, grid).offset);
      }
      expect(offsets.last, greaterThan(0));
      expect(
        offsets.any((offset) => offset > .1 && offset < offsets.last - .1),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, 3);
      expect(tester.takeException(), isNull);
    });
  }

  for (final accessible in [false, true]) {
    testWidgets('shelf respects reduced motion accessible=$accessible', (
      tester,
    ) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _show(
        tester,
        selected,
        reduced: !accessible,
        accessible: accessible,
      );
      selected.value = 3;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final offset = _scroll(tester, false).offset;
      await _frames(tester);
      expect(offset, greaterThan(0));
      expect(_scroll(tester, false).offset, closeTo(offset, .01));
      expect(
        _scroll(tester, false).position.isScrollingNotifier.value,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, 3);
      expect(tester.takeException(), isNull);
    });
  }
}

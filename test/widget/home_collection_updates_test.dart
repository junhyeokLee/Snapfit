import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_tab_screen.dart';

void main() {
  testWidgets(
    'collection handles favorite mutation, edits, deletion and account switch',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final albums = [
        for (var id = 3; id > 0; id--)
          Album(
            id: id,
            title: 'Album $id',
            createdAt: '2026-10-2$id',
            coverTheme: 'classic',
          ),
      ];
      final favorites = <int>{};
      var owner = 'first';
      late StateSetter change;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  change = setState;
                  // The maintained collection still processes metadata updates while
                  // hidden, without starting cover/progress workers in this test.
                  return TickerMode(
                    enabled: false,
                    child: HomeAlbumTabScreen(
                      allAlbums: albums,
                      favoriteAlbumIds: favorites,
                      currentUserId: owner,
                      albumTabIndex: 0,
                      showHeader: false,
                      onAlbumTabChanged: (_) {},
                      onToggleFavorite: (_) {},
                      onRefresh: () async {},
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      List<int> order() => tester
          .widgetList<HomeAlbumCoverThumbnail>(
            find.byType(HomeAlbumCoverThumbnail),
          )
          .map((tile) => tile.album.id)
          .toList();
      expect(order(), [3, 2, 1]);
      change(() => favorites.add(1));
      await tester.pumpAndSettle();
      expect(order(), [1, 3, 2]);
      change(() => albums[0] = albums[0].copyWith(title: 'Edited title'));
      await tester.pumpAndSettle();
      expect(find.text('Edited title'), findsOneWidget);
      change(() => albums.removeWhere((album) => album.id == 1));
      await tester.pumpAndSettle();
      expect(order(), [3, 2]);
      change(() {
        owner = 'second';
        albums
          ..clear()
          ..add(
            const Album(id: 9, title: 'New account', coverTheme: 'classic'),
          );
        favorites.clear();
      });
      await tester.pumpAndSettle();
      expect(order(), [9]);
      expect(find.text('Edited title'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

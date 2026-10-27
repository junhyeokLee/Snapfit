import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/utils/home_album_section_builder.dart';

Album _album(int id, {String? date}) => Album(
  id: id,
  createdAt: date ?? '2026-10-${id.toString().padLeft(2, '0')}',
  coverTheme: 'classic',
);

HomeAlbumTabPreparedData _collection(List<Album> source, Set<int> favorites) =>
    buildHomeAlbumTabData(
      allAlbums: source,
      currentUserId: 'owner',
      favoriteAlbumIds: favorites,
      albumTabIndex: 0,
    );

void main() {
  test('initial home reuses chronological metadata and excludes drafts', () {
    final albums = [_album(3), const Album(id: 0), _album(2), _album(1)];
    final prepared = buildHomeAlbumsData(
      albums: albums,
      currentUserId: 'owner',
    );
    expect(prepared.myRecordsAlbums.map((a) => a.id), [3, 2, 1]);
    expect(identical(prepared.baseAlbums, prepared.myRecordsAlbums), isTrue);
    expect(albums.length, 4);
  });

  test('unsorted albums are ordered without mutating their source', () {
    final albums = [_album(1), _album(3), _album(2)];
    final prepared = buildHomeAlbumsData(
      albums: albums,
      currentUserId: 'owner',
    );
    expect(prepared.myRecordsAlbums.map((a) => a.id), [3, 2, 1]);
    expect(prepared.baseAlbums.map((a) => a.id), [1, 3, 2]);
    expect(albums.map((a) => a.id), [1, 3, 2]);
    expect(_collection(albums, {2}).tabAlbums.map((a) => a.id), [2, 3, 1]);
  });

  test(
    'favorites preserve dates and ties through toggle, deletion and edits',
    () {
      final albums = [
        _album(4, date: '2026-10-24'),
        _album(3, date: '2026-10-24'),
        _album(2, date: '2026-10-22'),
        _album(1, date: 'not-a-date'),
      ];
      expect(_collection(albums, {1, 3}).tabAlbums.map((a) => a.id), [
        3,
        1,
        4,
        2,
      ]);
      expect(_collection(albums, {2}).tabAlbums.map((a) => a.id), [2, 4, 3, 1]);
      albums.removeAt(1);
      expect(_collection(albums, {1, 3}).tabAlbums.map((a) => a.id), [1, 4, 2]);
      albums[1] = albums[1].copyWith(createdAt: '2026-10-25');
      expect(_collection(albums, {}).tabAlbums.map((a) => a.id), [2, 4, 1]);
    },
  );

  test(
    'snapshot detects list mutation and new album objects with the same ID',
    () {
      final albums = [_album(2), _album(1)];
      final snapshot = List<Album>.of(albums);
      expect(sameHomeAlbumSequence(snapshot, List.of(albums)), isTrue);
      albums[0] = albums[0].copyWith(title: 'Updated cover');
      expect(sameHomeAlbumSequence(snapshot, albums), isFalse);
      albums[0] = snapshot[0];
      albums.removeLast();
      expect(sameHomeAlbumSequence(snapshot, albums), isFalse);
      expect(
        sameHomeAlbumSequence(snapshot, snapshot.reversed.toList()),
        isFalse,
      );
    },
  );

  test('large metadata lists do not need valid or decoded album documents', () {
    final sharedDocument = 'unparsed:${'photo-layer,' * 20000}';
    final albums = List.generate(
      5000,
      (i) => _album(
        i + 1,
        date: '2026-10-24',
      ).copyWith(coverLayersJson: sharedDocument),
    );
    final prepared = buildHomeAlbumsData(
      albums: albums,
      currentUserId: 'owner',
    );
    expect(identical(prepared.baseAlbums, prepared.myRecordsAlbums), isTrue);
    for (final favorites in [
      <int>{},
      {1, 2500, 5000},
      {5000},
    ]) {
      final result = _collection(prepared.myRecordsAlbums, favorites);
      expect(result.tabAlbums.length, 5000);
      expect(
        result.tabAlbums.take(favorites.length).map((a) => a.id).toSet(),
        favorites,
      );
      expect(result.allAlbums, same(result.tabAlbums));
      expect(
        result.tabAlbums.every(
          (a) => identical(a.coverLayersJson, sharedDocument),
        ),
        isTrue,
      );
    }
    expect(_collection([], {}).tabAlbums, isEmpty);
  });
}

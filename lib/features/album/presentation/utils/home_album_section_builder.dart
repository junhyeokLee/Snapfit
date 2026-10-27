import '../../domain/entities/album.dart';
import '../widgets/home/home_album_helpers.dart';

class HomeAlbumsPreparedData {
  const HomeAlbumsPreparedData({
    required this.baseAlbums,
    required this.myRecordsAlbums,
  });

  final List<Album> baseAlbums;
  final List<Album> myRecordsAlbums;
}

class HomeAlbumTabPreparedData {
  const HomeAlbumTabPreparedData({
    required this.allAlbums,
    required this.tabAlbums,
    required this.tabLabel,
  });

  final List<Album> allAlbums;
  final List<Album> tabAlbums;
  final String tabLabel;
}

HomeAlbumsPreparedData buildHomeAlbumsData({
  required List<Album> albums,
  required String currentUserId,
}) {
  final baseAlbums = albums.where((a) => !isDraftAlbum(a)).toList();
  final myRecordsAlbums = _latestHomeAlbums(baseAlbums);

  return HomeAlbumsPreparedData(
    baseAlbums: baseAlbums,
    myRecordsAlbums: myRecordsAlbums,
  );
}

HomeAlbumTabPreparedData buildHomeAlbumTabData({
  required List<Album> allAlbums,
  required String currentUserId,
  required Set<int> favoriteAlbumIds,
  required int albumTabIndex,
}) {
  // The home destination already supplies chronological order. Reuse it on
  // collection entry/favorite changes instead of sorting both groups again.
  // Other callers may supply an unsorted list; sort a copy only in that case.
  final latest = _latestHomeAlbums(allAlbums);
  // One output list, without allocating intermediate favorite/nonfavorite
  // lists. Stable partition also preserves the input order for equal dates.
  final sortedAlbums = <Album>[
    for (final album in latest)
      if (favoriteAlbumIds.contains(album.id)) album,
    for (final album in latest)
      if (!favoriteAlbumIds.contains(album.id)) album,
  ];

  return HomeAlbumTabPreparedData(
    allAlbums: sortedAlbums,
    tabAlbums: sortedAlbums,
    tabLabel: '나의 기록',
  );
}

List<Album> _latestHomeAlbums(List<Album> albums) {
  for (var i = 1; i < albums.length; i++) {
    if (compareAlbumByLatestDesc(albums[i - 1], albums[i]) > 0) {
      return List<Album>.of(albums)..sort(compareAlbumByLatestDesc);
    }
  }
  return albums;
}

// Album is immutable. Comparing object identities avoids traversing large
// documents through value equality, while still detecting in-place list edits.
bool sameHomeAlbumSequence(List<Album> a, List<Album> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

int compareAlbumByLatestDesc(Album a, Album b) {
  return latestAlbumTimeOf(b).compareTo(latestAlbumTimeOf(a));
}

final _albumTimes = Expando<DateTime>('album sort timestamp');
final _unknownAlbumTime = DateTime.fromMillisecondsSinceEpoch(0);

DateTime latestAlbumTimeOf(Album album) => _albumTimes[album] ??=
    DateTime.tryParse(album.createdAt) ?? _unknownAlbumTime;

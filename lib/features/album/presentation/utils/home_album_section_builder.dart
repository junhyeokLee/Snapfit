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
  final myRecordsAlbums = List<Album>.from(baseAlbums)
    ..sort(compareAlbumByLatestDesc);

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
  // Favorites first, then remaining sorted by latest
  final favorites = allAlbums
      .where((a) => favoriteAlbumIds.contains(a.id))
      .toList()
    ..sort(compareAlbumByLatestDesc);
  final rest = allAlbums
      .where((a) => !favoriteAlbumIds.contains(a.id))
      .toList()
    ..sort(compareAlbumByLatestDesc);
  final sortedAlbums = [...favorites, ...rest];

  return HomeAlbumTabPreparedData(
    allAlbums: sortedAlbums,
    tabAlbums: sortedAlbums,
    tabLabel: '나의 기록',
  );
}

int compareAlbumByLatestDesc(Album a, Album b) {
  return latestAlbumTimeOf(b).compareTo(latestAlbumTimeOf(a));
}

DateTime latestAlbumTimeOf(Album album) {
  return DateTime.tryParse(album.createdAt) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

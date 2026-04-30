import '../../domain/entities/album.dart';
import '../widgets/home/home_album_helpers.dart';

class HomeAlbumsPreparedData {
  const HomeAlbumsPreparedData({
    required this.baseAlbums,
    required this.myRecordsAlbums,
    required this.completedAlbums,
    required this.completedPreviewAlbums,
    required this.sharedOwnerCandidates,
  });

  final List<Album> baseAlbums;
  final List<Album> myRecordsAlbums;
  final List<Album> completedAlbums;
  final List<Album> completedPreviewAlbums;
  final List<Album> sharedOwnerCandidates;
}

class HomeAlbumTabPreparedData {
  const HomeAlbumTabPreparedData({
    required this.allAlbums,
    required this.inProgressAlbums,
    required this.completedAlbums,
    required this.favoriteAlbums,
    required this.sharedAlbums,
    required this.tabAlbums,
    required this.tabLabel,
  });

  final List<Album> allAlbums;
  final List<Album> inProgressAlbums;
  final List<Album> completedAlbums;
  final List<Album> favoriteAlbums;
  final List<Album> sharedAlbums;
  final List<Album> tabAlbums;
  final String tabLabel;
}

HomeAlbumsPreparedData buildHomeAlbumsData({
  required List<Album> albums,
  required String currentUserId,
}) {
  final normalizedUserId = currentUserId.trim();
  final baseAlbums = albums.where((a) => !isDraftAlbum(a)).toList();
  final myRecordsAlbums = List<Album>.from(baseAlbums)
    ..sort(compareAlbumByLatestDesc);

  final completedAlbums = List<Album>.from(
    baseAlbums.where((a) => isCompletedAlbum(a)),
  )..sort(compareAlbumByLatestDesc);

  final sharedOwnerCandidates = normalizedUserId.isEmpty
      ? <Album>[]
      : (baseAlbums
            .where(
              (a) =>
                  a.userId.trim().isNotEmpty &&
                  a.userId.trim() != normalizedUserId,
            )
            .toList()
          ..sort(compareAlbumByLatestDesc));

  return HomeAlbumsPreparedData(
    baseAlbums: baseAlbums,
    myRecordsAlbums: myRecordsAlbums,
    completedAlbums: completedAlbums,
    completedPreviewAlbums: completedAlbums.take(3).toList(),
    sharedOwnerCandidates: sharedOwnerCandidates,
  );
}

HomeAlbumTabPreparedData buildHomeAlbumTabData({
  required List<Album> allAlbums,
  required String currentUserId,
  required Set<int> favoriteAlbumIds,
  required int albumTabIndex,
}) {
  final allSortedAlbums = List<Album>.from(allAlbums)..sort(compareAlbumByLatestDesc);
  final normalizedUserId = currentUserId.trim();
  final inProgressAlbums = List<Album>.from(
    allAlbums.where((a) => isLiveEditingAlbum(a)),
  )..sort(compareAlbumByLatestDesc);
  final completedAlbums = List<Album>.from(
    allAlbums.where((a) => isCompletedAlbum(a)),
  )..sort(compareAlbumByLatestDesc);
  final favoriteAlbums = List<Album>.from(
    allAlbums.where((a) => favoriteAlbumIds.contains(a.id)),
  )..sort(compareAlbumByLatestDesc);
  final sharedAlbums = normalizedUserId.isEmpty
      ? <Album>[]
      : (List<Album>.from(
          allAlbums.where(
            (a) =>
                a.userId.trim().isNotEmpty && a.userId.trim() != normalizedUserId,
          ),
        )..sort(compareAlbumByLatestDesc));

  final tabAlbums = switch (albumTabIndex) {
    1 => inProgressAlbums,
    2 => completedAlbums,
    3 => favoriteAlbums,
    4 => sharedAlbums,
    _ => allSortedAlbums,
  };

  final tabLabel = switch (albumTabIndex) {
    1 => '진행중',
    2 => '완료',
    3 => '즐겨찾기',
    4 => '공유',
    _ => '전체',
  };

  return HomeAlbumTabPreparedData(
    allAlbums: allSortedAlbums,
    inProgressAlbums: inProgressAlbums,
    completedAlbums: completedAlbums,
    favoriteAlbums: favoriteAlbums,
    sharedAlbums: sharedAlbums,
    tabAlbums: tabAlbums,
    tabLabel: tabLabel,
  );
}

int compareAlbumByLatestDesc(Album a, Album b) {
  return latestAlbumTimeOf(b).compareTo(latestAlbumTimeOf(a));
}

DateTime latestAlbumTimeOf(Album album) {
  return DateTime.tryParse(album.createdAt) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

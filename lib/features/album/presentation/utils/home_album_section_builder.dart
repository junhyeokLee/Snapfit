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
    required this.inProgressAlbums,
    required this.completedAlbums,
    required this.favoriteAlbums,
    required this.tabAlbums,
    required this.tabLabel,
  });

  final List<Album> inProgressAlbums;
  final List<Album> completedAlbums;
  final List<Album> favoriteAlbums;
  final List<Album> tabAlbums;
  final String tabLabel;
}

HomeAlbumsPreparedData buildHomeAlbumsData({
  required List<Album> albums,
  required String currentUserId,
}) {
  final normalizedUserId = currentUserId.trim();
  final baseAlbums = albums.where((a) => !isDraftAlbum(a)).toList();

  final myOwnedAlbums = baseAlbums.where((a) {
    if (normalizedUserId.isEmpty) return true;
    return a.userId.trim() == normalizedUserId;
  }).toList();
  final myRecordsSource = myOwnedAlbums.isNotEmpty ? myOwnedAlbums : baseAlbums;
  final myRecordsAlbums = List<Album>.from(myRecordsSource)
    ..sort(compareAlbumByLatestDesc);

  final completedAlbums =
      List<Album>.from(baseAlbums.where((a) => isCompletedAlbum(a)))
        ..sort(compareAlbumByLatestDesc);

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
  required Set<int> favoriteAlbumIds,
  required int albumTabIndex,
}) {
  final inProgressAlbums =
      List<Album>.from(allAlbums.where((a) => isLiveEditingAlbum(a)))
        ..sort(compareAlbumByLatestDesc);
  final completedAlbums =
      List<Album>.from(allAlbums.where((a) => isCompletedAlbum(a)))
        ..sort(compareAlbumByLatestDesc);
  final favoriteAlbums =
      List<Album>.from(allAlbums.where((a) => favoriteAlbumIds.contains(a.id)))
        ..sort(compareAlbumByLatestDesc);

  final tabAlbums = switch (albumTabIndex) {
    1 => completedAlbums,
    2 => favoriteAlbums,
    _ => inProgressAlbums,
  };

  final tabLabel = switch (albumTabIndex) {
    1 => '완료',
    2 => '즐겨찾기',
    _ => '진행중',
  };

  return HomeAlbumTabPreparedData(
    inProgressAlbums: inProgressAlbums,
    completedAlbums: completedAlbums,
    favoriteAlbums: favoriteAlbums,
    tabAlbums: tabAlbums,
    tabLabel: tabLabel,
  );
}

int compareAlbumByLatestDesc(Album a, Album b) {
  return latestAlbumTimeOf(b).compareTo(latestAlbumTimeOf(a));
}

DateTime latestAlbumTimeOf(Album album) {
  final updated = DateTime.tryParse(album.updatedAt);
  if (updated != null) return updated;
  return DateTime.tryParse(album.createdAt) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

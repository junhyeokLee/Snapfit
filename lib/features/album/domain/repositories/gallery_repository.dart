import 'package:photo_manager/photo_manager.dart';

abstract class GalleryRepository {
  Future<bool> requestPermission();
  Future<List<AssetPathEntity>> loadAlbums();
  Future<List<AssetEntity>> loadImagesPaged(
      AssetPathEntity album,
      int page,
      int size,
      );
}
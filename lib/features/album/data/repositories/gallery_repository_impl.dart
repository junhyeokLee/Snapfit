import 'package:photo_manager/photo_manager.dart';
import '../../domain/repositories/gallery_repository.dart';

class GalleryRepositoryImpl implements GalleryRepository {
  @override
  Future<bool> requestPermission() async {
    final perm = await PhotoManager.requestPermissionExtend();
    return perm.isAuth;
  }

  @override
  Future<List<AssetPathEntity>> loadAlbums() {
    return PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: false,
    );
  }

  @override
  Future<List<AssetEntity>> loadImagesPaged(
      AssetPathEntity album,
      int page,
      int size,
      ) {
    return album.getAssetListPaged(page: page, size: size);
  }
}

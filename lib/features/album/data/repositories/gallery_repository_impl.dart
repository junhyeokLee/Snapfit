import 'package:photo_manager/photo_manager.dart';
import '../../domain/repositories/gallery_repository.dart';

class GalleryRepositoryImpl implements GalleryRepository {
  GalleryRepositoryImpl({
    Future<PermissionState> Function()? requestPermissionExtend,
  }) : _requestPermissionExtend =
           requestPermissionExtend ?? PhotoManager.requestPermissionExtend;

  final Future<PermissionState> Function() _requestPermissionExtend;

  @override
  Future<bool> requestPermission() async {
    final perm = await _requestPermissionExtend();
    return perm.hasAccess;
  }

  @override
  Future<List<AssetPathEntity>> loadAlbums() {
    return PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: false,
    );
  }

  @override
  Future<AssetPathEntity?> loadAllPhotosAlbum() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    return albums.isEmpty ? null : albums.first;
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

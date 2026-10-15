import 'package:photo_manager/photo_manager.dart';
import '../../domain/repositories/gallery_repository.dart';

class GalleryRepositoryImpl implements GalleryRepository {
  GalleryRepositoryImpl({
    Future<PermissionState> Function()? requestPermissionExtend,
  }) : _requestPermissionExtend =
           requestPermissionExtend ?? PhotoManager.requestPermissionExtend;

  final Future<PermissionState> Function() _requestPermissionExtend;

  static const _latestFirst = [
    OrderOption(type: OrderOptionType.createDate, asc: false),
    OrderOption(type: OrderOptionType.updateDate, asc: false),
  ];

  FilterOptionGroup _photoFilter() => FilterOptionGroup(orders: _latestFirst);

  @override
  Future<bool> requestPermission() async {
    final perm = await _requestPermissionExtend();
    return perm.hasAccess;
  }

  @override
  Future<List<AssetPathEntity>> loadAlbums() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
      onlyAll: false,
      filterOption: _photoFilter(),
    );
    return [
      ...albums.where((album) => album.isAll),
      ...albums.where((album) => !album.isAll),
    ];
  }

  @override
  Future<AssetPathEntity?> loadAllPhotosAlbum() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: _photoFilter(),
    );
    return albums.isEmpty ? null : albums.first;
  }

  @override
  Future<List<AssetEntity>> loadImagesPaged(
    AssetPathEntity album,
    int page,
    int size,
  ) {
    final filter = album.filterOption;
    // Sort in the native query, before pagination, including cached album paths.
    final ordered = album.copyWith(
      albumType: album.albumType,
      filterOption: filter is FilterOptionGroup
          ? filter.copyWith(orders: _latestFirst)
          : _photoFilter(),
    );
    return ordered.getAssetListPaged(page: page, size: size);
  }
}

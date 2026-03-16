import 'package:photo_manager/photo_manager.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../../data/api/album_provider.dart';

part 'gallery_notifier.freezed.dart';
part 'gallery_notifier.g.dart';

@freezed
abstract class GalleryState with _$GalleryState {
  const factory GalleryState({
    @Default([]) List<AssetPathEntity> albums,
    AssetPathEntity? selectedAlbum,
    @Default([]) List<AssetEntity> images,
    @Default(0) int currentPage,
    @Default(true) bool hasMore,
    @Default(false) bool isLoading,
    Object? error,
  }) = _GalleryState;
}

@Riverpod(keepAlive: true)
class GalleryNotifier extends _$GalleryNotifier {
  late final GalleryRepository _repository;
  final int _pageSize = 40;

  @override
  GalleryState build() {
    _repository = ref.read(galleryRepositoryProvider);
    return const GalleryState();
  }

  /// 초기 데이터 로드 (권한 확인 및 첫 앨범 로딩)
  Future<void> fetchInitialData() async {
    final permitted = await _repository.requestPermission();
    if (!ref.mounted) return;
    if (!permitted) return;

    final albums = await _repository.loadAlbums();
    if (!ref.mounted) return;
    if (albums.isEmpty) {
      state = state.copyWith(albums: [], error: '이미지 앨범이 없습니다.');
      return;
    }

    final firstAlbum = albums.first;
    state = state.copyWith(
      albums: albums,
      selectedAlbum: firstAlbum,
      currentPage: 0,
      images: [],
      hasMore: true,
    );

    await loadMore();
  }

  /// 앨범 선택 변경
  Future<void> selectAlbum(AssetPathEntity album) async {
    if (state.selectedAlbum?.id == album.id) return;

    state = state.copyWith(
      selectedAlbum: album,
      currentPage: 0,
      images: [],
      hasMore: true,
    );

    await loadMore();
  }

  /// 이미지 추가 로딩 (페이징)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.selectedAlbum == null)
      return;

    state = state.copyWith(isLoading: true);

    try {
      final newImages = await _repository.loadImagesPaged(
        state.selectedAlbum!,
        state.currentPage,
        _pageSize,
      );

      if (!ref.mounted) return;

      state = state.copyWith(
        images: [...state.images, ...newImages],
        currentPage: state.currentPage + 1,
        hasMore: newImages.length == _pageSize,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}

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
  int _requestVersion = 0;

  @override
  GalleryState build() {
    _repository = ref.read(galleryRepositoryProvider);
    return const GalleryState();
  }

  /// 초기 데이터 로드 (권한 확인 및 첫 앨범 로딩)
  Future<void> fetchInitialData({String? albumId}) async {
    final version = ++_requestVersion;
    state = const GalleryState(isLoading: true);
    try {
      final permitted = await _repository.requestPermission();
      if (!ref.mounted || version != _requestVersion) return;
      if (!permitted) {
        state = state.copyWith(
          isLoading: false,
          albums: const [],
          selectedAlbum: null,
          images: const [],
          hasMore: false,
          error: '사진 접근 권한이 필요합니다. 권한을 허용해주세요.',
        );
        return;
      }

      final albums = await _repository.loadAlbums();
      if (!ref.mounted || version != _requestVersion) return;
      if (albums.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          albums: const [],
          selectedAlbum: null,
          images: const [],
          hasMore: false,
          error: '이미지 앨범이 없습니다.',
        );
        return;
      }

      final firstAlbum =
          albums.where((album) => album.id == albumId).firstOrNull ??
          albums.where((album) => album.isAll).firstOrNull ??
          albums.first;
      state = state.copyWith(
        albums: albums,
        selectedAlbum: firstAlbum,
        currentPage: 0,
        images: const [],
        hasMore: true,
        isLoading: false,
        error: null,
      );

      await loadMore();
    } catch (e) {
      if (!ref.mounted || version != _requestVersion) return;
      state = state.copyWith(
        isLoading: false,
        selectedAlbum: null,
        images: const [],
        hasMore: false,
        error: e,
      );
    }
  }

  /// 앨범 선택 변경
  Future<void> selectAlbum(AssetPathEntity album) async {
    if (state.selectedAlbum?.id == album.id) return;

    ++_requestVersion;
    state = state.copyWith(
      selectedAlbum: album,
      currentPage: 0,
      images: [],
      hasMore: true,
      isLoading: false,
      error: null,
    );

    await loadMore();
  }

  /// 이미지 추가 로딩 (페이징)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.selectedAlbum == null) {
      return;
    }

    final version = _requestVersion;
    final album = state.selectedAlbum!;
    final page = state.currentPage;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final newImages = await _repository.loadImagesPaged(
        album,
        page,
        _pageSize,
      );

      // A previous album may finish loading after the user has switched albums.
      if (!ref.mounted || version != _requestVersion) return;

      state = state.copyWith(
        images: [...state.images, ...newImages],
        currentPage: page + 1,
        hasMore: newImages.length == _pageSize,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted || version != _requestVersion) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}

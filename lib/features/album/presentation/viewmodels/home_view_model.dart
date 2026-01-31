import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../album/data/api/album_provider.dart';
import '../../../album/domain/entities/album.dart';

part 'home_view_model.g.dart';

@riverpod
class HomeViewModel extends _$HomeViewModel {
  @override
  FutureOr<List<Album>> build() async {
    return _fetchAlbums();
  }

  Future<List<Album>> _fetchAlbums() async {
    // 기존에 정의된 albumRepositoryProvider를 사용합니다.
    final repository = ref.read(albumRepositoryProvider);
    return await repository.fetchMyAlbums();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchAlbums());
  }

  Future<void> deleteAlbum(Album album) async {
    // 낙관적 업데이트: 바로 목록에서 제거 후 서버 삭제 시도
    final prev = state.asData?.value;
    if (prev != null) {
      state = AsyncData(prev.where((a) => a.id != album.id).toList());
    }

    final repository = ref.read(albumRepositoryProvider);
    try {
      await repository.deleteAlbum(album.id);
    } catch (_) {
      // 실패 시 목록을 다시 새로고침
      state = await AsyncValue.guard(() => _fetchAlbums());
      rethrow;
    }
  }
}
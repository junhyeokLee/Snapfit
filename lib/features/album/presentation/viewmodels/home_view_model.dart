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

  Future<void> reorder(int oldIndex, int newIndex) async {
    final prev = state.asData?.value;
    if (prev == null) return;

    final items = List<Album>.from(prev);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // 낙관적 업데이트: orders 필드도 갱신
    final updatedItems = items.asMap().entries.map((entry) {
      final index = entry.key;
      final album = entry.value;
      return album.copyWith(orders: index);
    }).toList();

    state = AsyncData(updatedItems);

    final repository = ref.read(albumRepositoryProvider);
    try {
      // 순서가 변경된 전체 ID 리스트 전송
      final ids = updatedItems.map((e) => e.id).toList();
      await repository.reorderAlbums(ids);
    } catch (_) {
      // 실패 시 원복
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> reorderByCategory(List<Album> categoryAlbums) async {
    final prev = state.asData?.value;
    if (prev == null) return;

    // 1. 전체 리스트 복사
    final fullItems = List<Album>.from(prev);
    
    // 2. 전달받은 카테고리 앨범들의 ID 리스트 순서대로 orders 갱신
    final categoryIds = categoryAlbums.map((e) => e.id).toSet();
    final otherItems = fullItems.where((a) => !categoryIds.contains(a.id)).toList();
    
    // 합치기: 카테고리 변경된 것들 + 나머지 (카테고리 순서가 우선)
    final merged = [...categoryAlbums, ...otherItems];

    // orders 필드 일괄 갱신
    final updatedItems = merged.asMap().entries.map((entry) {
      final index = entry.key;
      final album = entry.value;
      return album.copyWith(orders: index);
    }).toList();

    state = AsyncData(updatedItems);

    final repository = ref.read(albumRepositoryProvider);
    try {
      final ids = updatedItems.map((e) => e.id).toList();
      await repository.reorderAlbums(ids);
    } catch (_) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}
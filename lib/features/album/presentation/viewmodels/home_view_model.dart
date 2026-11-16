import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../album/data/api/album_provider.dart';
import '../../../album/domain/entities/album.dart';
import '../providers/album_edit_session_provider.dart';

part 'home_view_model.g.dart';

final homeAlbumReadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 25),
);

@riverpod
class HomeViewModel extends _$HomeViewModel {
  Future<void>? _refreshFuture;
  final _deleteRequests = <int, Future<void>>{};
  int _mutationVersion = 0;
  int _activeMutations = 0;
  Completer<void>? _mutationsSettled;
  int _sessionRevision = 0;
  String? _sessionOwner;
  bool _ownerInitialized = false;

  bool _current(int revision, String? owner) =>
      ref.mounted &&
      revision == _sessionRevision &&
      ref.read(albumEditorOwnerReaderProvider)() == owner;

  @override
  FutureOr<List<Album>> build() async {
    final owner = ref.watch(albumCurrentSessionOwnerProvider);
    final changed = _ownerInitialized && _sessionOwner != owner;
    _ownerInitialized = true;
    _sessionOwner = owner;
    final revision = ++_sessionRevision;
    _refreshFuture = null;
    _deleteRequests.clear();
    _activeMutations = 0;
    _mutationVersion++;
    _mutationsSettled?.complete();
    _mutationsSettled = null;
    // 이전 계정의 자료를 지우되, 새 계정의 조회가 끝나기 전에는 로딩 상태와
    // 미완료 future를 유지한다. 임시 []를 성공한 빈 목록으로 처리하지 않는다.
    if (changed) {
      // Riverpod 3에는 공개 원자적 초기화 API가 없다. 이 호출의 호환성은
      // 실제 계정 교체·대기·실패·재시도 테스트로 검증한다.
      // ignore: invalid_use_of_internal_member
      state = const AsyncLoading<List<Album>>().copyWithPrevious(
        const AsyncData<List<Album>>([]),
        isRefresh: false,
      );
    }
    if (owner == null) return const [];
    final result = await _fetchAlbums();
    return _current(revision, owner) ? result : const [];
  }

  Future<List<Album>> _fetchAlbums() async {
    // 기존에 정의된 albumRepositoryProvider를 사용합니다.
    final repository = ref.read(albumRepositoryProvider);
    return await repository.fetchMyAlbums().timeout(
      ref.read(homeAlbumReadTimeoutProvider),
    );
  }

  Future<void> refresh() {
    final existing = _refreshFuture;
    if (existing != null) return existing;
    late final Future<void> request;
    request = _refreshAlbums().whenComplete(() {
      if (identical(_refreshFuture, request)) _refreshFuture = null;
    });
    return _refreshFuture = request;
  }

  Future<void> _refreshAlbums() async {
    final session = _sessionRevision;
    final owner = _sessionOwner;
    if (owner == null || !_current(session, owner)) return;
    // Keep the mounted slider and its selection during background refreshes.
    // A failed refresh should not replace usable albums with an error screen.
    if (!state.hasValue) state = const AsyncLoading();
    while (_current(session, owner)) {
      final pending = _mutationsSettled?.future;
      if (pending != null) await pending;
      if (!_current(session, owner)) return;
      if (_activeMutations > 0) continue;

      final version = _mutationVersion;
      final result = await AsyncValue.guard(() => _fetchAlbums());
      if (!_current(session, owner)) return;
      // A query started before a delete/reorder can still contain old data.
      // Wait for those writes and query again, without painting that snapshot.
      if (_activeMutations > 0 || version != _mutationVersion) continue;
      if (!result.hasError || !state.hasValue) state = result;
      return;
    }
  }

  Future<void> _runMutation(Future<void> Function() write) async {
    final session = _sessionRevision;
    final owner = _sessionOwner;
    if (owner == null || !_current(session, owner)) return;
    _mutationVersion++;
    _activeMutations++;
    _mutationsSettled ??= Completer<void>();
    try {
      await write();
    } finally {
      // Invalidate queries that started while a write was still outstanding,
      // including writes whose optimistic change had to be rolled back.
      if (_current(session, owner)) {
        _mutationVersion++;
        if (--_activeMutations == 0) {
          final settled = _mutationsSettled!;
          _mutationsSettled = null;
          settled.complete();
        }
      }
    }
  }

  Future<void> deleteAlbum(Album album) {
    // Duplicate taps must share one write and one rollback for this album.
    final existing = _deleteRequests[album.id];
    if (existing != null) return existing;
    late final Future<void> request;
    request = _deleteAlbum(album).whenComplete(() {
      if (identical(_deleteRequests[album.id], request)) {
        _deleteRequests.remove(album.id);
      }
    });
    return _deleteRequests[album.id] = request;
  }

  Future<void> _deleteAlbum(Album album) async {
    final session = _sessionRevision;
    final owner = _sessionOwner;
    // 낙관적 업데이트: 바로 목록에서 제거 후 서버 삭제 시도
    final prev = state.asData?.value;
    final repository = ref.read(albumRepositoryProvider);
    await _runMutation(() async {
      if (prev != null) {
        state = AsyncData(prev.where((a) => a.id != album.id).toList());
      }
      try {
        await repository.deleteAlbum(album.id);
      } catch (_) {
        if (_current(session, owner) && prev != null) {
          final index = prev.indexWhere((item) => item.id == album.id);
          final current = state.asData?.value;
          if (index >= 0 &&
              current != null &&
              !current.any((item) => item.id == album.id)) {
            // Restore only this failed deletion, preserving other changes.
            final restored = List<Album>.from(current);
            restored.insert(index.clamp(0, restored.length), prev[index]);
            state = AsyncData(restored);
          }
        }
        rethrow;
      }
    });
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final session = _sessionRevision;
    final owner = _sessionOwner;
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

    final repository = ref.read(albumRepositoryProvider);
    await _runMutation(() async {
      state = AsyncData(updatedItems);
      try {
        // 순서가 변경된 전체 ID 리스트 전송
        final ids = updatedItems.map((e) => e.id).toList();
        await repository.reorderAlbums(ids);
      } catch (_) {
        if (_current(session, owner)) {
          if (identical(state.asData?.value, updatedItems)) {
            state = AsyncData(prev);
          } else {
            // A newer mutation owns the current list. Reconcile only after
            // all writes finish instead of restoring an obsolete whole list.
            unawaited(refresh());
          }
        }
        rethrow;
      }
    });
  }

  Future<void> reorderByCategory(List<Album> categoryAlbums) async {
    final session = _sessionRevision;
    final owner = _sessionOwner;
    final prev = state.asData?.value;
    if (prev == null) return;

    // 1. 전체 리스트 복사
    final fullItems = List<Album>.from(prev);

    // 2. 전달받은 카테고리 앨범들의 ID 리스트 순서대로 orders 갱신
    final categoryIds = categoryAlbums.map((e) => e.id).toSet();
    final otherItems = fullItems
        .where((a) => !categoryIds.contains(a.id))
        .toList();

    // 합치기: 카테고리 변경된 것들 + 나머지 (카테고리 순서가 우선)
    final merged = [...categoryAlbums, ...otherItems];

    // orders 필드 일괄 갱신
    final updatedItems = merged.asMap().entries.map((entry) {
      final index = entry.key;
      final album = entry.value;
      return album.copyWith(orders: index);
    }).toList();

    final repository = ref.read(albumRepositoryProvider);
    await _runMutation(() async {
      state = AsyncData(updatedItems);
      try {
        final ids = updatedItems.map((e) => e.id).toList();
        await repository.reorderAlbums(ids);
      } catch (_) {
        if (_current(session, owner)) {
          if (identical(state.asData?.value, updatedItems)) {
            state = AsyncData(prev);
          } else {
            unawaited(refresh());
          }
        }
        rethrow;
      }
    });
  }
}

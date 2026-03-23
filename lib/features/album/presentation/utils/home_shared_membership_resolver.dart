import '../../domain/entities/album.dart';

class HomeSharedMembershipResolver {
  String _cachedUserId = '';
  final Map<int, bool> _membershipCache = <int, bool>{};
  final Map<int, Future<bool>> _inFlight = <int, Future<bool>>{};

  void clear() {
    _cachedUserId = '';
    _membershipCache.clear();
    _inFlight.clear();
  }

  Future<List<Album>> resolve({
    required List<Album> candidates,
    required String currentUserId,
    required Future<bool> Function(int albumId, String currentUserId)
    isJoinedLoader,
    required bool Function(Album album, String currentUserId) fallbackOnError,
    required int Function(Album a, Album b) sortBy,
  }) async {
    final normalizedUserId = currentUserId.trim();
    if (normalizedUserId.isEmpty || candidates.isEmpty) return <Album>[];

    if (_cachedUserId != normalizedUserId) {
      _cachedUserId = normalizedUserId;
      _membershipCache.clear();
      _inFlight.clear();
    }

    final tasks = candidates.map((album) async {
      final cached = _membershipCache[album.id];
      if (cached != null) return cached ? album : null;

      try {
        final running = _inFlight[album.id];
        final task =
            running ??
            isJoinedLoader(album.id, normalizedUserId).then((value) {
              _membershipCache[album.id] = value;
              _inFlight.remove(album.id);
              return value;
            });
        _inFlight[album.id] = task;
        final isJoined = await task;
        return isJoined ? album : null;
      } catch (_) {
        _inFlight.remove(album.id);
        final fallback = fallbackOnError(album, normalizedUserId);
        _membershipCache[album.id] = fallback;
        return fallback ? album : null;
      }
    });

    final resolved = (await Future.wait(tasks)).whereType<Album>().toList()
      ..sort(sortBy);
    return resolved;
  }
}

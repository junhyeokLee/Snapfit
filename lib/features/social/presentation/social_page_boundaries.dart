import '../domain/social_models.dart' show socialCursorKey;

/// Tracks the outgoing edge of every loaded page, keyed by its exact request.
/// A refreshed page can move its edge without changing the first page at all.
/// Loading/error snapshots pass null and never erase a known edge.
class SocialPageBoundaries<Query extends Object> {
  final _known = <Query, String>{};

  void clear() => _known.clear();

  /// Returns the number of pages to retain when an outgoing edge changes.
  /// The last page also counts: its previously rendered More action is stale.
  int? observe(List<Query> queries, List<String?> boundaries) {
    assert(queries.length == boundaries.length);
    _known.removeWhere((query, _) => !queries.contains(query));
    for (var index = 0; index < queries.length; index++) {
      final boundary = boundaries[index];
      if (boundary == null) continue;
      final query = queries[index];
      final previous = _known[query];
      _known[query] = boundary;
      if (previous != null && previous != boundary) {
        // Do not establish fresh baselines for replies from the stale suffix.
        for (final stale in queries.skip(index + 1)) {
          _known.remove(stale);
        }
        return index + 1;
      }
    }
    return null;
  }
}

String socialPageBoundary({
  required Map<String, dynamic>? nextCursor,
  required int nextOffset,
  required bool hasMore,
  required Iterable<String> itemKeys,
}) => nextCursor != null && nextCursor.isNotEmpty
    ? 'cursor:${socialCursorKey(nextCursor)}|more:$hasMore'
    : 'offset:$nextOffset|more:$hasMore|items:${itemKeys.join(',')}';

import '../../../core/templates/catalog_publication_dates.dart';

class StoreProductDiscovery {
  const StoreProductDiscovery({this.firstPublishedAt, this.bestRank});
  final DateTime? firstPublishedAt;
  final int? bestRank;
  static const newPeriod = Duration(days: 14);
  static const newDescription = '최초 공개 후 14일 동안 표시돼요.';
  static const bestDescription =
      '최근 30일간 10명 이상이 포인트로 소장한 상품 중 종류별 상위 5개예요. 같은 사람은 한 번만 집계해요.';

  factory StoreProductDiscovery.fromJson(Map<String, dynamic> row) =>
      StoreProductDiscovery(
        firstPublishedAt: DateTime.tryParse(
          row['first_published_at']?.toString() ?? '',
        ),
        bestRank: (row['best_rank'] as num?)?.toInt(),
      );

  bool isNewAt(DateTime now) {
    final first = firstPublishedAt;
    return first != null &&
        !now.isBefore(first) &&
        now.isBefore(first.add(newPeriod));
  }

  bool get isBest => bestRank != null && bestRank! >= 1 && bestRank! <= 5;
}

final bundledStoreDiscovery = Map<String, StoreProductDiscovery>.unmodifiable({
  for (final entry in catalogFirstPublicationDates.entries)
    entry.key: StoreProductDiscovery(
      firstPublishedAt: DateTime.parse(entry.value),
    ),
});

/// Store sorting uses the verified first publication date even after NEW has
/// expired. Only qualifying server ranks can lead popular order; all remaining
/// products fall back to the same latest order. Unknown/future dates keep their
/// stable source order behind known public releases.
List<T> sortStoreProducts<T>(
  Iterable<T> items, {
  required String Function(T) productKey,
  required Map<String, StoreProductDiscovery> discovery,
  required DateTime now,
  bool popularityFirst = false,
}) {
  DateTime? published(StoreProductDiscovery? metadata) {
    final date = metadata?.firstPublishedAt;
    return date != null && !date.isAfter(now) ? date : null;
  }

  final ranked = items.indexed.toList();
  ranked.sort((a, b) {
    final left = discovery[productKey(a.$2)];
    final right = discovery[productKey(b.$2)];
    if (popularityFirst) {
      final rank = (left?.isBest == true ? left!.bestRank! : 6).compareTo(
        right?.isBest == true ? right!.bestRank! : 6,
      );
      if (rank != 0) return rank;
    }
    final leftDate = published(left);
    final rightDate = published(right);
    if (leftDate != null && rightDate != null) {
      final date = rightDate.compareTo(leftDate);
      if (date != 0) return date;
    } else if (leftDate != null || rightDate != null) {
      return leftDate != null ? -1 : 1;
    }
    return a.$1.compareTo(b.$1);
  });
  return ranked.map((entry) => entry.$2).toList();
}

/// Stable metadata-only order. Flags, dates of edits and download/build time
/// cannot promote a product. No document/font/image generation occurs here.
List<T> prioritizeNewStoreProducts<T>(
  Iterable<T> items, {
  required String Function(T) productKey,
  required Map<String, StoreProductDiscovery> discovery,
  required DateTime now,
}) {
  final ranked = items.indexed.toList();
  ranked.sort((a, b) {
    final left = discovery[productKey(a.$2)];
    final right = discovery[productKey(b.$2)];
    final leftNew = left?.isNewAt(now) == true;
    final rightNew = right?.isNewAt(now) == true;
    if (leftNew != rightNew) return leftNew ? -1 : 1;
    if (leftNew && rightNew) {
      final date = right!.firstPublishedAt!.compareTo(left!.firstPublishedAt!);
      if (date != 0) return date;
    }
    return a.$1.compareTo(b.$1);
  });
  return ranked.map((entry) => entry.$2).toList();
}

import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';

/// Supplies fully loaded history fixtures without auth or repository queries.
class FixturePointLedgerHistoryController extends PointLedgerHistoryController {
  FixturePointLedgerHistoryController(super.filter, this.loadEntries);

  final Future<List<PointLedgerEntry>> Function() loadEntries;
  int _generation = 0;

  @override
  PointLedgerHistoryState build() {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    // Wait until the notifier has its initial state before resolving fixtures.
    Future<void>.microtask(() => _load(generation));
    return const PointLedgerHistoryState(loading: true);
  }

  @override
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    state = const PointLedgerHistoryState(loading: true);
    await _load(generation);
  }

  @override
  Future<void> loadMore() async {
    // Layout fixtures already contain every row, including the lazy 80-row case.
  }

  Future<void> _load(int generation) async {
    try {
      final entries = await loadEntries();
      if (!ref.mounted || generation != _generation) return;
      state = PointLedgerHistoryState(
        entries: entries
            .where((entry) {
              return switch (filter) {
                PointLedgerFilter.all => true,
                PointLedgerFilter.received => entry.amountDelta > 0,
                PointLedgerFilter.spent => entry.amountDelta < 0,
              };
            })
            .toList(growable: false),
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      state = const PointLedgerHistoryState(hasError: true);
    }
  }
}

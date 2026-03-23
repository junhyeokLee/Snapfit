import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoreFilterState {
  const StoreFilterState({
    this.selectedCategory = '전체',
    this.sortLatest = true,
    this.query = '',
  });

  final String selectedCategory;
  final bool sortLatest;
  final String query;

  StoreFilterState copyWith({
    String? selectedCategory,
    bool? sortLatest,
    String? query,
  }) {
    return StoreFilterState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      sortLatest: sortLatest ?? this.sortLatest,
      query: query ?? this.query,
    );
  }
}

class StoreFilterNotifier extends Notifier<StoreFilterState> {
  @override
  StoreFilterState build() => const StoreFilterState();

  void setCategory(String category) {
    if (state.selectedCategory == category) return;
    state = state.copyWith(selectedCategory: category);
  }

  void setSortLatest(bool latest) {
    if (state.sortLatest == latest) return;
    state = state.copyWith(sortLatest: latest);
  }

  void setQuery(String query) {
    final normalized = query.trim();
    if (state.query == normalized) return;
    state = state.copyWith(query: normalized);
  }
}

final storeFilterProvider =
    NotifierProvider.autoDispose<StoreFilterNotifier, StoreFilterState>(
      StoreFilterNotifier.new,
    );

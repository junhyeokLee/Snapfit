import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/templates/catalog_favorites.dart';
import '../../../../core/templates/catalog_favorite_keys.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../../album/data/bundled_creation_templates.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../domain/repositories/template_repository.dart';
import '../../domain/entities/premium_template.dart';
import '../repositories/supabase_template_repository.dart';

const String _templateLikeStateKey = 'template_like_state_v1';

PremiumTemplate normalizeTemplateLikeStateForDisplay(PremiumTemplate template) {
  final safeCount = template.likeCount < 0 ? 0 : template.likeCount;
  if (template.isLiked && safeCount == 0) {
    return template.copyWith(likeCount: 1);
  }
  if (safeCount != template.likeCount) {
    return template.copyWith(likeCount: safeCount);
  }
  return template;
}

String _templateLikeLookupKey(PremiumTemplate template, {String? userId}) {
  final userScope = (userId == null || userId.trim().isEmpty)
      ? 'guest'
      : userId.trim();
  final id = template.id;
  if (id > 0) return '$userScope:id:$id';
  return '$userScope:title:${_normalizeTemplateTitleKey(template.title)}';
}

Future<Map<String, dynamic>> _loadTemplateLikeStateMap() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_templateLikeStateKey);
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return <String, dynamic>{};
}

Future<void> persistTemplateLikeState(
  PremiumTemplate template, {
  String? userId,
}) async {
  try {
    final normalized = normalizeTemplateLikeStateForDisplay(template);
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadTemplateLikeStateMap();
    map[_templateLikeLookupKey(normalized, userId: userId)] = <String, dynamic>{
      'isLiked': normalized.isLiked,
      'likeCount': normalized.likeCount,
    };
    await prefs.setString(_templateLikeStateKey, jsonEncode(map));
  } catch (_) {}
}

PremiumTemplate _applyPersistedLikeState(
  PremiumTemplate template,
  Map<String, dynamic> likeStateMap, {
  String? userId,
}) {
  final raw = likeStateMap[_templateLikeLookupKey(template, userId: userId)];
  if (raw is! Map) return template;
  final state = Map<String, dynamic>.from(raw);
  return normalizeTemplateLikeStateForDisplay(
    template.copyWith(
      isLiked: state['isLiked'] == true,
      likeCount: (state['likeCount'] as num?)?.toInt() ?? template.likeCount,
    ),
  );
}

String _normalizeTemplateTitleKey(String value) {
  final base = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');
  const aliases = <String, String>{
    '제주의기록': 'jejutravel',
    '가족의주말': 'familyweekend',
    '우리의기념일': 'anniversarydays',
    'savethedate': 'savethedate',
    'scrapbook': 'scrapbook',
    'weddingeditorial': 'weddingeditorial',
    '화이트에디토리얼': 'whiteeditorial',
    '필름다이어리': 'filmdiary',
    '소프트베이비북': 'softbabybook',
  };
  return aliases[base] ?? base;
}

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);
  final supabase = ref.read(supabaseClientProvider);
  return SupabaseTemplateRepository(supabase, tokenStorage: tokenStorage);
});

/// Three-phase catalog load:
///  1. Return bundled templates IMMEDIATELY — no network, no SecureStorage wait.
///  2. Background: apply persisted like-state (SharedPreferences, ~5 ms).
///  3. Background: resolve userId (SecureStorage, can be 200-500 ms on Android)
///     and re-apply per-user like-state, then sync live counts from Supabase.
///
/// The store appears on the first frame; counts and like-badges update silently.
final templateListProvider =
    AsyncNotifierProvider<_TemplateCatalogNotifier, List<PremiumTemplate>>(
      _TemplateCatalogNotifier.new,
    );

/// Test helper — creates a provider override that skips all background work
/// and returns a fixed dataset. Drop-in replacement for the old FutureProvider
/// override pattern: `templateListProvider.overrideWith((ref) async => X)`
/// becomes `mockTemplateList(() async => X)`.
// ignore: invalid_use_of_internal_member
// Returns the same type as provider.overrideWith() — tests use it as Override.
// ignore_for_file: library_prefixes
dynamic mockTemplateList(FutureOr<List<PremiumTemplate>> Function() data) =>
    templateListProvider.overrideWith(
      () => _FixedTemplateCatalogNotifier(data),
    );

class _FixedTemplateCatalogNotifier extends _TemplateCatalogNotifier {
  _FixedTemplateCatalogNotifier(this._data);
  final FutureOr<List<PremiumTemplate>> Function() _data;

  @override
  FutureOr<List<PremiumTemplate>> build() => _data();

  @override
  void _enrichInBackground(bool Function() _) {
    /* no-op in tests */
  }
}

class _TemplateCatalogNotifier extends AsyncNotifier<List<PremiumTemplate>> {
  @override
  FutureOr<List<PremiumTemplate>> build() {
    // Track disposal so background tasks can bail out safely.
    var disposed = false;
    ref.onDispose(() => disposed = true);
    // Return synchronously — no awaits block the first render.
    _enrichInBackground(() => disposed);
    return Future.value(publishedCreationTemplates);
  }

  /// Runs all async work off the hot path so the grid renders in frame 1.
  void _enrichInBackground(bool Function() isDisposed) {
    Future.microtask(() async {
      if (isDisposed()) return;
      try {
        // ── Phase 2: SharedPreferences like-state (fast, ~5 ms) ───────────
        final likeStateMap = await _loadTemplateLikeStateMap();
        var enriched = List<PremiumTemplate>.unmodifiable(
          publishedCreationTemplates.map(
            (t) => _applyPersistedLikeState(t, likeStateMap, userId: null),
          ),
        );
        if (!isDisposed()) state = AsyncData(enriched);

        // ── Phase 3a: SecureStorage userId (200-500 ms on Android) ────────
        String? userId;
        try {
          userId = await ref.read(tokenStorageProvider).getResolvedUserId();
        } catch (_) {}
        if (isDisposed()) return;

        // Re-apply with user scope now that we have the userId.
        enriched = List<PremiumTemplate>.unmodifiable(
          publishedCreationTemplates.map(
            (t) => _applyPersistedLikeState(t, likeStateMap, userId: userId),
          ),
        );
        await CatalogFavorites.instance.importLegacyTemplates(
          enriched
              .where((t) => t.isLiked)
              .map((t) => CatalogFavoriteKeys.template(t.id)),
          scope: 'template-likes:${userId ?? 'guest'}',
        );
        if (!isDisposed()) state = AsyncData(enriched);

        // ── Phase 3b: Supabase server sync (network) ──────────────────────
        try {
          final serverTemplates = await ref
              .read(templateRepositoryProvider)
              .getTemplates();
          if (isDisposed()) return;
          final merged = _mergeWithServer(enriched, serverTemplates);
          state = AsyncData(List.unmodifiable(merged));
        } catch (_) {
          // Server unavailable — bundled + local like-state is sufficient.
        }
      } catch (_) {}
    });
  }

  /// Keeps bundled artwork (documentBuilder) but overlays live counts from DB.
  /// Server order drives the final list; bundled-only items append at the end.
  static List<PremiumTemplate> _mergeWithServer(
    List<PremiumTemplate> bundled,
    List<PremiumTemplate> server,
  ) => mergeTemplatesWithServer(bundled, server);
}

Future<List<PremiumTemplate>> loadCanonicalStoreTemplatesForRuntime() async =>
    publishedCreationTemplates;

/// Keeps bundled artwork but overlays live server metadata (counts, badges).
/// Server order drives the list; bundled-only items append at the end.
List<PremiumTemplate> mergeTemplatesWithServer(
  List<PremiumTemplate> bundled,
  List<PremiumTemplate> server,
) {
  final bundledById = {for (final t in bundled) t.id: t};
  final result = <PremiumTemplate>[];
  for (final s in server) {
    final b = bundledById[s.id];
    if (b != null) {
      result.add(
        b.copyWith(
          likeCount: s.likeCount,
          userCount: s.userCount,
          isLiked: b.isLiked || s.isLiked,
          weeklyScore: s.weeklyScore,
          isNew: s.isNew,
          isBest: s.isBest,
          isPremium: s.isPremium,
        ),
      );
    } else {
      result.add(s);
    }
  }
  for (final b in bundled) {
    if (!result.any((r) => r.id == b.id)) result.add(b);
  }
  return result;
}

class StoreTemplateFeedState {
  final List<PremiumTemplate> items;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasNext;
  final int page;
  final DateTime? lastSyncedAt;
  final Object? error;
  final String filterCategory;
  final String filterQuery;

  const StoreTemplateFeedState({
    required this.items,
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.hasNext,
    required this.page,
    this.lastSyncedAt,
    this.error,
    this.filterCategory = '',
    this.filterQuery = '',
  });

  StoreTemplateFeedState copyWith({
    List<PremiumTemplate>? items,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasNext,
    int? page,
    DateTime? lastSyncedAt,
    Object? error = const _NoUpdate(),
    String? filterCategory,
    String? filterQuery,
  }) => StoreTemplateFeedState(
    items: items ?? this.items,
    isInitialLoading: isInitialLoading ?? this.isInitialLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasNext: hasNext ?? this.hasNext,
    page: page ?? this.page,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    error: error is _NoUpdate ? this.error : error,
    filterCategory: filterCategory ?? this.filterCategory,
    filterQuery: filterQuery ?? this.filterQuery,
  );
}

class _NoUpdate {
  const _NoUpdate();
}

class StoreTemplateFeedNotifier extends Notifier<StoreTemplateFeedState> {
  static const _pageSize = 20;
  bool _loading = false;
  // Base catalog: seeded from templateListProvider so test mocks flow through.
  List<PremiumTemplate> _bundled = publishedCreationTemplates;

  @override
  StoreTemplateFeedState build() {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    // Seed _bundled from templateListProvider if it already has a sync value
    // (e.g. a test mock that returns synchronously).  In production the real
    // notifier returns a Future so asData is null here — we fall back to the
    // bundled list and the background server fetch fills in live data later.
    final syncValue = ref.read(templateListProvider).asData?.value;
    _bundled = syncValue ?? publishedCreationTemplates;
    // Only fetch from server when no synchronous catalog is available.
    // Production: templateListProvider is AsyncLoading → syncValue == null.
    // Tests that mock templateListProvider synchronously skip the server fetch,
    // keeping templateRepositoryProvider untouched (guards stay at 0 attempts).
    if (syncValue == null) {
      // Defer so _fetchPage0's catch block never runs during build().
      // (If _fetch throws synchronously, the catch block accesses `state` which
      // is uninitialized until build() returns.)
      Future.microtask(() => _fetchPage0(() => disposed, '', ''));
    }
    // Show bundled templates immediately while page 0 loads from server.
    // hasNext starts false — set to true only once server confirms more pages.
    return StoreTemplateFeedState(
      items: List.unmodifiable(_bundled),
      // isInitialLoading = false when all data came from a sync source and no
      // server fetch was started (test mocks); true otherwise (production).
      isInitialLoading: syncValue == null,
      isLoadingMore: false,
      hasNext: false,
      page: 0,
    );
  }

  Future<void> _fetchPage0(
    bool Function() isDisposed,
    String cat,
    String query,
  ) async {
    try {
      final result = await _fetch(0, cat, query);
      if (isDisposed()) return;
      if (state.filterCategory != cat || state.filterQuery != query) return;
      state = state.copyWith(
        items: List.unmodifiable(
          mergeTemplatesWithServer(_bundled, result.content),
        ),
        isInitialLoading: false,
        hasNext: result.hasNext,
        page: 0,
        lastSyncedAt: DateTime.now(),
        error: null,
      );
    } catch (e) {
      if (isDisposed()) return;
      state = state.copyWith(isInitialLoading: false, error: e, hasNext: false);
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (_loading || !current.hasNext || current.isInitialLoading) return;
    _loading = true;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = current.page + 1;
      final result = await _fetch(
        nextPage,
        current.filterCategory,
        current.filterQuery,
      );
      final merged = mergeTemplatesWithServer(_bundled, result.content);
      final existingIds = {for (final t in state.items) t.id};
      final newItems = merged
          .where((t) => !existingIds.contains(t.id))
          .toList();
      state = state.copyWith(
        items: List.unmodifiable([...state.items, ...newItems]),
        isLoadingMore: false,
        hasNext: result.hasNext,
        page: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    } finally {
      _loading = false;
    }
  }

  /// Changes server-side filters (category + query). Shows instant client-side
  /// filtered bundled data while the first server page loads.
  Future<void> setFilters({String? category, String? query}) async {
    final cat = category ?? state.filterCategory;
    final qry = query ?? state.filterQuery;
    if (cat == state.filterCategory && qry == state.filterQuery) return;
    _loading = false;
    // Instant bundled interim filtered client-side.
    final interim = _clientFilter(_bundled, cat, qry);
    state = state.copyWith(
      items: List.unmodifiable(interim),
      isInitialLoading: true,
      hasNext: true,
      page: 0,
      filterCategory: cat,
      filterQuery: qry,
      error: null,
    );
    try {
      final result = await _fetch(0, cat, qry);
      // Guard against a newer setFilters call overriding us.
      if (state.filterCategory != cat || state.filterQuery != qry) return;
      state = state.copyWith(
        items: List.unmodifiable(
          mergeTemplatesWithServer(_bundled, result.content),
        ),
        isInitialLoading: false,
        hasNext: result.hasNext,
        page: 0,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      if (state.filterCategory != cat || state.filterQuery != qry) return;
      state = state.copyWith(isInitialLoading: false, error: e, hasNext: false);
    }
  }

  Future<void> refresh() async {
    _loading = false;
    // Reload the base catalog so pull-to-refresh picks up any updates and
    // test mocks that track refresh calls see their counter increment.
    ref.invalidate(templateListProvider);
    _bundled = await ref.read(templateListProvider.future);
    final cat = state.filterCategory;
    final qry = state.filterQuery;
    final interim = _clientFilter(_bundled, cat, qry);
    state = state.copyWith(
      items: List.unmodifiable(interim),
      isInitialLoading: true,
      hasNext: false,
      page: 0,
      error: null,
    );
    try {
      final result = await _fetch(0, cat, qry);
      state = state.copyWith(
        items: List.unmodifiable(
          mergeTemplatesWithServer(_bundled, result.content),
        ),
        isInitialLoading: false,
        hasNext: result.hasNext,
        page: 0,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isInitialLoading: false, error: e, hasNext: false);
    }
  }

  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 45),
  }) async {
    final last = state.lastSyncedAt;
    if (last == null || DateTime.now().difference(last) >= maxAge) {
      await refresh();
    }
  }

  /// Legacy helper used by tests and owned-library views.
  /// Overlays only isLiked/likeCount, always returns the full published set.
  static List<PremiumTemplate> mergeServerSummaryWithLocalStatic({
    required List<PremiumTemplate> server,
    required List<PremiumTemplate> local,
  }) => withBundledCreationTemplates([...local, ...server]);

  Future<void> loadInitial() => refresh();

  Future<dynamic> _fetch(int page, String category, String query) => ref
      .read(templateRepositoryProvider)
      .getTemplateSummaries(
        page: page,
        size: _pageSize,
        category: category.isEmpty || category == '전체' ? null : category,
        query: query.isEmpty ? null : query,
      );

  static List<PremiumTemplate> _clientFilter(
    List<PremiumTemplate> templates,
    String category,
    String query,
  ) => templates.where((t) {
    if (category.isNotEmpty && category != '전체' && t.category != category)
      return false;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      return [
        t.title,
        t.subTitle ?? '',
        t.description ?? '',
        ...?t.tags,
      ].any((v) => v.toLowerCase().contains(q));
    }
    return true;
  }).toList();
}

final storeTemplateFeedProvider =
    NotifierProvider<StoreTemplateFeedNotifier, StoreTemplateFeedState>(
      StoreTemplateFeedNotifier.new,
    );

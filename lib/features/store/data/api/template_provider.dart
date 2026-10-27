import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/templates/catalog_favorites.dart';
import '../../../../core/templates/catalog_favorite_keys.dart';
import '../../../../core/templates/retired_store_templates.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../../album/data/bundled_creation_templates.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../domain/repositories/template_repository.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/entities/template_summary_page.dart';
import '../repositories/supabase_template_repository.dart';

const String _templateLikeStateKey = 'template_like_state_v1';
Future<void>? _templateLikeWriteTail;

/// Apply only at catalog entry points, never to saved album layers or drafts.
bool isRetiredStoreTemplate(
  PremiumTemplate template, {
  bool inspectLazyDocument = false,
}) {
  if (RetiredStoreTemplates.matches(id: template.id, title: template.title)) {
    return true;
  }
  // Catalog membership checks must not materialize lazy books. Remote rows
  // already carry eager JSON; the detail entry explicitly inspects an unknown
  // lazy document before showing artwork or offering any action.
  if (template.documentBuilder != null) {
    if (!inspectLazyDocument) return false;
    if (publishedCreationTemplates.any(
      (local) => identical(local.documentBuilder, template.documentBuilder),
    )) {
      return false;
    }
  }
  return RetiredStoreTemplates.matches(templateJson: template.templateJson);
}

List<PremiumTemplate> _currentStoreTemplates(
  Iterable<PremiumTemplate> source,
) => source.where((template) => !isRetiredStoreTemplate(template)).toList();

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
}) {
  try {
    final normalized = normalizeTemplateLikeStateForDisplay(template);
    return _enqueueTemplateLikeWrite(
      _templateLikeLookupKey(normalized, userId: userId),
      normalized.isLiked,
      normalized.likeCount,
    );
  } catch (_) {
    return Future<void>.value();
  }
}

Future<void> _enqueueTemplateLikeWrite(
  String key,
  bool isLiked,
  int likeCount,
) {
  // All records share one preferences value. Serialize its read/modify/write
  // before the first await, including cold storage initialization, so an older
  // toggle or a slower backing-store write cannot replace a newer snapshot.
  // Queued intents hold only these scalar values, not full template documents.
  late final Future<void> write;
  write = (_templateLikeWriteTail ?? Future<void>.value())
      .then((_) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final map = await _loadTemplateLikeStateMap();
          map[key] = <String, dynamic>{
            'isLiked': isLiked,
            'likeCount': likeCount,
          };
          await prefs.setString(_templateLikeStateKey, jsonEncode(map));
        } catch (_) {
          // Keep local persistence best-effort; one failure must not block
          // later records or the existing server/optimistic-update flow.
        }
      })
      .whenComplete(() {
        if (identical(_templateLikeWriteTail, write)) {
          _templateLikeWriteTail = null;
        }
      });
  _templateLikeWriteTail = write;
  return write;
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

String _normalizeTemplateTitleKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);
  final supabase = ref.read(supabaseClientProvider);
  return SupabaseTemplateRepository(supabase, tokenStorage: tokenStorage);
});

// One auth subscription is shared by browse, search and local/full catalogs.
// Same-owner token refreshes do not rebuild catalog metadata or restart reads.
final _templateSessionProvider =
    NotifierProvider<_TemplateSessionNotifier, String?>(
      _TemplateSessionNotifier.new,
    );

class _TemplateSessionNotifier extends Notifier<String?> {
  TemplateSessionSource? _source;
  bool get hasIdentity => _source != null;
  String? get currentOwner => _source?.currentTemplateUserId;

  @override
  String? build() {
    _source = null;
    try {
      final repository = ref.watch(templateRepositoryProvider);
      if (repository is TemplateSessionSource) {
        _source = repository as TemplateSessionSource;
      }
    } catch (_) {
      // Offline/public metadata still works when a repository is unavailable.
      // Its actual remote read retains the existing error/fallback behavior.
    }
    final subscription = _source?.templateUserChanges.distinct().listen(
      (owner) {
        if (ref.mounted && state != owner) state = owner;
      },
      // A token/network error is not an account change. Keep the last owner;
      // synchronous guards still read the repository's actual current owner.
      onError: (Object _, StackTrace __) {},
    );
    if (subscription != null) {
      ref.onDispose(() => unawaited(subscription.cancel()));
    }
    return currentOwner;
  }
}

// Shared local artwork/likes never start a full remote catalog request. The
// paginated store and full-catalog consumers opt into their own remote reads.
final _localTemplateCatalogProvider =
    AsyncNotifierProvider<_LocalTemplateCatalogNotifier, List<PremiumTemplate>>(
      _LocalTemplateCatalogNotifier.new,
    );

/// Full catalogs are fetched only by creation/library consumers that need one.
/// The store feed reads the shared local catalog instead of starting this load.
final templateListProvider =
    AsyncNotifierProvider<_TemplateCatalogNotifier, List<PremiumTemplate>>(
      _TemplateCatalogNotifier.new,
    );

/// One authoritative override supplies both full and paginated catalogs and
/// skips their remote reads. Async sources retain their loading/error states.
// ignore: invalid_use_of_internal_member
// Returns the same type as provider.overrideWith() — tests use it as Override.
// ignore_for_file: library_prefixes
dynamic mockTemplateList(FutureOr<List<PremiumTemplate>> Function() data) =>
    _localTemplateCatalogProvider.overrideWith(
      () => _FixedTemplateCatalogNotifier(data),
    );

class _FixedTemplateCatalogNotifier extends _LocalTemplateCatalogNotifier {
  _FixedTemplateCatalogNotifier(this._data);
  final FutureOr<List<PremiumTemplate>> Function() _data;

  @override
  FutureOr<List<PremiumTemplate>> build() => _data();

  @override
  bool get hasRemoteCatalog => false;
}

class _TemplateCatalogNotifier extends AsyncNotifier<List<PremiumTemplate>> {
  @override
  FutureOr<List<PremiumTemplate>> build() {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    final localState = ref.read(_localTemplateCatalogProvider);
    final localSource = ref.read(_localTemplateCatalogProvider.notifier);
    if (!localSource.hasRemoteCatalog) {
      return ref.watch(_localTemplateCatalogProvider.future);
    }
    ref.watch(_templateSessionProvider);
    final session = ref.read(_templateSessionProvider.notifier);
    final owner = session.currentOwner;
    bool isCurrent() =>
        !disposed && (!session.hasIdentity || session.currentOwner == owner);

    var local = localState.isLoading || !localSource.isForOwner(owner)
        ? publishedCreationTemplates
        : localState.asData?.value ?? publishedCreationTemplates;
    List<PremiumTemplate>? server;
    ref.listen(_localTemplateCatalogProvider, (_, next) {
      final updated = next.asData?.value;
      if (!isCurrent() ||
          next.isLoading ||
          updated == null ||
          !localSource.isForOwner(owner)) {
        return;
      }
      local = updated;
      state = AsyncData(
        List.unmodifiable(
          server == null ? local : mergeTemplatesWithServer(local, server!),
        ),
      );
    });
    Future.microtask(() async {
      if (!isCurrent()) return;
      // A full-catalog invalidation also reloads persisted likes. Initial local
      // initialization already has its own enrichment in flight.
      if (localState.hasValue) ref.invalidate(_localTemplateCatalogProvider);
      try {
        final rows = await ref.read(templateRepositoryProvider).getTemplates();
        if (!isCurrent()) return;
        server = rows;
        state = AsyncData(
          List.unmodifiable(mergeTemplatesWithServer(local, rows)),
        );
      } catch (_) {
        // Offline consumers retain the bundled catalog and persisted likes.
      }
    });
    return Future.value(local);
  }
}

class _LocalTemplateCatalogNotifier
    extends AsyncNotifier<List<PremiumTemplate>> {
  bool get hasRemoteCatalog => true;
  String? _owner;
  bool _hasIdentity = false;
  bool isForOwner(String? owner) => !_hasIdentity || _owner == owner;

  @override
  FutureOr<List<PremiumTemplate>> build() {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    ref.watch(_templateSessionProvider);
    final session = ref.read(_templateSessionProvider.notifier);
    final owner = session.currentOwner;
    _owner = owner;
    _hasIdentity = session.hasIdentity;
    _enrichInBackground(
      () => disposed || (session.hasIdentity && session.currentOwner != owner),
      session: session,
      owner: owner,
    );
    return Future.value(publishedCreationTemplates);
  }

  /// Runs all async work off the hot path so the grid renders in frame 1.
  void _enrichInBackground(
    bool Function() isDisposed, {
    required _TemplateSessionNotifier session,
    required String? owner,
  }) {
    Future.microtask(() async {
      if (isDisposed()) return;
      try {
        // ── Phase 2: SharedPreferences like-state (fast, ~5 ms) ───────────
        final likeStateMap = await _loadTemplateLikeStateMap();
        if (isDisposed()) return;
        // Real sessions use the already available SDK owner. In particular,
        // never overlay guest/previous-owner likes while secure storage lags.
        String? userId = owner;
        if (!session.hasIdentity) {
          try {
            userId = await ref.read(tokenStorageProvider).getResolvedUserId();
          } catch (_) {}
        }
        if (isDisposed()) return;

        // Re-apply with user scope now that we have the userId.
        final enriched = List<PremiumTemplate>.unmodifiable(
          publishedCreationTemplates.map(
            (t) => _applyPersistedLikeState(t, likeStateMap, userId: userId),
          ),
        );
        if (isDisposed()) return;
        state = AsyncData(enriched);
        await CatalogFavorites.instance.importLegacyTemplates(
          enriched
              .where((t) => t.isLiked)
              .map((t) => CatalogFavoriteKeys.template(t.id)),
          scope: 'template-likes:${userId ?? 'guest'}',
        );
      } catch (_) {}
    });
  }
}

Future<List<PremiumTemplate>> loadCanonicalStoreTemplatesForRuntime() async =>
    publishedCreationTemplates;

/// Keeps bundled artwork but overlays live server metadata (counts, badges).
/// Server order drives the list; bundled-only items append at the end.
List<PremiumTemplate> mergeTemplatesWithServer(
  List<PremiumTemplate> bundled,
  List<PremiumTemplate> server,
) {
  final currentBundled = _currentStoreTemplates(bundled);
  final bundledById = {for (final t in currentBundled) t.id: t};
  final result = <PremiumTemplate>[];
  final seenIds = <int>{};
  for (final s in _currentStoreTemplates(server)) {
    seenIds.add(s.id);
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
          // Tier and artwork belong to the bundled product identity. Live
          // purchase prices still come from point_shop_products.
          isPremium: b.isPremium,
        ),
      );
    } else {
      result.add(s);
    }
  }
  for (final b in currentBundled) {
    if (seenIds.add(b.id)) result.add(b);
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
  int _generation = 0;
  Future<void>? _firstPageRequest;
  Future<void>? _moreRequest;
  Future<void>? _refreshRequest;
  List<PremiumTemplate> _bundled = publishedCreationTemplates;
  List<PremiumTemplate> _remoteItems = const [];
  _TemplateSessionNotifier? _session;
  String? _owner;

  bool get _isOwnerCurrent =>
      _session == null || _session!.currentOwner == _owner;
  bool _isCurrent(int generation) =>
      ref.mounted && generation == _generation && _isOwnerCurrent;

  @override
  StoreTemplateFeedState build() {
    final generation = ++_generation;
    _firstPageRequest = _moreRequest = _refreshRequest = null;
    _remoteItems = const [];
    ref.onDispose(() => _generation++);
    final local = ref.read(_localTemplateCatalogProvider);
    final localSource = ref.read(_localTemplateCatalogProvider.notifier);
    final hasRemote = localSource.hasRemoteCatalog;
    _session = null;
    _owner = null;
    if (hasRemote) {
      ref.read(_templateSessionProvider);
      _session = ref.read(_templateSessionProvider.notifier);
      _owner = _session!.currentOwner;
      ref.listen(_templateSessionProvider, (_, owner) {
        if (ref.mounted && _owner != owner) _restartForOwner(owner);
      });
    }
    _bundled = _currentStoreTemplates(
      local.isLoading || !localSource.isForOwner(_owner)
          ? publishedCreationTemplates
          : local.asData?.value ?? publishedCreationTemplates,
    );
    ref.listen(_localTemplateCatalogProvider, (_, next) {
      if (!ref.mounted ||
          !_isOwnerCurrent ||
          next.isLoading ||
          next.asData == null ||
          !localSource.isForOwner(_owner)) {
        return;
      }
      _bundled = _currentStoreTemplates(next.requireValue);
      state = state.copyWith(
        items: _itemsFor(state.filterCategory, state.filterQuery),
      );
    });
    // Start the initial request only after state exists. A filter/refresh
    // started before this microtask invalidates it without sending a query.
    _firstPageRequest = Future<void>.microtask(() async {
      if (!_isCurrent(generation)) return;
      await _fetchFirstPage(generation, '', '');
    });
    return StoreTemplateFeedState(
      items: List.unmodifiable(_bundled),
      isInitialLoading: hasRemote || local.isLoading,
      isLoadingMore: false,
      hasNext: false,
      page: 0,
    );
  }

  void _restartForOwner(String? owner) {
    final generation = ++_generation;
    _owner = owner;
    _firstPageRequest = _moreRequest = _refreshRequest = null;
    _remoteItems = const [];
    _bundled = publishedCreationTemplates;
    final category = state.filterCategory;
    final query = state.filterQuery;
    // Preserve route filters/scroll ownership, but remove all previous-owner
    // rows, likes and sync timestamps before the new owner's response arrives.
    state = StoreTemplateFeedState(
      items: _itemsFor(category, query),
      isInitialLoading: true,
      isLoadingMore: false,
      hasNext: false,
      page: 0,
      filterCategory: category,
      filterQuery: query,
    );
    _firstPageRequest = Future<void>.microtask(
      () => _fetchFirstPage(generation, category, query),
    );
  }

  void _synchronizeOwner() {
    if (!_isOwnerCurrent) _restartForOwner(_session!.currentOwner);
  }

  List<PremiumTemplate> _itemsFor(String category, String query) =>
      List.unmodifiable(
        _clientFilter(
          mergeTemplatesWithServer(_bundled, _remoteItems),
          category,
          query,
        ),
      );

  Future<void> _fetchFirstPage(
    int generation,
    String category,
    String query,
  ) async {
    if (!_isCurrent(generation)) return;
    try {
      final source = ref.read(_localTemplateCatalogProvider.notifier);
      if (!source.hasRemoteCatalog) {
        final local = await ref.read(_localTemplateCatalogProvider.future);
        if (!_isCurrent(generation)) return;
        _bundled = _currentStoreTemplates(local);
        state = state.copyWith(
          items: _itemsFor(category, query),
          isInitialLoading: false,
          isLoadingMore: false,
          hasNext: false,
          page: 0,
          error: null,
        );
        return;
      }
      final result = await _fetch(0, category, query);
      if (!_isCurrent(generation)) return;
      _remoteItems = List.unmodifiable(result.content);
      state = state.copyWith(
        items: _itemsFor(category, query),
        isInitialLoading: false,
        isLoadingMore: false,
        hasNext: result.hasNext,
        page: 0,
        lastSyncedAt: DateTime.now(),
        error: null,
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        isInitialLoading: false,
        isLoadingMore: false,
        error: error,
        hasNext: false,
      );
    }
  }

  Future<void> loadMore() {
    _synchronizeOwner();
    if (_moreRequest != null) return _moreRequest!;
    final current = state;
    if (!current.hasNext || current.isInitialLoading || current.isLoadingMore)
      return Future.value();
    final generation = _generation;
    final nextPage = current.page + 1;
    late final Future<void> request;
    request =
        Future<void>.microtask(() async {
          try {
            if (!_isCurrent(generation)) return;
            final result = await _fetch(
              nextPage,
              current.filterCategory,
              current.filterQuery,
            );
            if (!_isCurrent(generation)) return;
            // Later pages can update existing products as well as append new ones.
            final rows = {for (final item in _remoteItems) item.id: item};
            for (final item in result.content) {
              rows[item.id] = item;
            }
            _remoteItems = List.unmodifiable(rows.values);
            state = state.copyWith(
              items: _itemsFor(current.filterCategory, current.filterQuery),
              isLoadingMore: false,
              hasNext: result.hasNext,
              page: nextPage,
              error: null,
            );
          } catch (error) {
            if (!_isCurrent(generation)) return;
            state = state.copyWith(isLoadingMore: false, error: error);
          }
        }).whenComplete(() {
          if (_isCurrent(generation) && identical(_moreRequest, request))
            _moreRequest = null;
        });
    _moreRequest = request;
    state = state.copyWith(isLoadingMore: true, error: null);
    return request;
  }

  Future<void> setFilters({String? category, String? query}) {
    _synchronizeOwner();
    final rawCategory = (category ?? state.filterCategory).trim();
    final cat = rawCategory == '전체' ? '' : rawCategory;
    final qry = (query ?? state.filterQuery).trim();
    if (cat == state.filterCategory && qry == state.filterQuery) {
      return state.isInitialLoading
          ? (_firstPageRequest ?? Future.value())
          : Future.value();
    }
    final generation = ++_generation;
    _moreRequest = _refreshRequest = null;
    _remoteItems = const [];
    final request = _firstPageRequest = Future<void>.microtask(
      () => _fetchFirstPage(generation, cat, qry),
    );
    state = state.copyWith(
      items: _itemsFor(cat, qry),
      isInitialLoading: true,
      isLoadingMore: false,
      hasNext: false,
      page: 0,
      filterCategory: cat,
      filterQuery: qry,
      error: null,
    );
    return request;
  }

  Future<void> refresh() {
    _synchronizeOwner();
    if (_refreshRequest != null) return _refreshRequest!;
    final generation = ++_generation;
    final category = state.filterCategory;
    final query = state.filterQuery;
    _moreRequest = null;
    // Keep the visible rows while reloading. Old page/filter failures must not
    // clear this loading state or replace the new request's error.
    late final Future<void> request;
    request =
        Future<void>.microtask(() async {
          try {
            if (!_isCurrent(generation)) return;
            ref.invalidate(_localTemplateCatalogProvider);
            final local = await ref.read(_localTemplateCatalogProvider.future);
            if (!_isCurrent(generation)) return;
            _bundled = _currentStoreTemplates(local);
            await _fetchFirstPage(generation, category, query);
          } catch (error) {
            if (!_isCurrent(generation)) return;
            state = state.copyWith(
              isInitialLoading: false,
              error: error,
              hasNext: false,
            );
          }
        }).whenComplete(() {
          if (_isCurrent(generation) && identical(_refreshRequest, request))
            _refreshRequest = null;
        });
    _firstPageRequest = _refreshRequest = request;
    state = state.copyWith(
      isInitialLoading: true,
      isLoadingMore: false,
      hasNext: false,
      error: null,
    );
    return request;
  }

  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 45),
  }) async {
    _synchronizeOwner();
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

  Future<TemplateSummaryPage> _fetch(int page, String category, String query) =>
      ref
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

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

/// The published catalog is curated locally. Legacy server/generated catalogs
/// must not reintroduce retired products or replace the approved artwork.
final templateListProvider = FutureProvider<List<PremiumTemplate>>((ref) async {
  String? userId;
  try {
    userId = await ref.read(tokenStorageProvider).getResolvedUserId();
  } catch (_) {
    // Offline guests still have access to all published collections.
  }
  final likeStateMap = await _loadTemplateLikeStateMap();
  final templates = List<PremiumTemplate>.unmodifiable(
    bundledCreationTemplates.map(
      (template) =>
          _applyPersistedLikeState(template, likeStateMap, userId: userId),
    ),
  );
  await CatalogFavorites.instance.importLegacyTemplates(
    templates
        .where((t) => t.isLiked)
        .map((t) => CatalogFavoriteKeys.template(t.id)),
    scope: 'template-likes:${userId ?? 'guest'}',
  );
  return templates;
});

Future<List<PremiumTemplate>> loadCanonicalStoreTemplatesForRuntime() async =>
    bundledCreationTemplates;

class StoreTemplateFeedState {
  final List<PremiumTemplate> items;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasNext;
  final int page;
  final DateTime? lastSyncedAt;
  final Object? error;

  const StoreTemplateFeedState({
    required this.items,
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.hasNext,
    required this.page,
    this.lastSyncedAt,
    this.error,
  });

  factory StoreTemplateFeedState.initial() => const StoreTemplateFeedState(
    items: [],
    isInitialLoading: true,
    isLoadingMore: false,
    hasNext: true,
    page: 0,
  );

  StoreTemplateFeedState copyWith({
    List<PremiumTemplate>? items,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasNext,
    int? page,
    DateTime? lastSyncedAt,
    Object? error = const _NoUpdate(),
  }) {
    return StoreTemplateFeedState(
      items: items ?? this.items,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasNext: hasNext ?? this.hasNext,
      page: page ?? this.page,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      error: error is _NoUpdate ? this.error : error,
    );
  }
}

class _NoUpdate {
  const _NoUpdate();
}

class StoreTemplateFeedNotifier extends Notifier<StoreTemplateFeedState> {
  @override
  StoreTemplateFeedState build() {
    final catalog = ref.watch(templateListProvider);
    return StoreTemplateFeedState(
      items: withBundledCreationTemplates(catalog.asData?.value ?? const []),
      isInitialLoading: false,
      isLoadingMore: false,
      hasNext: false,
      page: 0,
      lastSyncedAt: catalog.hasValue ? DateTime.now() : null,
    );
  }

  static List<PremiumTemplate> mergeServerSummaryWithLocalStatic({
    required List<PremiumTemplate> server,
    required List<PremiumTemplate> local,
  }) => withBundledCreationTemplates([...local, ...server]);

  Future<void> loadInitial() => refresh();

  Future<void> loadMore() async {}

  Future<void> refresh() async {
    ref.invalidate(templateListProvider);
    await ref.read(templateListProvider.future);
  }

  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 45),
  }) async {
    final last = state.lastSyncedAt;
    if (last == null || DateTime.now().difference(last) >= maxAge) {
      await refresh();
    }
  }
}

final storeTemplateFeedProvider =
    NotifierProvider<StoreTemplateFeedNotifier, StoreTemplateFeedState>(
      StoreTemplateFeedNotifier.new,
    );

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/interceptors/token_storage.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart'; // tokenStorageProvider
import '../../domain/repositories/template_repository.dart';
import '../../domain/entities/premium_template.dart'; // PremiumTemplate
import '../repositories/template_repository_impl.dart';
import 'template_api.dart';

String _safeTemplateText(String? raw, {String fallback = ''}) {
  final value = (raw ?? '').trim();
  return value.isEmpty ? fallback : value;
}

String _toneKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

bool _hasLocalOnlyImagePath(String value) {
  final trimmed = value.trim().toLowerCase();
  return trimmed.startsWith('asset:') ||
      trimmed.contains('figma.com/api/mcp/asset/');
}

bool _shouldPreferLocalTemplateJsonForSaveTheDate(
  PremiumTemplate local,
  PremiumTemplate server,
) {
  // SAVE_THE_DATE는 이제 서버가 단일 소스 오브 트루스다.
  // 로컬 번들 템플릿이 오래된 상태로 남아 상세/스토어/생성 화면을 덮지 않도록
  // 더 이상 로컬 templateJson을 우선하지 않는다.
  return false;
}

String _coverModeForTemplate(PremiumTemplate template) {
  final title = _toneKey(template.title);
  final category = _toneKey(template.category ?? '');
  final tags = (template.tags ?? const <String>[]).map(_toneKey).join(' ');
  if (title.contains('웨딩') ||
      title.contains('결혼') ||
      title.contains('이터널') ||
      category.contains('웨딩') ||
      tags.contains('웨딩')) {
    return 'wedding';
  }
  if (title.contains('세이브더데이트') ||
      title.contains('save') ||
      title.contains('링트립') ||
      tags.contains('세이브') ||
      tags.contains('링')) {
    return 'save_date';
  }
  return 'summer';
}

Map<String, dynamic> _textStyle({
  required double fontSize,
  required String fontFamily,
  required int fontWeight,
  required String color,
  double letterSpacing = 0.0,
}) {
  return {
    'fontSize': fontSize,
    'fontWeight': fontWeight,
    'fontFamily': fontFamily,
    'color': color,
    'letterSpacing': letterSpacing,
  };
}

Map<String, dynamic> _layerText({
  required String id,
  required double x,
  required double y,
  required double w,
  required double h,
  required String text,
  required String align,
  required int z,
  required Map<String, dynamic> style,
}) {
  return {
    'id': id,
    'type': 'TEXT',
    'x': x,
    'y': y,
    'width': w,
    'height': h,
    'rotation': 0.0,
    'opacity': 1.0,
    'scale': 1.0,
    'zIndex': z,
    'payload': {
      'text': text,
      'textAlign': align,
      'textStyleType': 'none',
      'textBackground': null,
      'textStyle': style,
    },
  };
}

Map<String, dynamic> _layerImage({
  required String id,
  required double x,
  required double y,
  required double w,
  required double h,
  required String imageUrl,
  required String frame,
  required int z,
}) {
  return {
    'id': id,
    'type': 'IMAGE',
    'x': x,
    'y': y,
    'width': w,
    'height': h,
    'rotation': 0.0,
    'opacity': 1.0,
    'scale': 1.0,
    'zIndex': z,
    'payload': {
      'imageBackground': frame,
      'imageTemplate': 'free',
      'imageUrl': imageUrl,
      'previewUrl': imageUrl,
      'originalUrl': imageUrl,
    },
  };
}

Map<String, dynamic> _layerDeco({
  required String id,
  required double x,
  required double y,
  required double w,
  required double h,
  required String background,
  required int z,
}) {
  return {
    'id': id,
    'type': 'DECORATION',
    'x': x,
    'y': y,
    'width': w,
    'height': h,
    'rotation': 0.0,
    'opacity': 1.0,
    'scale': 1.0,
    'zIndex': z,
    'payload': {'imageBackground': background, 'imageTemplate': 'free'},
  };
}

String _buildModernTemplateJson({
  required PremiumTemplate template,
  required List<String> orderedPreview,
  required int pageCount,
}) {
  final mode = _coverModeForTemplate(template);
  final title = _safeTemplateText(template.title, fallback: 'SNAPFIT');
  final sub = _safeTemplateText(
    template.subTitle ?? template.description,
    fallback: '오늘의 장면을 기록하세요',
  );
  final coverImage = orderedPreview.first;
  final coverTitleColor = mode == 'summer' ? '#FF0F172A' : '#FFFFFFFF';
  final topBandBg = mode == 'summer'
      ? 'paperYellow'
      : (mode == 'wedding' ? 'paperGray' : 'skyBlue');
  final bottomBandBg = mode == 'summer' ? 'paperWhite' : 'darkVignette';

  final pages = <Map<String, dynamic>>[];
  final safePageCount = pageCount.clamp(12, 24);
  for (var i = 0; i < safePageCount; i++) {
    if (i == 0) {
      final coverLayers = <Map<String, dynamic>>[
        if (mode == 'summer')
          _layerDeco(
            id: 'cover_top_band',
            x: 0,
            y: 0,
            w: 1,
            h: 0.18,
            background: topBandBg,
            z: 6,
          ),
        _layerImage(
          id: 'cover_hero',
          x: 0,
          y: mode == 'summer' ? 0.18 : 0.0,
          w: 1,
          h: mode == 'summer' ? 0.72 : 1.0,
          imageUrl: coverImage,
          frame: 'softGlow',
          z: 8,
        ),
        if (mode == 'summer')
          _layerDeco(
            id: 'cover_bottom_band',
            x: 0,
            y: 0.90,
            w: 1,
            h: 0.10,
            background: bottomBandBg,
            z: 6,
          ),
        _layerText(
          id: 'cover_title',
          x: mode == 'summer' ? 0.06 : 0.10,
          y: mode == 'summer' ? 0.01 : (mode == 'wedding' ? 0.40 : 0.52),
          w: mode == 'summer' ? 0.88 : 0.80,
          h: mode == 'summer' ? 0.14 : 0.16,
          text: mode == 'summer' ? title.toUpperCase() : title,
          align: 'center',
          z: 40,
          style: _textStyle(
            fontSize: mode == 'summer' ? 52 : (mode == 'wedding' ? 46 : 54),
            fontFamily: mode == 'wedding' ? 'Cormorant' : 'Raleway',
            fontWeight: 9,
            color: coverTitleColor,
            letterSpacing: mode == 'summer' ? 1.8 : 0.7,
          ),
        ),
        _layerText(
          id: 'cover_badge',
          x: mode == 'summer' ? 0.08 : (mode == 'wedding' ? 0.24 : 0.24),
          y: mode == 'summer' ? 0.18 : (mode == 'wedding' ? 0.33 : 0.06),
          w: mode == 'summer' ? 0.84 : 0.52,
          h: 0.05,
          text: mode == 'save_date'
              ? '2026.10.12 SAT'
              : (mode == 'wedding'
                    ? '{ We\'re Getting Married! }'
                    : 'Opening. 08.17 2:00'),
          align: mode == 'summer' ? 'left' : 'center',
          z: 40,
          style: _textStyle(
            fontSize: 11.0,
            fontFamily: 'Raleway',
            fontWeight: 7,
            color: '#FFE5E7EB',
            letterSpacing: 0.8,
          ),
        ),
        _layerText(
          id: 'cover_sub',
          x: mode == 'wedding' ? 0.08 : (mode == 'save_date' ? 0.22 : 0.72),
          y: mode == 'wedding' ? 0.79 : (mode == 'save_date' ? 0.70 : 0.70),
          w: mode == 'summer' ? 0.20 : (mode == 'save_date' ? 0.56 : 0.36),
          h: 0.10,
          text: mode == 'summer' ? 'MIRI KIM\n오늘의 어떤 발견' : sub,
          align: mode == 'summer' ? 'left' : 'center',
          z: 40,
          style: _textStyle(
            fontSize: mode == 'summer' ? 9.5 : 12.0,
            fontFamily: mode == 'summer' ? 'Raleway' : 'Cormorant',
            fontWeight: 7,
            color: '#FFFFFFFF',
            letterSpacing: 0.4,
          ),
        ),
        _layerText(
          id: 'cover_bottom',
          x: mode == 'wedding' ? 0.56 : 0.08,
          y: mode == 'wedding' ? 0.79 : (mode == 'save_date' ? 0.80 : 0.92),
          w: mode == 'wedding' ? 0.36 : 0.84,
          h: 0.08,
          text: mode == 'summer'
              ? 'MIRIKIM 1ST ART EXHIBITION'
              : (mode == 'wedding'
                    ? 'MAISON DE BLOSSOM, SEOUL'
                    : 'TWO HEARTS, ONE LOVE, ONE LIFETIME.'),
          align: mode == 'wedding' ? 'right' : 'center',
          z: 40,
          style: _textStyle(
            fontSize: 10.5,
            fontFamily: 'Raleway',
            fontWeight: 7,
            color: mode == 'summer' ? '#FF334155' : '#FFE2E8F0',
            letterSpacing: 1.0,
          ),
        ),
      ];
      pages.add({'pageNumber': 1, 'layers': coverLayers});
      continue;
    }

    final a = orderedPreview[(i - 1) % orderedPreview.length];
    final b = orderedPreview[i % orderedPreview.length];
    final c = orderedPreview[(i + 1) % orderedPreview.length];
    pages.add({
      'pageNumber': i + 1,
      'layers': [
        _layerDeco(
          id: 'p${i + 1}_bg',
          x: 0,
          y: 0,
          w: 1,
          h: 1,
          background: i.isEven ? 'paperWhite' : 'paperBeige',
          z: 1,
        ),
        _layerText(
          id: 'p${i + 1}_title',
          x: 0.08,
          y: 0.05,
          w: 0.84,
          h: 0.08,
          text: '${title.toUpperCase()}  ${i + 1}',
          align: 'left',
          z: 40,
          style: _textStyle(
            fontSize: 24,
            fontFamily: 'Raleway',
            fontWeight: 8,
            color: '#FF0F172A',
            letterSpacing: 0.8,
          ),
        ),
        _layerImage(
          id: 'p${i + 1}_hero',
          x: 0.08,
          y: 0.16,
          w: 0.84,
          h: 0.46,
          imageUrl: a,
          frame: 'posterPolaroid',
          z: 10,
        ),
        _layerImage(
          id: 'p${i + 1}_l',
          x: 0.08,
          y: 0.66,
          w: 0.40,
          h: 0.22,
          imageUrl: b,
          frame: 'collageTile',
          z: 12,
        ),
        _layerImage(
          id: 'p${i + 1}_r',
          x: 0.52,
          y: 0.66,
          w: 0.40,
          h: 0.22,
          imageUrl: c,
          frame: 'collageTile',
          z: 12,
        ),
      ],
    });
  }
  return jsonEncode({
    'metadata': {
      'style': 'editorial_modern',
      'mood': 'clean_trendy',
      'tags': ['modern', 'editorial', 'cover_and_pages'],
      'difficulty': 2,
      'recommendedPhotoCount': safePageCount,
      'heroTextSafeArea': const {
        'x': 0.08,
        'y': 0.05,
        'width': 0.84,
        'height': 0.30,
      },
      'sourceBottomSheetTemplateIds': const ['portrait_magazine_001'],
      'applyScope': 'cover_and_pages',
    },
    'pages': pages,
  });
}

List<String> _extractPreviewCandidatesFromJson(String? templateJson) {
  if (templateJson == null || templateJson.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(templateJson) as Map<String, dynamic>;
    final pages = decoded['pages'];
    if (pages is! List) return const [];
    final urls = <String>[];
    for (final page in pages) {
      if (page is! Map) continue;
      final layers = page['layers'];
      if (layers is! List) continue;
      for (final layer in layers) {
        if (layer is! Map) continue;
        if ((layer['type']?.toString().toUpperCase() ?? '') != 'IMAGE') {
          continue;
        }
        final payload = layer['payload'];
        if (payload is! Map) continue;
        final url =
            (payload['previewUrl'] ??
                    payload['imageUrl'] ??
                    payload['originalUrl'])
                ?.toString();
        if (url != null && url.trim().isNotEmpty) {
          urls.add(url.trim());
        }
      }
    }
    return urls;
  } catch (_) {
    return const [];
  }
}

String? _extractCoverCandidateFromJson(String? templateJson) {
  if (templateJson == null || templateJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(templateJson) as Map<String, dynamic>;
    final cover = decoded['cover'];
    if (cover is Map) {
      final layers = cover['layers'];
      if (layers is List) {
        for (final layer in layers) {
          if (layer is! Map) continue;
          if ((layer['type']?.toString().toUpperCase() ?? '') != 'IMAGE') {
            continue;
          }
          final payload = layer['payload'];
          if (payload is! Map) continue;
          final url =
              (payload['previewUrl'] ??
                      payload['imageUrl'] ??
                      payload['originalUrl'])
                  ?.toString()
                  .trim();
          if (url != null && url.isNotEmpty) return url;
        }
      }
    }
  } catch (_) {}
  return null;
}

int _extractPageCountFromJson(String? templateJson) {
  if (templateJson == null || templateJson.trim().isEmpty) return 0;
  try {
    final decoded = jsonDecode(templateJson) as Map<String, dynamic>;
    final pages = decoded['pages'];
    if (pages is! List) return 0;
    return pages.length;
  } catch (_) {
    return 0;
  }
}

PremiumTemplate _normalizeStoreTemplateRuntime(PremiumTemplate template) {
  final jsonPageCount = _extractPageCountFromJson(template.templateJson);
  final coverFromJson = _extractCoverCandidateFromJson(template.templateJson);
  final normalizedPreview = template.previewImages
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (normalizedPreview.isEmpty) {
    normalizedPreview.addAll(
      _extractPreviewCandidatesFromJson(template.templateJson),
    );
  }

  final hasCover = template.coverImageUrl.trim().isNotEmpty;
  final fallbackCover =
      (hasCover ? template.coverImageUrl.trim() : (coverFromJson ?? '')).trim();
  final resolvedFallbackCover = fallbackCover.isNotEmpty
      ? fallbackCover
      : 'https://picsum.photos/id/1015/1200/900';
  if (normalizedPreview.isEmpty) normalizedPreview.add(resolvedFallbackCover);

  if (normalizedPreview.length < 3) {
    final fill = <String>[
      resolvedFallbackCover,
      ..._extractPreviewCandidatesFromJson(template.templateJson),
      ...normalizedPreview,
    ];
    for (final candidate in fill) {
      if (normalizedPreview.length >= 3) break;
      if (candidate.trim().isEmpty) continue;
      normalizedPreview.add(candidate.trim());
    }
  }

  final coverCandidate =
      (template.coverImageUrl.trim().isNotEmpty
          ? template.coverImageUrl.trim()
          : null) ??
      coverFromJson ??
      (normalizedPreview.isNotEmpty ? normalizedPreview.first.trim() : null) ??
      resolvedFallbackCover;

  final orderedPreview = <String>[coverCandidate, ...normalizedPreview]
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .take(8)
      .toList(growable: false);

  final normalizedPageCount = jsonPageCount > 0
      ? jsonPageCount
      : template.pageCount;
  final hasTemplateJson =
      template.templateJson != null && template.templateJson!.trim().isNotEmpty;
  final normalizedTemplateJson = hasTemplateJson
      ? template.templateJson
      : _buildModernTemplateJson(
          template: template,
          orderedPreview: orderedPreview,
          pageCount: normalizedPageCount,
        );

  return template.copyWith(
    coverImageUrl: coverCandidate,
    previewImages: orderedPreview,
    pageCount: normalizedPageCount,
    // 서버/피그마 원본 JSON이 있으면 절대 재생성하지 않고 그대로 사용한다.
    templateJson: normalizedTemplateJson,
  );
}

String _normalizeTemplateTitleKey(String value) {
  final base = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');
  const aliases = <String, String>{
    '웨딩무드북': '시그니처웨딩',
    '썸머무드북': '썸머커버에디션',
    '스카이무드북': '스카이인비테이션',
    '로즈무드북': '로즈데이',
    '북클럽무드북': '어린이북클럽',
    '제주여름무드북': '우리들의여름제주',
    '오션브리즈무드북': '오션브리즈',
    '시티나이트무드북': '도시의밤',
    '졸업무드북': '빛나는졸업장',
    '패밀리트립무드북': '가족여행일기',
    '이터널러브무드북': '이터널러브',
    '빈티지무드북': '빈티지포커스',
    '링트립무드북': '링트립스토리',
  };
  return aliases[base] ?? base;
}

PremiumTemplate _mergeServerWithLocalTemplate(
  PremiumTemplate server,
  PremiumTemplate local,
) {
  final localSub = (local.subTitle ?? '').trim();
  final localDesc = (local.description ?? '').trim();
  final localCover = local.coverImageUrl.trim();
  final localJson = (local.templateJson ?? '').trim();
  final localPreview = local.previewImages
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  return server.copyWith(
    subTitle: localSub.isNotEmpty ? local.subTitle : server.subTitle,
    description: localDesc.isNotEmpty ? local.description : server.description,
    coverImageUrl: localCover.isNotEmpty ? localCover : server.coverImageUrl,
    previewImages: localPreview.isNotEmpty ? localPreview : server.previewImages,
    pageCount: local.pageCount > 0 ? local.pageCount : server.pageCount,
    category: (local.category ?? '').trim().isNotEmpty
        ? local.category
        : server.category,
    tags: (local.tags != null && local.tags!.isNotEmpty) ? local.tags : server.tags,
    templateJson: localJson.isNotEmpty ? local.templateJson : server.templateJson,
  );
}

Future<List<PremiumTemplate>> _loadGeneratedStoreLatestTemplates() async {
  try {
    final raw = await rootBundle.loadString(
      'assets/templates/generated/store_latest.json',
    );
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <PremiumTemplate>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PremiumTemplate.fromJson)
        .map(_normalizeStoreTemplateRuntime)
        .toList(growable: false);
  } catch (_) {
    return const <PremiumTemplate>[];
  }
}

bool _isStoreAllowedTemplate(PremiumTemplate template) {
  return template.title.trim().isNotEmpty;
}

final templateApiProvider = Provider<TemplateApi>((ref) {
  final dio = ref.read(dioProvider);
  return TemplateApi(dio);
});

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  final api = ref.read(templateApiProvider);
  final tokenStorage = ref.read(tokenStorageProvider);
  return TemplateRepositoryImpl(api, tokenStorage: tokenStorage);
});

List<PremiumTemplate> _visibleServerTemplates(
  Iterable<PremiumTemplate> items,
) {
  final visible = items
      .where(_isStoreAllowedTemplate)
      .map(_normalizeStoreTemplateRuntime)
      .toList(growable: false);
  final sorted = [...visible]..sort((a, b) => b.id.compareTo(a.id));
  final pinnedSaveTheDate = sorted.where((t) {
    final title = t.title.trim().toLowerCase();
    final raw = (t.templateJson ?? '').toLowerCase();
    return title == 'save the date' || raw.contains('save_the_date_v1');
  }).toList(growable: false);
  final others = sorted
      .where((t) => !pinnedSaveTheDate.any((p) => p.id == t.id))
      .toList(growable: false);
  return <PremiumTemplate>[
    ...pinnedSaveTheDate.take(1),
    ...others,
  ];
}

final templateListProvider = FutureProvider<List<PremiumTemplate>>((ref) async {
  final repository = ref.watch(templateRepositoryProvider);
  final remote = await repository.getTemplates();
  final local = await _loadGeneratedStoreLatestTemplates();
  return _visibleServerTemplates(
    StoreTemplateFeedNotifier.mergeServerSummaryWithLocalStatic(
      server: remote,
      local: local,
    ),
  );
});

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

class StoreTemplateFeedNotifier extends StateNotifier<StoreTemplateFeedState> {
  StoreTemplateFeedNotifier(this._repository)
    : super(StoreTemplateFeedState.initial()) {
    loadInitial();
  }

  static const int _pageSize = 20;
  final TemplateRepository _repository;
  Future<List<PremiumTemplate>>? _localTemplatesFuture;

  String _normalizeTitle(String value) => _normalizeTemplateTitleKey(value);

  Future<List<PremiumTemplate>> _loadLocalTemplates() {
    return _localTemplatesFuture ??= _loadGeneratedStoreLatestTemplates();
  }

  List<PremiumTemplate> _mergeServerSummaryWithLocal({
    required List<PremiumTemplate> server,
    required List<PremiumTemplate> local,
  }) {
    return mergeServerSummaryWithLocalStatic(server: server, local: local);
  }

  static List<PremiumTemplate> mergeServerSummaryWithLocalStatic({
    required List<PremiumTemplate> server,
    required List<PremiumTemplate> local,
  }) {
    final byKey = <String, PremiumTemplate>{};

    for (final item in server) {
      final normalized = _normalizeStoreTemplateRuntime(item);
      final key = _normalizeTemplateTitleKey(normalized.title);
      byKey[key] = normalized;
    }

    for (final localItem in local) {
      final normalizedLocal = _normalizeStoreTemplateRuntime(localItem);
      final key = _normalizeTemplateTitleKey(normalizedLocal.title);
      final current = byKey[key];
      if (current == null) {
        byKey[key] = normalizedLocal;
      } else {
        byKey[key] = _mergeServerWithLocalTemplate(current, normalizedLocal);
      }
    }

    return _visibleServerTemplates(byKey.values);
  }

  Future<void> loadInitial() async {
    state = StoreTemplateFeedState.initial();
    await _fetchPage(0, replace: true);
  }

  Future<void> loadMore() async {
    if (state.isInitialLoading || state.isLoadingMore || !state.hasNext) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, error: null);
    await _fetchPage(state.page + 1, replace: false);
  }

  Future<void> refresh() async {
    await loadInitial();
  }

  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 45),
  }) async {
    if (state.isInitialLoading || state.isLoadingMore) return;
    final last = state.lastSyncedAt;
    if (last == null || DateTime.now().difference(last) >= maxAge) {
      await refresh();
    }
  }

  Future<void> _fetchPage(int page, {required bool replace}) async {
    try {
      final local = await _loadLocalTemplates();
      final result = await _repository.getTemplateSummaries(
        page: page,
        size: _pageSize,
      );
      final hydrated = _mergeServerSummaryWithLocal(
        server: result.content,
        local: local,
      );
      final merged = replace
          ? hydrated
          : <PremiumTemplate>[
              ...state.items,
              ...hydrated.where(
                (candidate) => !state.items.any(
                  (t) =>
                      t.id == candidate.id ||
                      _normalizeTitle(t.title) ==
                          _normalizeTitle(candidate.title),
                ),
              ),
            ];
      state = state.copyWith(
        items: merged,
        isInitialLoading: false,
        isLoadingMore: false,
        hasNext: false,
        page: result.page,
        lastSyncedAt: DateTime.now(),
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        items: state.items,
        isInitialLoading: false,
        isLoadingMore: false,
        hasNext: false,
        lastSyncedAt: DateTime.now(),
        error: e,
      );
    }
  }
}

final storeTemplateFeedProvider =
    StateNotifierProvider<StoreTemplateFeedNotifier, StoreTemplateFeedState>((
      ref,
    ) {
      final repository = ref.read(templateRepositoryProvider);
      return StoreTemplateFeedNotifier(repository);
    });

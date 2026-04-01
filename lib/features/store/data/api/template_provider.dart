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
import '../local/local_featured_templates.dart';

String _safeTemplateText(String? raw, {String fallback = ''}) {
  final value = (raw ?? '').trim();
  return value.isEmpty ? fallback : value;
}

String _toneKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

bool _shouldPreferLocalTemplateJsonForSaveTheDate(
  PremiumTemplate local,
  PremiumTemplate server,
) {
  final localRaw = (local.templateJson ?? '').trim();
  if (localRaw.isEmpty) return false;
  try {
    final decoded = jsonDecode(localRaw) as Map<String, dynamic>;
    final metadata = decoded['metadata'];
    final localTemplateId =
        (decoded['templateId'] ??
                (metadata is Map ? metadata['templateId'] : null))
            ?.toString();
    final pageCount = (decoded['pages'] is List)
        ? (decoded['pages'] as List).length
        : 0;
    final serverRaw = (server.templateJson ?? '').trim();
    final serverTemplateId = serverRaw.isEmpty
        ? null
        : ((jsonDecode(serverRaw) as Map<String, dynamic>)['templateId']
              ?.toString());
    return localTemplateId == 'save_the_date_v1' &&
        pageCount >= 13 &&
        serverTemplateId == 'save_the_date_v1';
  } catch (_) {
    return false;
  }
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

bool _isStoreAllowedTemplate(PremiumTemplate template) {
  // 운영 정책 변경:
  // 스토어는 서버 DB에 active=true 로 등록된 템플릿을 전부 노출한다.
  // (이전에는 특정 3종만 허용하는 하드코딩 필터가 있었다.)
  return true;
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

final templateListProvider = FutureProvider<List<PremiumTemplate>>((ref) async {
  final repository = ref.watch(templateRepositoryProvider);
  final localCode = localFeaturedTemplates();

  PremiumTemplate normalizePreviewImages(PremiumTemplate template) =>
      _normalizeStoreTemplateRuntime(template);

  String normalizeTitle(String value) => _normalizeTemplateTitleKey(value);

  bool shouldPreferLocalTemplateJson(
    PremiumTemplate local,
    PremiumTemplate server,
  ) => _shouldPreferLocalTemplateJsonForSaveTheDate(local, server);

  PremiumTemplate pickBetter(PremiumTemplate a, PremiumTemplate b) {
    int score(PremiumTemplate t) {
      var s = 0;
      if (t.templateJson != null && t.templateJson!.trim().isNotEmpty) s += 5;
      if (t.previewImages.isNotEmpty) s += 3;
      if (t.coverImageUrl.trim().isNotEmpty) s += 1;
      if (t.id >= 0) s += 1; // server id slightly preferred for like/use sync
      return s;
    }

    final sa = score(a);
    final sb = score(b);
    if (sb > sa) return b;
    if (sa > sb) return a;
    return a.id >= 0 ? a : b;
  }

  PremiumTemplate mergeWithServerPriority(
    PremiumTemplate current,
    PremiumTemplate incoming,
  ) {
    final server = current.id >= 0
        ? current
        : (incoming.id >= 0 ? incoming : null);
    final local = identical(server, current) ? incoming : current;
    if (server == null) {
      return pickBetter(current, incoming);
    }

    if (_shouldPreferLocalTemplateJsonForSaveTheDate(local, server)) {
      return server.copyWith(
        subTitle: local.subTitle,
        description: local.description,
        coverImageUrl: local.coverImageUrl,
        previewImages: local.previewImages,
        pageCount: local.pageCount,
        category: local.category,
        tags: local.tags,
        isNew: server.isNew || local.isNew,
        isBest: server.isBest || local.isBest,
        isPremium: server.isPremium,
        templateJson: local.templateJson,
      );
    }

    final mergedPreview = local.previewImages.isNotEmpty
        ? local.previewImages
        : server.previewImages;
    final mergedCover = local.coverImageUrl.trim().isNotEmpty
        ? local.coverImageUrl.trim()
        : (server.coverImageUrl.trim().isNotEmpty
              ? server.coverImageUrl.trim()
              : (mergedPreview.isNotEmpty ? mergedPreview.first : ''));

    return server.copyWith(
      // 서버 id/좋아요/사용자수/isLiked는 유지해서 like/use API와 상태가 항상 동기화되게 한다.
      subTitle: (server.subTitle ?? '').trim().isNotEmpty
          ? server.subTitle
          : local.subTitle,
      description: (server.description ?? '').trim().isNotEmpty
          ? server.description
          : local.description,
      coverImageUrl: mergedCover,
      previewImages: mergedPreview,
      pageCount: _shouldPreferLocalTemplateJsonForSaveTheDate(local, server)
          ? local.pageCount
          : (server.pageCount > 0 ? server.pageCount : local.pageCount),
      category: (server.category ?? '').trim().isNotEmpty
          ? server.category
          : local.category,
      tags: (server.tags != null && server.tags!.isNotEmpty)
          ? server.tags
          : local.tags,
      weeklyScore: server.weeklyScore > 0
          ? server.weeklyScore
          : local.weeklyScore,
      isNew: server.isNew || local.isNew,
      isBest: server.isBest || local.isBest,
      isPremium: server.isPremium,
      templateJson: _shouldPreferLocalTemplateJsonForSaveTheDate(local, server)
          ? local.templateJson
          : ((server.templateJson ?? '').trim().isNotEmpty
                ? server.templateJson
                : local.templateJson),
    );
  }

  List<PremiumTemplate> dedupeByTitle(List<PremiumTemplate> items) {
    final byTitle = <String, PremiumTemplate>{};
    for (final t in items) {
      final key = normalizeTitle(t.title);
      if (key.isEmpty) {
        byTitle['id:${t.id}'] = t;
        continue;
      }
      final prev = byTitle[key];
      if (prev == null) {
        byTitle[key] = t;
      } else {
        byTitle[key] = mergeWithServerPriority(prev, t);
      }
    }
    return byTitle.values.toList();
  }

  bool isBlockedTemplate(PremiumTemplate template) {
    if (!_isStoreAllowedTemplate(template)) return true;
    final normalized = normalizeTitle(template.title);
    final blockedKeywords = <String>[
      '성수동 카페투어',
      '성수동 카페 투어',
      '미니멀포커스',
      '미니멀 포커스',
      '오션브리즈',
      '오션 브리즈',
      '링모먼트',
      '링 모먼트',
      '링 트립 스토리',
      '우리의결혼1주년',
      '우리의 결혼 1주년',
      '웨딩에디토리얼',
      '웨딩 에디토리얼',
      '썸머포스터',
      '썸머 포스터',
      '스카이레더',
      '스카이 레더',
      '스카이레터',
      '스카이 레터',
      '브랜드이벤트커버',
      '브랜드 이벤트 커버',
    ];
    for (final keyword in blockedKeywords) {
      if (normalized.contains(normalizeTitle(keyword))) {
        return true;
      }
    }
    return false;
  }

  bool isRenderableStoreTemplate(PremiumTemplate template) {
    final raw = template.templateJson;
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final pages = decoded['pages'];
      if (pages is! List) return false;
      if (pages.length < 12 || pages.length > 24) return false;
      final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt() ?? 1;
      for (final page in pages) {
        if (page is! Map) return false;
        if (schemaVersion >= 2) {
          final layoutId = page['layoutId']?.toString() ?? '';
          final role = page['role']?.toString() ?? '';
          final photoCount = page['recommendedPhotoCount'];
          if (layoutId.trim().isEmpty) return false;
          if (!{'cover', 'inner', 'chapter', 'end'}.contains(role))
            return false;
          if (photoCount is! num || photoCount < 0 || photoCount > 12) {
            return false;
          }
        }
        final layers = page['layers'];
        if (layers is! List || layers.isEmpty) return false;
        final hasImageLayer = layers.any(
          (layer) =>
              layer is Map &&
              (layer['type']?.toString().toUpperCase() == 'IMAGE'),
        );
        final photoCount =
            (page['recommendedPhotoCount'] as num?)?.toInt() ?? 1;
        if (photoCount > 0 && !hasImageLayer) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  bool hasRequiredTemplateMetadata(PremiumTemplate template) {
    final raw = template.templateJson;
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final metadata = decoded['metadata'];
      if (metadata is! Map) return false;
      final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt() ?? 1;
      final style = metadata['style']?.toString() ?? '';
      final mood = metadata['mood']?.toString() ?? '';
      final tags = metadata['tags'];
      final difficulty = metadata['difficulty'];
      final recommendedPhotoCount = metadata['recommendedPhotoCount'];
      final safeArea = metadata['heroTextSafeArea'];
      final sourceBottomSheetTemplateIds =
          metadata['sourceBottomSheetTemplateIds'];
      final applyScope = metadata['applyScope']?.toString() ?? '';
      if (schemaVersion >= 2) {
        final templateId = (decoded['templateId'] ?? metadata['templateId'])
            ?.toString();
        final version = decoded['version'] ?? metadata['version'];
        final lifecycle =
            (decoded['lifecycleStatus'] ?? metadata['lifecycleStatus'])
                ?.toString();
        if (templateId == null || templateId.trim().isEmpty) return false;
        if (version is! num || version < 1) return false;
        if (!{
          'draft',
          'qa_passed',
          'published',
          'deprecated',
        }.contains(lifecycle)) {
          return false;
        }
      }
      if (style.trim().isEmpty || mood.trim().isEmpty) return false;
      if (difficulty is! num || difficulty < 1 || difficulty > 5) return false;
      if (recommendedPhotoCount is! num ||
          recommendedPhotoCount < 1 ||
          recommendedPhotoCount > 24) {
        return false;
      }
      if (tags is! List || tags.isEmpty) return false;
      if (safeArea is! Map) return false;
      if (sourceBottomSheetTemplateIds is! List ||
          sourceBottomSheetTemplateIds.isEmpty) {
        return false;
      }
      if (applyScope != 'cover_and_pages') return false;
      for (final key in ['x', 'y', 'width', 'height']) {
        final value = safeArea[key];
        if (value is! num) return false;
      }
      final width = (safeArea['width'] as num).toDouble();
      final height = (safeArea['height'] as num).toDouble();
      if (width <= 0 || height <= 0 || width > 1.0 || height > 1.0) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  double liveOpsScore(PremiumTemplate t) {
    var score = 0.0;
    score += (t.weeklyScore.toDouble() * 1.2);
    score += (t.likeCount * 2.0);
    score += (t.userCount * 3.0);
    if (t.isBest) score += 120;
    if (t.isNew) score += 50;
    if (hasRequiredTemplateMetadata(t)) score += 80;
    if (t.pageCount >= 12 && t.pageCount <= 24) score += 30;
    if (!t.isPremium) score -= 20; // free 템플릿은 노출은 하되 살짝 하향
    return score;
  }

  List<PremiumTemplate> applyLiveOpsRanking(List<PremiumTemplate> items) {
    final sorted = [...items]
      ..sort((a, b) => liveOpsScore(b).compareTo(liveOpsScore(a)));
    final topQuality = sorted.take(12).toList();
    final topIds = topQuality.map((e) => e.id).toSet();
    final rest = sorted.where((e) => !topIds.contains(e.id)).toList();
    return [...topQuality, ...rest];
  }

  Future<List<PremiumTemplate>> loadStoreTemplatesFromAssets() async {
    const paths = [
      'assets/templates/generated/store_latest.json',
      'assets/templates/store_templates_v1.json',
    ];
    final loaded = <PremiumTemplate>[];
    for (final path in paths) {
      try {
        final raw = await rootBundle.loadString(path);
        final decoded = jsonDecode(raw);
        final items = decoded is List
            ? decoded
            : (decoded is Map<String, dynamic> ? decoded['templates'] : null);
        if (items is! List) continue;
        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          loaded.add(PremiumTemplate.fromJson(item));
        }
      } catch (_) {
        // optional asset path
      }
    }
    return loaded;
  }

  final localAsset = await loadStoreTemplatesFromAssets();
  final local = localAsset.isNotEmpty
      ? dedupeByTitle([
          ...localCode.map(normalizePreviewImages),
          ...localAsset.map(normalizePreviewImages),
        ])
      : localCode.map(normalizePreviewImages).toList();

  try {
    final remote = await repository.getTemplates();
    final localByTitle = <String, PremiumTemplate>{};
    for (final t in local) {
      final key = normalizeTitle(t.title);
      if (key.isEmpty) continue;
      final prev = localByTitle[key];
      localByTitle[key] = prev == null ? t : mergeWithServerPriority(prev, t);
    }

    final serverAnchored = remote.map((remoteTemplate) {
      final normalizedRemote = normalizePreviewImages(remoteTemplate);
      final key = normalizeTitle(normalizedRemote.title);
      final localMatch = key.isEmpty ? null : localByTitle[key];
      if (localMatch == null) return normalizedRemote;
      return mergeWithServerPriority(localMatch, normalizedRemote);
    }).toList();

    final serverTitleKeys = serverAnchored
        .map((t) => normalizeTitle(t.title))
        .where((k) => k.isNotEmpty)
        .toSet();
    final localExtras = local.where((t) {
      final key = normalizeTitle(t.title);
      if (key.isEmpty) return true;
      return !serverTitleKeys.contains(key);
    }).toList();

    final deduped = dedupeByTitle([...serverAnchored, ...localExtras]);
    final visible = deduped
        .where((t) => _isStoreAllowedTemplate(t))
        .where((t) => !isBlockedTemplate(t))
        .toList();
    final valid = visible
        .where(isRenderableStoreTemplate)
        .where(hasRequiredTemplateMetadata)
        .toList();
    final renderable = visible.where(isRenderableStoreTemplate).toList();

    // 서버 + 로컬(중복 제목은 서버 우선)로 노출한다.
    // 품질 필터가 너무 엄격해 비어버리면 단계적으로 완화해 빈 화면을 방지한다.
    if (valid.isNotEmpty) return applyLiveOpsRanking(valid);
    if (renderable.isNotEmpty) return applyLiveOpsRanking(renderable);
    return applyLiveOpsRanking(visible);
  } catch (_) {
    return applyLiveOpsRanking(
      dedupeByTitle(local.map(normalizePreviewImages).toList())
          .where((t) => !isBlockedTemplate(t))
          .where(isRenderableStoreTemplate)
          .where(hasRequiredTemplateMetadata)
          .toList(),
    );
  }
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
    return _localTemplatesFuture ??= () async {
      final localCode = localFeaturedTemplates();
      final loaded = <PremiumTemplate>[...localCode];
      const paths = [
        'assets/templates/generated/store_latest.json',
        'assets/templates/store_templates_v1.json',
      ];
      for (final path in paths) {
        try {
          final raw = await rootBundle.loadString(path);
          final decoded = jsonDecode(raw);
          final items = decoded is List
              ? decoded
              : (decoded is Map<String, dynamic> ? decoded['templates'] : null);
          if (items is! List) continue;
          for (final item in items) {
            if (item is! Map<String, dynamic>) continue;
            loaded.add(PremiumTemplate.fromJson(item));
          }
        } catch (_) {
          // optional asset path
        }
      }

      final byTitle = <String, PremiumTemplate>{};
      for (final t in loaded) {
        final key = _normalizeTitle(t.title);
        if (key.isEmpty) continue;
        byTitle[key] = t;
      }
      return byTitle.values.toList(growable: false);
    }();
  }

  List<PremiumTemplate> _mergeServerSummaryWithLocal({
    required List<PremiumTemplate> server,
    required List<PremiumTemplate> local,
  }) {
    final localByTitle = <String, PremiumTemplate>{
      for (final l in local) _normalizeTitle(l.title): l,
    };

    final mergedServer = server
        .map((s) {
          final key = _normalizeTitle(s.title);
          final localMatch = key.isEmpty ? null : localByTitle[key];
          if (localMatch == null) return s;
          if (_shouldPreferLocalTemplateJsonForSaveTheDate(localMatch, s)) {
            return s.copyWith(
              subTitle: localMatch.subTitle,
              description: localMatch.description,
              coverImageUrl: localMatch.coverImageUrl,
              previewImages: localMatch.previewImages,
              pageCount: localMatch.pageCount,
              category: localMatch.category,
              tags: localMatch.tags,
              templateJson: localMatch.templateJson,
            );
          }
          return s.copyWith(
            subTitle: localMatch.subTitle,
            description: localMatch.description,
            coverImageUrl: localMatch.coverImageUrl.trim().isNotEmpty
                ? localMatch.coverImageUrl
                : s.coverImageUrl,
            previewImages: localMatch.previewImages,
            pageCount: localMatch.pageCount,
            category: localMatch.category,
            tags: (s.tags != null && s.tags!.isNotEmpty)
                ? s.tags
                : localMatch.tags,
            // 서버 등록본을 우선 신뢰하고, 서버 요약에 templateJson이 비어있을 때만 로컬 fallback 사용
            templateJson:
                (s.templateJson != null && s.templateJson!.trim().isNotEmpty)
                ? s.templateJson
                : localMatch.templateJson,
          );
        })
        .toList(growable: false);

    // Rule: 스토어 화면에는 서버 DB에 등록된 템플릿만 노출한다.
    // 로컬 템플릿은 서버 summary 아이템을 보강(hydration)하는 용도로만 사용한다.
    return mergedServer
        .where(_isStoreAllowedTemplate)
        .map(_normalizeStoreTemplateRuntime)
        .toList(growable: false);
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
        hasNext: result.hasNext,
        page: result.page,
        lastSyncedAt: DateTime.now(),
        error: null,
      );
    } catch (e) {
      final localFallback = await _loadLocalTemplates();
      state = state.copyWith(
        items: replace && state.items.isEmpty ? localFallback : state.items,
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

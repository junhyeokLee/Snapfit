import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/network/dio_provider.dart';
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
  final canonicalTitle = _canonicalStoreTemplateTitle(template);
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

  final normalized = template.copyWith(
    title: canonicalTitle,
    coverImageUrl: coverCandidate,
    previewImages: orderedPreview,
    pageCount: normalizedPageCount,
    // 서버/피그마 원본 JSON이 있으면 절대 재생성하지 않고 그대로 사용한다.
    templateJson: normalizedTemplateJson,
  );
  return _applyExactFigmaCoverPresentation(normalized);
}

PremiumTemplate _applyExactFigmaCoverPresentation(PremiumTemplate template) {
  final rawJson = (template.templateJson ?? '').toLowerCase();
  final title = _canonicalStoreTemplateTitle(template);

  if (title == 'SAVE THE DATE' ||
      title == 'JEJU TRAVEL' ||
      title == 'FAMILY WEEKEND' ||
      title == 'ANNIVERSARY DAYS' ||
      title == 'Wedding Editorial' ||
      title == 'Scrapbook' ||
      rawJson.contains('save_the_date_v1') ||
      rawJson.contains('jeju_travel_v1') ||
      rawJson.contains('family_weekend_v1') ||
      rawJson.contains('anniversary_days_v1') ||
      rawJson.contains('wedding_editorial_v1') ||
      rawJson.contains('scrapbook_v1')) {
    return template.copyWith(coverImageUrl: '', previewImages: const []);
  }
  return template;
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

String _canonicalStoreTemplateTitle(PremiumTemplate template) {
  final rawTitle = template.title.trim();
  final titleKey = _normalizeTemplateTitleKey(rawTitle);
  final rawJson = (template.templateJson ?? '').toLowerCase();

  if (titleKey == 'savethedate' || rawJson.contains('save_the_date_v1')) {
    return 'SAVE THE DATE';
  }
  if (titleKey == 'jejutravel' || rawJson.contains('jeju_travel_v1')) {
    return 'JEJU TRAVEL';
  }
  if (titleKey == 'familyweekend' || rawJson.contains('family_weekend_v1')) {
    return 'FAMILY WEEKEND';
  }
  if (titleKey == 'anniversarydays' ||
      rawJson.contains('anniversary_days_v1')) {
    return 'ANNIVERSARY DAYS';
  }
  if (titleKey == 'weddingeditorial' ||
      rawJson.contains('wedding_editorial_v1')) {
    return 'Wedding Editorial';
  }
  if (titleKey == 'scrapbook' || rawJson.contains('scrapbook_v1')) {
    return 'Scrapbook';
  }

  return rawTitle;
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
    previewImages: localPreview.isNotEmpty
        ? localPreview
        : server.previewImages,
    pageCount: local.pageCount > 0 ? local.pageCount : server.pageCount,
    category: (local.category ?? '').trim().isNotEmpty
        ? local.category
        : server.category,
    tags: (local.tags != null && local.tags!.isNotEmpty)
        ? local.tags
        : server.tags,
    templateJson: localJson.isNotEmpty
        ? local.templateJson
        : server.templateJson,
  );
}

PremiumTemplate _premiumTemplateFromLooseJson(Map<String, dynamic> json) {
  List<String> stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  return PremiumTemplate(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: (json['title'] ?? '').toString(),
    subTitle: json['subTitle']?.toString(),
    description: json['description']?.toString(),
    coverImageUrl: (json['coverImageUrl'] ?? '').toString(),
    previewImages: stringList(json['previewImages']),
    pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    userCount: (json['userCount'] as num?)?.toInt() ?? 0,
    category: json['category']?.toString(),
    tags: stringList(json['tags']),
    weeklyScore: (json['weeklyScore'] as num?)?.toInt() ?? 0,
    isNew: json['isNew'] == true,
    isBest: json['isBest'] == true,
    isPremium: json['isPremium'] != false,
    isLiked: json['isLiked'] == true,
    templateJson: json['templateJson']?.toString(),
    createdAt: json['createdAt']?.toString(),
  );
}

String _extractFirstPreviewFromFigmaNode(Map<String, dynamic> node) {
  final previews = node['previewImages'];
  if (previews is List) {
    for (final item in previews) {
      final value = item?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
  }

  final layers = node['layers'];
  if (layers is List) {
    for (final rawLayer in layers) {
      if (rawLayer is! Map) continue;
      final layer = Map<String, dynamic>.from(rawLayer);
      if ((layer['type'] ?? '').toString().toUpperCase() != 'IMAGE') continue;
      final payload = layer['payload'];
      if (payload is! Map) continue;
      final url =
          (payload['previewUrl'] ??
                  payload['imageUrl'] ??
                  payload['originalUrl'])
              ?.toString()
              .trim() ??
          '';
      if (url.isNotEmpty) return url;
    }
  }

  return '';
}

Future<List<PremiumTemplate>> _loadFigmaMcpStoreTemplates() async {
  final templates = <PremiumTemplate>[];

  try {
    final raw = await rootBundle.loadString(
      'assets/templates/figma_handoff_example.json',
    );
    final decoded = jsonDecode(raw);
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      final item = Map<String, dynamic>.from(decoded.first as Map);
      final preview = _extractFirstPreviewFromFigmaNode(item);
      final previewImages = <String>[
        ...((item['previewImages'] as List?) ?? const <dynamic>[])
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty),
      ];
      if (preview.isNotEmpty && !previewImages.contains(preview)) {
        previewImages.insert(0, preview);
      }
      final figmaJson = <String, dynamic>{
        'designWidth': 1080.0,
        'designHeight': 1440.0,
        'metadata': {
          'category': item['category'],
          'style': item['style'],
          'templateType': 'wedding',
        },
        'pages': item['pages'] ?? const [],
        'variants': item['variants'] ?? const {},
      };
      templates.add(
        PremiumTemplate(
          id: -9001,
          title: 'SAVE THE DATE',
          subTitle: '웨딩 · figma editorial',
          description: 'Figma MCP 기반 SAVE THE DATE 템플릿',
          coverImageUrl: preview,
          previewImages: previewImages,
          pageCount: ((item['pages'] as List?) ?? const []).length,
          userCount: 0,
          category: '웨딩',
          tags: const ['웨딩', 'figma', '세이브더데이트'],
          isPremium: true,
          templateJson: jsonEncode(figmaJson),
        ),
      );
    }
  } catch (_) {
    // Fallback continues with other figma-generated assets.
  }

  try {
    final raw = await rootBundle.loadString(
      'assets/templates/generated/auto_template_samples.json',
    );
    final decoded = jsonDecode(raw);
    final items = decoded is Map ? decoded['templates'] : null;
    if (items is List) {
      const titleMap = <int, String>{
        0: 'JEJU TRAVEL',
        1: 'ANNIVERSARY DAYS',
        2: 'FAMILY WEEKEND',
        3: 'Scrapbook',
        4: 'Wedding Editorial',
      };
      const subTitleMap = <int, String>{
        0: '여행 · figma editorial',
        1: '커플 · figma editorial',
        2: '가족 · figma editorial',
        3: '스크랩북 · figma editorial',
        4: '웨딩 · figma editorial',
      };
      const categoryMap = <int, String>{
        0: '여행',
        1: '기념일',
        2: '가족',
        3: '스크랩북',
        4: '웨딩',
      };
      for (var i = 0; i < items.length; i++) {
        final rawItem = items[i];
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final flutterTemplateJson = item['flutterTemplateJson'];
        final templateJson = flutterTemplateJson is Map
            ? jsonEncode(Map<String, dynamic>.from(flutterTemplateJson))
            : flutterTemplateJson?.toString();
        final previewImages = ((item['previewImages'] as List?) ?? const [])
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
        final title = titleMap[i];
        if (title == null || templateJson == null || templateJson.isEmpty) {
          continue;
        }
        templates.add(
          PremiumTemplate(
            id: -9002 - i,
            title: title,
            subTitle: subTitleMap[i],
            description: '$title Figma MCP 자동 생성 템플릿',
            coverImageUrl: (item['coverImageUrl'] ?? '').toString(),
            previewImages: previewImages,
            pageCount: (item['pageCount'] as num?)?.toInt() ?? 16,
            userCount: 0,
            category: categoryMap[i],
            tags: const ['figma', 'mcp'],
            isPremium: true,
            templateJson: templateJson,
          ),
        );
      }
    }
  } catch (_) {
    // ignore
  }

  return templates.map(_normalizeStoreTemplateRuntime).toList(growable: false);
}

Future<List<PremiumTemplate>> _loadCanonicalHandoffStoreTemplates() async {
  const assetPaths = <String>[
    'assets/templates/save_the_date_handoff.json',
    'assets/templates/jeju_travel_handoff.json',
    'assets/templates/family_weekend_handoff.json',
    'assets/templates/anniversary_days_handoff.json',
    'assets/templates/wedding_editorial_handoff.json',
    'assets/templates/scrapbook_handoff.json',
  ];

  PremiumTemplate? fromDirectPremium(Map<String, dynamic> raw) {
    final title = (raw['title'] ?? raw['name'] ?? '').toString().trim();
    if (title.isEmpty && raw['templateJson'] == null) return null;
    return _premiumTemplateFromLooseJson(raw);
  }

  PremiumTemplate? fromWrappedTemplate(Map<String, dynamic> raw) {
    final nested = raw['template'];
    if (nested is! Map) return null;
    return _premiumTemplateFromLooseJson(Map<String, dynamic>.from(nested));
  }

  PremiumTemplate? fromSaveTheDateHandoff(Map<String, dynamic> raw) {
    final coverImageUrl = (raw['coverImageUrl'] ?? '').toString().trim();
    final previewImages = ((raw['previewImages'] as List?) ?? const [])
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final handoffJson = <String, dynamic>{
      'designWidth': raw['designWidth'] ?? 1080,
      'designHeight': raw['designHeight'] ?? 1440,
      'templateId': raw['templateId'],
      'version': raw['version'],
      'lifecycleStatus': raw['lifecycleStatus'],
      'aspect': raw['aspect'],
      'ratio': raw['ratio'],
      'recommendedPhotoCount': raw['recommendedPhotoCount'],
      'strictLayout': raw['strictLayout'],
      'autoFit': raw['autoFit'],
      'metadata': {
        'category': raw['category'],
        'style': raw['style'],
        'tags': raw['tags'],
        'title': raw['title'] ?? raw['name'],
      },
      'cover': raw['cover'],
      'pages': raw['pages'] ?? const [],
      'variants': raw['variants'] ?? const {},
    };
    return PremiumTemplate(
      id: (raw['id'] as num?)?.toInt() ?? -7001,
      title: (raw['title'] ?? raw['name'] ?? 'SAVE THE DATE').toString(),
      subTitle: raw['subTitle']?.toString() ?? '웨딩 · editorial',
      description: raw['description']?.toString() ?? 'SAVE THE DATE 템플릿',
      coverImageUrl: coverImageUrl,
      previewImages: previewImages,
      pageCount:
          (raw['pageCount'] as num?)?.toInt() ??
          ((raw['pages'] as List?)?.length ?? 0),
      likeCount: (raw['likeCount'] as num?)?.toInt() ?? 0,
      userCount: (raw['userCount'] as num?)?.toInt() ?? 0,
      category: raw['category']?.toString(),
      tags: ((raw['tags'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      weeklyScore: (raw['weeklyScore'] as num?)?.toInt() ?? 0,
      isNew: raw['isNew'] == true,
      isBest: raw['isBest'] == true,
      isPremium: raw['isPremium'] != false,
      isLiked: raw['isLiked'] == true,
      templateJson: jsonEncode(handoffJson),
      createdAt: raw['createdAt']?.toString(),
    );
  }

  final templates = <PremiumTemplate>[];
  for (final assetPath in assetPaths) {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      final map = decoded is List
          ? (decoded.isNotEmpty && decoded.first is Map
                ? Map<String, dynamic>.from(decoded.first as Map)
                : null)
          : (decoded is Map ? Map<String, dynamic>.from(decoded) : null);
      if (map == null) continue;

      final parsed =
          (assetPath.endsWith('save_the_date_handoff.json')
              ? fromSaveTheDateHandoff(map)
              : null) ??
          fromWrappedTemplate(map) ??
          fromDirectPremium(map);
      if (parsed != null) {
        templates.add(_normalizeStoreTemplateRuntime(parsed));
      }
    } catch (_) {
      // Ignore broken handoff files so the remaining canonical templates survive.
    }
  }

  return templates;
}

List<PremiumTemplate> _hardcodedCanonicalStoreTemplates() {
  return <PremiumTemplate>[
    PremiumTemplate(
      id: -1115056,
      title: 'SAVE THE DATE',
      subTitle: '웨딩 · editorial',
      description: 'SAVE THE DATE 스토어 템플릿',
      coverImageUrl:
          'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fsave_the_date%2Fv1%2Fcover_full_bleed.png?alt=media&token=b63dea3e-40c3-4f07-9b2c-59bc688c7fd2',
      previewImages: const [
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fsave_the_date%2Fv1%2Fcover_full_bleed.png?alt=media&token=b63dea3e-40c3-4f07-9b2c-59bc688c7fd2',
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fsave_the_date%2Fv1%2Fp01_arch_editorial.png?alt=media&token=83681da7-617c-44bc-a2b4-c66c724bc2fc',
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fsave_the_date%2Fv1%2Fp02_circle_card.png?alt=media&token=1c6f41f7-e0cc-4880-b040-6894de2e9011',
      ],
      pageCount: 13,
      userCount: 0,
      category: '웨딩',
      tags: const ['웨딩', '세이브더데이트'],
      isPremium: true,
    ),
    PremiumTemplate(
      id: 46,
      title: 'JEJU TRAVEL',
      subTitle: '제주 여행 앨범 · editorial',
      description: '제주의 바다와 풍경을 담는 여행 앨범 템플릿',
      coverImageUrl:
          'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fjeju_travel%2Fv1%2Fjeju_aerial.jpg?alt=media&token=db0d66a4-b6a1-498d-a79c-f41582a68cd2',
      previewImages: const [
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fjeju_travel%2Fv1%2Fjeju_aerial.jpg?alt=media&token=db0d66a4-b6a1-498d-a79c-f41582a68cd2',
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fjeju_travel%2Fv1%2Fjeju_seongsan.jpg?alt=media&token=3e444f31-41bb-4fe5-9843-5193f6065b72',
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fjeju_travel%2Fv1%2Fjeju_ocean.jpg?alt=media&token=ea599666-206d-4681-b09f-fcaea17bc0fc',
      ],
      pageCount: 14,
      userCount: 0,
      category: '여행',
      tags: const ['여행', '제주도'],
      isPremium: false,
    ),
    PremiumTemplate(
      id: 48,
      title: 'FAMILY WEEKEND',
      subTitle: '가족 앨범 · bright scrapbook',
      description: '함께 보낸 주말을 담는 가족 포토북 템플릿',
      coverImageUrl:
          'asset:assets/templates/family_weekend/images/sources/city_weekend.png',
      previewImages: const [
        'asset:assets/templates/family_weekend/images/sources/city_weekend.png',
        'asset:assets/templates/family_weekend/images/sources/ceremony_moment.png',
        'asset:assets/templates/family_weekend/images/sources/hands_bw.png',
      ],
      pageCount: 15,
      userCount: 0,
      category: '가족',
      tags: const ['가족', '주말'],
      isPremium: false,
    ),
    PremiumTemplate(
      id: 49,
      title: 'ANNIVERSARY DAYS',
      subTitle: '커플 기념일 앨범 · clean romantic',
      description: '100일, 1주년 같은 기념일을 담는 템플릿',
      coverImageUrl:
          'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fanniversary_days%2Fv1%2Fanniversary_sample.png?alt=media&token=59dd742d-6a21-4284-bdfd-3981d34b06b0',
      previewImages: const [
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fanniversary_days%2Fv1%2Fanniversary_sample.png?alt=media&token=59dd742d-6a21-4284-bdfd-3981d34b06b0',
      ],
      pageCount: 16,
      userCount: 0,
      category: '기념일',
      tags: const ['기념일', '커플'],
      isPremium: false,
    ),
    PremiumTemplate(
      id: 50,
      title: 'Wedding Editorial',
      subTitle: '웨딩 · clean editorial',
      description: '크림과 브라운 톤의 웨딩 에디토리얼 포토북 템플릿',
      coverImageUrl:
          'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fwedding_editorial%2Fv1%2Fceremony_moment.png?alt=media&token=7206cd84-6a88-45b5-b0f8-59456c6e3739',
      previewImages: const [
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fwedding_editorial%2Fv1%2Fceremony_moment.png?alt=media&token=7206cd84-6a88-45b5-b0f8-59456c6e3739',
      ],
      pageCount: 22,
      userCount: 0,
      category: '웨딩',
      tags: const ['웨딩', '에디토리얼'],
      isPremium: false,
    ),
    PremiumTemplate(
      id: 51,
      title: 'Scrapbook',
      subTitle: '스크랩북 · layered collage',
      description: 'Pinterest 감성 스크랩북 템플릿',
      coverImageUrl:
          'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fscrapbook%2Fv1%2Fceremony_moment.png?alt=media&token=ed55bc8d-9144-4072-bcc4-c8c1f4bf59a5',
      previewImages: const [
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fscrapbook%2Fv1%2Fceremony_moment.png?alt=media&token=ed55bc8d-9144-4072-bcc4-c8c1f4bf59a5',
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fscrapbook%2Fv1%2Fsunset_pair.png?alt=media&token=3a41d69d-1aab-4836-bb97-ba2da69450de',
        'https://firebasestorage.googleapis.com/v0/b/snapfit-c719d.firebasestorage.app/o/templates%2Fscrapbook%2Fv1%2Fhands_bw.png?alt=media&token=01171c9a-c9b2-4814-b3fd-3a4720e65a0d',
      ],
      pageCount: 16,
      userCount: 0,
      category: '스크랩북',
      tags: const ['스크랩북', '콜라주'],
      isPremium: false,
    ),
  ].map(_normalizeStoreTemplateRuntime).toList(growable: false);
}

Future<List<PremiumTemplate>> _loadGeneratedStoreLatestTemplates() async {
  final explicitFallback = await _loadExplicitStoreTemplateFallbacks();
  final hardcodedFallback = _hardcodedCanonicalStoreTemplates();
  if (explicitFallback.isNotEmpty) {
    return explicitFallback;
  }
  try {
    final raw = await rootBundle.loadString(
      'assets/templates/generated/store_latest.json',
    );
    final decoded = jsonDecode(raw);
    if (decoded is! List) return hardcodedFallback;
    final templates = decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(_premiumTemplateFromLooseJson)
        .map(_normalizeStoreTemplateRuntime)
        .toList(growable: false);
    if (templates.isNotEmpty) return templates;
    return hardcodedFallback;
  } catch (_) {
    return hardcodedFallback;
  }
}

Future<List<PremiumTemplate>> _loadExplicitStoreTemplateFallbacks() async {
  const assetPaths = <String>[
    'assets/templates/generated/save_the_date_store.json',
    'assets/templates/generated/jeju_travel_store.json',
    'assets/templates/generated/family_weekend_store.json',
    'assets/templates/generated/anniversary_days_store.json',
    'assets/templates/generated/wedding_editorial_store.json',
    'assets/templates/generated/scrapbook_store.json',
  ];

  final templates = <PremiumTemplate>[];
  for (final assetPath in assetPaths) {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty) {
        final item = decoded.first;
        if (item is Map) {
          templates.add(
            _normalizeStoreTemplateRuntime(
              _premiumTemplateFromLooseJson(Map<String, dynamic>.from(item)),
            ),
          );
        }
      }
    } catch (_) {
      // Keep loading the rest so one broken asset does not hide the store.
    }
  }
  return templates.isNotEmpty ? templates : _hardcodedCanonicalStoreTemplates();
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

List<PremiumTemplate> _visibleServerTemplates(Iterable<PremiumTemplate> items) {
  final visible = items
      .where(_isStoreAllowedTemplate)
      .map(_normalizeStoreTemplateRuntime)
      .toList(growable: false);
  final sorted = [...visible]..sort((a, b) => b.id.compareTo(a.id));
  final pinnedSaveTheDate = sorted
      .where((t) {
        final title = t.title.trim().toLowerCase();
        final raw = (t.templateJson ?? '').toLowerCase();
        return title == 'save the date' || raw.contains('save_the_date_v1');
      })
      .toList(growable: false);
  final others = sorted
      .where((t) => !pinnedSaveTheDate.any((p) => p.id == t.id))
      .toList(growable: false);
  return <PremiumTemplate>[...pinnedSaveTheDate.take(1), ...others];
}

List<PremiumTemplate> _buildCanonicalStoreTemplates({
  required List<PremiumTemplate> server,
  required List<PremiumTemplate> local,
}) {
  final normalizedServerByKey = <String, PremiumTemplate>{};
  for (final item in server) {
    final normalized = _normalizeStoreTemplateRuntime(item);
    final key = _normalizeTemplateTitleKey(normalized.title);
    normalizedServerByKey[key] = normalized;
  }

  final canonical = <PremiumTemplate>[];
  for (final localItem in local) {
    final normalizedLocal = _normalizeStoreTemplateRuntime(localItem);
    if (!_isStoreAllowedTemplate(normalizedLocal)) continue;
    final key = _normalizeTemplateTitleKey(normalizedLocal.title);
    final serverMatch = normalizedServerByKey[key];
    canonical.add(
      serverMatch == null
          ? normalizedLocal
          : _mergeServerWithLocalTemplate(serverMatch, normalizedLocal),
    );
  }

  if (canonical.isNotEmpty) {
    return canonical;
  }

  return _visibleServerTemplates(server);
}

final templateListProvider = FutureProvider<List<PremiumTemplate>>((ref) async {
  final canonical = await _loadCanonicalHandoffStoreTemplates();
  if (canonical.isNotEmpty) return canonical;

  final local = await loadCanonicalStoreTemplatesForRuntime();
  if (local.isNotEmpty) return local;
  return _hardcodedCanonicalStoreTemplates();
});

Future<List<PremiumTemplate>> loadCanonicalStoreTemplatesForRuntime() async {
  final canonical = await _loadCanonicalHandoffStoreTemplates();
  if (canonical.isNotEmpty) return canonical;
  final figmaTemplates = await _loadFigmaMcpStoreTemplates();
  if (figmaTemplates.isNotEmpty) return figmaTemplates;
  return _loadGeneratedStoreLatestTemplates();
}

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
    return _localTemplatesFuture ??= loadCanonicalStoreTemplatesForRuntime();
  }

  static List<PremiumTemplate> mergeServerSummaryWithLocalStatic({
    required List<PremiumTemplate> server,
    required List<PremiumTemplate> local,
  }) {
    return _buildCanonicalStoreTemplates(server: server, local: local);
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
    final local = await _loadLocalTemplates();
    final merged = replace
        ? local
        : <PremiumTemplate>[
            ...state.items,
            ...local.where(
              (candidate) => !state.items.any(
                (t) =>
                    t.id == candidate.id ||
                    _normalizeTitle(t.title) == _normalizeTitle(candidate.title),
              ),
            ),
          ];
    state = state.copyWith(
      items: merged.isNotEmpty ? merged : local,
      isInitialLoading: false,
      isLoadingMore: false,
      hasNext: false,
      page: page,
      lastSyncedAt: DateTime.now(),
      error: null,
    );
  }
}

final storeTemplateFeedProvider =
    StateNotifierProvider<StoreTemplateFeedNotifier, StoreTemplateFeedState>((
      ref,
    ) {
      final repository = ref.read(templateRepositoryProvider);
      return StoreTemplateFeedNotifier(repository);
    });

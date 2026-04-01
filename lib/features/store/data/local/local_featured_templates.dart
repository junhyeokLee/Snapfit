import 'dart:convert';

import '../../domain/entities/premium_template.dart';

Map<String, dynamic> _textStyle({
  required double fontSize,
  String? fontFamily,
  int fontWeight = 5,
  String color = '#FF1F2937',
  double letterSpacing = 0,
}) {
  return {
    'fontSize': fontSize,
    'fontWeight': fontWeight,
    'fontFamily': fontFamily,
    'color': color,
    'letterSpacing': letterSpacing,
  };
}

Map<String, dynamic> _img(
  String id,
  double x,
  double y,
  double w,
  double h, {
  String? frame,
  String? imageTemplate,
  String? imageUrl,
  double rotation = 0,
  int z = 10,
}) {
  final fallbackUrl = imageUrl ?? _sampleImageForId(id);
  return {
    'id': id,
    'type': 'IMAGE',
    'x': x,
    'y': y,
    'width': w,
    'height': h,
    'rotation': rotation,
    'opacity': 1.0,
    'scale': 1.0,
    'zIndex': z,
    'payload': {
      'imageBackground': frame,
      'imageTemplate': imageTemplate ?? 'free',
      'imageUrl': fallbackUrl,
      'previewUrl': fallbackUrl,
      'originalUrl': fallbackUrl,
    },
  };
}

String _sampleImageForId(String id) {
  const urls = [
    'https://picsum.photos/id/1015/1200/900',
    'https://picsum.photos/id/1016/1200/900',
    'https://picsum.photos/id/1025/1200/900',
    'https://picsum.photos/id/1035/1200/900',
    'https://picsum.photos/id/1040/1200/900',
    'https://picsum.photos/id/1050/1200/900',
    'https://picsum.photos/id/1067/1200/900',
    'https://picsum.photos/id/1074/1200/900',
  ];
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return urls[hash % urls.length];
}

int _stableHash(String input) {
  var hash = 0;
  for (final unit in input.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

String _stablePicsum(String seed, {int width = 1200, int height = 900}) {
  final safeSeed = seed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return 'https://picsum.photos/seed/$safeSeed/$width/$height';
}

String _sanitizeNetworkImageUrl(
  String raw, {
  required String seed,
  int width = 1200,
  int height = 900,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return _stablePicsum(seed, width: width, height: height);
  try {
    final uri = Uri.parse(trimmed);
    if (trimmed.startsWith('asset:') || uri.host.contains('figma.com')) {
      return trimmed;
    }
    if (uri.host.contains('images.unsplash.com')) {
      final q = Map<String, String>.from(uri.queryParameters);
      q['auto'] = 'format';
      q['fit'] = 'crop';
      q['w'] = '${width < 1600 ? 1600 : width}';
      q['q'] = '86';
      return uri.replace(queryParameters: q).toString();
    }
    if (uri.host.contains('picsum.photos')) {
      final targetW = width < 1600 ? 1600 : width;
      final targetH = height < 1200 ? 1200 : height;
      return _stablePicsum(seed, width: targetW, height: targetH);
    }
  } catch (_) {
    // fall through
  }
  return trimmed;
}

Map<String, dynamic> _txt(
  String id,
  double x,
  double y,
  double w,
  double h,
  String text, {
  String align = 'center',
  int z = 20,
  Map<String, dynamic>? style,
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
      'textStyle': style ?? _textStyle(fontSize: 22),
    },
  };
}

Map<String, dynamic> _deco(
  String id,
  double x,
  double y,
  double w,
  double h, {
  required String background,
  double rotation = 0,
  int z = 1,
}) {
  return {
    'id': id,
    'type': 'DECORATION',
    'x': x,
    'y': y,
    'width': w,
    'height': h,
    'rotation': rotation,
    'opacity': 1.0,
    'scale': 1.0,
    'zIndex': z,
    'payload': {'imageBackground': background, 'imageTemplate': 'free'},
  };
}

String buildJejuSummerTemplateJson() {
  final pages = <Map<String, dynamic>>[
    {
      'pageNumber': 1,
      'layers': [
        _deco('cover_bg', 0.0, 0.0, 1.0, 1.0, background: 'paperWarm', z: 1),
        _txt(
          'cover_badge',
          0.34,
          0.06,
          0.32,
          0.06,
          'PHOTOTRIP 2026',
          style: _textStyle(
            fontSize: 12,
            fontFamily: 'Cormorant',
            fontWeight: 6,
            color: '#FF5A5A5A',
            letterSpacing: 1.2,
          ),
        ),
        _txt(
          'cover_title',
          0.12,
          0.12,
          0.76,
          0.12,
          '우리들의 여름 제주',
          align: 'center',
          style: _textStyle(
            fontSize: 34,
            fontFamily: 'BookMyungjo',
            fontWeight: 7,
            color: '#FF134E4A',
          ),
        ),
        _img(
          'cover_main',
          0.10,
          0.28,
          0.80,
          0.48,
          frame: 'paperClipCard',
          z: 10,
        ),
        _img(
          'cover_polaroid',
          0.62,
          0.63,
          0.26,
          0.23,
          frame: 'polaroidClassic',
          rotation: -6,
          z: 12,
        ),
        _img(
          'cover_side',
          0.12,
          0.67,
          0.24,
          0.18,
          frame: 'ribbonPolaroid',
          rotation: 5,
          z: 11,
        ),
        _txt(
          'cover_bottom',
          0.18,
          0.90,
          0.64,
          0.06,
          'JEJU · BEACH · SUNSET',
          style: _textStyle(
            fontSize: 13,
            fontFamily: 'Cormorant',
            fontWeight: 6,
            color: '#FF4B5563',
            letterSpacing: 1.2,
          ),
        ),
      ],
    },
    {
      'pageNumber': 2,
      'layers': [
        _deco('p2_bg', 0.0, 0.0, 1.0, 1.0, background: 'paperWhite', z: 1),
        _txt(
          'p2_title',
          0.12,
          0.06,
          0.76,
          0.09,
          'DAY 1 · 공항에서 해변까지',
          align: 'left',
          style: _textStyle(
            fontSize: 24,
            fontFamily: 'BookMyungjo',
            fontWeight: 7,
          ),
        ),
        _img('p2_main', 0.08, 0.18, 0.84, 0.42, frame: 'tornPaperCard'),
        _img(
          'p2_left',
          0.08,
          0.65,
          0.40,
          0.24,
          frame: 'roughPolaroid',
          rotation: -3,
        ),
        _img(
          'p2_right',
          0.52,
          0.65,
          0.40,
          0.24,
          frame: 'roughPolaroid',
          rotation: 3,
        ),
      ],
    },
    {
      'pageNumber': 3,
      'layers': [
        _deco('p3_bg', 0.0, 0.0, 1.0, 1.0, background: 'paperWarm', z: 1),
        _txt(
          'p3_title',
          0.10,
          0.05,
          0.80,
          0.08,
          '오름과 바람의 날',
          style: _textStyle(
            fontSize: 23,
            fontFamily: 'BookMyungjo',
            fontWeight: 7,
          ),
        ),
        _img('p3_1', 0.06, 0.16, 0.42, 0.28, frame: 'collageTile'),
        _img('p3_2', 0.52, 0.16, 0.42, 0.28, frame: 'collageTile'),
        _img('p3_3', 0.06, 0.48, 0.28, 0.22, frame: 'collageTile'),
        _img('p3_4', 0.36, 0.48, 0.28, 0.22, frame: 'collageTile'),
        _img('p3_5', 0.66, 0.48, 0.28, 0.22, frame: 'collageTile'),
        _img('p3_6', 0.10, 0.73, 0.80, 0.20, frame: 'filmSquare'),
      ],
    },
    {
      'pageNumber': 4,
      'layers': [
        _deco('p4_bg', 0.0, 0.0, 1.0, 1.0, background: 'paperBeige', z: 1),
        _txt(
          'p4_quote',
          0.11,
          0.08,
          0.78,
          0.10,
          '파도 소리와 함께 걷던 오후',
          style: _textStyle(
            fontSize: 24,
            fontFamily: 'SeoulNamsan',
            fontWeight: 8,
            color: '#FF1F2937',
          ),
        ),
        _img('p4_main', 0.10, 0.22, 0.80, 0.54, frame: 'posterPolaroid'),
        _img(
          'p4_stamp',
          0.70,
          0.15,
          0.18,
          0.14,
          frame: 'polaroidFilm',
          rotation: 8,
          z: 13,
        ),
        _txt(
          'p4_note',
          0.15,
          0.80,
          0.70,
          0.10,
          '제주의 바람은 사진보다 오래 남았다.',
          style: _textStyle(
            fontSize: 16,
            fontFamily: 'Run',
            fontWeight: 6,
            color: '#FF4B5563',
          ),
        ),
      ],
    },
    {
      'pageNumber': 5,
      'layers': [
        _deco('p5_bg', 0.0, 0.0, 1.0, 1.0, background: 'paperWarm', z: 1),
        _txt(
          'p5_title',
          0.14,
          0.06,
          0.72,
          0.08,
          '카페 · 골목 · 노을 · 밤',
          style: _textStyle(
            fontSize: 24,
            fontFamily: 'BookMyungjo',
            fontWeight: 7,
          ),
        ),
        _img('p5_l', 0.08, 0.18, 0.40, 0.30, frame: 'photoCard', rotation: -2),
        _img('p5_r', 0.52, 0.18, 0.40, 0.30, frame: 'photoCard', rotation: 2),
        _img('p5_m', 0.20, 0.52, 0.60, 0.34, frame: 'maskingTapeFrame'),
        _txt(
          'p5_cap',
          0.23,
          0.88,
          0.54,
          0.06,
          '기억은 항상 빛났다',
          style: _textStyle(
            fontSize: 14,
            fontFamily: 'SeoulNamsan',
            fontWeight: 6,
            color: '#FF525252',
          ),
        ),
      ],
    },
    {
      'pageNumber': 6,
      'layers': [
        _deco('p6_bg', 0.0, 0.0, 1.0, 1.0, background: 'paperWhite', z: 1),
        _img('p6_main', 0.08, 0.07, 0.84, 0.56, frame: 'filmSquare'),
        _txt(
          'p6_t1',
          0.12,
          0.68,
          0.76,
          0.08,
          'DAY 3 · 해질녘 드라이브',
          style: _textStyle(
            fontSize: 22,
            fontFamily: 'Cormorant',
            fontWeight: 7,
            letterSpacing: 1.0,
          ),
        ),
        _img('p6_sub1', 0.08, 0.79, 0.26, 0.15, frame: 'collageTile'),
        _img('p6_sub2', 0.37, 0.79, 0.26, 0.15, frame: 'collageTile'),
        _img('p6_sub3', 0.66, 0.79, 0.26, 0.15, frame: 'collageTile'),
      ],
    },
    {
      'pageNumber': 7,
      'layers': [
        _deco('p7_bg', 0.0, 0.0, 1.0, 1.0, background: 'paperWarm', z: 1),
        _img(
          'p7_1',
          0.06,
          0.10,
          0.28,
          0.24,
          frame: 'polaroidClassic',
          rotation: -4,
        ),
        _img('p7_2', 0.36, 0.10, 0.28, 0.24, frame: 'polaroidClassic'),
        _img(
          'p7_3',
          0.66,
          0.10,
          0.28,
          0.24,
          frame: 'polaroidClassic',
          rotation: 4,
        ),
        _img('p7_4', 0.06, 0.38, 0.28, 0.24, frame: 'polaroidClassic'),
        _img(
          'p7_5',
          0.36,
          0.38,
          0.28,
          0.24,
          frame: 'polaroidClassic',
          rotation: -2,
        ),
        _img(
          'p7_6',
          0.66,
          0.38,
          0.28,
          0.24,
          frame: 'polaroidClassic',
          rotation: 2,
        ),
        _img(
          'p7_bottom',
          0.10,
          0.68,
          0.80,
          0.22,
          frame: 'paperTapeCard',
          rotation: -1,
        ),
        _txt(
          'p7_t',
          0.20,
          0.74,
          0.60,
          0.12,
          '우리의 제주는\n사진보다 더 선명했다',
          style: _textStyle(
            fontSize: 21,
            fontFamily: 'Run',
            fontWeight: 7,
            color: '#FF0F766E',
          ),
        ),
      ],
    },
    {
      'pageNumber': 8,
      'layers': [
        _deco('p8_bg', 0.0, 0.0, 1.0, 1.0, background: 'paperWhite', z: 1),
        _img('p8_main', 0.10, 0.10, 0.80, 0.52, frame: 'softGlow'),
        _txt(
          'p8_thanks',
          0.16,
          0.70,
          0.68,
          0.10,
          'THANK YOU, JEJU',
          style: _textStyle(
            fontSize: 30,
            fontFamily: 'Cormorant',
            fontWeight: 7,
            letterSpacing: 1.2,
            color: '#FF134E4A',
          ),
        ),
        _txt(
          'p8_date',
          0.20,
          0.82,
          0.60,
          0.06,
          '2026 · SUMMER TRIP',
          style: _textStyle(
            fontSize: 14,
            fontFamily: 'Raleway',
            fontWeight: 6,
            letterSpacing: 1.3,
            color: '#FF6B7280',
          ),
        ),
      ],
    },
  ];

  return jsonEncode({'pages': pages});
}

String _buildStoreVariantTemplateJson({
  required Map<String, String> textById,
  required Map<String, String> bgById,
  required Map<String, String> frameById,
  required String titleColor,
  required String subColor,
  required String badgeColor,
}) {
  final base =
      jsonDecode(buildJejuSummerTemplateJson()) as Map<String, dynamic>;
  final pages = (base['pages'] as List).cast<Map<String, dynamic>>();

  for (final page in pages) {
    final layers = (page['layers'] as List).cast<Map<String, dynamic>>();
    for (final layer in layers) {
      final id = (layer['id'] ?? '').toString();
      final type = (layer['type'] ?? '').toString();

      if (type == 'TEXT' && textById.containsKey(id)) {
        final payload =
            (layer['payload'] as Map<String, dynamic>? ?? <String, dynamic>{});
        payload['text'] = textById[id];
        final textStyle =
            (payload['textStyle'] as Map<String, dynamic>? ??
            <String, dynamic>{});
        if (id == 'cover_badge') {
          textStyle['color'] = badgeColor;
        } else if (id == 'cover_title' ||
            id == 'p2_title' ||
            id == 'p3_title' ||
            id == 'p4_quote' ||
            id == 'p5_title' ||
            id == 'p6_t1' ||
            id == 'p7_t' ||
            id == 'p8_thanks') {
          textStyle['color'] = titleColor;
        } else {
          textStyle['color'] = subColor;
        }
        payload['textStyle'] = textStyle;
        layer['payload'] = payload;
      }

      if (type == 'DECORATION' && bgById.containsKey(id)) {
        final payload =
            (layer['payload'] as Map<String, dynamic>? ?? <String, dynamic>{});
        payload['imageBackground'] = bgById[id];
        layer['payload'] = payload;
      }

      if (type == 'IMAGE' && frameById.containsKey(id)) {
        final payload =
            (layer['payload'] as Map<String, dynamic>? ?? <String, dynamic>{});
        payload['imageBackground'] = frameById[id];
        layer['payload'] = payload;
      }
    }
  }

  return jsonEncode({'pages': pages});
}

String buildOceanBreezeTemplateJson() => _buildStoreVariantTemplateJson(
  textById: const {
    'cover_badge': 'OCEAN BREEZE 2026',
    'cover_title': '오션 브리즈',
    'cover_bottom': 'SEA · BREEZE · VACATION',
    'p2_title': 'DAY 1 · 푸른 파도와 첫 장면',
    'p3_title': '바다 위의 작은 이야기',
    'p4_quote': '짙은 파랑은 마음을 천천히 열어준다',
    'p4_note': '바다 냄새를 따라 걷던 하루를 담았어요.',
    'p5_title': '썬셋 · 비치 · 나이트',
    'p5_cap': '우리의 여름은 파도처럼 반짝였다',
    'p6_t1': 'DAY 3 · 바람이 좋은 오후',
    'p7_t': '푸른 계절의 조각을\n한 페이지에 담다',
    'p8_thanks': 'THANK YOU, OCEAN',
    'p8_date': '2026 · OCEAN TRIP',
  },
  bgById: const {
    'cover_bg': 'softSkyBloom',
    'p2_bg': 'softSkyBloom',
    'p3_bg': 'paperWhite',
    'p4_bg': 'softSkyBloom',
    'p5_bg': 'paperWhite',
    'p6_bg': 'softSkyBloom',
    'p7_bg': 'paperWhite',
    'p8_bg': 'softSkyBloom',
  },
  frameById: const {
    'cover_main': 'softGlow',
    'cover_side': 'paperTapeCard',
    'p2_main': 'posterPolaroid',
    'p2_left': 'collageTile',
    'p2_right': 'collageTile',
  },
  titleColor: '#FF0C4A6E',
  subColor: '#FF475569',
  badgeColor: '#FF64748B',
);

String buildCityNightTemplateJson() => _buildStoreVariantTemplateJson(
  textById: const {
    'cover_badge': 'CITY LIGHT ARCHIVE',
    'cover_title': '도시의 밤',
    'cover_bottom': 'CITY · NEON · MIDNIGHT',
    'p2_title': 'NIGHT 1 · 불빛을 따라 걷다',
    'p3_title': '도시의 리듬, 밤의 온도',
    'p4_quote': '네온은 밤을 더 또렷하게 만든다',
    'p4_note': '골목마다 다른 색의 기억이 남았다.',
    'p5_title': 'LIGHT · STREET · FRAME',
    'p5_cap': '도시의 밤은 늘 영화 같았다',
    'p6_t1': 'NIGHT 3 · 새벽 직전의 풍경',
    'p7_t': '모든 불빛은\n하나의 장면이 된다',
    'p8_thanks': 'CITY NIGHT LOG',
    'p8_date': '2026 · CITY MOOD',
  },
  bgById: const {
    'cover_bg': 'paperGray',
    'p2_bg': 'paperGray',
    'p3_bg': 'paperGray',
    'p4_bg': 'darkVignette',
    'p5_bg': 'paperGray',
    'p6_bg': 'paperGray',
    'p7_bg': 'paperGray',
    'p8_bg': 'paperGray',
  },
  frameById: const {
    'cover_main': 'polaroidFilm',
    'cover_side': 'maskingTapeFrame',
    'p2_main': 'posterPolaroid',
    'p2_left': 'filmSquare',
    'p2_right': 'filmSquare',
  },
  titleColor: '#FF111827',
  subColor: '#FF374151',
  badgeColor: '#FF6B7280',
);

String buildGraduationTemplateJson() => _buildStoreVariantTemplateJson(
  textById: const {
    'cover_badge': 'GRADUATION MEMORIES',
    'cover_title': '빛나는 졸업장',
    'cover_bottom': 'CAMPUS · CLASS · CHEER',
    'p2_title': 'DAY 1 · 졸업식의 시작',
    'p3_title': '친구들과의 마지막 교정',
    'p4_quote': '끝은 언제나 새로운 시작이었다',
    'p4_note': '교복보다 선명했던 우리의 웃음.',
    'p5_title': 'CLASS · FRIENDS · MEMO',
    'p5_cap': '여기서 배운 모든 날을 기억해',
    'p6_t1': 'DAY 2 · 교정의 오후',
    'p7_t': '우리의 졸업은\n한 장면으로 끝나지 않는다',
    'p8_thanks': 'CONGRATS, GRAD',
    'p8_date': '2026 · GRADUATION',
  },
  bgById: const {
    'cover_bg': 'paperYellow',
    'p2_bg': 'paperYellow',
    'p3_bg': 'paperBeige',
    'p4_bg': 'paperYellow',
    'p5_bg': 'paperBeige',
    'p6_bg': 'paperYellow',
    'p7_bg': 'paperBeige',
    'p8_bg': 'paperYellow',
  },
  frameById: const {
    'cover_main': 'paperClipCard',
    'cover_side': 'roughPolaroid',
    'p2_main': 'paperTapeCard',
    'p2_left': 'photoCard',
    'p2_right': 'photoCard',
  },
  titleColor: '#FF7C2D12',
  subColor: '#FF6B7280',
  badgeColor: '#FF9A3412',
);

String buildFamilyTripTemplateJson() => _buildStoreVariantTemplateJson(
  textById: const {
    'cover_badge': 'FAMILY STORY BOOK',
    'cover_title': '가족 여행 일기',
    'cover_bottom': 'FAMILY · WEEKEND · LOVE',
    'p2_title': 'DAY 1 · 함께라서 더 좋았던 길',
    'p3_title': '작은 순간이 큰 기억이 되는 날',
    'p4_quote': '가족의 시간은 느리게, 따뜻하게 흐른다',
    'p4_note': '평범한 하루도 함께면 특별해진다.',
    'p5_title': 'PICNIC · TALK · SUNSET',
    'p5_cap': '서로의 표정이 가장 예쁜 풍경',
    'p6_t1': 'DAY 3 · 웃음이 멈추지 않던 저녁',
    'p7_t': '우리 가족의 오늘을\n오래 남겨둘래요',
    'p8_thanks': 'OUR FAMILY DAYS',
    'p8_date': '2026 · FAMILY TRIP',
  },
  bgById: const {
    'cover_bg': 'paperWarm',
    'p2_bg': 'paperBeige',
    'p3_bg': 'paperWarm',
    'p4_bg': 'paperBeige',
    'p5_bg': 'paperBeige',
    'p6_bg': 'paperWarm',
    'p7_bg': 'paperWarm',
    'p8_bg': 'paperBeige',
  },
  frameById: const {
    'cover_main': 'ribbonPolaroid',
    'cover_side': 'photoCard',
    'p2_main': 'paperTapeCard',
    'p2_left': 'softPaperCard',
    'p2_right': 'softPaperCard',
  },
  titleColor: '#FF14532D',
  subColor: '#FF4B5563',
  badgeColor: '#FF166534',
);

String buildEternalLoveTemplateJson() => _buildStoreVariantTemplateJson(
  textById: const {
    'cover_badge': 'ETERNAL LOVE NOTE',
    'cover_title': '이터널 러브',
    'cover_bottom': 'LOVE · PROMISE · MOMENT',
    'p2_title': 'DAY 1 · 서로를 바라본 순간',
    'p3_title': '두 사람의 계절이 겹친 날',
    'p4_quote': '사랑은 조용히, 오래 남는다',
    'p4_note': '한 장면 한 장면이 약속이 되었다.',
    'p5_title': 'LOOK · HOLD · KISS',
    'p5_cap': '우리는 같은 방향을 보고 있었다',
    'p6_t1': 'DAY 3 · 반짝이는 저녁',
    'p7_t': '우리의 사랑을\n한 권의 이야기로',
    'p8_thanks': 'FOREVER, LOVE',
    'p8_date': '2026 · LOVE STORY',
  },
  bgById: const {
    'cover_bg': 'paperPink',
    'p2_bg': 'paperPink',
    'p3_bg': 'paperPink',
    'p4_bg': 'paperBeige',
    'p5_bg': 'paperPink',
    'p6_bg': 'paperPink',
    'p7_bg': 'paperPink',
    'p8_bg': 'paperBeige',
  },
  frameById: const {
    'cover_main': 'ribbonPolaroid',
    'cover_side': 'polaroidClassic',
    'p2_main': 'posterPolaroid',
    'p2_left': 'photoCard',
    'p2_right': 'photoCard',
  },
  titleColor: '#FF9D174D',
  subColor: '#FF6B7280',
  badgeColor: '#FFBE185D',
);

String buildVintageFocusTemplateJson() => _buildStoreVariantTemplateJson(
  textById: const {
    'cover_badge': 'VINTAGE FOCUS',
    'cover_title': '빈티지 포커스',
    'cover_bottom': 'FILM · GRAIN · RETRO',
    'p2_title': 'SCENE 1 · 오래된 필름의 온도',
    'p3_title': '빛바랜 색감 속의 순간들',
    'p4_quote': '시간이 지나도 분위기는 남는다',
    'p4_note': '그레인과 대비가 만든 빈티지 감성.',
    'p5_title': 'GRAIN · FRAME · TONE',
    'p5_cap': '옛날 영화처럼 선명한 오늘',
    'p6_t1': 'SCENE 3 · 빛과 그림자의 사이',
    'p7_t': '필름 한 롤처럼\n이어진 장면들',
    'p8_thanks': 'END OF FILM',
    'p8_date': '2026 · RETRO TOUR',
  },
  bgById: const {
    'cover_bg': 'paperBrownLined',
    'p2_bg': 'paperBeige',
    'p3_bg': 'paperBrownLined',
    'p4_bg': 'paperGray',
    'p5_bg': 'paperBeige',
    'p6_bg': 'paperGray',
    'p7_bg': 'paperBrownLined',
    'p8_bg': 'paperBrownLined',
  },
  frameById: const {
    'cover_main': 'polaroidFilm',
    'cover_side': 'filmSquare',
    'p2_main': 'oldNewspaper',
    'p2_left': 'filmSquare',
    'p2_right': 'filmSquare',
  },
  titleColor: '#FF1F2937',
  subColor: '#FF4B5563',
  badgeColor: '#FF6B7280',
);

String buildRingTripStoryTemplateJson() => _buildStoreVariantTemplateJson(
  textById: const {
    'cover_badge': 'RING TRIP STORY',
    'cover_title': '링 트립 스토리',
    'cover_bottom': 'RING · TRIP · MEMORY',
    'p2_title': 'DAY 1 · 고백처럼 시작된 여행',
    'p3_title': '서로의 반지를 닮은 빛',
    'p4_quote': '작은 반짝임이 큰 약속이 되었다',
    'p4_note': '여행 끝에서 우리는 더 가까워졌다.',
    'p5_title': 'PROMISE · ROUTE · MOMENT',
    'p5_cap': '한 걸음마다 사랑이 쌓였다',
    'p6_t1': 'DAY 3 · 다시 꺼내볼 장면',
    'p7_t': '우리 둘의 하이라이트를\n지금, 한 권으로',
    'p8_thanks': 'RING TRIP LOG',
    'p8_date': '2026 · COUPLE TRIP',
  },
  bgById: const {
    'cover_bg': 'paperWarm',
    'p2_bg': 'paperWarm',
    'p3_bg': 'paperWarm',
    'p4_bg': 'paperBeige',
    'p5_bg': 'paperWarm',
    'p6_bg': 'paperWarm',
    'p7_bg': 'paperWarm',
    'p8_bg': 'paperBeige',
  },
  frameById: const {
    'cover_main': 'paperClipCard',
    'cover_side': 'maskingTapeFrame',
    'p2_main': 'paperTapeCard',
    'p2_left': 'collageTile',
    'p2_right': 'collageTile',
  },
  titleColor: '#FF0F766E',
  subColor: '#FF475569',
  badgeColor: '#FF0F766E',
);

String _buildHeroEditorialTemplateJson({
  required String coverBadge,
  required String coverTitle,
  required String coverSubtitle,
  required String bottomCaption,
}) {
  final pages = <Map<String, dynamic>>[
    {
      'pageNumber': 1,
      'layers': [
        _img('hero_cover_bg', 0.0, 0.0, 1.0, 1.0, frame: 'softGlow', z: 1),
        _txt(
          'hero_cover_badge',
          0.20,
          0.08,
          0.60,
          0.06,
          coverBadge,
          style: _textStyle(
            fontSize: 13,
            fontFamily: 'Cormorant',
            fontWeight: 7,
            color: '#FFF8FAFC',
            letterSpacing: 1.2,
          ),
        ),
        _txt(
          'hero_cover_title',
          0.10,
          0.16,
          0.80,
          0.18,
          coverTitle,
          style: _textStyle(
            fontSize: 46,
            fontFamily: 'Cormorant',
            fontWeight: 8,
            color: '#FFFFFFFF',
            letterSpacing: 0.5,
          ),
        ),
        _txt(
          'hero_cover_sub',
          0.14,
          0.78,
          0.72,
          0.10,
          coverSubtitle,
          style: _textStyle(
            fontSize: 17,
            fontFamily: 'BookMyungjo',
            fontWeight: 6,
            color: '#FFF1F5F9',
            letterSpacing: 0.3,
          ),
        ),
        _txt(
          'hero_cover_bottom',
          0.12,
          0.90,
          0.76,
          0.06,
          bottomCaption,
          style: _textStyle(
            fontSize: 12,
            fontFamily: 'Raleway',
            fontWeight: 6,
            color: '#FFE2E8F0',
            letterSpacing: 1.1,
          ),
        ),
      ],
    },
    {
      'pageNumber': 2,
      'layers': [
        _img('hero_p2_bg', 0.0, 0.0, 1.0, 1.0, frame: 'softGlow', z: 1),
        _txt(
          'hero_p2_title',
          0.12,
          0.09,
          0.76,
          0.10,
          'MEMORY CHAPTER 01',
          style: _textStyle(
            fontSize: 26,
            fontFamily: 'Cormorant',
            fontWeight: 7,
            color: '#FFFFFFFF',
            letterSpacing: 1.0,
          ),
        ),
        _img(
          'hero_p2_side_l',
          0.06,
          0.58,
          0.38,
          0.30,
          frame: 'polaroidClassic',
        ),
        _img(
          'hero_p2_side_r',
          0.56,
          0.58,
          0.38,
          0.30,
          frame: 'polaroidClassic',
        ),
      ],
    },
    {
      'pageNumber': 3,
      'layers': [
        _img('hero_p3_bg', 0.0, 0.0, 1.0, 1.0, frame: 'softGlow', z: 1),
        _txt(
          'hero_p3_title',
          0.10,
          0.74,
          0.80,
          0.10,
          'YOU & ME',
          style: _textStyle(
            fontSize: 42,
            fontFamily: 'Cormorant',
            fontWeight: 8,
            color: '#FFFFFFFF',
            letterSpacing: 0.8,
          ),
        ),
        _txt(
          'hero_p3_caption',
          0.10,
          0.86,
          0.80,
          0.06,
          'special day, special mood',
          style: _textStyle(
            fontSize: 13,
            fontFamily: 'Run',
            fontWeight: 6,
            color: '#FFF8FAFC',
            letterSpacing: 0.6,
          ),
        ),
      ],
    },
    {
      'pageNumber': 4,
      'layers': [
        _img('hero_p4_bg', 0.0, 0.0, 1.0, 1.0, frame: 'softGlow', z: 1),
        _txt(
          'hero_p4_title',
          0.12,
          0.08,
          0.76,
          0.09,
          'SCENE 04',
          style: _textStyle(
            fontSize: 22,
            fontFamily: 'Raleway',
            fontWeight: 7,
            color: '#FFF8FAFC',
            letterSpacing: 1.0,
          ),
        ),
        _img('hero_p4_frame', 0.12, 0.22, 0.76, 0.58, frame: 'paperTapeCard'),
      ],
    },
    {
      'pageNumber': 5,
      'layers': [
        _img('hero_p5_bg', 0.0, 0.0, 1.0, 1.0, frame: 'softGlow', z: 1),
        _txt(
          'hero_p5_title',
          0.10,
          0.08,
          0.80,
          0.10,
          'HIGHLIGHT CUT',
          style: _textStyle(
            fontSize: 28,
            fontFamily: 'Cormorant',
            fontWeight: 8,
            color: '#FFFFFFFF',
            letterSpacing: 0.8,
          ),
        ),
        _img('hero_p5_a', 0.08, 0.24, 0.40, 0.26, frame: 'collageTile'),
        _img('hero_p5_b', 0.52, 0.24, 0.40, 0.26, frame: 'collageTile'),
        _img('hero_p5_c', 0.08, 0.54, 0.84, 0.34, frame: 'paperClipCard'),
      ],
    },
    {
      'pageNumber': 6,
      'layers': [
        _img('hero_p6_bg', 0.0, 0.0, 1.0, 1.0, frame: 'softGlow', z: 1),
        _txt(
          'hero_p6_quote',
          0.12,
          0.76,
          0.76,
          0.12,
          'The best moments\nstay in one page.',
          style: _textStyle(
            fontSize: 26,
            fontFamily: 'BookMyungjo',
            fontWeight: 7,
            color: '#FFFFFFFF',
          ),
        ),
      ],
    },
    {
      'pageNumber': 7,
      'layers': [
        _img('hero_p7_bg', 0.0, 0.0, 1.0, 1.0, frame: 'softGlow', z: 1),
        _img('hero_p7_card', 0.10, 0.18, 0.80, 0.64, frame: 'posterPolaroid'),
        _txt(
          'hero_p7_caption',
          0.16,
          0.84,
          0.68,
          0.07,
          'SNAPFIT POSTER EDITION',
          style: _textStyle(
            fontSize: 12,
            fontFamily: 'Raleway',
            fontWeight: 7,
            color: '#FFF8FAFC',
            letterSpacing: 1.1,
          ),
        ),
      ],
    },
    {
      'pageNumber': 8,
      'layers': [
        _img('hero_p8_bg', 0.0, 0.0, 1.0, 1.0, frame: 'softGlow', z: 1),
        _txt(
          'hero_p8_title',
          0.12,
          0.70,
          0.76,
          0.12,
          'THANK YOU',
          style: _textStyle(
            fontSize: 44,
            fontFamily: 'Cormorant',
            fontWeight: 8,
            color: '#FFFFFFFF',
            letterSpacing: 1.0,
          ),
        ),
        _txt(
          'hero_p8_sub',
          0.16,
          0.84,
          0.68,
          0.06,
          'made by SNAPFIT template studio',
          style: _textStyle(
            fontSize: 12,
            fontFamily: 'Run',
            fontWeight: 6,
            color: '#FFE2E8F0',
            letterSpacing: 0.8,
          ),
        ),
      ],
    },
  ];
  return jsonEncode({'pages': pages});
}

int _stableRandomPageCount(int templateId) {
  final seed = (templateId.abs() * 2654435761) & 0x7fffffff;
  return 12 + (seed % 13); // 12..24
}

Map<String, dynamic> _cloneJsonMap(Map<String, dynamic> value) {
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

Map<String, dynamic> _extraStickerLayer({
  required String id,
  required double x,
  required double y,
  required double w,
  required double h,
  required String sticker,
  double rotation = 0,
  int zIndex = 30,
}) {
  return {
    'id': id,
    'type': 'DECORATION',
    'x': x,
    'y': y,
    'width': w,
    'height': h,
    'rotation': rotation,
    'opacity': 1.0,
    'scale': 1.0,
    'zIndex': zIndex,
    'payload': {'imageBackground': sticker, 'imageTemplate': 'free'},
  };
}

class _StoreMood {
  final List<String> frames;
  final List<String> pageBackgrounds;
  final List<String> stickers;
  final String titleColor;
  final String bodyColor;
  final String accentColor;
  final String titleFontFamily;
  final String bodyFontFamily;
  final String accentFontFamily;
  final double titleLetterSpacing;
  final double imageRotationMax;
  final bool useDualStickers;

  const _StoreMood({
    required this.frames,
    required this.pageBackgrounds,
    required this.stickers,
    required this.titleColor,
    required this.bodyColor,
    required this.accentColor,
    required this.titleFontFamily,
    required this.bodyFontFamily,
    required this.accentFontFamily,
    required this.titleLetterSpacing,
    this.imageRotationMax = 2.0,
    this.useDualStickers = false,
  });
}

_StoreMood _moodForVariant(String variantKey) {
  switch (variantKey) {
    case 'ocean':
      return const _StoreMood(
        frames: ['softGlow', 'posterPolaroid', 'collageTile', 'photoCard'],
        pageBackgrounds: [
          'softSkyBloom',
          'paperWhite',
          'softSkyBloom',
          'paperWhite',
        ],
        stickers: [
          'stickerCloudSoft',
          'stickerSparkleBlue',
          'stickerStarGold',
          'stickerTapeDotsBlue',
        ],
        titleColor: '#FF0C4A6E',
        bodyColor: '#FF35516B',
        accentColor: '#FF3B82F6',
        titleFontFamily: 'Raleway',
        bodyFontFamily: 'Raleway',
        accentFontFamily: 'Raleway',
        titleLetterSpacing: 0.6,
        imageRotationMax: 1.4,
      );
    case 'city':
      return const _StoreMood(
        frames: ['polaroidFilm', 'filmSquare', 'posterPolaroid', 'collageTile'],
        pageBackgrounds: [
          'paperGray',
          'darkVignette',
          'paperGray',
          'paperGray',
        ],
        stickers: [
          'stickerSparkleGold',
          'stickerPaperClip',
          'stickerArrowCoral',
          'stickerTapeStripePink',
        ],
        titleColor: '#FFF3F4F6',
        bodyColor: '#FFE5E7EB',
        accentColor: '#FFFACC15',
        titleFontFamily: 'Raleway',
        bodyFontFamily: 'Raleway',
        accentFontFamily: 'Cormorant',
        titleLetterSpacing: 0.8,
        imageRotationMax: 1.2,
      );
    case 'graduation':
      return const _StoreMood(
        frames: ['paperClipCard', 'paperTapeCard', 'photoCard', 'softGlow'],
        pageBackgrounds: [
          'paperYellow',
          'paperBeige',
          'paperYellow',
          'paperBeige',
        ],
        stickers: [
          'stickerRibbonBlue',
          'stickerStarGold',
          'stickerTapeBeige',
          'stickerTicketPaper',
        ],
        titleColor: '#FF7C2D12',
        bodyColor: '#FF6B4A1F',
        accentColor: '#FFF59E0B',
        titleFontFamily: 'Raleway',
        bodyFontFamily: 'Raleway',
        accentFontFamily: 'Raleway',
        titleLetterSpacing: 0.4,
        imageRotationMax: 1.8,
        useDualStickers: true,
      );
    case 'family':
      return const _StoreMood(
        frames: ['ribbonPolaroid', 'paperTapeCard', 'collageTile', 'photoCard'],
        pageBackgrounds: ['paperWarm', 'paperBeige', 'paperWarm', 'paperBeige'],
        stickers: [
          'stickerFlowerCoral',
          'stickerHeartPink',
          'stickerCloverGreen',
          'stickerEnvelopeBlue',
        ],
        titleColor: '#FF14532D',
        bodyColor: '#FF35573D',
        accentColor: '#FF22C55E',
        titleFontFamily: 'Raleway',
        bodyFontFamily: 'Raleway',
        accentFontFamily: 'Raleway',
        titleLetterSpacing: 0.3,
        imageRotationMax: 1.6,
        useDualStickers: true,
      );
    case 'eternal':
      return const _StoreMood(
        frames: ['ribbonPolaroid', 'posterPolaroid', 'photoCard', 'softGlow'],
        pageBackgrounds: ['paperPink', 'paperBeige', 'paperPink', 'paperBeige'],
        stickers: [
          'stickerHeartPink',
          'stickerFlowerPink',
          'stickerSparkleGold',
          'stickerBowPink',
        ],
        titleColor: '#FF9D174D',
        bodyColor: '#FF7A2E58',
        accentColor: '#FFF472B6',
        titleFontFamily: 'Raleway',
        bodyFontFamily: 'Raleway',
        accentFontFamily: 'Raleway',
        titleLetterSpacing: 0.5,
        imageRotationMax: 1.6,
      );
    case 'vintage':
      return const _StoreMood(
        frames: ['polaroidFilm', 'filmSquare', 'oldNewspaper', 'photoCard'],
        pageBackgrounds: [
          'paperBrownLined',
          'paperGray',
          'paperBrownLined',
          'paperBeige',
        ],
        stickers: [
          'stickerPaperClip',
          'stickerTapeBeige',
          'stickerTicketPaper',
          'stickerScribbleBlue',
        ],
        titleColor: '#FF3B2F2A',
        bodyColor: '#FF5A4B44',
        accentColor: '#FFC4A484',
        titleFontFamily: 'Raleway',
        bodyFontFamily: 'Raleway',
        accentFontFamily: 'Cormorant',
        titleLetterSpacing: 0.5,
        imageRotationMax: 1.2,
      );
    case 'ring':
      return const _StoreMood(
        frames: [
          'paperClipCard',
          'maskingTapeFrame',
          'collageTile',
          'photoCard',
        ],
        pageBackgrounds: ['paperWarm', 'paperBeige', 'paperWarm', 'paperBeige'],
        stickers: [
          'stickerHeartPink',
          'stickerFlowerCoral',
          'stickerSparkleBlue',
          'stickerRibbonBlue',
        ],
        titleColor: '#FF0F766E',
        bodyColor: '#FF3D5D58',
        accentColor: '#FF2DD4BF',
        titleFontFamily: 'Raleway',
        bodyFontFamily: 'Raleway',
        accentFontFamily: 'Raleway',
        titleLetterSpacing: 0.5,
        imageRotationMax: 1.6,
      );
    case 'jeju':
    default:
      return const _StoreMood(
        frames: [
          'paperClipCard',
          'polaroidClassic',
          'paperTapeCard',
          'collageTile',
        ],
        pageBackgrounds: ['paperWarm', 'paperBeige', 'paperWarm', 'paperBeige'],
        stickers: [
          'stickerFlowerCoral',
          'stickerSparkleGold',
          'stickerCloudSoft',
          'stickerTapeStripePink',
        ],
        titleColor: '#FF134E4A',
        bodyColor: '#FF3F5A58',
        accentColor: '#FFF59E0B',
        titleFontFamily: 'Raleway',
        bodyFontFamily: 'Raleway',
        accentFontFamily: 'Raleway',
        titleLetterSpacing: 0.4,
        imageRotationMax: 1.8,
        useDualStickers: true,
      );
  }
}

String _coverTopBandBackground(String variantKey) {
  switch (variantKey) {
    case 'city':
    case 'vintage':
      return 'paperGray';
    case 'eternal':
      return 'paperPink';
    default:
      return 'paperYellow';
  }
}

String _coverStyleModeForVariant(String variantKey) {
  switch (variantKey) {
    case 'eternal':
      return 'wedding_clean';
    case 'ring':
      return 'save_date';
    case 'ocean':
    case 'city':
    case 'vintage':
    case 'jeju':
    case 'graduation':
    case 'family':
    default:
      return 'summer_poster';
  }
}

String _coverBottomBandBackground(String variantKey) {
  switch (variantKey) {
    case 'city':
      return 'darkVignette';
    case 'vintage':
      return 'paperBrownLined';
    default:
      return 'paperWhite';
  }
}

String _coverTitleColor(String variantKey) {
  switch (variantKey) {
    case 'city':
    case 'vintage':
      return '#FFF8FAFC';
    default:
      return '#FF0F172A';
  }
}

String _coverCaptionColor(String variantKey) {
  switch (variantKey) {
    case 'city':
    case 'vintage':
      return '#FFE2E8F0';
    default:
      return '#FF334155';
  }
}

void _applyGeneratedPageLayoutQuality({
  required List<Map<String, dynamic>> layers,
  required int pageIndex,
  required _StoreMood mood,
  required String variantKey,
}) {
  final imageLayers = layers
      .where((layer) => (layer['type']?.toString() ?? '') == 'IMAGE')
      .toList();
  if (imageLayers.isEmpty) return;

  final styleIndex = pageIndex % 6;
  final patterns = <List<Map<String, double>>>[
    // Editorial split
    [
      {'x': 0.08, 'y': 0.14, 'w': 0.54, 'h': 0.48},
      {'x': 0.64, 'y': 0.16, 'w': 0.28, 'h': 0.30},
      {'x': 0.62, 'y': 0.50, 'w': 0.30, 'h': 0.34},
      {'x': 0.08, 'y': 0.66, 'w': 0.50, 'h': 0.24},
    ],
    // Hero + 2 cards
    [
      {'x': 0.10, 'y': 0.12, 'w': 0.80, 'h': 0.42},
      {'x': 0.10, 'y': 0.58, 'w': 0.38, 'h': 0.28},
      {'x': 0.52, 'y': 0.58, 'w': 0.38, 'h': 0.28},
    ],
    // Vertical magazine
    [
      {'x': 0.06, 'y': 0.16, 'w': 0.42, 'h': 0.62},
      {'x': 0.52, 'y': 0.16, 'w': 0.42, 'h': 0.30},
      {'x': 0.52, 'y': 0.50, 'w': 0.42, 'h': 0.28},
    ],
    // Big photo + footer rail
    [
      {'x': 0.08, 'y': 0.18, 'w': 0.84, 'h': 0.54},
      {'x': 0.14, 'y': 0.75, 'w': 0.30, 'h': 0.16},
      {'x': 0.46, 'y': 0.75, 'w': 0.40, 'h': 0.16},
    ],
    // Mosaic collage
    [
      {'x': 0.08, 'y': 0.16, 'w': 0.40, 'h': 0.30},
      {'x': 0.52, 'y': 0.16, 'w': 0.40, 'h': 0.30},
      {'x': 0.08, 'y': 0.50, 'w': 0.26, 'h': 0.22},
      {'x': 0.36, 'y': 0.50, 'w': 0.26, 'h': 0.22},
      {'x': 0.64, 'y': 0.50, 'w': 0.28, 'h': 0.22},
    ],
    // Poster-style full with floating photos
    [
      {'x': 0.06, 'y': 0.14, 'w': 0.88, 'h': 0.64},
      {'x': 0.14, 'y': 0.70, 'w': 0.26, 'h': 0.18},
      {'x': 0.62, 'y': 0.68, 'w': 0.24, 'h': 0.18},
    ],
  ];
  final pattern = patterns[styleIndex % patterns.length];
  final titleLexicon = <String, List<String>>{
    'jeju': ['여름의 파도', '해질녘 산책', '바람의 기억', '제주의 하루'],
    'ocean': ['Ocean Mood', 'Blue Horizon', 'Wave Diary', 'Sea Story'],
    'city': ['CITY ARCHIVE', 'NIGHT MOTION', 'URBAN FRAME', 'NEON MOMENT'],
    'graduation': ['우리의 졸업', '캠퍼스 데이', '빛나는 장면', '청춘의 페이지'],
    'family': ['가족의 장면', '우리의 주말', '함께한 순간', '따뜻한 기록'],
    'eternal': ['LOVE SCENE', 'ROMANTIC DAY', 'FOREVER START', '우리의 약속'],
    'vintage': ['RETRO DIARY', 'FILM SCENE', 'VINTAGE CUT', 'OLD BUT GOLD'],
    'ring': ['RING MOMENT', 'COUPLE TRIP', 'OUR HIGHLIGHT', 'LOVE ROUTE'],
  };
  final quoteLexicon = <String, List<String>>{
    'jeju': ['오늘의 온도를 기록해요', '빛과 바람을 담은 장면'],
    'ocean': ['파도 위로 스친 여름', '푸른 무드의 한 장면'],
    'city': ['도시의 리듬을 수집하다', '밤의 결을 기록하다'],
    'graduation': ['청춘은 페이지로 남는다', '한 챕터의 마지막, 새로운 시작'],
    'family': ['서로의 웃음이 풍경이 되는 날', '평범한 하루가 특별한 기억'],
    'eternal': ['두 사람의 계절을 담다', '사랑은 장면이 되어 남는다'],
    'vintage': ['빛바랜 톤의 감성 아카이브', '필름처럼 번지는 기억'],
    'ring': ['작은 반짝임이 큰 약속이 되는 순간', '우리 둘의 하이라이트를 남겨요'],
  };
  final titles = titleLexicon[variantKey] ?? titleLexicon['jeju']!;
  final quotes = quoteLexicon[variantKey] ?? quoteLexicon['jeju']!;
  final dynamicTitle = titles[pageIndex % titles.length];
  final dynamicQuote = quotes[pageIndex % quotes.length];

  for (var i = 0; i < imageLayers.length; i++) {
    final layer = imageLayers[i];
    final rect = pattern[i % pattern.length];
    layer['x'] = rect['x'];
    layer['y'] = rect['y'];
    layer['width'] = rect['w'];
    layer['height'] = rect['h'];
    final rotation = mood.imageRotationMax.clamp(0.8, 2.2);
    layer['rotation'] = i == 0
        ? 0.0
        : ((styleIndex + i).isEven ? -rotation : rotation);
    layer['zIndex'] = 10 + i;
    final payload =
        (layer['payload'] as Map<String, dynamic>? ?? <String, dynamic>{});
    payload['imageBackground'] =
        mood.frames[(pageIndex + i) % mood.frames.length];
    layer['payload'] = payload;
  }

  if (imageLayers.length == 1) {
    final leadPayload =
        (imageLayers.first['payload'] as Map<String, dynamic>? ??
        <String, dynamic>{});
    final leadUrl =
        (leadPayload['previewUrl'] ??
                leadPayload['imageUrl'] ??
                leadPayload['originalUrl'])
            ?.toString();
    if (leadUrl != null && leadUrl.isNotEmpty) {
      layers.add({
        'id': 'auto_extra_img_a_p$pageIndex',
        'type': 'IMAGE',
        'x': 0.08,
        'y': 0.68,
        'width': 0.34,
        'height': 0.22,
        'rotation': -3.0,
        'opacity': 1.0,
        'scale': 1.0,
        'zIndex': 22,
        'payload': {
          'imageBackground': mood.frames[(pageIndex + 1) % mood.frames.length],
          'imageTemplate': 'free',
          'imageUrl': leadUrl,
          'previewUrl': leadUrl,
          'originalUrl': leadUrl,
        },
      });
      layers.add({
        'id': 'auto_extra_img_b_p$pageIndex',
        'type': 'IMAGE',
        'x': 0.58,
        'y': 0.70,
        'width': 0.32,
        'height': 0.20,
        'rotation': 2.5,
        'opacity': 1.0,
        'scale': 1.0,
        'zIndex': 21,
        'payload': {
          'imageBackground': mood.frames[(pageIndex + 2) % mood.frames.length],
          'imageTemplate': 'free',
          'imageUrl': leadUrl,
          'previewUrl': leadUrl,
          'originalUrl': leadUrl,
        },
      });
    }
  }

  final textLayers = layers
      .where((layer) => (layer['type']?.toString() ?? '') == 'TEXT')
      .toList();
  if (textLayers.isNotEmpty) {
    final titleLayer = textLayers.first;
    titleLayer['x'] = 0.10;
    titleLayer['y'] = 0.04;
    titleLayer['width'] = 0.80;
    titleLayer['height'] = 0.10;
    titleLayer['zIndex'] = 40;
    final payload =
        (titleLayer['payload'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final style =
        (payload['textStyle'] as Map<String, dynamic>? ?? <String, dynamic>{});
    style['fontSize'] = styleIndex == 5 ? 26.0 : 22.0;
    style['fontWeight'] = 7;
    style['color'] = mood.titleColor;
    style['fontFamily'] = mood.titleFontFamily;
    style['letterSpacing'] = mood.titleLetterSpacing;
    payload['textStyle'] = style;
    payload['text'] = dynamicTitle;
    titleLayer['payload'] = payload;
  }

  layers.add({
    'id': 'auto_caption_band_p$pageIndex',
    'type': 'DECORATION',
    'x': 0.08,
    'y': 0.90,
    'width': 0.84,
    'height': 0.06,
    'rotation': 0.0,
    'opacity': 1.0,
    'scale': 1.0,
    'zIndex': 35,
    'payload': {
      'imageBackground':
          mood.pageBackgrounds[(pageIndex + 1) % mood.pageBackgrounds.length],
      'imageTemplate': 'free',
    },
  });
  layers.add({
    'id': 'auto_caption_text_p$pageIndex',
    'type': 'TEXT',
    'x': 0.10,
    'y': 0.905,
    'width': 0.80,
    'height': 0.05,
    'rotation': 0.0,
    'opacity': 1.0,
    'scale': 1.0,
    'zIndex': 42,
    'payload': {
      'text': '#${(pageIndex + 1).toString().padLeft(2, '0')}  SNAPFIT EDIT',
      'textAlign': 'center',
      'textStyleType': 'none',
      'textBackground': null,
      'textStyle': {
        'fontSize': 12.0,
        'fontSizeRatio': 12.0 / 1080.0,
        'fontWeight': 6,
        'fontFamily': mood.accentFontFamily,
        'color': mood.accentColor,
        'letterSpacing': 0.9,
      },
    },
  });

  layers.add({
    'id': 'auto_quote_text_p$pageIndex',
    'type': 'TEXT',
    'x': 0.12,
    'y': 0.84,
    'width': 0.76,
    'height': 0.06,
    'rotation': 0.0,
    'opacity': 1.0,
    'scale': 1.0,
    'zIndex': 43,
    'payload': {
      'text': dynamicQuote,
      'textAlign': 'center',
      'textStyleType': 'none',
      'textBackground': null,
      'textStyle': {
        'fontSize': 11.0,
        'fontSizeRatio': 11.0 / 1080.0,
        'fontWeight': 5,
        'fontFamily': mood.bodyFontFamily,
        'color': mood.bodyColor,
        'letterSpacing': 0.3,
      },
    },
  });
}

String _buildStoreTemplateWithPages({
  required String baseTemplateJson,
  required int targetPageCount,
  required String variantKey,
  required List<String> imagePool,
  required String style,
  required String mood,
  required int difficulty,
  required int recommendedPhotoCount,
  required List<String> sourceBottomSheetTemplateIds,
  Map<String, dynamic>? heroTextSafeArea,
}) {
  const designWidth = 1080.0;
  const designHeight = 1350.0;
  final moodProfile = _moodForVariant(variantKey);
  final decoded = jsonDecode(baseTemplateJson) as Map<String, dynamic>;
  final rawPages = (decoded['pages'] as List<dynamic>? ?? const []);
  final basePages = rawPages.cast<Map<String, dynamic>>();
  if (basePages.isEmpty) return baseTemplateJson;
  final stickerSlots = <Map<String, double>>[
    {'x': 0.03, 'y': 0.06, 'w': 0.09, 'h': 0.09},
    {'x': 0.89, 'y': 0.07, 'w': 0.08, 'h': 0.08},
    {'x': 0.06, 'y': 0.84, 'w': 0.09, 'h': 0.09},
    {'x': 0.86, 'y': 0.82, 'w': 0.10, 'h': 0.10},
    {'x': 0.44, 'y': 0.09, 'w': 0.12, 'h': 0.05},
  ];

  final validImages = imagePool
      .asMap()
      .entries
      .map(
        (e) => _sanitizeNetworkImageUrl(
          e.value,
          seed: '${variantKey}_pool_${e.key}',
        ),
      )
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  final fallbackImages = <String>[
    'https://picsum.photos/id/1015/1200/900',
    'https://picsum.photos/id/1016/1200/900',
    'https://picsum.photos/id/1025/1200/900',
    'https://picsum.photos/id/1035/1200/900',
    'https://picsum.photos/id/1040/1200/900',
  ];
  final images = validImages.isEmpty ? fallbackImages : validImages;

  var imageCursor = 0;
  final generatedPages = <Map<String, dynamic>>[];
  final safeCount = targetPageCount.clamp(12, 24);

  for (var pageIndex = 0; pageIndex < safeCount; pageIndex++) {
    final coverStyleMode = _coverStyleModeForVariant(variantKey);
    final source = _cloneJsonMap(basePages[pageIndex % basePages.length]);
    source['pageNumber'] = pageIndex + 1;
    final rawLayers = (source['layers'] as List<dynamic>? ?? const []);
    final updatedLayers = <Map<String, dynamic>>[];

    for (final rawLayer in rawLayers) {
      if (rawLayer is! Map) continue;
      final layer = _cloneJsonMap(
        rawLayer.map((key, value) => MapEntry(key.toString(), value)),
      );
      final originalId = (layer['id'] ?? 'layer').toString();
      layer['id'] = '${originalId}_${variantKey}_p${pageIndex + 1}';
      final type = (layer['type'] ?? '').toString();

      if (type == 'IMAGE') {
        final payload =
            (layer['payload'] as Map<String, dynamic>? ?? <String, dynamic>{});
        final imageUrl = images[imageCursor % images.length];
        imageCursor++;
        payload['imageUrl'] = imageUrl;
        payload['previewUrl'] = imageUrl;
        payload['originalUrl'] = imageUrl;
        if (pageIndex >= basePages.length) {
          payload['imageBackground'] = moodProfile
              .frames[(pageIndex + imageCursor) % moodProfile.frames.length];
        }
        layer['payload'] = payload;
        if (pageIndex == 0) {
          final lowerId = originalId.toLowerCase();
          final isCoverMain =
              lowerId.contains('cover_main') ||
              lowerId.contains('hero_cover_bg');
          if (isCoverMain) {
            layer['x'] = 0.0;
            layer['y'] = coverStyleMode == 'summer_poster' ? 0.18 : 0.0;
            layer['width'] = 1.0;
            layer['height'] = coverStyleMode == 'summer_poster' ? 0.72 : 1.0;
            layer['rotation'] = 0.0;
            layer['zIndex'] = 8;
            payload['imageBackground'] = '';
            layer['payload'] = payload;
          } else if (lowerId.contains('cover') ||
              lowerId.contains('hero_cover')) {
            // Cover is modernized to single hero image + typography.
            layer['opacity'] = 0.0;
            layer['scale'] = 0.0;
            layer['zIndex'] = 2;
          }
        }
      } else if (type == 'DECORATION') {
        final payload =
            (layer['payload'] as Map<String, dynamic>? ?? <String, dynamic>{});
        final decoration = (payload['imageBackground'] ?? '').toString();
        if (originalId.contains('bg') || decoration.startsWith('paper')) {
          payload['imageBackground'] =
              moodProfile.pageBackgrounds[(pageIndex + imageCursor) %
                  moodProfile.pageBackgrounds.length];
        }
        layer['payload'] = payload;
        if (pageIndex == 0) {
          final lowerId = originalId.toLowerCase();
          if (lowerId.contains('cover_bg') ||
              lowerId.contains('hero_cover_bg')) {
            payload['imageBackground'] = 'softSkyBloom';
            layer['payload'] = payload;
            layer['x'] = 0.0;
            layer['y'] = coverStyleMode == 'summer_poster' ? 0.18 : 0.0;
            layer['width'] = 1.0;
            layer['height'] = coverStyleMode == 'summer_poster' ? 0.72 : 1.0;
            layer['zIndex'] = 7;
          }
        }
      } else if (type == 'TEXT') {
        final payload =
            (layer['payload'] as Map<String, dynamic>? ?? <String, dynamic>{});
        final textStyle =
            (payload['textStyle'] as Map<String, dynamic>? ??
            <String, dynamic>{});
        final lowerId = originalId.toLowerCase();
        final isTitle =
            originalId.contains('title') ||
            originalId.contains('quote') ||
            originalId.contains('thanks');
        final isAccent =
            originalId.contains('badge') ||
            originalId.contains('date') ||
            originalId.contains('cap');
        textStyle['color'] = isTitle
            ? moodProfile.titleColor
            : (isAccent ? moodProfile.accentColor : moodProfile.bodyColor);
        textStyle['fontFamily'] = isTitle
            ? moodProfile.titleFontFamily
            : (isAccent
                  ? moodProfile.accentFontFamily
                  : moodProfile.bodyFontFamily);
        if (isTitle) {
          textStyle['letterSpacing'] = moodProfile.titleLetterSpacing;
        }
        if (pageIndex == 0) {
          if (coverStyleMode == 'wedding_clean') {
            if (lowerId.contains('cover_title')) {
              layer['x'] = 0.08;
              layer['y'] = 0.40;
              layer['width'] = 0.84;
              layer['height'] = 0.16;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'center';
              textStyle['fontFamily'] = 'Cormorant';
              textStyle['fontSize'] = 46.0;
              textStyle['fontWeight'] = 8;
              textStyle['letterSpacing'] = 0.6;
              textStyle['color'] = '#FFFFFFFF';
            } else if (lowerId.contains('cover_badge')) {
              layer['x'] = 0.24;
              layer['y'] = 0.33;
              layer['width'] = 0.52;
              layer['height'] = 0.05;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'center';
              textStyle['fontFamily'] = 'Raleway';
              textStyle['fontSize'] = 11.0;
              textStyle['fontWeight'] = 7;
              textStyle['letterSpacing'] = 0.6;
              textStyle['color'] = '#FFE5E7EB';
            } else if (lowerId.contains('cover_sub')) {
              layer['x'] = 0.08;
              layer['y'] = 0.79;
              layer['width'] = 0.36;
              layer['height'] = 0.10;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'left';
              textStyle['fontFamily'] = 'Raleway';
              textStyle['fontSize'] = 10.5;
              textStyle['fontWeight'] = 7;
              textStyle['letterSpacing'] = 0.4;
              textStyle['color'] = '#FFF8FAFC';
            } else if (lowerId.contains('cover_bottom')) {
              layer['x'] = 0.56;
              layer['y'] = 0.79;
              layer['width'] = 0.36;
              layer['height'] = 0.10;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'right';
              textStyle['fontFamily'] = 'Raleway';
              textStyle['fontSize'] = 10.5;
              textStyle['fontWeight'] = 7;
              textStyle['letterSpacing'] = 0.4;
              textStyle['color'] = '#FFF8FAFC';
            }
          } else if (coverStyleMode == 'save_date') {
            if (lowerId.contains('cover_title')) {
              layer['x'] = 0.14;
              layer['y'] = 0.52;
              layer['width'] = 0.72;
              layer['height'] = 0.16;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'center';
              textStyle['fontFamily'] = 'Raleway';
              textStyle['fontSize'] = 54.0;
              textStyle['fontWeight'] = 9;
              textStyle['letterSpacing'] = 0.8;
              textStyle['color'] = '#FFFFFFFF';
              final currentText = (payload['text'] ?? '').toString();
              if (RegExp(r'^[A-Za-z0-9 .,&!:-]+$').hasMatch(currentText)) {
                payload['text'] = currentText.toUpperCase();
              }
            } else if (lowerId.contains('cover_badge')) {
              layer['x'] = 0.24;
              layer['y'] = 0.06;
              layer['width'] = 0.52;
              layer['height'] = 0.05;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'center';
              textStyle['fontFamily'] = 'Raleway';
              textStyle['fontSize'] = 10.5;
              textStyle['fontWeight'] = 7;
              textStyle['letterSpacing'] = 1.0;
              textStyle['color'] = '#FFF8FAFC';
            } else if (lowerId.contains('cover_sub')) {
              layer['x'] = 0.22;
              layer['y'] = 0.70;
              layer['width'] = 0.56;
              layer['height'] = 0.08;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'center';
              textStyle['fontFamily'] = 'Raleway';
              textStyle['fontSize'] = 13.0;
              textStyle['fontWeight'] = 7;
              textStyle['letterSpacing'] = 0.4;
              textStyle['color'] = '#FFFFFFFF';
            } else if (lowerId.contains('cover_bottom')) {
              layer['x'] = 0.12;
              layer['y'] = 0.80;
              layer['width'] = 0.76;
              layer['height'] = 0.08;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'center';
              textStyle['fontFamily'] = 'Raleway';
              textStyle['fontSize'] = 10.5;
              textStyle['fontWeight'] = 6;
              textStyle['letterSpacing'] = 0.5;
              textStyle['color'] = '#FFE2E8F0';
            }
          } else {
            if (lowerId.contains('cover_title')) {
              layer['x'] = 0.06;
              layer['y'] = 0.015;
              layer['width'] = 0.88;
              layer['height'] = 0.14;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'center';
              textStyle['fontFamily'] = 'Raleway';
              textStyle['fontSize'] = 52.0;
              textStyle['fontWeight'] = 9;
              textStyle['letterSpacing'] = 1.8;
              textStyle['color'] = _coverTitleColor(variantKey);
              final currentText = (payload['text'] ?? '').toString();
              if (RegExp(r'^[A-Za-z0-9 .,&!:-]+$').hasMatch(currentText)) {
                payload['text'] = currentText.toUpperCase();
              }
            } else if (lowerId.contains('cover_badge')) {
              layer['x'] = 0.08;
              layer['y'] = 0.18;
              layer['width'] = 0.84;
              layer['height'] = 0.05;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'left';
              textStyle['fontFamily'] = 'Raleway';
              textStyle['fontSize'] = 12.0;
              textStyle['fontWeight'] = 7;
              textStyle['letterSpacing'] = 0.9;
              textStyle['color'] = _coverCaptionColor(variantKey);
            } else if (lowerId.contains('cover_sub')) {
              layer['x'] = 0.08;
              layer['y'] = 0.71;
              layer['width'] = 0.84;
              layer['height'] = 0.12;
              layer['zIndex'] = 40;
              payload['textAlign'] = 'right';
              textStyle['fontFamily'] = 'Cormorant';
              textStyle['fontSize'] = 18.0;
              textStyle['fontWeight'] = 6;
              textStyle['letterSpacing'] = 0.4;
              textStyle['color'] = '#FFF8FAFC';
            } else if (lowerId.contains('cover_bottom')) {
              layer['x'] = 0.08;
              layer['y'] = 0.92;
              layer['width'] = 0.84;
              layer['height'] = 0.05;
              layer['zIndex'] = 41;
              payload['textAlign'] = 'center';
              textStyle['fontFamily'] = 'Raleway';
              textStyle['fontSize'] = 12.0;
              textStyle['fontWeight'] = 7;
              textStyle['letterSpacing'] = 1.2;
              textStyle['color'] = _coverCaptionColor(variantKey);
            }
          }
        }
        if (variantKey == 'city' && isTitle) {
          textStyle['fontWeight'] = 7;
        }
        if (!originalId.contains('cover') && pageIndex >= basePages.length) {
          final currentText = (payload['text'] ?? '').toString();
          if (originalId.contains('title') || originalId.contains('quote')) {
            payload['text'] = '$currentText · ${pageIndex + 1}P';
          }
          final currentSize = (textStyle['fontSize'] as num?)?.toDouble() ?? 18;
          textStyle['fontSize'] = (currentSize * 0.96).clamp(12, 36);
        }
        final fontSize = (textStyle['fontSize'] as num?)?.toDouble() ?? 16.0;
        textStyle['fontSizeRatio'] = (fontSize / designWidth).clamp(0.001, 1.0);
        payload['textStyle'] = textStyle;
        layer['payload'] = payload;
      }

      updatedLayers.add(layer);
    }

    if (pageIndex == 0 && coverStyleMode == 'summer_poster') {
      updatedLayers.add({
        'id': 'auto_cover_top_band_${variantKey}_${pageIndex + 1}',
        'type': 'DECORATION',
        'x': 0.0,
        'y': 0.0,
        'width': 1.0,
        'height': 0.18,
        'rotation': 0.0,
        'opacity': 1.0,
        'scale': 1.0,
        'zIndex': 6,
        'payload': {
          'imageBackground': _coverTopBandBackground(variantKey),
          'imageTemplate': 'free',
        },
      });
      updatedLayers.add({
        'id': 'auto_cover_bottom_band_${variantKey}_${pageIndex + 1}',
        'type': 'DECORATION',
        'x': 0.0,
        'y': 0.90,
        'width': 1.0,
        'height': 0.10,
        'rotation': 0.0,
        'opacity': 1.0,
        'scale': 1.0,
        'zIndex': 6,
        'payload': {
          'imageBackground': _coverBottomBandBackground(variantKey),
          'imageTemplate': 'free',
        },
      });
    }

    if (pageIndex > 0) {
      _applyGeneratedPageLayoutQuality(
        layers: updatedLayers,
        pageIndex: pageIndex,
        mood: moodProfile,
        variantKey: variantKey,
      );
    }

    if (moodProfile.useDualStickers && pageIndex > 0 && pageIndex % 4 == 0) {
      final stickerSlotA = stickerSlots[pageIndex % stickerSlots.length];
      updatedLayers.add(
        _extraStickerLayer(
          id: 'auto_sticker_a_${variantKey}_${pageIndex + 1}',
          x: stickerSlotA['x']!,
          y: stickerSlotA['y']!,
          w: stickerSlotA['w']! * 0.82,
          h: stickerSlotA['h']! * 0.82,
          sticker:
              moodProfile.stickers[pageIndex % moodProfile.stickers.length],
          rotation: (pageIndex.isEven ? -6 : 6).toDouble(),
        ),
      );
      final stickerSlotB = stickerSlots[(pageIndex + 2) % stickerSlots.length];
      updatedLayers.add(
        _extraStickerLayer(
          id: 'auto_sticker_b_${variantKey}_${pageIndex + 1}',
          x: stickerSlotB['x']!,
          y: stickerSlotB['y']!,
          w: stickerSlotB['w']! * 0.78,
          h: stickerSlotB['h']! * 0.78,
          sticker: moodProfile
              .stickers[(pageIndex + 1) % moodProfile.stickers.length],
          rotation: (pageIndex.isEven ? 5 : -5).toDouble(),
          zIndex: 29,
        ),
      );
    }

    source['layers'] = updatedLayers;
    source['layoutId'] = (source['layoutId'] ?? 'layout_${pageIndex + 1}')
        .toString();
    source['role'] = pageIndex == 0
        ? 'cover'
        : (pageIndex == safeCount - 1 ? 'end' : 'inner');
    final imageLayerCount = updatedLayers
        .where((l) => (l['type'] ?? '').toString().toUpperCase() == 'IMAGE')
        .length;
    source['recommendedPhotoCount'] = imageLayerCount.clamp(1, 12);
    generatedPages.add(source);
  }

  final safeArea =
      heroTextSafeArea ??
      const {'x': 0.10, 'y': 0.10, 'width': 0.80, 'height': 0.28};
  final metadata = <String, dynamic>{
    'style': style,
    'designWidth': designWidth,
    'designHeight': designHeight,
    'difficulty': difficulty.clamp(1, 5),
    'recommendedPhotoCount': recommendedPhotoCount.clamp(1, 24),
    'mood': mood,
    'tags': [variantKey, style, mood],
    'heroTextSafeArea': safeArea,
    'sourceBottomSheetTemplateIds': sourceBottomSheetTemplateIds,
    'applyScope': 'cover_and_pages',
    'bottomSheetReferenceMode': 'style_and_tone_only',
  };

  return jsonEncode({
    'schemaVersion': 1,
    'templateId': '${style}_$variantKey',
    'version': 1,
    'lifecycleStatus': 'published',
    'metadata': metadata,
    'pages': generatedPages,
  });
}

PremiumTemplate _sanitizeTemplateForRuntime(PremiumTemplate template) {
  String normalizedTitle(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^0-9a-z가-힣]'), '');

  const localizedTitleMap = <String, String>{
    '시그니처웨딩': '웨딩 무드북',
    '썸머커버에디션': '썸머 무드북',
    '스카이인비테이션': '스카이 무드북',
    '로즈데이': '로즈 무드북',
    '어린이북클럽': '북클럽 무드북',
    '우리들의여름제주': '제주 여름 무드북',
    '오션브리즈': '오션 브리즈 무드북',
    '도시의밤': '시티 나이트 무드북',
    '빛나는졸업장': '졸업 무드북',
    '가족여행일기': '패밀리 트립 무드북',
    '이터널러브': '이터널 러브 무드북',
    '빈티지포커스': '빈티지 무드북',
    '링트립스토리': '링 트립 무드북',
  };

  final localizedTitle =
      localizedTitleMap[normalizedTitle(template.title)] ?? template.title;

  final safeCover = _sanitizeNetworkImageUrl(
    template.coverImageUrl,
    seed: 'cover_${template.id}',
  );
  final safePreview = template.previewImages
      .asMap()
      .entries
      .map(
        (e) => _sanitizeNetworkImageUrl(
          e.value,
          seed: 'preview_${template.id}_${e.key}',
        ),
      )
      .toList();

  final raw = template.templateJson;
  if (raw == null || raw.trim().isEmpty) {
    final previewWithCover = <String>[
      safeCover,
      ...safePreview,
    ].where((e) => e.trim().isNotEmpty).toSet().toList(growable: false);
    return template.copyWith(
      title: localizedTitle,
      coverImageUrl: safeCover,
      previewImages: previewWithCover,
    );
  }

  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final pages = decoded['pages'];
    final layerPreview = <String>[];
    String? coverCandidate;
    if (pages is List) {
      for (var i = 0; i < pages.length; i++) {
        final page = pages[i];
        if (page is! Map) continue;
        final layers = page['layers'];
        if (layers is! List) continue;
        for (var j = 0; j < layers.length; j++) {
          final layer = layers[j];
          if (layer is! Map) continue;
          if ((layer['type']?.toString().toUpperCase() ?? '') != 'IMAGE') {
            continue;
          }
          final payload = layer['payload'];
          if (payload is! Map) continue;
          final seed = 'tpl_${template.id}_p${i}_l${j}';
          final imageUrl = _sanitizeNetworkImageUrl(
            (payload['imageUrl'] ?? '').toString(),
            seed: seed,
          );
          payload['imageUrl'] = imageUrl;
          payload['previewUrl'] = imageUrl;
          payload['originalUrl'] = imageUrl;
          if (layerPreview.length < 8) layerPreview.add(imageUrl);
          if (i == 0 && coverCandidate == null) {
            coverCandidate = imageUrl;
          }
        }
      }
    }
    final finalCover = (coverCandidate != null && coverCandidate!.isNotEmpty)
        ? coverCandidate!
        : safeCover;
    final finalPreview = <String>[
      finalCover,
      ...layerPreview,
      ...safePreview,
    ].where((e) => e.trim().isNotEmpty).toSet().toList(growable: false);
    return template.copyWith(
      title: localizedTitle,
      coverImageUrl: finalCover,
      previewImages: finalPreview,
      templateJson: jsonEncode(decoded),
    );
  } catch (_) {
    final previewWithCover = <String>[
      safeCover,
      ...safePreview,
    ].where((e) => e.trim().isNotEmpty).toSet().toList(growable: false);
    return template.copyWith(
      title: localizedTitle,
      coverImageUrl: safeCover,
      previewImages: previewWithCover,
    );
  }
}

List<PremiumTemplate> localFeaturedTemplates() {
  final weddingSignatureCount = _stableRandomPageCount(-1011);
  final weddingSignatureJson = _buildStoreTemplateWithPages(
    baseTemplateJson: _buildHeroEditorialTemplateJson(
      coverBadge: 'THE MARRIAGE INVITATION',
      coverTitle: '시그니처 웨딩',
      coverSubtitle: 'Jiwoo & Minji · 2026.10.12',
      bottomCaption: 'SATURDAY 3PM · SEOUL',
    ),
    targetPageCount: weddingSignatureCount,
    variantKey: 'eternal',
    style: 'wedding_editorial',
    mood: 'romantic_elegant',
    difficulty: 2,
    recommendedPhotoCount: 14,
    sourceBottomSheetTemplateIds: const [
      'portrait_wedding_001',
      'portrait_classic_001',
      'square_center_001',
    ],
    heroTextSafeArea: const {
      'x': 0.10,
      'y': 0.08,
      'width': 0.80,
      'height': 0.30,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1523438885200-e635ba2c371e?auto=format&fit=crop&w=1200&q=80',
      'https://picsum.photos/id/1043/1600/1200',
    ],
  );

  final summerPosterCount = _stableRandomPageCount(-1012);
  final summerPosterJson = _buildStoreTemplateWithPages(
    baseTemplateJson: _buildHeroEditorialTemplateJson(
      coverBadge: 'SUMMER ISSUE 2026',
      coverTitle: '썸머 커버 에디션',
      coverSubtitle: 'Opening · 08.17 2PM',
      bottomCaption: 'SNAPFIT 1ST MAGAZINE COVER',
    ),
    targetPageCount: summerPosterCount,
    variantKey: 'ocean',
    style: 'summer_poster',
    mood: 'bright_fresh',
    difficulty: 2,
    recommendedPhotoCount: 16,
    sourceBottomSheetTemplateIds: const [
      'portrait_magazine_001',
      'square_travel_001',
      'landscape_magazine_001',
    ],
    heroTextSafeArea: const {
      'x': 0.10,
      'y': 0.08,
      'width': 0.80,
      'height': 0.30,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1504608524841-42fe6f032b4b?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1473116763249-2faaef81ccda?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1493558103817-58b2924bce98?auto=format&fit=crop&w=1200&q=80',
      'https://picsum.photos/id/1057/1600/1200',
      'https://images.unsplash.com/photo-1500375592092-40eb2168fd21?auto=format&fit=crop&w=1200&q=80',
    ],
  );

  final skyInvitationCount = _stableRandomPageCount(-1013);
  final skyInvitationJson = _buildStoreTemplateWithPages(
    baseTemplateJson: _buildHeroEditorialTemplateJson(
      coverBadge: 'LETTER FROM SUMMER SKY',
      coverTitle: '스카이 인비테이션',
      coverSubtitle: 'Summer day · your pretty letter',
      bottomCaption: 'BLUE SKY · POSTER MOOD',
    ),
    targetPageCount: skyInvitationCount,
    variantKey: 'family',
    style: 'sky_invitation',
    mood: 'airy_soft',
    difficulty: 1,
    recommendedPhotoCount: 12,
    sourceBottomSheetTemplateIds: const [
      'portrait_pastel_001',
      'square_pastel_001',
      'landscape_pastel_001',
    ],
    heroTextSafeArea: const {
      'x': 0.12,
      'y': 0.10,
      'width': 0.76,
      'height': 0.28,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1505761671935-60b3a7427bad?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1431440869543-efaf3388c585?auto=format&fit=crop&w=1200&q=80',
      'https://picsum.photos/id/1062/1600/1200',
      'https://images.unsplash.com/photo-1510784722466-f2aa9c52fff6?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1524601500432-1e1a4c71d692?auto=format&fit=crop&w=1200&q=80',
    ],
  );
  final roseDayCount = _stableRandomPageCount(-1014);
  final roseDayJson = _buildStoreTemplateWithPages(
    baseTemplateJson: _buildHeroEditorialTemplateJson(
      coverBadge: 'ROSE DAY SPECIAL',
      coverTitle: '로즈 데이',
      coverSubtitle: '5월 14일 · 당신과 함께한 장면',
      bottomCaption: 'PRETTIER THAN ROSE',
    ),
    targetPageCount: roseDayCount,
    variantKey: 'eternal',
    style: 'floral_poster',
    mood: 'romantic_sweet',
    difficulty: 2,
    recommendedPhotoCount: 12,
    sourceBottomSheetTemplateIds: const [
      'portrait_story_001',
      'square_stamp_001',
      'landscape_banner_001',
    ],
    heroTextSafeArea: const {
      'x': 0.10,
      'y': 0.10,
      'width': 0.80,
      'height': 0.26,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1468327768560-75b778cbb551?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1527061011665-3652c757a4d4?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1455659817273-f96807779a8a?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1521540216272-a50305cd4421?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1525310072745-f49212b5ac6d?auto=format&fit=crop&w=1200&q=80',
    ],
  );
  final bookClubCount = _stableRandomPageCount(-1015);
  final bookClubJson = _buildStoreTemplateWithPages(
    baseTemplateJson: _buildHeroEditorialTemplateJson(
      coverBadge: 'MIRI LIBRARY PICK',
      coverTitle: '어린이 북클럽',
      coverSubtitle: '이번 달 추천 도서와 기록',
      bottomCaption: 'KIDS BOOKLIST · NIGHT SKY',
    ),
    targetPageCount: bookClubCount,
    variantKey: 'city',
    style: 'bookclub_editorial',
    mood: 'deep_night',
    difficulty: 3,
    recommendedPhotoCount: 15,
    sourceBottomSheetTemplateIds: const [
      'portrait_magazine_001',
      'portrait_miricar_001',
      'landscape_film_001',
    ],
    heroTextSafeArea: const {
      'x': 0.10,
      'y': 0.08,
      'width': 0.80,
      'height': 0.30,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1474932430478-367dbb6832c1?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1495640388908-05fa85288e61?auto=format&fit=crop&w=1200&q=80',
    ],
  );
  final jejuPageCount = _stableRandomPageCount(-1001);
  final jejuJson = _buildStoreTemplateWithPages(
    baseTemplateJson: buildJejuSummerTemplateJson(),
    targetPageCount: jejuPageCount,
    variantKey: 'jeju',
    style: 'travel_story',
    mood: 'warm_natural',
    difficulty: 2,
    recommendedPhotoCount: 15,
    sourceBottomSheetTemplateIds: const [
      'portrait_travel_001',
      'square_travel_001',
      'landscape_travel_001',
    ],
    heroTextSafeArea: const {
      'x': 0.12,
      'y': 0.10,
      'width': 0.76,
      'height': 0.28,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1200&q=80',
      'https://picsum.photos/id/1039/1600/1200',
      'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=1200&q=80',
      'https://picsum.photos/id/1027/1600/1200',
    ],
  );
  final oceanPageCount = _stableRandomPageCount(-1002);
  final oceanJson = _buildStoreTemplateWithPages(
    baseTemplateJson: buildOceanBreezeTemplateJson(),
    targetPageCount: oceanPageCount,
    variantKey: 'ocean',
    style: 'travel_ocean',
    mood: 'fresh_blue',
    difficulty: 2,
    recommendedPhotoCount: 14,
    sourceBottomSheetTemplateIds: const [
      'portrait_travel_tape_001',
      'square_tape_001',
      'landscape_banner_001',
    ],
    heroTextSafeArea: const {
      'x': 0.10,
      'y': 0.10,
      'width': 0.80,
      'height': 0.28,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1500375592092-40eb2168fd21?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1520942702018-0862200e6873?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=80',
    ],
  );
  final cityPageCount = _stableRandomPageCount(-1003);
  final cityJson = _buildStoreTemplateWithPages(
    baseTemplateJson: buildCityNightTemplateJson(),
    targetPageCount: cityPageCount,
    variantKey: 'city',
    style: 'city_editorial',
    mood: 'urban_night',
    difficulty: 3,
    recommendedPhotoCount: 16,
    sourceBottomSheetTemplateIds: const [
      'portrait_minimal_001',
      'square_minimal_001',
      'landscape_minimal_001',
    ],
    heroTextSafeArea: const {
      'x': 0.10,
      'y': 0.10,
      'width': 0.80,
      'height': 0.26,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1465447142348-e9952c393450?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1514565131-fce0801e5785?auto=format&fit=crop&w=1200&q=80',
      'https://picsum.photos/id/1011/1600/1200',
    ],
  );
  final graduationPageCount = _stableRandomPageCount(-1004);
  final graduationJson = _buildStoreTemplateWithPages(
    baseTemplateJson: buildGraduationTemplateJson(),
    targetPageCount: graduationPageCount,
    variantKey: 'graduation',
    style: 'school_memory',
    mood: 'cheerful_warm',
    difficulty: 2,
    recommendedPhotoCount: 13,
    sourceBottomSheetTemplateIds: const [
      'portrait_paper_note_001',
      'square_grid_001',
      'landscape_triptych_001',
    ],
    heroTextSafeArea: const {
      'x': 0.10,
      'y': 0.10,
      'width': 0.80,
      'height': 0.26,
    },
    imagePool: const [
      'https://picsum.photos/id/1005/1600/1200',
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1557804506-669a67965ba0?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?auto=format&fit=crop&w=1200&q=80',
      'https://picsum.photos/id/1018/1600/1200',
    ],
  );
  final familyPageCount = _stableRandomPageCount(-1005);
  final familyJson = _buildStoreTemplateWithPages(
    baseTemplateJson: buildFamilyTripTemplateJson(),
    targetPageCount: familyPageCount,
    variantKey: 'family',
    style: 'family_journal',
    mood: 'cozy_warm',
    difficulty: 1,
    recommendedPhotoCount: 12,
    sourceBottomSheetTemplateIds: const [
      'portrait_kids_life_001',
      'portrait_kids_collage_001',
      'square_center_001',
    ],
    heroTextSafeArea: const {
      'x': 0.12,
      'y': 0.10,
      'width': 0.76,
      'height': 0.26,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1511895426328-dc8714191300?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1516627145497-ae6968895b74?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1518933165971-611dbc9c412d?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1609220136736-443140cffec6?auto=format&fit=crop&w=1200&q=80',
      'https://picsum.photos/id/1062/1600/1200',
    ],
  );
  final eternalPageCount = _stableRandomPageCount(-1006);
  final eternalJson = _buildStoreTemplateWithPages(
    baseTemplateJson: buildEternalLoveTemplateJson(),
    targetPageCount: eternalPageCount,
    variantKey: 'eternal',
    style: 'romance_story',
    mood: 'romantic_soft',
    difficulty: 2,
    recommendedPhotoCount: 14,
    sourceBottomSheetTemplateIds: const [
      'portrait_wedding_001',
      'square_vintage_001',
      'landscape_film_001',
    ],
    heroTextSafeArea: const {
      'x': 0.10,
      'y': 0.10,
      'width': 0.80,
      'height': 0.28,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1516339901601-2e1b62dc0c45?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1511988617509-a57c8a288659?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1529636798458-92182e662485?auto=format&fit=crop&w=1200&q=80',
      'https://picsum.photos/id/1020/1600/1200',
    ],
  );
  final vintagePageCount = _stableRandomPageCount(-1007);
  final vintageJson = _buildStoreTemplateWithPages(
    baseTemplateJson: buildVintageFocusTemplateJson(),
    targetPageCount: vintagePageCount,
    variantKey: 'vintage',
    style: 'vintage_film',
    mood: 'retro_deep',
    difficulty: 3,
    recommendedPhotoCount: 15,
    sourceBottomSheetTemplateIds: const [
      'portrait_vintage_001',
      'square_vintage_001',
      'landscape_vintage_001',
    ],
    heroTextSafeArea: const {
      'x': 0.10,
      'y': 0.10,
      'width': 0.80,
      'height': 0.26,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1473654729523-203e25dfda10?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1433838552652-f9a46b332c40?auto=format&fit=crop&w=1200&q=80',
    ],
  );
  final ringPageCount = _stableRandomPageCount(-1008);
  final ringJson = _buildStoreTemplateWithPages(
    baseTemplateJson: buildRingTripStoryTemplateJson(),
    targetPageCount: ringPageCount,
    variantKey: 'ring',
    style: 'couple_trip',
    mood: 'romantic_natural',
    difficulty: 2,
    recommendedPhotoCount: 14,
    sourceBottomSheetTemplateIds: const [
      'portrait_ribbon_001',
      'square_tape_001',
      'landscape_strip_001',
    ],
    heroTextSafeArea: const {
      'x': 0.10,
      'y': 0.10,
      'width': 0.80,
      'height': 0.28,
    },
    imagePool: const [
      'https://images.unsplash.com/photo-1520854221256-17451cc331bf?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=1200&q=80',
      'https://picsum.photos/id/1043/1600/1200',
    ],
  );

  final templates = [
    PremiumTemplate(
      id: -1011,
      title: '시그니처 웨딩',
      subTitle: '풀배경 사진 + 타이포 중심의 청첩장 무드 템플릿',
      description: '커버 포함 $weddingSignatureCount페이지로 구성된 우선순위 웨딩 템플릿',
      coverImageUrl:
          'https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: weddingSignatureCount,
      likeCount: 0,
      userCount: 0,
      category: '웨딩',
      tags: const ['웨딩', '인비테이션', '포스터'],
      weeklyScore: 1200,
      isNew: true,
      isBest: true,
      isPremium: true,
      isLiked: false,
      templateJson: weddingSignatureJson,
    ),
    PremiumTemplate(
      id: -1012,
      title: '썸머 커버 에디션',
      subTitle: '매거진 표지 느낌의 대담한 타이포 템플릿',
      description: '커버 포함 $summerPosterCount페이지로 구성된 우선순위 썸머 포스터 템플릿',
      coverImageUrl:
          'https://images.unsplash.com/photo-1504608524841-42fe6f032b4b?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1504608524841-42fe6f032b4b?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1473116763249-2faaef81ccda?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1493558103817-58b2924bce98?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: summerPosterCount,
      likeCount: 0,
      userCount: 0,
      category: '시즌',
      tags: const ['여름', '매거진', '포스터'],
      weeklyScore: 1150,
      isNew: true,
      isBest: true,
      isPremium: true,
      isLiked: false,
      templateJson: summerPosterJson,
    ),
    PremiumTemplate(
      id: -1013,
      title: '스카이 인비테이션',
      subTitle: '하늘 톤 포스터 스타일의 감성 커버 템플릿',
      description: '커버 포함 $skyInvitationCount페이지로 구성된 우선순위 스카이 무드 템플릿',
      coverImageUrl:
          'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1505761671935-60b3a7427bad?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1431440869543-efaf3388c585?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: skyInvitationCount,
      likeCount: 0,
      userCount: 0,
      category: '감성',
      tags: const ['하늘', '인비테이션', '포스터'],
      weeklyScore: 1100,
      isNew: true,
      isBest: true,
      isPremium: true,
      isLiked: false,
      templateJson: skyInvitationJson,
    ),
    PremiumTemplate(
      id: -1014,
      title: '로즈 데이',
      subTitle: '플라워 무드 포스터형 템플릿',
      description: '커버 포함 $roseDayCount페이지, 로맨틱 타이포 중심 구성',
      coverImageUrl:
          'https://images.unsplash.com/photo-1468327768560-75b778cbb551?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1468327768560-75b778cbb551?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1527061011665-3652c757a4d4?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1455659817273-f96807779a8a?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: roseDayCount,
      likeCount: 0,
      userCount: 0,
      category: '연인',
      tags: const ['로즈', '감성', '연인'],
      weeklyScore: 1050,
      isNew: true,
      isBest: true,
      isPremium: true,
      isLiked: false,
      templateJson: roseDayJson,
    ),
    PremiumTemplate(
      id: -1015,
      title: '어린이 북클럽',
      subTitle: '북포스터 감성의 에디토리얼 템플릿',
      description: '커버 포함 $bookClubCount페이지, 딥블루 배경의 북클럽 무드',
      coverImageUrl:
          'https://images.unsplash.com/photo-1474932430478-367dbb6832c1?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1474932430478-367dbb6832c1?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: bookClubCount,
      likeCount: 0,
      userCount: 0,
      category: '매거진',
      tags: const ['북클럽', '매거진', '에디토리얼'],
      weeklyScore: 1030,
      isNew: true,
      isBest: true,
      isPremium: true,
      isLiked: false,
      templateJson: bookClubJson,
    ),
    PremiumTemplate(
      id: -1001,
      title: '우리들의 여름 제주',
      subTitle: '프리미엄 무드로 구성된 제주 여행 앨범 템플릿',
      description: '커버 포함 $jejuPageCount페이지가 감성 프레임/타이포와 함께 자동 구성됩니다.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1200&q=80',
        'https://picsum.photos/id/1039/1600/1200',
      ],
      pageCount: jejuPageCount,
      likeCount: 0,
      userCount: 0,
      category: '여행',
      tags: const ['여행', '제주', '감성'],
      weeklyScore: 980,
      isNew: true,
      isBest: true,
      isPremium: true,
      isLiked: false,
      templateJson: jejuJson,
    ),
    PremiumTemplate(
      id: -1002,
      title: '오션 브리즈',
      subTitle: '푸른 바다의 감성을 담은 여행 템플릿',
      description: '해변 감성 레이아웃과 페이퍼 프레임으로 구성된 $oceanPageCount페이지 템플릿',
      coverImageUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1500375592092-40eb2168fd21?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: oceanPageCount,
      likeCount: 124,
      userCount: 4,
      category: '여행',
      tags: const ['여행', '바다', '오션'],
      weeklyScore: 905,
      isNew: true,
      isBest: true,
      isPremium: true,
      templateJson: oceanJson,
    ),
    PremiumTemplate(
      id: -1003,
      title: '도시의 밤',
      subTitle: '화려한 도심 야경을 담은 시티 무드',
      description: '네온 컬러 포인트와 모던 타이포로 도시 여행 기록에 어울리는 템플릿',
      coverImageUrl:
          'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: cityPageCount,
      likeCount: 98,
      userCount: 2,
      category: '레트로',
      tags: const ['레트로', '도시', '야경'],
      weeklyScore: 720,
      isNew: true,
      isBest: true,
      isPremium: true,
      templateJson: cityJson,
    ),
    PremiumTemplate(
      id: -1004,
      title: '빛나는 졸업장',
      subTitle: '소중한 졸업 순간을 담는 기념 템플릿',
      description: '졸업식/입학식 사진에 맞춘 깔끔한 격자형 구성',
      coverImageUrl: 'https://picsum.photos/id/1005/1600/1200',
      previewImages: const [
        'https://picsum.photos/id/1005/1600/1200',
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1557804506-669a67965ba0?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: graduationPageCount,
      likeCount: 88,
      userCount: 2,
      category: '졸업',
      tags: const ['졸업', '입학', '학교'],
      weeklyScore: 750,
      isNew: true,
      isBest: false,
      isPremium: false,
      templateJson: graduationJson,
    ),
    PremiumTemplate(
      id: -1005,
      title: '가족 여행 일기',
      subTitle: '가족과 함께한 하루를 따뜻하게 기록해요',
      description: '여행/가족 카테고리에 모두 어울리는 다목적 템플릿',
      coverImageUrl:
          'https://images.unsplash.com/photo-1511895426328-dc8714191300?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1511895426328-dc8714191300?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1516627145497-ae6968895b74?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1518933165971-611dbc9c412d?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: familyPageCount,
      likeCount: 142,
      userCount: 3,
      category: '가족',
      tags: const ['가족', '여행', '일상'],
      weeklyScore: 810,
      isNew: false,
      isBest: false,
      isPremium: true,
      templateJson: familyJson,
    ),
    PremiumTemplate(
      id: -1006,
      title: '이터널 러브',
      subTitle: '연인의 특별한 순간을 담는 하드커버',
      description: '커플/프로포즈 스냅에 어울리는 로맨틱 톤 템플릿',
      coverImageUrl:
          'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1516339901601-2e1b62dc0c45?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1511988617509-a57c8a288659?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: eternalPageCount,
      likeCount: 176,
      userCount: 1,
      category: '연인',
      tags: const ['연인', '웨딩', '프로포즈'],
      weeklyScore: 930,
      isNew: false,
      isBest: true,
      isPremium: true,
      templateJson: eternalJson,
    ),
    PremiumTemplate(
      id: -1007,
      title: '빈티지 포커스',
      subTitle: '레트로 무드를 담은 빈티지 스타일 템플릿',
      description: '스크린샷 레퍼런스 기반의 빈티지 무드 템플릿',
      coverImageUrl:
          'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: vintagePageCount,
      likeCount: 132,
      userCount: 2,
      category: '레트로',
      tags: const ['레트로', '빈티지', '투어'],
      weeklyScore: 760,
      isNew: false,
      isBest: true,
      isPremium: true,
      templateJson: vintageJson,
    ),
    PremiumTemplate(
      id: -1008,
      title: '링 트립 스토리',
      subTitle: '연인 여행의 하이라이트를 담는 스토리 템플릿',
      description: '프로포즈 순간에 어울리는 스티커 스타일 구성',
      coverImageUrl:
          'https://images.unsplash.com/photo-1520854221256-17451cc331bf?auto=format&fit=crop&w=1200&q=80',
      previewImages: const [
        'https://images.unsplash.com/photo-1520854221256-17451cc331bf?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80',
      ],
      pageCount: ringPageCount,
      likeCount: 109,
      userCount: 5,
      category: '연인',
      tags: const ['연인', '링', '트립'],
      weeklyScore: 790,
      isNew: true,
      isBest: false,
      isPremium: false,
      templateJson: ringJson,
    ),
  ];
  return templates
      .where((template) => !_isRemovedStoreTemplateTitle(template.title))
      .map(_sanitizeTemplateForRuntime)
      .toList();
}

bool _isRemovedStoreTemplateTitle(String rawTitle) {
  final title = rawTitle
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^0-9a-zA-Z가-힣]'), '');
  if (title.isEmpty) return false;

  final blocked = <String>[
    '브랜드이벤트커버',
    '브랜드이벤트커버02',
    '브랜드이벤트커버03',
    '브랜드이벤트커버04',
    '브랜드이벤트커버05',
    '브랜드이벤트커버06',
    '브랜드이벤트커버07',
    '브랜드이벤트커버08',
    '브랜드이벤트커버09',
    '브랜드이벤트커버10',
    '브랜드이벤트커버11',
    '브랜드이벤트커버12',
    '스카이레더',
    '스카이레터',
    '썸머포스터',
    '웨딩에디토리얼',
    '우리의결혼1주년',
    '성수동카페투어',
    '미니멀포커스',
    '링모먼트',
    '링트립스토리',
    '오션브리즈',
  ];
  return blocked.any((keyword) => title.contains(keyword));
}

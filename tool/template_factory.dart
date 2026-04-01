import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) async {
  final options = _CliOptions.parse(args);
  final rng = math.Random(
    options.seed ?? DateTime.now().millisecondsSinceEpoch,
  );

  final catalogFile = File(options.catalogPath);
  if (!catalogFile.existsSync()) {
    stderr.writeln('Catalog not found: ${options.catalogPath}');
    exit(2);
  }

  final constantsFile = File(options.constantsPath);
  if (!constantsFile.existsSync()) {
    stderr.writeln('Constants not found: ${options.constantsPath}');
    exit(2);
  }

  final existingTemplates = _readTemplateList(catalogFile);
  final existingNames = <String>{};
  final existingTextTokens = <String, Set<String>>{};
  final existingImages = <String>{};
  final existingFingerprints = <Set<String>>[];

  for (final t in existingTemplates) {
    final name = _normalize((t['name'] ?? '').toString());
    if (name.isNotEmpty) existingNames.add(name);

    for (final text in _extractLayerTexts(t)) {
      final key = _normalize(text);
      if (key.isEmpty) continue;
      existingTextTokens[key] = _tokenize(key);
    }

    for (final url in _extractPreviewUrls(t)) {
      if (url.isNotEmpty) existingImages.add(url);
    }

    existingFingerprints.add(_designFingerprintSet(t));
  }

  existingImages.addAll(
    _extractUrlsFromConstants(constantsFile.readAsStringSync()),
  );

  final generated = <Map<String, dynamic>>[];
  final today = DateTime.now();
  final dayStamp =
      '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

  var attempts = 0;
  while (generated.length < options.count && attempts < options.count * 120) {
    attempts += 1;
    final recipe = _recipes[rng.nextInt(_recipes.length)];
    final theme = _themes[rng.nextInt(_themes.length)];
    final aspect = _aspects[rng.nextInt(_aspects.length)];
    final imagePool =
        _imagePoolByTheme[theme.slug] ?? _imagePoolByTheme['general']!;
    final picks = _pickUniqueImages(
      pool: imagePool,
      used: existingImages,
      take: 4,
      rng: rng,
      seedPrefix: '${theme.slug}_$dayStamp',
    );
    if (picks.length < 4) {
      continue;
    }

    final title =
        _pickUniqueTitle(theme, existingTextTokens.keys, rng) ??
        '${theme.name.toUpperCase()} MOMENT ${100 + rng.nextInt(900)}';
    final subtitle =
        _pickUniqueSubtitle(theme, existingTextTokens.keys, rng) ??
        '${today.year}.${today.month.toString().padLeft(2, '0')}.${today.day.toString().padLeft(2, '0')} 기록';

    final id =
        'data_auto_${dayStamp}_${generated.length.toString().padLeft(3, '0')}';
    final name = '${theme.name} ${recipe.displayName}';
    final normName = _normalize(name);
    if (existingNames.contains(normName)) {
      continue;
    }

    final candidate = _buildTemplate(
      id: id,
      name: name,
      aspect: aspect,
      theme: theme,
      recipe: recipe,
      title: title,
      subtitle: subtitle,
      previewImages: picks,
      rng: rng,
    );

    final fingerprint = _designFingerprintSet(candidate);
    if (_isDesignOverlap(fingerprint, existingFingerprints)) {
      continue;
    }

    if (_isTextOverlap(candidate, existingTextTokens.values)) {
      continue;
    }

    generated.add(candidate);
    existingNames.add(normName);
    for (final t in _extractLayerTexts(candidate)) {
      final norm = _normalize(t);
      if (norm.isEmpty) continue;
      existingTextTokens[norm] = _tokenize(norm);
    }
    existingImages.addAll(picks);
    existingFingerprints.add(fingerprint);
  }

  final outFile = File(options.outputPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(generated),
  );

  final registryFile = File(options.registryPath);
  registryFile.parent.createSync(recursive: true);
  registryFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'generatedAt': DateTime.now().toIso8601String(),
      'count': generated.length,
      'outputPath': options.outputPath,
      'templateIds': generated.map((e) => e['id']).toList(),
      'notes': 'Auto-generated with uniqueness guard (name/text/image/design)',
    }),
  );

  stdout.writeln('Generated ${generated.length}/${options.count} templates');
  stdout.writeln('Output: ${options.outputPath}');
  stdout.writeln('Registry: ${options.registryPath}');
  if (generated.length < options.count) {
    stdout.writeln(
      'Warning: uniqueness guard blocked some candidates. Expand text/image pools.',
    );
  }
}

List<Map<String, dynamic>> _readTemplateList(File file) {
  final raw = jsonDecode(file.readAsStringSync());
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (raw is Map && raw['templates'] is List) {
    return (raw['templates'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return <Map<String, dynamic>>[];
}

Set<String> _extractUrlsFromConstants(String source) {
  final re = RegExp(r'''https://images\.unsplash\.com/[^\s'"]+''');
  return re.allMatches(source).map((m) => m.group(0)!).toSet();
}

List<String> _extractLayerTexts(Map<String, dynamic> template) {
  final layers = template['layers'];
  if (layers is! List) return const [];
  final texts = <String>[];
  for (final layer in layers) {
    if (layer is! Map) continue;
    final text = (layer['text'] ?? '').toString();
    if (text.trim().isNotEmpty) texts.add(text);
  }
  return texts;
}

Set<String> _extractPreviewUrls(Map<String, dynamic> template) {
  final out = <String>{};
  final thumb = (template['previewThumbUrl'] ?? '').toString();
  final detail = (template['previewDetailUrl'] ?? '').toString();
  if (thumb.isNotEmpty) out.add(thumb);
  if (detail.isNotEmpty) out.add(detail);
  final list = template['previewImageUrls'];
  if (list is List) {
    for (final url in list) {
      final s = (url ?? '').toString();
      if (s.isNotEmpty) out.add(s);
    }
  }
  return out;
}

Set<String> _designFingerprintSet(Map<String, dynamic> template) {
  final layers = template['layers'];
  if (layers is! List) return <String>{};
  final out = <String>{};
  for (final raw in layers) {
    if (raw is! Map) continue;
    final type = (raw['type'] ?? '').toString();
    final x = _q(raw['x']);
    final y = _q(raw['y']);
    final w = _q(raw['w']);
    final h = _q(raw['h']);
    final frame = (raw['frame'] ?? '').toString();
    final style = (raw['style'] ?? '').toString();
    out.add('$type:$x:$y:$w:$h:$frame:$style');
  }
  return out;
}

double _q(dynamic value) {
  final v = value is num ? value.toDouble() : 0.0;
  return (v * 20).round() / 20;
}

bool _isDesignOverlap(Set<String> candidate, List<Set<String>> existing) {
  for (final e in existing) {
    final score = _jaccard(candidate, e);
    if (score >= 0.86) return true;
  }
  return false;
}

bool _isTextOverlap(
  Map<String, dynamic> candidate,
  Iterable<Set<String>> existing,
) {
  for (final text in _extractLayerTexts(candidate)) {
    final tokens = _tokenize(_normalize(text));
    if (tokens.isEmpty) continue;
    for (final e in existing) {
      if (_jaccard(tokens, e) >= 0.82) return true;
    }
  }
  return false;
}

double _jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final inter = a.intersection(b).length;
  final union = a.union(b).length;
  if (union == 0) return 0;
  return inter / union;
}

String _normalize(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

Set<String> _tokenize(String value) {
  return value
      .split(RegExp(r'[^a-z0-9가-힣]+'))
      .map((e) => e.trim())
      .where((e) => e.length >= 2)
      .toSet();
}

List<String> _pickUniqueImages({
  required List<String> pool,
  required Set<String> used,
  required int take,
  required math.Random rng,
  required String seedPrefix,
}) {
  final available = pool.where((e) => !used.contains(e)).toList()..shuffle(rng);
  final selected = <String>[];
  selected.addAll(available.take(take));

  var index = 0;
  while (selected.length < take) {
    final fallback =
        'https://picsum.photos/seed/${seedPrefix}_$index/1200/1600';
    index += 1;
    if (used.contains(fallback) || selected.contains(fallback)) {
      continue;
    }
    selected.add(fallback);
  }

  return selected;
}

String? _pickUniqueTitle(
  _Theme theme,
  Iterable<String> existingTextNormalized,
  math.Random rng,
) {
  final used = existingTextNormalized.toSet();
  final list = List<String>.from(theme.titles)..shuffle(rng);
  for (final t in list) {
    if (!used.contains(_normalize(t))) return t;
  }
  return null;
}

String? _pickUniqueSubtitle(
  _Theme theme,
  Iterable<String> existingTextNormalized,
  math.Random rng,
) {
  final used = existingTextNormalized.toSet();
  final list = List<String>.from(theme.subtitles)..shuffle(rng);
  for (final t in list) {
    if (!used.contains(_normalize(t))) return t;
  }
  return null;
}

Map<String, dynamic> _buildTemplate({
  required String id,
  required String name,
  required String aspect,
  required _Theme theme,
  required _Recipe recipe,
  required String title,
  required String subtitle,
  required List<String> previewImages,
  required math.Random rng,
}) {
  final layers = recipe.build(title: title, subtitle: subtitle, rng: rng);

  return {
    'id': id,
    'name': name,
    'category': theme.category,
    'tags': theme.tags,
    'style': theme.style,
    'aspect': aspect,
    'difficulty': 'normal',
    'recommendedPhotoCount': recipe.recommendedPhotoCount,
    'isFeatured': false,
    'priority': 0,
    'previewThumbUrl': previewImages.first,
    'previewDetailUrl': previewImages[1],
    'previewImageUrls': previewImages,
    'autoFit': true,
    'autoFitPadding': 0.012,
    'layers': layers,
  };
}

final List<String> _aspects = <String>['portrait', 'square', 'landscape'];

final List<_Recipe> _recipes = <_Recipe>[
  _Recipe(
    id: 'hero_full_bleed',
    displayName: '히어로',
    recommendedPhotoCount: 1,
    build:
        ({
          required String title,
          required String subtitle,
          required math.Random rng,
        }) {
          return [
            {
              'id': 'main',
              'type': 'image',
              'x': 0.0,
              'y': 0.0,
              'w': 1.0,
              'h': 1.0,
              'frame': 'softGlow',
              'z': 1,
            },
            {
              'id': 'overlay',
              'type': 'decoration',
              'x': 0.0,
              'y': 0.0,
              'w': 1.0,
              'h': 1.0,
              'style': 'darkVignette',
              'z': 5,
            },
            {
              'id': 'title',
              'type': 'text',
              'x': 0.08 + (rng.nextDouble() * 0.04),
              'y': 0.08,
              'w': 0.84,
              'h': 0.12,
              'text': title,
              'align': 'center',
              'z': 20,
              'style': {
                'fontSize': 16.8,
                'fontFamily': 'Cormorant',
                'fontWeight': 'w800',
                'color': '#F9F7F1',
                'letterSpacing': 0.7,
              },
            },
            {
              'id': 'subtitle',
              'type': 'text',
              'x': 0.10,
              'y': 0.84,
              'w': 0.80,
              'h': 0.08,
              'text': subtitle,
              'align': 'center',
              'z': 20,
              'style': {
                'fontSize': 10.2,
                'fontFamily': 'Raleway',
                'fontWeight': 'w600',
                'color': '#F2F2F2',
                'letterSpacing': 0.9,
              },
            },
          ];
        },
  ),
  _Recipe(
    id: 'editorial_split',
    displayName: '에디토리얼',
    recommendedPhotoCount: 2,
    build:
        ({
          required String title,
          required String subtitle,
          required math.Random rng,
        }) {
          return [
            {
              'id': 'bg',
              'type': 'decoration',
              'x': 0,
              'y': 0,
              'w': 1,
              'h': 1,
              'style': 'paperWhite',
              'z': 0,
            },
            {
              'id': 'main',
              'type': 'image',
              'x': 0.07,
              'y': 0.12,
              'w': 0.58,
              'h': 0.78,
              'frame': 'collageTile',
              'z': 10,
            },
            {
              'id': 'sub',
              'type': 'image',
              'x': 0.69,
              'y': 0.18 + (rng.nextDouble() * 0.06),
              'w': 0.24,
              'h': 0.44,
              'frame': 'polaroidClassic',
              'rotation': -2 + (rng.nextDouble() * 4),
              'z': 12,
            },
            {
              'id': 'title',
              'type': 'text',
              'x': 0.69,
              'y': 0.65,
              'w': 0.24,
              'h': 0.16,
              'text': title,
              'align': 'left',
              'z': 18,
              'style': {
                'fontSize': 11.6,
                'fontFamily': 'BookMyungjo',
                'fontWeight': 'w800',
                'color': '#222222',
                'height': 1.2,
              },
            },
            {
              'id': 'subtitle',
              'type': 'text',
              'x': 0.69,
              'y': 0.83,
              'w': 0.24,
              'h': 0.10,
              'text': subtitle,
              'align': 'left',
              'z': 18,
              'style': {
                'fontSize': 8.6,
                'fontFamily': 'Raleway',
                'fontWeight': 'w600',
                'color': '#4A4A4A',
                'height': 1.2,
              },
            },
          ];
        },
  ),
  _Recipe(
    id: 'scrapbook_doodle',
    displayName: '스크랩',
    recommendedPhotoCount: 3,
    build:
        ({
          required String title,
          required String subtitle,
          required math.Random rng,
        }) {
          return [
            {
              'id': 'bg',
              'type': 'decoration',
              'x': 0,
              'y': 0,
              'w': 1,
              'h': 1,
              'style': 'paperWarm',
              'z': 0,
            },
            {
              'id': 'a',
              'type': 'image',
              'x': 0.08,
              'y': 0.16,
              'w': 0.40,
              'h': 0.34,
              'frame': 'roughPolaroid',
              'rotation': -4,
              'z': 10,
            },
            {
              'id': 'b',
              'type': 'image',
              'x': 0.52,
              'y': 0.18,
              'w': 0.40,
              'h': 0.30,
              'frame': 'paperClipCard',
              'rotation': 3,
              'z': 10,
            },
            {
              'id': 'c',
              'type': 'image',
              'x': 0.20,
              'y': 0.54,
              'w': 0.62,
              'h': 0.34,
              'frame': 'maskingTapeFrame',
              'z': 10,
            },
            {
              'id': 'sticker',
              'type': 'decoration',
              'x': 0.10,
              'y': 0.08,
              'w': 0.10,
              'h': 0.08,
              'style': 'stickerSparkleGold',
              'z': 20,
            },
            {
              'id': 'title',
              'type': 'text',
              'x': 0.12,
              'y': 0.06,
              'w': 0.76,
              'h': 0.08,
              'text': title,
              'align': 'center',
              'z': 22,
              'style': {
                'fontSize': 12.8,
                'fontFamily': 'Tenada',
                'fontWeight': 'w800',
                'color': '#2F2A24',
                'letterSpacing': 0.2,
              },
            },
            {
              'id': 'subtitle',
              'type': 'text',
              'x': 0.12,
              'y': 0.91,
              'w': 0.76,
              'h': 0.06,
              'text': subtitle,
              'align': 'center',
              'z': 22,
              'style': {
                'fontSize': 8.8,
                'fontFamily': 'SeoulNamsan',
                'fontWeight': 'w600',
                'color': '#4A4339',
                'letterSpacing': 0.4,
              },
            },
          ];
        },
  ),
  _Recipe(
    id: 'bold_typography_poster',
    displayName: '타이포 포스터',
    recommendedPhotoCount: 1,
    build:
        ({
          required String title,
          required String subtitle,
          required math.Random rng,
        }) {
          return [
            {
              'id': 'main',
              'type': 'image',
              'x': 0.03,
              'y': 0.03,
              'w': 0.94,
              'h': 0.94,
              'frame': 'collageTile',
              'z': 1,
            },
            {
              'id': 'mask',
              'type': 'decoration',
              'x': 0.0,
              'y': 0.0,
              'w': 1.0,
              'h': 0.25,
              'style': 'paperYellow',
              'z': 10,
            },
            {
              'id': 'title',
              'type': 'text',
              'x': 0.05,
              'y': 0.04,
              'w': 0.90,
              'h': 0.12,
              'text': title,
              'align': 'left',
              'z': 20,
              'style': {
                'fontSize': 18.0,
                'fontFamily': 'Raleway',
                'fontWeight': 'w900',
                'color': '#18222E',
                'letterSpacing': 0.6,
              },
            },
            {
              'id': 'subtitle',
              'type': 'text',
              'x': 0.06,
              'y': 0.86,
              'w': 0.88,
              'h': 0.08,
              'text': subtitle,
              'align': 'center',
              'z': 20,
              'style': {
                'fontSize': 9.2,
                'fontFamily': 'NotoSans',
                'fontWeight': 'w600',
                'color': '#F6F7F9',
                'letterSpacing': 0.2,
              },
            },
          ];
        },
  ),
  _Recipe(
    id: 'triptych_strip',
    displayName: '트립틱',
    recommendedPhotoCount: 3,
    build:
        ({
          required String title,
          required String subtitle,
          required math.Random rng,
        }) {
          return [
            {
              'id': 'bg',
              'type': 'decoration',
              'x': 0,
              'y': 0,
              'w': 1,
              'h': 1,
              'style': 'paperGray',
              'z': 0,
            },
            {
              'id': 'p1',
              'type': 'image',
              'x': 0.07,
              'y': 0.18,
              'w': 0.26,
              'h': 0.62,
              'frame': 'filmSquare',
              'z': 10,
            },
            {
              'id': 'p2',
              'type': 'image',
              'x': 0.37,
              'y': 0.15,
              'w': 0.26,
              'h': 0.66,
              'frame': 'film',
              'z': 10,
            },
            {
              'id': 'p3',
              'type': 'image',
              'x': 0.67,
              'y': 0.18,
              'w': 0.26,
              'h': 0.62,
              'frame': 'filmSquare',
              'z': 10,
            },
            {
              'id': 'title',
              'type': 'text',
              'x': 0.08,
              'y': 0.06,
              'w': 0.84,
              'h': 0.08,
              'text': title,
              'align': 'center',
              'z': 20,
              'style': {
                'fontSize': 12.8,
                'fontFamily': 'BookMyungjo',
                'fontWeight': 'w800',
                'color': '#222222',
                'letterSpacing': 1.2,
              },
            },
            {
              'id': 'subtitle',
              'type': 'text',
              'x': 0.08,
              'y': 0.88,
              'w': 0.84,
              'h': 0.08,
              'text': subtitle,
              'align': 'center',
              'z': 20,
              'style': {
                'fontSize': 8.8,
                'fontFamily': 'Raleway',
                'fontWeight': 'w600',
                'color': '#3D3D3D',
                'letterSpacing': 0.8,
              },
            },
          ];
        },
  ),
];

final List<_Theme> _themes = <_Theme>[
  _Theme(
    slug: 'wedding',
    name: '웨딩',
    category: '커플',
    style: 'romantic',
    tags: ['웨딩', '초대장', '세리프'],
    titles: ['SAVE THE DATE', 'OUR WEDDING DAY', 'FOREVER STARTS HERE'],
    subtitles: ['함께하는 날, 우리의 첫 장면', '사랑의 시작을 초대합니다', '두 사람의 이야기를 기록하세요'],
  ),
  _Theme(
    slug: 'summer',
    name: '서머',
    category: '여행',
    style: 'vivid',
    tags: ['여름', '휴양', '포스터'],
    titles: ['HELLO SUMMER', 'SUMMER VACATION', 'BEACH POSTCARD'],
    subtitles: ['뜨거운 계절의 가장 반짝이는 장면', '푸른 바다와 햇살을 한 장에', '이번 여름의 모든 기록'],
  ),
  _Theme(
    slug: 'daily',
    name: '데일리',
    category: '감성',
    style: 'editorial',
    tags: ['일상', '무드', '매거진'],
    titles: ['MY DAILY FRAME', 'MOOD ARCHIVE', 'TODAY IN PAGES'],
    subtitles: ['사소한 하루가 가장 선명한 기억이 돼요', '장면마다 감정을 담아보세요', '오늘의 공기까지 저장하는 페이지'],
  ),
  _Theme(
    slug: 'family',
    name: '패밀리',
    category: '가족',
    style: 'warm',
    tags: ['가족', '따뜻함', '추억'],
    titles: ['FAMILY MOMENTS', 'OUR LITTLE DAYS', 'HOME STORY'],
    subtitles: ['우리 가족의 오늘을 오래 남겨요', '사랑이 자라는 순간들', '같이 웃은 날의 기록'],
  ),
];

final Map<String, List<String>> _imagePoolByTheme = <String, List<String>>{
  'wedding': [
    'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1513278974582-3e1b4a4fa21f?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=1200&q=80',
  ],
  'summer': [
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1473116763249-2faaef81ccda?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1493558103817-58b2924bce98?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1520942702018-0862200e6873?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=1200&q=80',
  ],
  'daily': [
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1506869640319-fe1a24fd76dc?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
  ],
  'family': [
    'https://images.unsplash.com/photo-1511895426328-dc8714191300?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1516627145497-ae6968895b74?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1518933165971-611dbc9c412d?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1511988617509-a57c8a288659?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1472396961693-142e6e269027?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1469571486292-b53601020e7f?auto=format&fit=crop&w=1200&q=80',
  ],
  'general': [
    'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1482192505345-5655af888cc4?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=1200&q=80',
  ],
};

typedef _LayerBuilder =
    List<Map<String, dynamic>> Function({
      required String title,
      required String subtitle,
      required math.Random rng,
    });

class _Recipe {
  const _Recipe({
    required this.id,
    required this.displayName,
    required this.recommendedPhotoCount,
    required this.build,
  });

  final String id;
  final String displayName;
  final int recommendedPhotoCount;
  final _LayerBuilder build;
}

class _Theme {
  const _Theme({
    required this.slug,
    required this.name,
    required this.category,
    required this.style,
    required this.tags,
    required this.titles,
    required this.subtitles,
  });

  final String slug;
  final String name;
  final String category;
  final String style;
  final List<String> tags;
  final List<String> titles;
  final List<String> subtitles;
}

class _CliOptions {
  const _CliOptions({
    required this.count,
    required this.outputPath,
    required this.catalogPath,
    required this.constantsPath,
    required this.registryPath,
    this.seed,
  });

  final int count;
  final int? seed;
  final String outputPath;
  final String catalogPath;
  final String constantsPath;
  final String registryPath;

  static _CliOptions parse(List<String> args) {
    int count = 6;
    int? seed;
    String outputPath = 'assets/templates/generated/latest.json';
    String catalogPath = 'assets/templates/design_templates_v1.json';
    String constantsPath = 'lib/core/constants/design_templates.dart';
    String registryPath =
        'assets/templates/generated/template_factory_registry.json';

    for (final arg in args) {
      if (arg.startsWith('--count=')) {
        count = int.tryParse(arg.split('=').last) ?? count;
      } else if (arg.startsWith('--seed=')) {
        seed = int.tryParse(arg.split('=').last);
      } else if (arg.startsWith('--output=')) {
        outputPath = arg.split('=').last;
      } else if (arg.startsWith('--catalog=')) {
        catalogPath = arg.split('=').last;
      } else if (arg.startsWith('--constants=')) {
        constantsPath = arg.split('=').last;
      } else if (arg.startsWith('--registry=')) {
        registryPath = arg.split('=').last;
      }
    }

    return _CliOptions(
      count: count,
      seed: seed,
      outputPath: outputPath,
      catalogPath: catalogPath,
      constantsPath: constantsPath,
      registryPath: registryPath,
    );
  }
}

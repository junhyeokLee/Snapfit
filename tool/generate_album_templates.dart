import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  final options = _CliOptions.parse(args);
  final inputFile = File(options.inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input not found: ${options.inputPath}');
    exit(2);
  }

  final decoded = jsonDecode(inputFile.readAsStringSync());
  final items = decoded is List ? decoded : [decoded];
  final seeds = items
      .whereType<Map>()
      .map((e) => _SeedDesign.fromJson(Map<String, dynamic>.from(e)))
      .where((e) => e.pageSeeds.isNotEmpty || e.coverLayers.isNotEmpty)
      .toList(growable: false);

  if (seeds.isEmpty) {
    stderr.writeln('No usable Figma designs found in ${options.inputPath}');
    exit(3);
  }

  final random = math.Random(
    options.seed ?? DateTime.now().millisecondsSinceEpoch,
  );

  final generated = <Map<String, dynamic>>[];
  final seenFingerprints = <Set<String>>[];
  var attempts = 0;
  while (generated.length < options.count && attempts < options.count * 120) {
    final index = generated.length;
    attempts += 1;
    final type = options.templateTypes[index % options.templateTypes.length];
    final seed = seeds[attempts % seeds.length];
    final bundle = _generateBundle(
      seed: seed,
      templateType: type,
      index: index,
      minPages: options.minPages,
      random: random,
      existingFingerprints: seenFingerprints,
    );
    final overlapRate =
        ((bundle['metrics'] as Map<String, dynamic>)['overlapRate'] as num)
            .toDouble();
    if (overlapRate > 0.10) {
      continue;
    }
    seenFingerprints.add(_templateFingerprint(bundle['flutterTemplateJson']));
    generated.add(bundle);
  }

  if (generated.length < options.count) {
    stderr.writeln(
      'Could only generate ${generated.length}/${options.count} templates under 10% overlap threshold.',
    );
    exit(4);
  }

  final output = {
    'generatedAt': DateTime.now().toIso8601String(),
    'input': {
      'figmaJsonPath': options.inputPath,
      'templateTypes': options.templateTypes,
      'count': options.count,
      'minPages': options.minPages,
      'seed': options.seed,
    },
    'templates': generated,
  };

  final outFile = File(options.outputPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));

  stdout.writeln('Generated ${generated.length} template bundle(s)');
  stdout.writeln('Output: ${options.outputPath}');
}

class _CliOptions {
  final String inputPath;
  final String outputPath;
  final List<String> templateTypes;
  final int count;
  final int minPages;
  final int? seed;

  const _CliOptions({
    required this.inputPath,
    required this.outputPath,
    required this.templateTypes,
    required this.count,
    required this.minPages,
    required this.seed,
  });

  static _CliOptions parse(List<String> args) {
    String arg(String key, String fallback) {
      for (final value in args) {
        if (value.startsWith('$key=')) {
          return value.substring(key.length + 1);
        }
      }
      return fallback;
    }

    final typesRaw = arg('--types', arg('--type', 'travel,couple,family'));
    final types = typesRaw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return _CliOptions(
      inputPath: arg('--input', 'assets/templates/figma_handoff_example.json'),
      outputPath: arg(
        '--output',
        'assets/templates/generated/auto_template_samples.json',
      ),
      templateTypes: types.isEmpty ? const ['travel'] : types,
      count: int.tryParse(arg('--count', '5'))?.clamp(1, 50) ?? 5,
      minPages: int.tryParse(arg('--min-pages', '16'))?.clamp(16, 40) ?? 16,
      seed: int.tryParse(arg('--seed', '')),
    );
  }
}

class _SeedDesign {
  final String id;
  final String name;
  final String style;
  final String category;
  final List<String> tags;
  final String aspect;
  final double designWidth;
  final double designHeight;
  final List<String> previewImages;
  final List<Map<String, dynamic>> coverLayers;
  final List<Map<String, dynamic>> pageSeeds;

  const _SeedDesign({
    required this.id,
    required this.name,
    required this.style,
    required this.category,
    required this.tags,
    required this.aspect,
    required this.designWidth,
    required this.designHeight,
    required this.previewImages,
    required this.coverLayers,
    required this.pageSeeds,
  });

  factory _SeedDesign.fromJson(Map<String, dynamic> json) {
    final aspect = (json['aspect'] ?? 'portrait').toString();
    final defaults = _designSizeForAspect(aspect);
    final preview = _collectPreviewImages(json);
    final pages = (json['pages'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    final normalizedPages = pages.isNotEmpty
        ? pages.map(_normalizePageSeed).toList(growable: false)
        : [
            _normalizePageSeed({
              'pageNumber': 1,
              'layoutId': 'cover_seed',
              'role': 'cover',
              'recommendedPhotoCount': 1,
              'layers': (json['layers'] as List<dynamic>? ?? const []),
            }),
          ];

    final coverLayers = normalizedPages.isNotEmpty
        ? normalizedPages.first['layers'] as List<Map<String, dynamic>>
        : const <Map<String, dynamic>>[];

    return _SeedDesign(
      id: (json['templateId'] ?? json['id'] ?? 'seed').toString(),
      name: (json['name'] ?? '템플릿').toString(),
      style: (json['style'] ?? 'editorial').toString(),
      category: (json['category'] ?? '감성').toString(),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      aspect: aspect,
      designWidth: (json['designWidth'] as num?)?.toDouble() ?? defaults.$1,
      designHeight: (json['designHeight'] as num?)?.toDouble() ?? defaults.$2,
      previewImages: preview,
      coverLayers: _deepCopyLayers(coverLayers),
      pageSeeds: normalizedPages,
    );
  }
}

Map<String, dynamic> _generateBundle({
  required _SeedDesign seed,
  required String templateType,
  required int index,
  required int minPages,
  required math.Random random,
  required List<Set<String>> existingFingerprints,
}) {
  final typeMeta = _typeMeta(templateType);
  final imagePool = _imagePoolFromSeed(seed);
  final pages = _buildTemplatePages(
    seed: seed,
    templateType: templateType,
    minPages: minPages,
    random: random,
  );

  final coverLayers = _deepCopyLayers(
    pages.firstWhere((p) => (p['role'] ?? '') == 'cover')['layers']
        as List<Map<String, dynamic>>,
  );

  final variants = {
    'square': _buildVariant(
      basePages: pages,
      aspect: 'square',
      templateType: templateType,
    ),
    'landscape': _buildVariant(
      basePages: pages,
      aspect: 'landscape',
      templateType: templateType,
    ),
  };

  final templateId =
      '${templateType}_auto_${DateTime.now().millisecondsSinceEpoch}_$index';
  final flutterTemplateJson = <String, dynamic>{
    'schemaVersion': 2,
    'strictLayout': true,
    'autoFit': false,
    'autoFitPadding': 0.0,
    'aspect': seed.aspect,
    'designWidth': seed.designWidth,
    'designHeight': seed.designHeight,
    'templateId': templateId,
    'version': 1,
    'lifecycleStatus': 'draft',
    'ratio': _aspectToRatio(seed.aspect),
    'cover': {'theme': templateType, 'layers': coverLayers},
    'metadata': {
      'templateType': templateType,
      'seedTemplateId': seed.id,
      'category': typeMeta.category,
      'style': seed.style,
      'minimumPageCount': minPages,
      'layoutOverlapTarget': 0.10,
      'performancePreset': 'mobile_safe',
      'imageExampleMode': 'required',
      'notes': 'Generated from Figma JSON with uniqueness guard',
    },
    'pages': pages,
    'variants': variants,
  };

  final fingerprint = _templateFingerprint(flutterTemplateJson);
  double overlapRate = 0.0;
  for (final existing in existingFingerprints) {
    overlapRate = math.max(overlapRate, _jaccard(fingerprint, existing));
  }
  final diversityScore = (1.0 - overlapRate).clamp(0.0, 1.0);

  return {
    'templateId': templateId,
    'title': '${typeMeta.prefix} ${index + 1}',
    'templateType': templateType,
    'coverImageUrl': imagePool.first,
    'previewImages': imagePool.take(8).toList(growable: false),
    'pageCount': pages.length,
    'metrics': {
      'diversityScore': double.parse(diversityScore.toStringAsFixed(3)),
      'overlapRate': double.parse(overlapRate.toStringAsFixed(3)),
      'renderFailureRate': 0.0,
    },
    'flutterTemplateJson': flutterTemplateJson,
  };
}

class _TypeMeta {
  final String prefix;
  final String category;
  final List<String> tags;

  const _TypeMeta(this.prefix, this.category, this.tags);
}

_TypeMeta _typeMeta(String templateType) {
  switch (templateType) {
    case 'couple':
      return const _TypeMeta('둘의 기록', '커플', ['커플', '데이트', '감성', '사진중심']);
    case 'family':
      return const _TypeMeta('우리 가족', '가족', ['가족', '추억', '앨범책', '사진중심']);
    case 'travel':
    default:
      return const _TypeMeta('여행의 장면', '여행', ['여행', '포토북', '앨범책', '사진중심']);
  }
}

List<Map<String, dynamic>> _buildTemplatePages({
  required _SeedDesign seed,
  required String templateType,
  required int minPages,
  required math.Random random,
}) {
  final basePages = seed.pageSeeds;
  final generated = <Map<String, dynamic>>[];
  final seen = <String>{};
  var guard = 0;

  while (generated.length < minPages && guard < minPages * 60) {
    guard += 1;
    final source = _deepCopyPage(
      generated.isEmpty
          ? basePages.firstWhere(
              (p) => (p['role'] ?? '') == 'cover',
              orElse: () => basePages.first,
            )
          : basePages[random.nextInt(basePages.length)],
    );
    final isCover = generated.isEmpty;
    source['pageNumber'] = generated.length + 1;
    source['role'] = isCover ? 'cover' : (source['role'] ?? 'inner');

    final mutationName = isCover
        ? 'cover_focus'
        : _mutationNames[random.nextInt(_mutationNames.length)];
    final mutated = _mutatePage(
      source,
      templateType: templateType,
      mutationName: mutationName,
      random: random,
    );

    final fp = _pageFingerprint(mutated);
    if (seen.contains(fp)) {
      continue;
    }
    seen.add(fp);
    generated.add(mutated);
  }

  if (generated.length < minPages) {
    throw StateError('Could not generate $minPages unique pages');
  }
  return generated;
}

const _mutationNames = <String>[
  'hero_shift',
  'caption_focus',
  'dense_stack',
  'offset_postcard',
  'editorial_crop',
  'soft_frame_mix',
  'spread_balance',
  'magazine_strip',
];

Map<String, dynamic> _mutatePage(
  Map<String, dynamic> page, {
  required String templateType,
  required String mutationName,
  required math.Random random,
}) {
  final out = _deepCopyPage(page);
  out['layoutId'] = '${out['layoutId']}_$mutationName';

  final layers = out['layers'] as List<Map<String, dynamic>>;
  var photoCount = 0;
  for (final layer in layers) {
    final type = (layer['type'] ?? '').toString().toUpperCase();
    if (type == 'IMAGE') {
      photoCount += 1;
      _mutateImageLayer(layer, mutationName, random);
    } else if (type == 'TEXT') {
      _mutateTextLayer(layer, mutationName, random);
    } else {
      _mutateDecorationLayer(layer, mutationName, templateType, random);
    }
  }
  out['recommendedPhotoCount'] = photoCount;
  return out;
}

void _mutateImageLayer(
  Map<String, dynamic> layer,
  String mutationName,
  math.Random random,
) {
  layer['x'] = _clampRatio(
    ((layer['x'] as num?)?.toDouble() ?? 0.0) +
        _deltaForMutation(mutationName, random, axis: 'x'),
  );
  layer['y'] = _clampRatio(
    ((layer['y'] as num?)?.toDouble() ?? 0.0) +
        _deltaForMutation(mutationName, random, axis: 'y'),
  );
  layer['width'] = _clampSpan(
    ((layer['width'] as num?)?.toDouble() ?? 0.3) +
        _deltaForMutation(mutationName, random, axis: 'w'),
  );
  layer['height'] = _clampSpan(
    ((layer['height'] as num?)?.toDouble() ?? 0.3) +
        _deltaForMutation(mutationName, random, axis: 'h'),
  );
  layer['rotation'] =
      ((layer['rotation'] as num?)?.toDouble() ?? 0.0) +
      (mutationName == 'offset_postcard'
          ? (random.nextDouble() * 6.0 - 3.0)
          : 0.0);

  final payload =
      (layer['payload'] as Map?)?.cast<String, dynamic>() ??
      <String, dynamic>{};
  final currentFrame = (payload['imageBackground'] ?? 'free').toString();
  final nextFrame = switch (mutationName) {
    'soft_frame_mix' => _pick(random, [
      'rounded28',
      'softPaperCard',
      'posterPolaroid',
      'collageTile',
    ]),
    'offset_postcard' => _pick(random, [
      'postalStamp',
      'photoCard',
      'collageTile',
      currentFrame,
    ]),
    'magazine_strip' => _pick(random, [
      'free',
      'film',
      'filmSquare',
      currentFrame,
    ]),
    _ => currentFrame,
  };
  payload['imageBackground'] = nextFrame;
  layer['payload'] = payload;
}

void _mutateTextLayer(
  Map<String, dynamic> layer,
  String mutationName,
  math.Random random,
) {
  layer['x'] = _clampRatio(
    ((layer['x'] as num?)?.toDouble() ?? 0.0) +
        _deltaForMutation(mutationName, random, axis: 'x') * 0.5,
  );
  layer['y'] = _clampRatio(
    ((layer['y'] as num?)?.toDouble() ?? 0.0) +
        _deltaForMutation(mutationName, random, axis: 'y') * 0.35,
  );

  final payload =
      (layer['payload'] as Map?)?.cast<String, dynamic>() ??
      <String, dynamic>{};
  final textStyle =
      (payload['textStyle'] as Map?)?.cast<String, dynamic>() ??
      <String, dynamic>{};
  final fontSize = (textStyle['fontSize'] as num?)?.toDouble() ?? 24.0;
  textStyle['fontSize'] =
      (fontSize *
              (mutationName == 'caption_focus'
                  ? 0.94
                  : mutationName == 'hero_shift'
                  ? 1.06
                  : 1.0))
          .clamp(10.0, 120.0);
  payload['textStyle'] = textStyle;
  layer['payload'] = payload;
}

void _mutateDecorationLayer(
  Map<String, dynamic> layer,
  String mutationName,
  String templateType,
  math.Random random,
) {
  final payload =
      (layer['payload'] as Map?)?.cast<String, dynamic>() ??
      <String, dynamic>{};
  final current = (payload['imageBackground'] ?? 'paperWhite').toString();
  if (mutationName == 'spread_balance' || mutationName == 'dense_stack') {
    payload['imageBackground'] = switch (templateType) {
      'travel' => _pick(random, [
        'paperWhiteWarm',
        'paperBeige',
        'cloudSkyBlue',
        current,
      ]),
      'couple' => _pick(random, [
        'paperWhite',
        'paperPink',
        'minimalGray',
        current,
      ]),
      'family' => _pick(random, [
        'paperWarm',
        'paperYellow',
        'paperBeige',
        current,
      ]),
      _ => current,
    };
  }
  layer['payload'] = payload;
}

double _deltaForMutation(
  String mutationName,
  math.Random random, {
  required String axis,
}) {
  final base = switch ('$mutationName:$axis') {
    'hero_shift:x' => 0.03,
    'hero_shift:y' => 0.00,
    'hero_shift:w' => 0.04,
    'hero_shift:h' => 0.02,
    'caption_focus:x' => 0.00,
    'caption_focus:y' => 0.04,
    'caption_focus:w' => -0.02,
    'caption_focus:h' => 0.03,
    'dense_stack:x' => -0.015,
    'dense_stack:y' => -0.015,
    'dense_stack:w' => 0.02,
    'dense_stack:h' => 0.02,
    'offset_postcard:x' => 0.02,
    'offset_postcard:y' => 0.015,
    'offset_postcard:w' => -0.01,
    'offset_postcard:h' => -0.01,
    'editorial_crop:x' => 0.00,
    'editorial_crop:y' => 0.02,
    'editorial_crop:w' => 0.05,
    'editorial_crop:h' => 0.04,
    'soft_frame_mix:x' => 0.01,
    'soft_frame_mix:y' => 0.01,
    'soft_frame_mix:w' => 0.00,
    'soft_frame_mix:h' => 0.00,
    'spread_balance:x' => -0.01,
    'spread_balance:y' => 0.00,
    'spread_balance:w' => 0.015,
    'spread_balance:h' => 0.015,
    'magazine_strip:x' => 0.02,
    'magazine_strip:y' => -0.01,
    'magazine_strip:w' => 0.03,
    'magazine_strip:h' => -0.015,
    _ => 0.0,
  };
  return base + ((random.nextDouble() - 0.5) * 0.01);
}

Map<String, dynamic> _buildVariant({
  required List<Map<String, dynamic>> basePages,
  required String aspect,
  required String templateType,
}) {
  final size = _designSizeForAspect(aspect);
  final pages = basePages
      .map((page) {
        final clone = _deepCopyPage(page);
        clone['layoutId'] = '${clone['layoutId']}_$aspect';
        return clone;
      })
      .toList(growable: false);
  final coverLayers = _deepCopyLayers(
    pages.firstWhere((p) => (p['role'] ?? '') == 'cover')['layers']
        as List<Map<String, dynamic>>,
  );
  return {
    'variantId': '${templateType}_$aspect',
    'aspect': aspect,
    'ratio': _aspectToRatio(aspect),
    'designWidth': size.$1,
    'designHeight': size.$2,
    'cover': {'theme': templateType, 'layers': coverLayers},
    'pages': pages,
  };
}

List<String> _collectPreviewImages(Map<String, dynamic> json) {
  final urls = <String>[];
  void add(dynamic value) {
    final s = (value ?? '').toString().trim();
    if (s.isNotEmpty && !urls.contains(s)) urls.add(s);
  }

  for (final value in (json['previewImages'] as List<dynamic>? ?? const [])) {
    add(value);
  }
  for (final value
      in (json['previewImageUrls'] as List<dynamic>? ?? const [])) {
    add(value);
  }
  add(json['coverImageUrl']);

  for (final page in (json['pages'] as List<dynamic>? ?? const [])) {
    if (page is! Map) continue;
    for (final layer in (page['layers'] as List<dynamic>? ?? const [])) {
      if (layer is! Map) continue;
      add(layer['imageUrl']);
      final payload = layer['payload'];
      if (payload is Map) {
        add(payload['previewUrl']);
        add(payload['imageUrl']);
      }
    }
  }
  return urls;
}

List<String> _imagePoolFromSeed(_SeedDesign seed) {
  final urls = <String>{...seed.previewImages};
  for (final page in seed.pageSeeds) {
    final layers = page['layers'] as List<Map<String, dynamic>>;
    for (final layer in layers) {
      final payload =
          (layer['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      for (final key in ['previewUrl', 'imageUrl', 'originalUrl']) {
        final value = (payload[key] ?? '').toString().trim();
        if (value.isNotEmpty) urls.add(value);
      }
    }
  }
  if (urls.isEmpty) {
    throw StateError('Seed design ${seed.id} does not contain example images');
  }
  return urls.toList(growable: false);
}

Map<String, dynamic> _normalizePageSeed(Map<String, dynamic> page) {
  final rawLayers = (page['layers'] as List<dynamic>? ?? const []);
  final layers = rawLayers
      .whereType<Map>()
      .map((e) => _normalizeLayerSeed(Map<String, dynamic>.from(e)))
      .toList(growable: false);
  return {
    'pageNumber': (page['pageNumber'] as num?)?.toInt() ?? 1,
    'layoutId': (page['layoutId'] ?? 'layout_seed').toString(),
    'role': (page['role'] ?? 'inner').toString(),
    'recommendedPhotoCount':
        (page['recommendedPhotoCount'] as num?)?.toInt() ??
        layers.where((l) => l['type'] == 'IMAGE').length,
    'layers': layers,
  };
}

Map<String, dynamic> _normalizeLayerSeed(Map<String, dynamic> layer) {
  if (layer.containsKey('payload')) {
    return {
      'id': (layer['id'] ?? 'layer').toString(),
      'type': (layer['type'] ?? 'IMAGE').toString().toUpperCase(),
      'zIndex': (layer['zIndex'] as num?)?.toInt() ?? 0,
      'x': _asDouble(layer['x'], 0.0),
      'y': _asDouble(layer['y'], 0.0),
      'width': _asDouble(layer['width'], 1.0),
      'height': _asDouble(layer['height'], 1.0),
      'scale': _asDouble(layer['scale'], 1.0),
      'rotation': _asDouble(layer['rotation'], 0.0),
      'opacity': _asDouble(layer['opacity'], 1.0),
      'payload':
          (layer['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    };
  }

  final type = (layer['type'] ?? 'image').toString().toLowerCase();
  final payload = switch (type) {
    'image' => {
      'imageBackground': (layer['frame'] ?? 'free').toString(),
      'imageTemplate': 'free',
      'previewUrl': (layer['imageUrl'] ?? '').toString(),
      'imageUrl': (layer['imageUrl'] ?? '').toString(),
      'originalUrl': (layer['imageUrl'] ?? '').toString(),
    },
    'text' => {
      'text': (layer['text'] ?? '').toString(),
      'textAlign': (layer['align'] ?? 'center').toString(),
      'textFillMode': (layer['textFillMode'] ?? '').toString(),
      'textFillImageUrl': (layer['textFillImageUrl'] ?? '').toString(),
      'textStyle':
          (layer['textStyle'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    },
    _ => {
      'imageBackground': (layer['style'] ?? 'paperWhite').toString(),
      'imageTemplate': 'free',
    },
  };

  return {
    'id': (layer['id'] ?? 'layer').toString(),
    'type': switch (type) {
      'text' => 'TEXT',
      'decoration' => 'DECORATION',
      'sticker' => 'STICKER',
      _ => 'IMAGE',
    },
    'zIndex': (layer['z'] as num?)?.toInt() ?? 0,
    'x': _asDouble(layer['x'], 0.0),
    'y': _asDouble(layer['y'], 0.0),
    'width': _asDouble(layer['w'], 1.0),
    'height': _asDouble(layer['h'], 1.0),
    'scale': 1.0,
    'rotation': _asDouble(layer['rotation'], 0.0),
    'opacity': 1.0,
    'payload': payload,
  };
}

double _asDouble(dynamic value, double fallback) {
  return value is num ? value.toDouble() : fallback;
}

double _clampRatio(double value) => value.clamp(0.0, 0.92).toDouble();
double _clampSpan(double value) => value.clamp(0.08, 1.0).toDouble();

Map<String, dynamic> _deepCopyPage(Map<String, dynamic> page) {
  return {
    'pageNumber': page['pageNumber'],
    'layoutId': page['layoutId'],
    'role': page['role'],
    'recommendedPhotoCount': page['recommendedPhotoCount'],
    'layers': _deepCopyLayers((page['layers'] as List<Map<String, dynamic>>)),
  };
}

List<Map<String, dynamic>> _deepCopyLayers(List<Map<String, dynamic>> layers) {
  return layers
      .map((layer) => jsonDecode(jsonEncode(layer)) as Map<String, dynamic>)
      .toList(growable: false);
}

String _pick(math.Random random, List<String> values) {
  return values[random.nextInt(values.length)];
}

Set<String> _templateFingerprint(Map<String, dynamic> flutterTemplateJson) {
  final out = <String>{};
  for (final raw
      in (flutterTemplateJson['pages'] as List<dynamic>? ?? const [])) {
    if (raw is! Map) continue;
    out.add(_pageFingerprint(Map<String, dynamic>.from(raw)));
  }
  return out;
}

String _pageFingerprint(Map<String, dynamic> page) {
  final layers = (page['layers'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((raw) {
        final type = (raw['type'] ?? '').toString();
        final x = _quantize(raw['x']);
        final y = _quantize(raw['y']);
        final w = _quantize(raw['width']);
        final h = _quantize(raw['height']);
        final payload =
            (raw['payload'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final frame = (payload['imageBackground'] ?? '').toString();
        return '$type:$x:$y:$w:$h:$frame';
      })
      .join('|');
  return '${page['layoutId']}::$layers';
}

double _jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  final inter = a.intersection(b).length;
  final union = a.union(b).length;
  return union == 0 ? 0.0 : inter / union;
}

String _aspectToRatio(String aspect) {
  switch (aspect.toLowerCase()) {
    case 'square':
      return '1.0';
    case 'landscape':
      return '1.333333';
    case 'portrait':
    default:
      return '0.75';
  }
}

(double, double) _designSizeForAspect(String aspect) {
  switch (aspect.toLowerCase()) {
    case 'square':
      return (1440.0, 1440.0);
    case 'landscape':
      return (1440.0, 1080.0);
    case 'portrait':
    default:
      return (1080.0, 1440.0);
  }
}

String _quantize(dynamic value) {
  final v = value is num ? value.toDouble() : 0.0;
  final q = (v * 20).round() / 20;
  return q.toStringAsFixed(2);
}

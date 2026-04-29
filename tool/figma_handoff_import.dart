import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final inputPath =
      _arg(args, '--input') ?? 'assets/templates/figma_handoff_example.json';
  final outputPath =
      _arg(args, '--output') ?? 'assets/templates/generated/latest.json';

  final inFile = File(inputPath);
  if (!inFile.existsSync()) {
    stderr.writeln('Input not found: $inputPath');
    exit(2);
  }

  final raw = jsonDecode(inFile.readAsStringSync());
  final handoffs = raw is List ? raw : [raw];

  final templates = <Map<String, dynamic>>[];
  for (final item in handoffs) {
    if (item is! Map) continue;
    templates.add(_convert(Map<String, dynamic>.from(item)));
  }

  final outFile = File(outputPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(templates),
  );

  stdout.writeln('Imported ${templates.length} template(s) from Figma handoff');
  stdout.writeln('Output: $outputPath');
}

String? _arg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) {
      return arg.substring(key.length + 1);
    }
  }
  return null;
}

Map<String, dynamic> _convert(Map<String, dynamic> src) {
  final previewImages = (src['previewImages'] as List<dynamic>? ?? const [])
      .map((e) => e.toString())
      .where((e) => e.trim().isNotEmpty)
      .toList();

  final layers = (src['layers'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((l) => _convertLayer(Map<String, dynamic>.from(l)))
      .toList();

  final aspect = (src['aspect'] ?? 'portrait').toString();
  final designSize = _defaultDesignSize(aspect);
  final designWidth = _n(src['designWidth'], designSize.$1);
  final designHeight = _n(src['designHeight'], designSize.$2);

  return {
    'id': (src['id'] ?? 'figma_import_${DateTime.now().millisecondsSinceEpoch}')
        .toString(),
    'name': (src['name'] ?? '피그마 템플릿').toString(),
    'category': (src['category'] ?? '감성').toString(),
    'tags': (src['tags'] as List<dynamic>? ?? const ['피그마'])
        .map((e) => e.toString())
        .toList(),
    'style': (src['style'] ?? 'editorial').toString(),
    'aspect': aspect,
    'designWidth': designWidth,
    'designHeight': designHeight,
    'difficulty': (src['difficulty'] ?? 'normal').toString(),
    'recommendedPhotoCount': (src['recommendedPhotoCount'] is num)
        ? (src['recommendedPhotoCount'] as num).toInt()
        : 3,
    'isFeatured': src['isFeatured'] == true,
    'priority': (src['priority'] is num) ? (src['priority'] as num).toInt() : 0,
    'previewThumbUrl': previewImages.isNotEmpty ? previewImages.first : '',
    'previewDetailUrl': previewImages.length > 1
        ? previewImages[1]
        : (previewImages.isNotEmpty ? previewImages.first : ''),
    'previewImageUrls': previewImages,
    // Figma handoff는 원본 위치/크기 유지가 핵심이라 자동 보정 비활성화
    'strictLayout': true,
    'autoFit': false,
    'autoFitPadding': 0.0,
    'layers': layers
        .map(
          (l) => _normalizeLayerRect(
            l,
            designWidth: designWidth,
            designHeight: designHeight,
          ),
        )
        .toList(growable: false),
  };
}

(double, double) _defaultDesignSize(String aspect) {
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

Map<String, dynamic> _convertLayer(Map<String, dynamic> src) {
  final type = (src['type'] ?? 'decoration').toString().toLowerCase();
  final base = <String, dynamic>{
    'id': (src['id'] ?? 'layer').toString(),
    'type': type,
    'x': _n(src['x'], 0.0),
    'y': _n(src['y'], 0.0),
    'w': _n(src['w'], 1.0),
    'h': _n(src['h'], 1.0),
    'z': _n(src['z'], 0).toInt(),
  };

  final rotation = _n(src['rotation'], 0.0);
  if (rotation != 0) base['rotation'] = rotation;

  if (type == 'image') {
    base['frame'] = (src['frame'] ?? 'photoCard').toString();
    final imageUrl = (src['imageUrl'] ?? '').toString().trim();
    final asset = (src['asset'] ?? '').toString().trim();
    if (imageUrl.isNotEmpty) {
      base['imageUrl'] = imageUrl;
    } else if (asset.isNotEmpty) {
      base['asset'] = asset.startsWith('asset:') ? asset : 'asset:$asset';
    }
  } else if (type == 'text') {
    base['text'] = (src['text'] ?? '').toString();
    base['align'] = (src['align'] ?? 'center').toString();
    final textFillMode = (src['textFillMode'] ?? '').toString().trim();
    final textFillImageUrl = (src['textFillImageUrl'] ?? '').toString().trim();
    if (textFillMode.isNotEmpty) base['textFillMode'] = textFillMode;
    if (textFillImageUrl.isNotEmpty) {
      base['textFillImageUrl'] = textFillImageUrl;
    }
    base['style'] = Map<String, dynamic>.from(
      src['textStyle'] as Map? ??
          const {
            'fontSize': 14.0,
            'fontFamily': 'NotoSans',
            'fontWeight': 'w600',
            'color': '#1F2937',
          },
    );
  } else {
    base['style'] = (src['style'] ?? 'paperWhite').toString();
  }

  return base;
}

Map<String, dynamic> _normalizeLayerRect(
  Map<String, dynamic> src, {
  required double designWidth,
  required double designHeight,
}) {
  final out = Map<String, dynamic>.from(src);
  final x = (out['x'] as num?)?.toDouble() ?? 0.0;
  final y = (out['y'] as num?)?.toDouble() ?? 0.0;
  final w = (out['w'] as num?)?.toDouble() ?? 1.0;
  final h = (out['h'] as num?)?.toDouble() ?? 1.0;

  out['x'] = _toUnitOrRatio(x, base: designWidth);
  out['y'] = _toUnitOrRatio(y, base: designHeight);
  out['w'] = _toUnitOrRatio(w, base: designWidth);
  out['h'] = _toUnitOrRatio(h, base: designHeight);
  return out;
}

double _toUnitOrRatio(double value, {required double base}) {
  if (value.isNaN || !value.isFinite) return 0.0;
  // 이미 비율인 경우
  if (value >= 0.0 && value <= 1.0) return value;
  if (base <= 0) return value;
  // 절대 좌표(px)로 들어온 경우를 비율로 변환
  final ratio = value / base;
  return ratio.clamp(-2.0, 3.0).toDouble();
}

double _n(dynamic value, num fallback) {
  if (value is num) return value.toDouble();
  return fallback.toDouble();
}

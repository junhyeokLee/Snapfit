import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final inputPath =
      _arg(args, '--input') ?? 'assets/templates/figma_handoff_example.json';
  final outputPath =
      _arg(args, '--output') ?? 'assets/templates/generated/store_latest.json';
  final pageCount =
      int.tryParse(_arg(args, '--pages') ?? '12')?.clamp(12, 24) ?? 12;
  final exactMode = (_arg(args, '--exact') ?? 'true').toLowerCase() != 'false';

  final inFile = File(inputPath);
  if (!inFile.existsSync()) {
    stderr.writeln('Input not found: $inputPath');
    exit(2);
  }

  final decoded = jsonDecode(inFile.readAsStringSync());
  final handoffs = decoded is List ? decoded : [decoded];

  final out = <Map<String, dynamic>>[];
  for (final raw in handoffs) {
    if (raw is! Map) continue;
    final src = Map<String, dynamic>.from(raw);
    out.add(_toStoreTemplate(src, pageCount: pageCount, exactMode: exactMode));
  }

  final outFile = File(outputPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  stdout.writeln('Built ${out.length} store template(s)');
  stdout.writeln('Output: $outputPath');
}

String? _arg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) return arg.substring(key.length + 1);
  }
  return null;
}

int _stableHash(String input) {
  var hash = 0;
  for (final c in input.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  return hash;
}

String _safeImage(String seed, {int w = 1200, int h = 900}) {
  final clean = seed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return 'https://picsum.photos/seed/$clean/$w/$h';
}

String _normalizeArgbColor(String raw, {String fallback = '#FF1F2937'}) {
  final s = raw.trim();
  if (s.isEmpty) return fallback;
  final hex = s.startsWith('#') ? s.substring(1) : s;
  if (hex.length == 6) return '#FF${hex.toUpperCase()}';
  if (hex.length == 8) return '#${hex.toUpperCase()}';
  return fallback;
}

int _toDifficulty(dynamic v) {
  final s = (v ?? 'normal').toString().toLowerCase();
  if (s.contains('easy')) return 1;
  if (s.contains('hard')) return 3;
  return 2;
}

List<String> _previewImages(Map<String, dynamic> src) {
  final fromPreviewImages = (src['previewImages'] as List<dynamic>? ?? const [])
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (fromPreviewImages.isNotEmpty) return fromPreviewImages;

  final fromPreviewImageUrls =
      (src['previewImageUrls'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
  if (fromPreviewImageUrls.isNotEmpty) return fromPreviewImageUrls;

  return [_safeImage((src['id'] ?? 'tpl').toString())];
}

Map<String, dynamic> _toStoreTemplate(
  Map<String, dynamic> src, {
  required int pageCount,
  required bool exactMode,
}) {
  final sourceId = (src['id'] ?? 'tpl').toString();
  final title = (src['name'] ?? sourceId).toString();
  final category = (src['category'] ?? '감성').toString();
  final style = (src['style'] ?? 'editorial').toString();
  final tags = (src['tags'] as List<dynamic>? ?? const ['템플릿'])
      .map((e) => e.toString())
      .toList();
  final preview = _previewImages(src);
  final aspect = (src['aspect'] ?? 'portrait').toString();
  final designSize = _defaultDesignSize(aspect);
  final designWidth = (src['designWidth'] as num?)?.toDouble() ?? designSize.$1;
  final designHeight =
      (src['designHeight'] as num?)?.toDouble() ?? designSize.$2;
  final pages = _resolvePagesForTemplate(
    src: src,
    pageCount: pageCount,
    preview: preview,
    designWidth: designWidth,
    designHeight: designHeight,
    exactMode: exactMode,
  );
  final coverLayers = _resolveCoverLayers(
    src: src,
    preview: preview,
    designWidth: designWidth,
    designHeight: designHeight,
    exactMode: exactMode,
  );

  final variants = <String, dynamic>{};
  final variantsRaw = src['variants'];
  if (variantsRaw is Map) {
    for (final entry in variantsRaw.entries) {
      final key = entry.key.toString().toLowerCase();
      if (entry.value is! Map) continue;
      final variant = Map<String, dynamic>.from(entry.value as Map);
      final vAspect = (variant['aspect'] ?? key).toString();
      final vDefault = _defaultDesignSize(vAspect);
      final vWidth =
          (variant['designWidth'] as num?)?.toDouble() ?? vDefault.$1;
      final vHeight =
          (variant['designHeight'] as num?)?.toDouble() ?? vDefault.$2;
      final vPages = _resolvePagesForTemplate(
        src: variant,
        pageCount: pageCount,
        preview: preview,
        designWidth: vWidth,
        designHeight: vHeight,
        exactMode: exactMode,
      );
      final vCoverLayers = _resolveCoverLayers(
        src: variant,
        preview: preview,
        designWidth: vWidth,
        designHeight: vHeight,
        exactMode: exactMode,
      );
      if (vPages.isEmpty) continue;

      variants[key] = {
        'designWidth': vWidth,
        'designHeight': vHeight,
        'cover': {'theme': 'auto', 'layers': vCoverLayers},
        'pages': vPages,
      };
    }
  }

  final templateId = (src['templateId'] ?? sourceId).toString();
  final templateVersion = (src['version'] is num)
      ? (src['version'] as num).toInt()
      : int.tryParse((src['version'] ?? '1').toString()) ?? 1;
  final lifecycleRaw = (src['lifecycleStatus'] ?? src['status'] ?? 'published')
      .toString()
      .toLowerCase();
  final lifecycleStatus = switch (lifecycleRaw) {
    'draft' => 'draft',
    'qa_passed' => 'qa_passed',
    'published' => 'published',
    'deprecated' => 'deprecated',
    _ => 'published',
  };
  final ratio = (src['ratio'] ?? _aspectToRatio(aspect)).toString();

  final metadata = {
    'style': style,
    'designWidth': designWidth,
    'designHeight': designHeight,
    'difficulty': _toDifficulty(src['difficulty']),
    'recommendedPhotoCount': (src['recommendedPhotoCount'] is num)
        ? (src['recommendedPhotoCount'] as num).toInt().clamp(0, 24)
        : 6,
    'mood': '${category.toLowerCase()}_$style',
    'tags': tags,
    'heroTextSafeArea': {'x': 0.10, 'y': 0.08, 'width': 0.80, 'height': 0.28},
    'sourceBottomSheetTemplateIds': [sourceId],
    'applyScope': 'cover_and_pages',
    'bottomSheetReferenceMode': 'style_and_tone_only',
    'templateId': templateId,
    'version': templateVersion,
    'lifecycleStatus': lifecycleStatus,
  };

  final storeId = -1000000 - (_stableHash(sourceId) % 1000000);
  final cover = preview.first;
  final templateJson = jsonEncode({
    'schemaVersion': 2,
    'strictLayout': true,
    'autoFit': false,
    'autoFitPadding': 0.0,
    'templateId': templateId,
    'version': templateVersion,
    'lifecycleStatus': lifecycleStatus,
    'ratio': ratio,
    'cover': {'theme': 'auto', 'layers': coverLayers},
    'metadata': metadata,
    'pages': pages,
    if (variants.isNotEmpty) 'variants': variants,
  });

  final weekly =
      ((src['priority'] as num?)?.toInt() ?? 0) +
      (src['isFeatured'] == true ? 100 : 0);

  return {
    'id': storeId,
    'title': title,
    'subTitle': '$category · $style',
    'description': '$title 스토어 템플릿 (자동 생성)',
    'coverImageUrl': cover,
    'previewImages': preview.take(8).toList(),
    'pageCount': pageCount,
    'likeCount': 0,
    'userCount': 0,
    'category': category,
    'tags': tags,
    'weeklyScore': weekly,
    'isNew': true,
    'isBest': src['isFeatured'] == true,
    'isPremium': true,
    'isLiked': false,
    'templateId': templateId,
    'version': templateVersion,
    'lifecycleStatus': lifecycleStatus,
    'templateJson': templateJson,
  };
}

List<Map<String, dynamic>> _resolvePagesForTemplate({
  required Map<String, dynamic> src,
  required int pageCount,
  required List<String> preview,
  required double designWidth,
  required double designHeight,
  required bool exactMode,
}) {
  final pageSpecs = (src['pages'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);

  if (pageSpecs.isNotEmpty) {
    return _buildPagesFromPageSpecs(
      pageSpecs: pageSpecs,
      pageCount: pageCount,
      preview: preview,
      designWidth: designWidth,
      designHeight: designHeight,
      exactMode: exactMode,
    );
  }

  // fallback: legacy handoff(layers 단일 배열)를 페이지 수만큼 복제
  final layers = (src['layers'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);

  return _buildPagesFromLayers(
    layers: layers,
    pageCount: pageCount,
    preview: preview,
    designWidth: designWidth,
    designHeight: designHeight,
    exactMode: exactMode,
  );
}

List<Map<String, dynamic>> _resolveCoverLayers({
  required Map<String, dynamic> src,
  required List<String> preview,
  required double designWidth,
  required double designHeight,
  required bool exactMode,
}) {
  final cover = src['cover'];
  if (cover is Map) {
    final layers = (cover['layers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    if (layers.isNotEmpty) {
      final converted = _convertLayers(
        layers: layers,
        pageIndex: 0,
        preview: preview,
        designWidth: designWidth,
        designHeight: designHeight,
      );
      if (!exactMode && !converted.hasImageLayer) {
        converted.layers.add(
          _buildFallbackImageLayer(pageIndex: 0, preview: preview),
        );
      }
      return converted.layers;
    }
  }

  final pageSpecs = (src['pages'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
  if (pageSpecs.isNotEmpty) {
    final candidate = pageSpecs.firstWhere(
      (p) => (p['role'] ?? '').toString().toLowerCase() == 'cover',
      orElse: () => pageSpecs.first,
    );
    final layers = (candidate['layers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final converted = _convertLayers(
      layers: layers,
      pageIndex: 0,
      preview: preview,
      designWidth: designWidth,
      designHeight: designHeight,
    );
    if (!exactMode && !converted.hasImageLayer) {
      converted.layers.add(
        _buildFallbackImageLayer(pageIndex: 0, preview: preview),
      );
    }
    return converted.layers;
  }

  return [_buildFallbackImageLayer(pageIndex: 0, preview: preview)];
}

List<Map<String, dynamic>> _buildPagesFromPageSpecs({
  required List<Map<String, dynamic>> pageSpecs,
  required int pageCount,
  required List<String> preview,
  required double designWidth,
  required double designHeight,
  required bool exactMode,
}) {
  final safePageCount = exactMode ? pageSpecs.length : pageCount.clamp(12, 24);
  final normalizedSpecs = pageSpecs.isEmpty
      ? const <Map<String, dynamic>>[]
      : pageSpecs;
  final pages = <Map<String, dynamic>>[];
  for (var i = 0; i < safePageCount; i++) {
    final srcPage = normalizedSpecs[i % normalizedSpecs.length];
    final declaredPageNumber = (srcPage['pageNumber'] as num?)?.toInt();
    final pageNumber = declaredPageNumber != null && declaredPageNumber > 0
        ? declaredPageNumber
        : (i + 1);
    final roleRaw = (srcPage['role'] ?? (i == 0 ? 'cover' : 'inner'))
        .toString()
        .toLowerCase();
    final role = switch (roleRaw) {
      'cover' => 'cover',
      'inner' => 'inner',
      'chapter' => 'chapter',
      'end' => 'end',
      _ => 'inner',
    };
    final layoutId = (srcPage['layoutId'] ?? 'layout_${i + 1}').toString();
    final recommendedPhotoCount =
        ((srcPage['recommendedPhotoCount'] as num?)?.toInt() ?? 1).clamp(0, 12);
    final layers = (srcPage['layers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    final converted = _convertLayers(
      layers: layers,
      pageIndex: i,
      preview: preview,
      designWidth: designWidth,
      designHeight: designHeight,
    );
    if (!exactMode && !converted.hasImageLayer) {
      converted.layers.add(
        _buildFallbackImageLayer(pageIndex: i, preview: preview),
      );
    }
    pages.add({
      'pageNumber': pageNumber,
      'layoutId': layoutId,
      'role': role,
      'recommendedPhotoCount': recommendedPhotoCount,
      'layers': converted.layers,
    });
  }
  return pages;
}

List<Map<String, dynamic>> _buildPagesFromLayers({
  required List<Map<String, dynamic>> layers,
  required int pageCount,
  required List<String> preview,
  required double designWidth,
  required double designHeight,
  required bool exactMode,
}) {
  final pages = <Map<String, dynamic>>[];
  for (var p = 0; p < pageCount; p++) {
    final converted = _convertLayers(
      layers: layers,
      pageIndex: p,
      preview: preview,
      designWidth: designWidth,
      designHeight: designHeight,
    );
    if (!exactMode && !converted.hasImageLayer) {
      converted.layers.add(
        _buildFallbackImageLayer(pageIndex: p, preview: preview),
      );
    }
    pages.add({
      'pageNumber': p + 1,
      'layoutId': 'legacy_layout_${p + 1}',
      'role': p == 0 ? 'cover' : 'inner',
      'recommendedPhotoCount': 1,
      'layers': converted.layers,
    });
  }

  return pages;
}

({List<Map<String, dynamic>> layers, bool hasImageLayer}) _convertLayers({
  required List<Map<String, dynamic>> layers,
  required int pageIndex,
  required List<String> preview,
  required double designWidth,
  required double designHeight,
}) {
  final pageLayers = <Map<String, dynamic>>[];
  var hasImageLayer = false;
  for (var i = 0; i < layers.length; i++) {
    final l = layers[i];
    final incomingType = (l['type'] ?? 'decoration').toString().toUpperCase();
    final type = incomingType == 'STICKER' ? 'IMAGE' : incomingType;
    final id = '${(l['id'] ?? 'layer')}_p${pageIndex + 1}';
    final x = _toUnitOrRatio(
      (l['x'] as num?)?.toDouble() ?? 0.0,
      base: designWidth,
    );
    final y = _toUnitOrRatio(
      (l['y'] as num?)?.toDouble() ?? 0.0,
      base: designHeight,
    );
    final wSource =
        (l['width'] as num?)?.toDouble() ?? (l['w'] as num?)?.toDouble() ?? 1.0;
    final hSource =
        (l['height'] as num?)?.toDouble() ??
        (l['h'] as num?)?.toDouble() ??
        1.0;
    final w = _toUnitOrRatio(wSource, base: designWidth);
    final h = _toUnitOrRatio(hSource, base: designHeight);
    final z = (l['zIndex'] as num?)?.toInt() ?? (l['z'] as num?)?.toInt() ?? 0;
    final rotation = (l['rotation'] as num?)?.toDouble() ?? 0.0;
    final opacity = (l['opacity'] as num?)?.toDouble() ?? 1.0;
    final incomingPayload = l['payload'];
    if (incomingPayload is Map && incomingPayload.isNotEmpty) {
      final payload =
          jsonDecode(jsonEncode(incomingPayload)) as Map<String, dynamic>;
      if (type == 'IMAGE') {
        final iurl = (payload['imageUrl'] ?? '').toString().trim();
        final purl = (payload['previewUrl'] ?? '').toString().trim();
        final ourl = (payload['originalUrl'] ?? '').toString().trim();
        final fallback = preview[(pageIndex + i) % preview.length];
        if (iurl.isEmpty)
          payload['imageUrl'] = purl.isNotEmpty
              ? purl
              : (ourl.isNotEmpty ? ourl : fallback);
        if (purl.isEmpty) payload['previewUrl'] = payload['imageUrl'];
        if (ourl.isEmpty) payload['originalUrl'] = payload['imageUrl'];
        payload['imageTemplate'] = (payload['imageTemplate'] ?? 'free')
            .toString();
        hasImageLayer = true;
      }

      pageLayers.add({
        'id': id,
        'type': type,
        'zIndex': z,
        'x': x,
        'y': y,
        'width': w,
        'height': h,
        'scale': (l['scale'] as num?)?.toDouble() ?? 1.0,
        'rotation': rotation,
        'opacity': opacity,
        'payload': payload,
      });
      continue;
    }

    final payload = <String, dynamic>{};
    if (type == 'IMAGE') {
      final preferred = (l['imageUrl'] ?? '').toString().trim();
      final img = preferred.isNotEmpty
          ? preferred
          : preview[(pageIndex + i) % preview.length];
      final frameRaw = (l['frame'] ?? '').toString().trim();
      payload['imageBackground'] =
          (frameRaw.isEmpty || frameRaw.toLowerCase() == 'none')
          ? ''
          : frameRaw;
      payload['imageTemplate'] = 'free';
      payload['imageUrl'] = img;
      payload['previewUrl'] = img;
      payload['originalUrl'] = img;
      hasImageLayer = true;
    } else if (type == 'TEXT') {
      final styleMap = Map<String, dynamic>.from(
        l['textStyle'] as Map? ?? const {},
      );
      payload['text'] = (l['text'] ?? '').toString();
      payload['textAlign'] = (l['align'] ?? 'center').toString();
      payload['textStyleType'] = 'none';
      payload['textBackground'] = null;
      final textFillMode = (l['textFillMode'] ?? styleMap['textFillMode'])
          ?.toString();
      final textFillImageUrl =
          (l['textFillImageUrl'] ?? styleMap['textFillImageUrl'])?.toString();
      if (textFillMode != null && textFillMode.trim().isNotEmpty) {
        payload['textFillMode'] = textFillMode.trim();
      }
      if (textFillImageUrl != null && textFillImageUrl.trim().isNotEmpty) {
        payload['textFillImageUrl'] = textFillImageUrl.trim();
      }
      final fwRaw = (styleMap['fontWeight'] ?? 'w600').toString();
      final fwNum =
          int.tryParse(fwRaw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 600;
      final fwIdx = ((fwNum ~/ 100) - 1).clamp(0, 8);
      final fontSize = (styleMap['fontSize'] as num?)?.toDouble() ?? 16.0;
      payload['textStyle'] = {
        'fontSize': fontSize,
        'fontSizeRatio': fontSize / (designWidth <= 0 ? 1080.0 : designWidth),
        'fontWeight': fwIdx,
        'fontStyle': 0,
        'fontFamily': (styleMap['fontFamily'] ?? 'NotoSans').toString(),
        'color': _normalizeArgbColor(
          (styleMap['color'] ?? '#1F2937').toString(),
        ),
        'letterSpacing': (styleMap['letterSpacing'] as num?)?.toDouble() ?? 0.0,
      };
    } else {
      payload['imageBackground'] = (l['style'] ?? 'paperWhite').toString();
      payload['imageTemplate'] = 'free';
    }

    pageLayers.add({
      'id': id,
      'type': type,
      'zIndex': z,
      'x': x,
      'y': y,
      'width': w,
      'height': h,
      'scale': 1.0,
      'rotation': rotation,
      'opacity': opacity,
      'payload': payload,
    });
  }
  return (layers: pageLayers, hasImageLayer: hasImageLayer);
}

Map<String, dynamic> _buildFallbackImageLayer({
  required int pageIndex,
  required List<String> preview,
}) {
  final img = preview[pageIndex % preview.length];
  return {
    'id': 'auto_img_p${pageIndex + 1}',
    'type': 'IMAGE',
    'zIndex': 10,
    'x': 0.08,
    'y': 0.16,
    'width': 0.84,
    'height': 0.58,
    'scale': 1.0,
    'rotation': 0.0,
    'opacity': 1.0,
    'payload': {
      'imageBackground': 'photoCard',
      'imageTemplate': 'free',
      'imageUrl': img,
      'previewUrl': img,
      'originalUrl': img,
    },
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

String _aspectToRatio(String aspect) {
  switch (aspect.toLowerCase()) {
    case 'square':
      return '1.0';
    case 'landscape':
      return '1.3333333333';
    case 'portrait':
    default:
      return '0.8';
  }
}

double _toUnitOrRatio(double value, {required double base}) {
  if (value.isNaN || !value.isFinite) return 0.0;
  if (value >= 0.0 && value <= 1.0) return value;
  if (base <= 0) return value;
  final ratio = value / base;
  return ratio.clamp(-2.0, 3.0).toDouble();
}

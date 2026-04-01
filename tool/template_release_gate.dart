import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:snap_fit/features/store/data/local/local_featured_templates.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

Future<int> _checkUrl(String url) async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    final uri = Uri.parse(url);
    final req = await client.getUrl(uri);
    final res = await req.close().timeout(const Duration(seconds: 8));
    await res.drain<void>();
    client.close(force: true);
    return res.statusCode;
  } catch (_) {
    return -1;
  }
}

bool _isTextOverflowRisk(Map<String, dynamic> layer) {
  final payload = layer['payload'];
  if (payload is! Map) return false;
  final text = (payload['text'] ?? '').toString();
  if (text.trim().isEmpty) return false;
  final width = ((layer['width'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
  final height = ((layer['height'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
  final style = payload['textStyle'];
  final fontSize = style is Map
      ? ((style['fontSize'] as num?)?.toDouble() ?? 16)
      : 16.0;

  final maxChars =
      ((width * 100) / (fontSize / 18)).floor() *
      (height >= 0.10 ? 3 : (height >= 0.06 ? 2 : 1));
  return text.length > (maxChars + 8);
}

Map<String, dynamic>? _decodeTemplateJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

List<String> _validateMetadata(Map<String, dynamic> root) {
  final issues = <String>[];
  final metadata = root['metadata'];
  if (metadata is! Map) {
    return ['metadata missing'];
  }
  final required = [
    'style',
    'designWidth',
    'designHeight',
    'difficulty',
    'recommendedPhotoCount',
    'mood',
    'tags',
    'heroTextSafeArea',
    'sourceBottomSheetTemplateIds',
    'applyScope',
    'bottomSheetReferenceMode',
  ];
  for (final key in required) {
    if (!metadata.containsKey(key)) issues.add('metadata.$key missing');
  }
  final difficulty = metadata['difficulty'];
  if (difficulty is! num || difficulty < 1 || difficulty > 5) {
    issues.add('metadata.difficulty must be 1..5');
  }
  final count = metadata['recommendedPhotoCount'];
  if (count is! num || count < 1 || count > 24) {
    issues.add('metadata.recommendedPhotoCount must be 1..24');
  }
  final tags = metadata['tags'];
  if (tags is! List || tags.isEmpty) {
    issues.add('metadata.tags must be non-empty list');
  }
  final designWidth = metadata['designWidth'];
  final designHeight = metadata['designHeight'];
  if (designWidth is! num || designWidth <= 0) {
    issues.add('metadata.designWidth must be > 0');
  }
  if (designHeight is! num || designHeight <= 0) {
    issues.add('metadata.designHeight must be > 0');
  }
  final safe = metadata['heroTextSafeArea'];
  final sourceIds = metadata['sourceBottomSheetTemplateIds'];
  if (sourceIds is! List || sourceIds.isEmpty) {
    issues.add('metadata.sourceBottomSheetTemplateIds must be non-empty list');
  }
  if ((metadata['applyScope']?.toString() ?? '') != 'cover_and_pages') {
    issues.add('metadata.applyScope must be cover_and_pages');
  }
  if ((metadata['bottomSheetReferenceMode']?.toString() ?? '') !=
      'style_and_tone_only') {
    issues.add('metadata.bottomSheetReferenceMode invalid');
  }
  if (safe is! Map) {
    issues.add('metadata.heroTextSafeArea must be map');
  } else {
    for (final key in ['x', 'y', 'width', 'height']) {
      if (safe[key] is! num)
        issues.add('metadata.heroTextSafeArea.$key missing');
    }
  }
  return issues;
}

String _normalizeKey(String input) {
  return input.trim().toLowerCase();
}

Set<String> _extractCaseKeys(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) return <String>{};
  final text = file.readAsStringSync();
  final keys = <String>{};
  final caseRe = RegExp(r"""case\s+['"]([^'"]+)['"]""");
  keys.addAll(
    caseRe
      .allMatches(text)
      .map((m) => _normalizeKey(m.group(1) ?? ''))
      .where((e) => e.isNotEmpty),
  );
  // if (layer.imageBackground == 'foo') 패턴도 허용 키로 추출
  final ifEqRe = RegExp(r"""==\s*['"]([^'"]+)['"]""");
  keys.addAll(
    ifEqRe
        .allMatches(text)
        .map((m) => _normalizeKey(m.group(1) ?? ''))
        .where((e) => e.isNotEmpty),
  );
  return keys;
}

Set<String> _buildAllowedFrameKeys() {
  final keys = _extractCaseKeys(
    'lib/features/album/presentation/controllers/layer_builder_frame_switch.dart',
  );
  keys.addAll(const {'', 'free'});
  return keys;
}

Set<String> _buildAllowedDecorationStyleKeys() {
  final keys = <String>{};
  keys.addAll(
    _extractCaseKeys(
      'lib/features/album/presentation/controllers/layer_builder_decoration_presets.dart',
    ),
  );
  keys.addAll(
    _extractCaseKeys(
      'lib/features/album/presentation/controllers/layer_builder_sticker_decorations.dart',
    ),
  );
  // 실제 템플릿에서 자주 쓰는 none/빈 키를 허용
  keys.addAll(const {'', 'none'});
  return keys;
}

double _relativeLuminance(String hexColor) {
  final raw = hexColor.trim().replaceFirst('#', '');
  String argb = raw;
  if (raw.length == 6) argb = 'FF$raw';
  if (argb.length != 8) return 1.0;
  final rgb = argb.substring(2);
  final r = int.tryParse(rgb.substring(0, 2), radix: 16) ?? 255;
  final g = int.tryParse(rgb.substring(2, 4), radix: 16) ?? 255;
  final b = int.tryParse(rgb.substring(4, 6), radix: 16) ?? 255;

  double c(int x) {
    final s = x / 255.0;
    if (s <= 0.03928) return s / 12.92;
    return math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  final rr = c(r);
  final gg = c(g);
  final bb = c(b);
  return 0.2126 * rr + 0.7152 * gg + 0.0722 * bb;
}

double _contrastRatio(String colorA, String colorB) {
  final l1 = _relativeLuminance(colorA);
  final l2 = _relativeLuminance(colorB);
  final bright = math.max(l1, l2);
  final dark = math.min(l1, l2);
  return (bright + 0.05) / (dark + 0.05);
}

List<String> _validatePageLayoutMetadata(
  Map<String, dynamic> root,
  String prefix,
) {
  final issues = <String>[];
  final pages = root['pages'];
  if (pages is! List) return issues;
  for (var i = 0; i < pages.length; i++) {
    final page = pages[i];
    if (page is! Map<String, dynamic>) continue;
    final layoutId = page['layoutId']?.toString() ?? '';
    final role = page['role']?.toString() ?? '';
    final rpc = page['recommendedPhotoCount'];
    if (layoutId.trim().isEmpty) {
      issues.add('$prefix page ${i + 1} layoutId missing');
    }
    if (!const {'cover', 'inner', 'chapter', 'end'}.contains(role)) {
      issues.add('$prefix page ${i + 1} role invalid: $role');
    }
    if (rpc is! num || rpc < 1 || rpc > 12) {
      issues.add('$prefix page ${i + 1} recommendedPhotoCount invalid');
    }
  }
  return issues;
}

String? _validateTextStylePayload(Map<String, dynamic> layer) {
  final type = (layer['type'] ?? '').toString().toUpperCase();
  if (type != 'TEXT') return null;
  final payload = layer['payload'];
  if (payload is! Map) return 'TEXT payload missing';
  final textStyle = payload['textStyle'];
  if (textStyle is! Map) return 'TEXT payload.textStyle missing';
  final fontSizeRatio = textStyle['fontSizeRatio'];
  if (fontSizeRatio is! num || fontSizeRatio <= 0) {
    return 'TEXT textStyle.fontSizeRatio missing';
  }
  return null;
}

Future<void> main(List<String> args) async {
  final storeJsonPath = _arg(args, '--store-json');

  final templates =
      (storeJsonPath != null && storeJsonPath.trim().isNotEmpty)
      ? _loadTemplatesFromJsonFile(storeJsonPath.trim())
      : <PremiumTemplate>[...localFeaturedTemplates()];
  final hardFails = <String>[];
  final softWarnings = <String>[];
  final allowedFrames = _buildAllowedFrameKeys();
  final allowedStyles = _buildAllowedDecorationStyleKeys();

  for (final t in templates) {
    final prefix = '[${t.id} ${t.title}]';
    final root = _decodeTemplateJson(t.templateJson);
    if (root == null) {
      hardFails.add('$prefix templateJson parse failed');
      continue;
    }

    final metadataIssues = _validateMetadata(root);
    for (final issue in metadataIssues) {
      hardFails.add('$prefix $issue');
    }

    final schemaVersion = root['schemaVersion'];
    if (schemaVersion is! num) {
      hardFails.add('$prefix schemaVersion missing');
    } else if (schemaVersion.toInt() < 1) {
      hardFails.add('$prefix schemaVersion invalid');
    }

    final templateId = (root['templateId'] ?? '').toString();
    final version = root['version'];
    final lifecycle = (root['lifecycleStatus'] ?? '').toString();
    if (templateId.trim().isEmpty) hardFails.add('$prefix templateId missing');
    if (version is! num || version < 1) hardFails.add('$prefix version invalid');
    if (!const {'draft', 'qa_passed', 'published', 'deprecated'}.contains(lifecycle)) {
      hardFails.add('$prefix lifecycleStatus invalid');
    }

    final pages = root['pages'];
    if (pages is! List) {
      hardFails.add('$prefix pages missing');
      continue;
    }
    if (pages.length < 12 || pages.length > 24) {
      hardFails.add(
        '$prefix pages length ${pages.length} out of range(12..24)',
      );
    }
    hardFails.addAll(_validatePageLayoutMetadata(root, prefix));

    final layerImages = <String>{};
    for (var i = 0; i < pages.length; i++) {
      final p = pages[i];
      if (p is! Map) {
        hardFails.add('$prefix page ${i + 1} invalid map');
        continue;
      }
      final layers = p['layers'];
      if (layers is! List || layers.isEmpty) {
        hardFails.add('$prefix page ${i + 1} layers missing');
        continue;
      }
      final hasImage = layers.any(
        (l) => l is Map && (l['type']?.toString().toUpperCase() == 'IMAGE'),
      );
      if (!hasImage) hardFails.add('$prefix page ${i + 1} has no IMAGE layer');

      for (final rawLayer in layers) {
        if (rawLayer is! Map<String, dynamic>) continue;
        final textStyleIssue = _validateTextStylePayload(rawLayer);
        if (textStyleIssue != null) {
          hardFails.add(
            '$prefix page ${i + 1} ${rawLayer['id'] ?? '(no-id)'} $textStyleIssue',
          );
        }
        final type = (rawLayer['type'] ?? '').toString().toUpperCase();
        if (type == 'TEXT') {
          final payload = rawLayer['payload'];
          if (payload is Map) {
            final textStyle = payload['textStyle'];
            final textColor = textStyle is Map
                ? (textStyle['color'] ?? '#FFFFFFFF').toString()
                : '#FFFFFFFF';
            // 레이어 단위 배경색 추정이 어려워 기본 배경 대비 최소 기준만 강제
            final darkRatio = _contrastRatio(textColor, '#FF000000');
            final lightRatio = _contrastRatio(textColor, '#FFFFFFFF');
            if (math.max(darkRatio, lightRatio) < 4.5) {
              hardFails.add(
                '$prefix page ${i + 1} ${rawLayer['id'] ?? '(no-id)'} low text contrast',
              );
            }
          }
        }
        if (type == 'IMAGE') {
          final payload = rawLayer['payload'];
          if (payload is Map) {
            final frame = _normalizeKey((payload['imageBackground'] ?? '').toString());
            if (frame.isNotEmpty && !allowedFrames.contains(frame)) {
              hardFails.add(
                '$prefix page ${i + 1} ${rawLayer['id'] ?? '(no-id)'} unsupported frame: $frame',
              );
            }
            final url =
                (payload['previewUrl'] ??
                        payload['imageUrl'] ??
                        payload['originalUrl'])
                    ?.toString();
            if (url != null && url.trim().isNotEmpty)
              layerImages.add(url.trim());
          }
        }
        if (type == 'DECORATION') {
          final payload = rawLayer['payload'];
          if (payload is Map) {
            final style = _normalizeKey((payload['imageBackground'] ?? '').toString());
            if (!allowedStyles.contains(style)) {
              hardFails.add(
                '$prefix page ${i + 1} ${rawLayer['id'] ?? '(no-id)'} unsupported style: $style',
              );
            }
          }
        }
        if (type == 'TEXT' && _isTextOverflowRisk(rawLayer)) {
          softWarnings.add(
            '$prefix page ${i + 1} text overflow risk at ${rawLayer['id']}',
          );
        }
      }

      final zSet = <int>{};
      for (final rawLayer in layers) {
        if (rawLayer is! Map<String, dynamic>) continue;
        final z = (rawLayer['zIndex'] as num?)?.toInt();
        if (z == null) continue;
        if (zSet.contains(z)) {
          softWarnings.add('$prefix page ${i + 1} z-index collision at $z');
        } else {
          zSet.add(z);
        }
      }
    }

    final previewSet = t.previewImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (previewSet.isEmpty) {
      hardFails.add('$prefix previewImages empty');
    } else {
      final intersect = previewSet.intersection(layerImages);
      if (intersect.isEmpty) {
        softWarnings.add(
          '$prefix preview mismatch: none of previewImages exist in template pages',
        );
      }
    }

    final urlCandidates = <String>{
      t.coverImageUrl.trim(),
      ...previewSet,
      ...layerImages.take(10),
    }..removeWhere((e) => e.isEmpty || !e.startsWith('http'));

    for (final url in urlCandidates) {
      final code = await _checkUrl(url);
      if (code < 200 || code >= 400) {
        hardFails.add('$prefix url failed ($code): $url');
      }
    }
  }

  stdout.writeln('=== Template Release Gate ===');
  stdout.writeln('templates: ${templates.length}');
  stdout.writeln('hard-fails: ${hardFails.length}');
  stdout.writeln('soft-warnings: ${softWarnings.length}');

  if (hardFails.isNotEmpty) {
    stdout.writeln('\n[Hard Fails]');
    for (final f in hardFails) {
      stdout.writeln('- $f');
    }
  }
  if (softWarnings.isNotEmpty) {
    stdout.writeln('\n[Soft Warnings]');
    for (final w in softWarnings) {
      stdout.writeln('- $w');
    }
  }

  if (hardFails.isNotEmpty) {
    exitCode = 2;
    return;
  }
  stdout.writeln('\nPASS: release gate succeeded.');
}

String? _arg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) {
      return arg.substring(key.length + 1);
    }
  }
  return null;
}

List<PremiumTemplate> _loadTemplatesFromJsonFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(PremiumTemplate.fromJson)
        .toList();
  } catch (_) {
    return const [];
  }
}

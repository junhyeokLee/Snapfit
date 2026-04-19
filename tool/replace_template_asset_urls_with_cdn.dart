import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final input = _arg(args, '--input');
  final manifestPath = _arg(args, '--manifest');
  final output = _arg(args, '--output') ?? input;
  final failOnForbidden = (_arg(args, '--fail-on-forbidden') ?? 'true') != 'false';

  if (input == null || input.trim().isEmpty) {
    stderr.writeln('Missing --input');
    exit(2);
  }
  if (manifestPath == null || manifestPath.trim().isEmpty) {
    stderr.writeln('Missing --manifest');
    exit(2);
  }

  final inputFile = File(input);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input not found: $input');
    exit(2);
  }

  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('Manifest not found: $manifestPath');
    exit(2);
  }

  final manifest = jsonDecode(manifestFile.readAsStringSync());
  final mappingsRaw = manifest is Map<String, dynamic>
      ? (manifest['mappings'] as List<dynamic>? ?? const [])
      : const <dynamic>[];
  final replacements = <String, String>{};
  for (final row in mappingsRaw) {
    if (row is! Map) continue;
    final map = Map<String, dynamic>.from(row);
    final cdnUrl = (map['cdnUrl'] ?? '').toString().trim();
    if (cdnUrl.isEmpty) continue;
    for (final key in ['assetPath', 'filePath']) {
      final src = (map[key] ?? '').toString().trim();
      if (src.isNotEmpty) replacements[src] = cdnUrl;
    }
  }

  final decoded = jsonDecode(inputFile.readAsStringSync());
  final result = _transform(decoded, replacements);

  if (failOnForbidden) {
    final offenders = <String>[];
    _collectForbiddenUrls(result, offenders);
    if (offenders.isNotEmpty) {
      stderr.writeln('Forbidden URLs remain after CDN rewrite:');
      for (final item in offenders.take(20)) {
        stderr.writeln('- $item');
      }
      exit(2);
    }
  }

  final outFile = File(output!);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));

  stdout.writeln('replace_template_asset_urls_with_cdn');
  stdout.writeln('input=$input');
  stdout.writeln('manifest=$manifestPath');
  stdout.writeln('output=$output');
  stdout.writeln('replacements=${replacements.length}');
}

String? _arg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) return arg.substring(key.length + 1);
  }
  return null;
}

dynamic _transform(dynamic value, Map<String, String> replacements) {
  if (value is Map) {
    final out = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final raw = entry.value;
      if (key == 'templateJson' && raw is String && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          out[key] = jsonEncode(_transform(decoded, replacements));
          continue;
        } catch (_) {
          out[key] = _rewriteString(raw, replacements);
          continue;
        }
      }
      out[key] = _transform(raw, replacements);
    }
    return out;
  }
  if (value is List) {
    return value.map((e) => _transform(e, replacements)).toList();
  }
  if (value is String) {
    return _rewriteString(value, replacements);
  }
  return value;
}

String _rewriteString(String value, Map<String, String> replacements) {
  final trimmed = value.trim();
  return replacements[trimmed] ?? value;
}

void _collectForbiddenUrls(dynamic value, List<String> offenders) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key == 'templateJson' && entry.value is String) {
        final raw = (entry.value as String).trim();
        if (raw.isNotEmpty) {
          try {
            _collectForbiddenUrls(jsonDecode(raw), offenders);
          } catch (_) {
            if (_isForbiddenUrl(raw)) offenders.add(raw);
          }
        }
        continue;
      }
      _collectForbiddenUrls(entry.value, offenders);
    }
    return;
  }
  if (value is List) {
    for (final item in value) {
      _collectForbiddenUrls(item, offenders);
    }
    return;
  }
  if (value is String && _isForbiddenUrl(value.trim())) {
    offenders.add(value.trim());
  }
}

bool _isForbiddenUrl(String value) {
  if (value.isEmpty) return false;
  final lower = value.toLowerCase();
  return lower.startsWith('asset:') ||
      lower.contains('figma.com/api/mcp/asset/') ||
      lower.contains('picsum.photos') ||
      lower.contains('unsplash.com') ||
      lower.contains('pexels.com');
}

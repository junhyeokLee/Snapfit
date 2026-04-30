import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final input =
      _arg(args, '--input') ?? 'assets/templates/generated/store_latest.json';
  final baseUrl =
      _arg(args, '--base-url') ?? Platform.environment['SNAPFIT_API_BASE_URL'];
  final adminKey =
      _arg(args, '--admin-key') ??
      Platform.environment['SNAPFIT_PUSH_ADMIN_KEY'];
  final dryRun = args.contains('--dry-run');

  if (baseUrl == null || baseUrl.trim().isEmpty) {
    stderr.writeln('Missing --base-url or SNAPFIT_API_BASE_URL');
    exit(2);
  }
  if (adminKey == null || adminKey.trim().isEmpty) {
    stderr.writeln('Missing --admin-key or SNAPFIT_PUSH_ADMIN_KEY');
    exit(2);
  }

  final file = File(input);
  if (!file.existsSync()) {
    stderr.writeln('Input not found: $input');
    exit(2);
  }

  final decoded = jsonDecode(await file.readAsString());
  final templates = decoded is List
      ? decoded.cast<Map<String, dynamic>>()
      : (decoded is Map<String, dynamic>
            ? (decoded['templates'] as List? ?? const <dynamic>[])
                  .cast<Map<String, dynamic>>()
            : const <Map<String, dynamic>>[]);

  if (templates.isEmpty) {
    stdout.writeln('No templates found in $input');
    return;
  }

  final assetIssues = <String>[];
  for (final item in templates) {
    final title = (item['title'] ?? '').toString().trim();
    _collectAssetPaths(item, assetIssues, title.isEmpty ? 'unknown' : title);
  }
  if (assetIssues.isNotEmpty) {
    stderr.writeln('Publish blocked: asset paths remain in input JSON.');
    for (final issue in assetIssues.take(30)) {
      stderr.writeln('- $issue');
    }
    exit(2);
  }

  final existingTemplates = await _fetchServerTemplates(baseUrl);
  var created = 0;
  var updated = 0;
  var skipped = 0;
  final failed = <String>[];

  for (final item in templates) {
    final title = (item['title'] ?? '').toString().trim();
    if (title.isEmpty) continue;
    final key = _normalize(title);
    final existingId = existingTemplates[key];

    final payload = _buildUpsertPayload(item);
    if (existingId != null) {
      payload['id'] = existingId;
    }

    if (dryRun) {
      if (existingId != null) {
        updated++;
      } else {
        created++;
      }
      continue;
    }

    final ok = await _postUpsert(baseUrl, adminKey, payload);
    if (ok) {
      if (existingId != null) {
        updated++;
      } else {
        created++;
      }
    } else {
      failed.add(title);
    }
  }

  stdout.writeln('publish_store_templates_to_server');
  stdout.writeln('input=$input');
  stdout.writeln(
    'created=$created updated=$updated skipped=$skipped failed=${failed.length}',
  );
  if (failed.isNotEmpty) {
    stdout.writeln('failed_titles=${failed.take(10).join(', ')}');
  }
}

Future<Map<String, int>> _fetchServerTemplates(String baseUrl) async {
  final uri = Uri.parse('$baseUrl/api/templates');
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    final resp = await req.close();
    final body = await utf8.decodeStream(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('GET /api/templates failed: ${resp.statusCode}');
    }
    final data = jsonDecode(body);
    if (data is! List) return <String, int>{};
    final byTitle = <String, int>{};
    for (final row in data) {
      if (row is! Map<String, dynamic>) continue;
      final title = _normalize((row['title'] ?? '').toString());
      final id = (row['id'] as num?)?.toInt();
      if (title.isEmpty || id == null) continue;
      byTitle[title] = id;
    }
    return byTitle;
  } finally {
    client.close(force: true);
  }
}

Map<String, dynamic> _buildUpsertPayload(Map<String, dynamic> item) {
  final now = DateTime.now().toUtc();
  final isNew = item['isNew'] == true;
  final newUntil = isNew
      ? now.add(const Duration(days: 7)).toIso8601String().split('.').first
      : null;

  final rawTemplateJson = (item['templateJson'] ?? '{}').toString();
  Map<String, dynamic> templateData;
  try {
    templateData = jsonDecode(rawTemplateJson) as Map<String, dynamic>;
  } catch (_) {
    templateData = <String, dynamic>{'pages': <dynamic>[]};
  }

  final cover = (templateData['cover'] is Map<String, dynamic>)
      ? (templateData['cover'] as Map<String, dynamic>)
      : <String, dynamic>{};
  if (cover['layers'] is! List) {
    cover['layers'] = <dynamic>[];
  }
  templateData['cover'] = cover;
  if (templateData['pages'] is! List) {
    templateData['pages'] = <dynamic>[];
  }

  return <String, dynamic>{
    'title': (item['title'] ?? '').toString(),
    'subTitle': item['subTitle']?.toString(),
    'description': item['description']?.toString(),
    'coverImageUrl': (item['coverImageUrl'] ?? '').toString(),
    'previewImagesJson': jsonEncode(
      (item['previewImages'] as List?) ?? const <dynamic>[],
    ),
    'pageCount': (item['pageCount'] as num?)?.toInt() ?? 12,
    'likeCount': (item['likeCount'] as num?)?.toInt() ?? 0,
    'userCount': (item['userCount'] as num?)?.toInt() ?? 0,
    'isBest': item['isBest'] == true,
    'isPremium': item['isPremium'] != false,
    'category': (item['category'] ?? '기타').toString(),
    'tagsJson': jsonEncode((item['tags'] as List?) ?? const <dynamic>[]),
    'weeklyScore': (item['weeklyScore'] as num?)?.toInt() ?? 0,
    'newUntil': newUntil,
    'active': true,
    'templateJson': jsonEncode(templateData),
  };
}

Future<bool> _postUpsert(
  String baseUrl,
  String adminKey,
  Map<String, dynamic> payload,
) async {
  final uris = <Uri>[
    Uri.parse('$baseUrl/api/admin/templates/upsert'),
  ];
  final client = HttpClient();
  try {
    for (final uri in uris) {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Admin-Key', adminKey);
      req.add(utf8.encode(jsonEncode(payload)));
      final resp = await req.close();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      }
      final body = await utf8.decodeStream(resp);
      stderr.writeln(
        'Upsert failed via ${uri.path}: ${payload['title']} (${resp.statusCode}) $body',
      );
      return false;
    }
    return false;
  } catch (e) {
    stderr.writeln('Upsert exception: ${payload['title']} $e');
    return false;
  } finally {
    client.close(force: true);
  }
}

String _normalize(String value) {
  final lower = value.toLowerCase();
  final sb = StringBuffer();
  for (final c in lower.runes) {
    final ch = String.fromCharCode(c);
    final isAscii =
        (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) ||
        (ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122);
    final isKorean = c >= 0xAC00 && c <= 0xD7A3;
    if (isAscii || isKorean) sb.write(ch);
  }
  return sb.toString();
}

String? _arg(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('$name=')) {
      return a.substring(name.length + 1);
    }
  }
  return null;
}

void _collectAssetPaths(dynamic value, List<String> issues, String context) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key == 'templateJson' && entry.value is String) {
        final raw = (entry.value as String).trim();
        if (raw.isEmpty) continue;
        try {
          _collectAssetPaths(jsonDecode(raw), issues, '$context.templateJson');
        } catch (_) {
          if (raw.startsWith('asset:')) {
            issues.add('$context.templateJson -> $raw');
          }
        }
        continue;
      }
      _collectAssetPaths(entry.value, issues, '$context.${entry.key}');
    }
    return;
  }
  if (value is List) {
    for (var i = 0; i < value.length; i++) {
      _collectAssetPaths(value[i], issues, '$context[$i]');
    }
    return;
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('asset:')) {
      issues.add('$context -> $trimmed');
    }
  }
}

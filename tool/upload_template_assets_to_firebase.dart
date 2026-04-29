import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> main(List<String> args) async {
  final templateSlug = _arg(args, '--template-slug');
  final checklistPath =
      _arg(args, '--checklist') ??
      (templateSlug == null
          ? null
          : 'assets/templates/$templateSlug/export_checklist.json');
  final configPath =
      _arg(args, '--config') ??
      'assets/templates/workspace/template_cdn_config.json';
  final imageDir =
      _arg(args, '--image-dir') ??
      (templateSlug == null ? null : 'assets/templates/$templateSlug/images');
  final manifestPath =
      _arg(args, '--manifest') ??
      (templateSlug == null
          ? null
          : 'assets/templates/$templateSlug/cdn_manifest.json');
  final storeJsonPath =
      _arg(args, '--store-json') ??
      (templateSlug == null
          ? null
          : 'assets/templates/generated/${templateSlug}_store.json');
  final dryRun = (_arg(args, '--dry-run') ?? 'false') == 'true';

  if (templateSlug == null || templateSlug.trim().isEmpty) {
    stderr.writeln('Missing --template-slug');
    exit(2);
  }
  if (checklistPath == null || imageDir == null || manifestPath == null) {
    stderr.writeln('Unable to resolve checklist/imageDir/manifest path');
    exit(2);
  }

  final checklistFile = File(checklistPath);
  final configFile = File(configPath);
  if (!checklistFile.existsSync()) {
    stderr.writeln('Checklist not found: $checklistPath');
    exit(2);
  }
  if (!configFile.existsSync()) {
    stderr.writeln('Config not found: $configPath');
    exit(2);
  }

  final checklist =
      jsonDecode(checklistFile.readAsStringSync()) as Map<String, dynamic>;
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;

  final bucket = (config['storageBucket'] ?? '').toString().trim();
  final publicBaseUrl = (config['publicBaseUrl'] ?? '').toString().trim();
  final version = (checklist['firebaseStorageVersion'] ?? 'v1')
      .toString()
      .trim();
  if (bucket.isEmpty || publicBaseUrl.isEmpty) {
    stderr.writeln('storageBucket/publicBaseUrl missing in $configPath');
    exit(2);
  }

  final requiredExports = _resolveRequiredExports(
    checklist: checklist,
    templateSlug: templateSlug,
    storeJsonPath: storeJsonPath,
  );
  if (requiredExports.isEmpty) {
    stderr.writeln(
      'No upload candidates found in requiredExports or store JSON: $checklistPath',
    );
    exit(2);
  }

  final token = await _resolveFirebaseAccessToken();
  final imageDirectory = Directory(imageDir);
  if (!imageDirectory.existsSync()) {
    stderr.writeln('Image directory not found: $imageDir');
    exit(2);
  }
  final imageFilesByName = <String, File>{
    for (final entity
        in imageDirectory.listSync(recursive: true).whereType<File>())
      entity.uri.pathSegments.last: entity,
  };

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  final mappings = <Map<String, dynamic>>[];
  final missingFiles = <String>[];

  for (final item in requiredExports) {
    final fileName = (item['fileName'] ?? '').toString().trim();
    final storagePath = (item['firebaseStoragePath'] ?? '').toString().trim();
    if (fileName.isEmpty || storagePath.isEmpty) continue;

    final file = imageFilesByName[fileName];
    if (file == null || !file.existsSync()) {
      missingFiles.add(fileName);
      continue;
    }

    final downloadToken = dryRun
        ? _uuidLike()
        : await _uploadFile(
            client: client,
            bucket: bucket,
            storagePath: storagePath,
            file: file,
            authToken: token,
          );
    final cdnUrl =
        '$publicBaseUrl/${Uri.encodeComponent(storagePath)}?alt=media&token=$downloadToken';

    final relativePath = file.path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^.*/SnapFit/SnapFit/'), '');
    mappings.add(<String, dynamic>{
      'fileName': fileName,
      'filePath': relativePath,
      'assetPath': 'asset:$relativePath',
      'firebaseStoragePath': storagePath,
      'cdnUrl': cdnUrl,
      'downloadToken': downloadToken,
      'sourcePageNodeId': (item['pageNodeId'] ?? '').toString(),
      'sourceImageNodeId': (item['imageNodeId'] ?? '').toString(),
    });
  }

  client.close(force: true);

  if (missingFiles.isNotEmpty) {
    stderr.writeln('Missing local files:');
    for (final file in missingFiles) {
      stderr.writeln('- $file');
    }
    exit(2);
  }

  final out = <String, dynamic>{
    'templateSlug': templateSlug,
    'version': version,
    'provider': 'firebase_storage',
    'bucket': bucket,
    'cdnBaseUrl': publicBaseUrl,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'dryRun': dryRun,
    'mappings': mappings,
  };

  final manifestFile = File(manifestPath);
  manifestFile.parent.createSync(recursive: true);
  manifestFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(out),
  );

  stdout.writeln('upload_template_assets_to_firebase');
  stdout.writeln('templateSlug=$templateSlug');
  stdout.writeln('version=$version');
  stdout.writeln('bucket=$bucket');
  stdout.writeln('files=${mappings.length}');
  stdout.writeln('manifest=$manifestPath');
  stdout.writeln('dryRun=$dryRun');
}

List<Map<String, dynamic>> _resolveRequiredExports({
  required Map<String, dynamic> checklist,
  required String templateSlug,
  required String? storeJsonPath,
}) {
  final assetPaths = _discoverAssetPaths(templateSlug, storeJsonPath);
  final version = (checklist['firebaseStorageVersion'] ?? 'v1')
      .toString()
      .trim();

  if (assetPaths.isNotEmpty) {
    return assetPaths
        .map((assetPath) {
          final normalized = assetPath.replaceFirst('asset:', '');
          final fileName = normalized.split('/').last;
          return <String, dynamic>{
            'fileName': fileName,
            'pageNodeId': '',
            'pageName': 'AUTO_DISCOVERED',
            'imageNodeId': '',
            'usage': <String>['auto-discovered-from-store-json'],
            'firebaseStoragePath': 'templates/$templateSlug/$version/$fileName',
          };
        })
        .toList(growable: false);
  }

  return (checklist['requiredExports'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}

Set<String> _discoverAssetPaths(String templateSlug, String? storeJsonPath) {
  if (storeJsonPath == null || storeJsonPath.trim().isEmpty) {
    return <String>{};
  }
  final storeFile = File(storeJsonPath);
  if (!storeFile.existsSync()) {
    return <String>{};
  }

  final decoded = jsonDecode(storeFile.readAsStringSync());
  final assetPaths = <String>{};
  _collectTemplateAssetPaths(decoded, templateSlug, assetPaths);
  return assetPaths;
}

void _collectTemplateAssetPaths(
  dynamic value,
  String templateSlug,
  Set<String> out,
) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (key == 'templateJson' && entry.value is String) {
        final raw = (entry.value as String).trim();
        if (raw.isEmpty) continue;
        try {
          _collectTemplateAssetPaths(jsonDecode(raw), templateSlug, out);
        } catch (_) {}
        continue;
      }
      _collectTemplateAssetPaths(entry.value, templateSlug, out);
    }
    return;
  }
  if (value is List) {
    for (final item in value) {
      _collectTemplateAssetPaths(item, templateSlug, out);
    }
    return;
  }
  if (value is String) {
    final trimmed = value.trim();
    final marker = 'asset:assets/templates/$templateSlug/images/';
    if (trimmed.startsWith(marker)) {
      out.add(trimmed);
    }
  }
}

String? _arg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) return arg.substring(key.length + 1);
  }
  return null;
}

Future<String> _resolveFirebaseAccessToken() async {
  final result = await Process.run('firebase', ['login:list', '--json']);
  if (result.exitCode != 0) {
    stderr.writeln(result.stderr);
    throw ProcessException(
      'firebase',
      ['login:list', '--json'],
      'Unable to read firebase login state',
      result.exitCode,
    );
  }

  final decoded = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final rows = (decoded['result'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);

  for (final row in rows) {
    final tokens = row['tokens'];
    if (tokens is! Map) continue;
    final token = (tokens['access_token'] ?? '').toString().trim();
    if (token.isNotEmpty) return token;
  }

  throw StateError(
    'No firebase access token found. Run `firebase login` first.',
  );
}

Future<String> _uploadFile({
  required HttpClient client,
  required String bucket,
  required String storagePath,
  required File file,
  required String authToken,
}) async {
  final uri = Uri.parse('https://firebasestorage.googleapis.com/v0/b/$bucket/o')
      .replace(
        queryParameters: <String, String>{
          'uploadType': 'media',
          'name': storagePath,
        },
      );
  final request = await client.postUrl(uri);
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
  final bytes = await file.readAsBytes();
  final mimeType = _contentTypeFor(file.path);
  request.headers.set(HttpHeaders.contentTypeHeader, mimeType);
  request.add(bytes);
  final response = await request.close();
  final responseBody = await utf8.decodeStream(response);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    stderr.writeln(responseBody);
    throw HttpException(
      'Firebase upload failed for $storagePath (${response.statusCode})',
      uri: uri,
    );
  }
  final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
  final token = (decoded['downloadTokens'] ?? '').toString().trim();
  if (token.isEmpty) {
    throw StateError(
      'Firebase upload succeeded but no download token was returned for $storagePath',
    );
  }
  return token;
}

String _contentTypeFor(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'application/octet-stream';
}

String _uuidLike() {
  final random = Random.secure();
  String hex(int length) {
    const chars = '0123456789abcdef';
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  return '${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}';
}

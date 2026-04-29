import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final templateSlug = _arg(args, '--template-slug');
  final checklistPath =
      _arg(args, '--checklist') ??
      (templateSlug == null
          ? null
          : 'assets/templates/$templateSlug/export_checklist.json');
  final manifestPath =
      _arg(args, '--manifest') ??
      (templateSlug == null
          ? null
          : 'assets/templates/$templateSlug/cdn_manifest.json');
  final imageDir =
      _arg(args, '--image-dir') ??
      (templateSlug == null ? null : 'assets/templates/$templateSlug/images');
  final storeJsonPath =
      _arg(args, '--store-json') ??
      (templateSlug == null
          ? null
          : 'assets/templates/generated/${templateSlug}_store.json');

  if (templateSlug == null || templateSlug.trim().isEmpty) {
    stderr.writeln('Missing --template-slug');
    exit(2);
  }
  if (checklistPath == null || manifestPath == null || imageDir == null) {
    stderr.writeln('Unable to resolve checklist/manifest/imageDir');
    exit(2);
  }

  final checklistFile = File(checklistPath);
  if (!checklistFile.existsSync()) {
    stderr.writeln('Checklist not found: $checklistPath');
    exit(2);
  }

  final checklist =
      jsonDecode(checklistFile.readAsStringSync()) as Map<String, dynamic>;
  final requiredExports = _resolveRequiredExports(
    checklist: checklist,
    templateSlug: templateSlug,
    storeJsonPath: storeJsonPath,
  );

  final imageDirectory = Directory(imageDir);
  final existingFiles = imageDirectory.existsSync()
      ? imageDirectory
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => _isImagePath(f.path))
            .map((f) => f.uri.pathSegments.last)
            .toSet()
      : <String>{};
  final fileByName = imageDirectory.existsSync()
      ? <String, File>{
          for (final file
              in imageDirectory
                  .listSync(recursive: true)
                  .whereType<File>()
                  .where((f) => _isImagePath(f.path)))
            file.uri.pathSegments.last: file,
        }
      : <String, File>{};

  final missingLocalFiles = <String>[];
  final invalidLocalFiles = <String>[];
  for (final item in requiredExports) {
    final fileName = (item['fileName'] ?? '').toString().trim();
    if (fileName.isEmpty) continue;
    if (!existingFiles.contains(fileName)) {
      missingLocalFiles.add(fileName);
      continue;
    }
    final file = fileByName[fileName];
    if (file == null) {
      invalidLocalFiles.add(fileName);
      continue;
    }
    if (!_looksLikeImage(file)) {
      invalidLocalFiles.add(fileName);
    }
  }

  final manifestFile = File(manifestPath);
  final missingManifestEntries = <String>[];
  final manifestMismatches = <String>[];
  if (manifestFile.existsSync()) {
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final mappings =
        (manifest['mappings'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
    final mappingByFile = <String, Map<String, dynamic>>{
      for (final row in mappings)
        (row['fileName'] ?? '').toString().trim(): row,
    };

    for (final item in requiredExports) {
      final fileName = (item['fileName'] ?? '').toString().trim();
      final storagePath = (item['firebaseStoragePath'] ?? '').toString().trim();
      if (fileName.isEmpty) continue;
      final row = mappingByFile[fileName];
      if (row == null) {
        missingManifestEntries.add(fileName);
        continue;
      }
      final cdnUrl = (row['cdnUrl'] ?? '').toString().trim();
      final decodedUrl = Uri.decodeFull(cdnUrl);
      if (storagePath.isNotEmpty &&
          cdnUrl.isNotEmpty &&
          !cdnUrl.contains(storagePath) &&
          !decodedUrl.contains(storagePath)) {
        manifestMismatches.add(
          '$fileName -> expected path fragment $storagePath',
        );
      }
    }
  }

  stdout.writeln('validate_template_asset_pipeline');
  stdout.writeln('templateSlug=$templateSlug');
  stdout.writeln('requiredExports=${requiredExports.length}');
  stdout.writeln('localFiles=${existingFiles.length}');
  stdout.writeln('missingLocalFiles=${missingLocalFiles.length}');
  stdout.writeln('invalidLocalFiles=${invalidLocalFiles.length}');
  stdout.writeln('missingManifestEntries=${missingManifestEntries.length}');
  stdout.writeln('manifestMismatches=${manifestMismatches.length}');

  if (missingLocalFiles.isNotEmpty) {
    stdout.writeln('[Missing local files]');
    for (final file in missingLocalFiles) {
      stdout.writeln('- $file');
    }
  }
  if (missingManifestEntries.isNotEmpty) {
    stdout.writeln('[Missing manifest entries]');
    for (final file in missingManifestEntries) {
      stdout.writeln('- $file');
    }
  }
  if (invalidLocalFiles.isNotEmpty) {
    stdout.writeln('[Invalid local files]');
    for (final file in invalidLocalFiles) {
      stdout.writeln('- $file');
    }
  }
  if (manifestMismatches.isNotEmpty) {
    stdout.writeln('[Manifest mismatches]');
    for (final item in manifestMismatches) {
      stdout.writeln('- $item');
    }
  }

  if (missingLocalFiles.isNotEmpty ||
      invalidLocalFiles.isNotEmpty ||
      missingManifestEntries.isNotEmpty ||
      manifestMismatches.isNotEmpty) {
    exitCode = 2;
  }
}

String? _arg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) return arg.substring(key.length + 1);
  }
  return null;
}

bool _looksLikeImage(File file) {
  if (!file.existsSync()) return false;
  final bytes = file.readAsBytesSync();
  if (bytes.length < 12) return false;

  final isPng =
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
  if (isPng) return true;

  final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
  if (isJpeg) return true;

  final riff = String.fromCharCodes(bytes.sublist(0, 4));
  final webp = String.fromCharCodes(bytes.sublist(8, 12));
  if (riff == 'RIFF' && webp == 'WEBP') return true;

  return false;
}

bool _isImagePath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp');
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

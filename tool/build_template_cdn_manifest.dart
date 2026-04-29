import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final templateSlug = _arg(args, '--template-slug');
  final cdnBaseUrl = _arg(args, '--cdn-base-url');
  final version = _arg(args, '--version') ?? 'v1';
  final prefix = _arg(args, '--prefix') ?? 'templates';
  final inputDir =
      _arg(args, '--input-dir') ??
      (templateSlug == null ? null : 'assets/templates/$templateSlug/images');
  final output =
      _arg(args, '--output') ??
      (templateSlug == null
          ? null
          : 'assets/templates/$templateSlug/cdn_manifest.json');

  if (templateSlug == null || templateSlug.trim().isEmpty) {
    stderr.writeln('Missing --template-slug');
    exit(2);
  }
  if (cdnBaseUrl == null || cdnBaseUrl.trim().isEmpty) {
    stderr.writeln('Missing --cdn-base-url');
    exit(2);
  }
  if (inputDir == null || output == null) {
    stderr.writeln('Unable to resolve input/output path');
    exit(2);
  }

  final dir = Directory(inputDir);
  if (!dir.existsSync()) {
    stderr.writeln('Input directory not found: $inputDir');
    exit(2);
  }

  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => _isImageFile(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final normalizedBase = cdnBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final normalizedPrefix = prefix.replaceAll(RegExp(r'^/+|/+$'), '');
  final normalizedVersion = version.startsWith('v') ? version : 'v$version';

  final mappings = files
      .map((file) {
        final name = file.uri.pathSegments.last;
        final relativePath = 'assets/templates/$templateSlug/images/$name';
        return <String, dynamic>{
          'fileName': name,
          'filePath': relativePath,
          'assetPath': 'asset:$relativePath',
          'cdnUrl':
              '$normalizedBase/$normalizedPrefix/$templateSlug/$normalizedVersion/$name',
        };
      })
      .toList(growable: false);

  final payload = <String, dynamic>{
    'templateSlug': templateSlug,
    'version': normalizedVersion,
    'cdnBaseUrl': normalizedBase,
    'prefix': normalizedPrefix,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'mappings': mappings,
  };

  final outFile = File(output);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(payload),
  );

  stdout.writeln('build_template_cdn_manifest');
  stdout.writeln('templateSlug=$templateSlug');
  stdout.writeln('version=$normalizedVersion');
  stdout.writeln('files=${mappings.length}');
  stdout.writeln('output=$output');
}

String? _arg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) return arg.substring(key.length + 1);
  }
  return null;
}

bool _isImageFile(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp');
}

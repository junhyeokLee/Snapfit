import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final storeJson =
      _arg(args, '--store-json') ??
      'assets/templates/generated/store_latest.json';
  final registryPath =
      _arg(args, '--registry') ??
      'assets/templates/workspace/template_registry.json';

  final storeFile = File(storeJson);
  final registryFile = File(registryPath);
  if (!storeFile.existsSync()) {
    stderr.writeln('Store JSON not found: $storeJson');
    exit(2);
  }
  if (!registryFile.existsSync()) {
    stderr.writeln('Registry not found: $registryPath');
    exit(2);
  }

  final store = (jsonDecode(storeFile.readAsStringSync()) as List<dynamic>)
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
  final registry =
      jsonDecode(registryFile.readAsStringSync()) as Map<String, dynamic>;
  final templates =
      (registry['templates'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);

  final byTemplateId = <String, Map<String, dynamic>>{
    for (final row in store) (row['templateId'] ?? '').toString().trim(): row,
  };

  final issues = <String>[];
  final seen = <String>{};

  for (final row in store) {
    final templateId = (row['templateId'] ?? '').toString().trim();
    if (templateId.isEmpty) {
      issues.add('template without templateId: ${row['title']}');
      continue;
    }
    if (!seen.add(templateId)) {
      issues.add('duplicate templateId: $templateId');
    }
  }

  for (final row in templates) {
    final status = (row['status'] ?? '').toString();
    final locked = row['locked'] == true;
    final templateId = (row['templateId'] ?? '').toString().trim();
    if (status != 'approved' || !locked || templateId.isEmpty) continue;
    final item = byTemplateId[templateId];
    if (item == null) {
      issues.add('approved template missing from store_latest: $templateId');
      continue;
    }
    final cover = (item['coverImageUrl'] ?? '').toString().trim();
    final previews = (item['previewImages'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    final templateJson = (item['templateJson'] ?? '').toString();
    if (cover.startsWith('asset:')) {
      issues.add('approved template has asset coverImageUrl: $templateId');
    }
    if (previews.any((e) => e.startsWith('asset:'))) {
      issues.add('approved template has asset previewImages: $templateId');
    }
    if (templateJson.contains('asset:assets/templates/$templateId')) {
      issues.add(
        'approved template templateJson contains asset paths: $templateId',
      );
    }
    if (templateJson.contains('asset:assets/templates/')) {
      issues.add(
        'approved template templateJson still has asset path: $templateId',
      );
    }
  }

  stdout.writeln('template_registry_guard');
  stdout.writeln('storeJson=$storeJson');
  stdout.writeln('registry=$registryPath');
  stdout.writeln('templates=${store.length}');
  stdout.writeln('issues=${issues.length}');
  if (issues.isNotEmpty) {
    for (final issue in issues) {
      stdout.writeln('- $issue');
    }
    exitCode = 2;
  }
}

String? _arg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) return arg.substring(key.length + 1);
  }
  return null;
}

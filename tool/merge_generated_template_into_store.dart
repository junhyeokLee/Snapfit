import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final input =
      _arg(args, '--input') ??
      (throw ArgumentError('Missing --input=<template_store.json>'));
  final output =
      _arg(args, '--output') ?? 'assets/templates/generated/store_latest.json';
  final registryPath =
      _arg(args, '--registry') ??
      'assets/templates/workspace/template_registry.json';

  final inputFile = File(input);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input not found: $input');
    exit(2);
  }

  final incomingDecoded = jsonDecode(inputFile.readAsStringSync());
  final incoming = (incomingDecoded is List ? incomingDecoded : <dynamic>[])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
  if (incoming.isEmpty) {
    stderr.writeln('No templates found in input: $input');
    exit(2);
  }

  final outputFile = File(output);
  final existing = outputFile.existsSync()
      ? ((jsonDecode(outputFile.readAsStringSync()) as List<dynamic>)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList())
      : <Map<String, dynamic>>[];

  final lockedTemplateIds = _loadLockedTemplateIds(registryPath);
  final incomingIds = incoming
      .map((e) => (e['templateId'] ?? '').toString().trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  final merged = <Map<String, dynamic>>[];
  final seen = <String>{};

  void addTemplate(Map<String, dynamic> item) {
    final templateId = (item['templateId'] ?? '').toString().trim();
    final title = (item['title'] ?? '').toString().trim();
    final key = templateId.isNotEmpty ? 'id:$templateId' : 'title:$title';
    if (seen.contains(key)) return;
    seen.add(key);
    merged.add(item);
  }

  for (final item in incoming) {
    addTemplate(item);
  }

  for (final item in existing) {
    final templateId = (item['templateId'] ?? '').toString().trim();
    if (templateId.isNotEmpty &&
        lockedTemplateIds.contains(templateId) &&
        !incomingIds.contains(templateId)) {
      addTemplate(item);
      continue;
    }
    if (templateId.isNotEmpty && !incomingIds.contains(templateId)) {
      addTemplate(item);
    }
  }

  merged.sort(
    (a, b) => ((b['id'] as num?)?.toInt() ?? 0).compareTo(
      (a['id'] as num?)?.toInt() ?? 0,
    ),
  );

  outputFile
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(merged));

  stdout.writeln('merge_generated_template_into_store');
  stdout.writeln('input=$input');
  stdout.writeln('output=$output');
  stdout.writeln('incoming=${incoming.length}');
  stdout.writeln('merged=${merged.length}');
}

Set<String> _loadLockedTemplateIds(String registryPath) {
  final file = File(registryPath);
  if (!file.existsSync()) return <String>{};
  try {
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final rows = (decoded['templates'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e));
    return rows
        .where(
          (row) =>
              (row['locked'] == true) &&
              (row['status']?.toString() == 'approved'),
        )
        .map((row) => (row['templateId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  } catch (_) {
    return <String>{};
  }
}

String? _arg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) return arg.substring(key.length + 1);
  }
  return null;
}

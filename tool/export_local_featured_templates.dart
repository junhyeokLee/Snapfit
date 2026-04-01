import 'dart:convert';
import 'dart:io';

import 'package:snap_fit/features/store/data/local/local_featured_templates.dart';

void main(List<String> args) {
  final outputPath =
      _arg(args, '--output') ?? 'assets/templates/generated/store_latest.json';

  final templates = localFeaturedTemplates();
  final payload = templates.map((e) => e.toJson()).toList();

  final outFile = File(outputPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));

  stdout.writeln('Exported ${payload.length} curated store template(s)');
  stdout.writeln('Output: $outputPath');
}

String? _arg(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('$name=')) {
      return a.substring(name.length + 1);
    }
  }
  return null;
}


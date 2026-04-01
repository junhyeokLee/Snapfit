import 'dart:io';

final _targetRoots = <String>[
  'lib/features/profile/presentation',
  'lib/features/store/presentation',
  'lib/features/notification/presentation',
];

final _skipPathContains = <String>[
  'template_page_renderer.dart',
  'premium_template_list.dart',
];

void main() {
  final hardFails = <String>[];
  final softWarnings = <String>[];

  for (final root in _targetRoots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      if (_skipPathContains.any(entity.path.contains)) continue;
      final content = entity.readAsStringSync();
      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineNo = i + 1;
        if (line.contains("fontFamily: 'Inter'")) {
          hardFails.add(
            '${entity.path}:$lineNo forbidden font family Inter. Use NotoSans/Raleway tokens.',
          );
        }
        if (line.contains('Color(0x') &&
            !line.contains('SnapFitColors.') &&
            !line.contains('SnapFitStylePalette.')) {
          softWarnings.add(
            '${entity.path}:$lineNo raw hex color found. Prefer SnapFitColors tokens.',
          );
        }
      }
    }
  }

  stdout.writeln('=== UI Consistency Gate ===');
  stdout.writeln('roots: ${_targetRoots.join(', ')}');
  stdout.writeln('hard-fails: ${hardFails.length}');
  stdout.writeln('soft-warnings: ${softWarnings.length}');

  if (hardFails.isNotEmpty) {
    stdout.writeln('\n[Hard Fails]');
    for (final issue in hardFails) {
      stdout.writeln('- $issue');
    }
  }

  if (softWarnings.isNotEmpty) {
    stdout.writeln('\n[Soft Warnings]');
    for (final issue in softWarnings.take(80)) {
      stdout.writeln('- $issue');
    }
    if (softWarnings.length > 80) {
      stdout.writeln('- ... and ${softWarnings.length - 80} more');
    }
  }

  if (hardFails.isNotEmpty) {
    exit(2);
  }
  stdout.writeln('\nPASS: UI consistency gate succeeded.');
}


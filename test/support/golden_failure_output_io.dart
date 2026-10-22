import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keep exact pixel comparisons without leaving large failure images on disk.
void configureGoldenFailureOutput() {
  final comparator = goldenFileComparator;
  if (comparator is LocalFileComparator) {
    goldenFileComparator = _MemoryFailureOutputComparator(
      comparator.basedir.resolve('_golden_test.dart'),
    );
  }
}

class _MemoryFailureOutputComparator extends LocalFileComparator {
  _MemoryFailureOutputComparator(super.testFile);

  @override
  Future<String> generateFailureOutput(
    ComparisonResult result,
    Uri golden,
    Uri basedir, {
    String key = '',
  }) async {
    if (const bool.fromEnvironment('SNAPFIT_GOLDEN_MEMORY')) {
      for (final entry
          in result.diffs?.entries ?? <MapEntry<String, ui.Image>>[]) {
        if (entry.key != 'masterImage' && entry.key != 'testImage') continue;
        final bytes = await entry.value.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (bytes == null) continue;
        debugPrintSynchronously(
          'SNAPFIT_GOLDEN_MEMORY_V1:${jsonEncode({'golden': golden.toString(), 'role': entry.key, 'width': entry.value.width, 'height': entry.value.height, 'base64': base64Encode(bytes.buffer.asUint8List())})}',
        );
      }
    }
    return 'Golden "$golden": ${result.error} (diff images were not saved).';
  }
}

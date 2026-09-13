import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:snap_fit/core/templates/preview_cache.dart';

void main() {
  test('warm remounts parse once and revisions never reuse stale previews', () {
    final cache = PreviewCache<String, Object>(capacity: 2);
    var parses = 0;
    Object parse() {
      parses++;
      return Object();
    }

    final first = cache.get('cover', 'json-v1', parse);
    for (var i = 0; i < 100; i++) {
      expect(identical(cache.get('cover', 'json-v1', parse), first), isTrue);
    }
    expect(parses, 1);
    debugPrint('BUDGET cache_requests=101 parses=$parses uncached_parses=101');
    expect(identical(cache.get('cover', 'json-v2', parse), first), isFalse);
    expect(parses, 2);
    cache.get('second', 'v1', parse);
    cache.get('third', 'v1', parse);
    expect(cache.length, 2);
    cache.get('cover', 'json-v2', parse);
    expect(parses, 5);
  });
}

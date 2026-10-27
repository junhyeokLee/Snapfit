import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';

void main() {
  test('physical size is resolved once per immutable album', () {
    // A nonstandard ratio creates a fresh CoverSize on each uncached resolve.
    final album = Album(
      ratio: '1.6',
      coverLayersJson: jsonEncode({
        'pages': List.generate(100, (i) => {'index': i, 'layers': []}),
      }),
    );
    final first = album.physicalCoverSize;
    expect(album.physicalCoverSize, same(first));
    expect(first.realSize, const Size(20, 12.5));
  });

  test(
    'copyWith ratio and print product changes resolve independent sizes',
    () {
      final album = Album(
        ratio: '1',
        coverLayersJson: jsonEncode({
          'printProduct': {
            'id': 'REDP_200_HARD',
            'trimWidthMm': 200,
            'trimHeightMm': 200,
          },
        }),
      );
      expect(album.physicalCoverSize.productId, 'REDP_200_HARD');
      final larger = album.copyWith(
        coverLayersJson: jsonEncode({
          'printProduct': {
            'id': 'REDP_300_HARD',
            'trimWidthMm': 300,
            'trimHeightMm': 300,
          },
        }),
      );
      expect(larger.physicalCoverSize.realSize, const Size(30, 30));
      expect(larger.physicalCoverSize, same(larger.physicalCoverSize));
      final portrait = larger.copyWith(ratio: '3:4');
      expect(portrait.physicalCoverSize.realSize, const Size(14.5, 19.4));
      expect(portrait.physicalCoverSize.productId, isNull);
      expect(album.physicalCoverSize.realSize, const Size(20, 20));
    },
  );

  test('malformed documents retain the legacy ratio fallback', () {
    const album = Album(ratio: '4/3', coverLayersJson: '{broken');
    expect(album.physicalCoverSize.realSize, const Size(19.4, 14.5));
    expect(album.physicalCoverSize, same(album.physicalCoverSize));
  });
}

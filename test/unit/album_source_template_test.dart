import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_source_template.dart';

void main() {
  test('source metadata exposes only the exact official product identity', () {
    final document = {
      'sourceTemplate': {
        'productKey': 'template:summer-memory',
        'albumId': 15,
        'photos': ['private-photo'],
      },
      'title': 'A title cannot infer a product',
    };
    final album = Album(coverLayersJson: jsonEncode(document));
    expect(album.sourceTemplateProductKey, 'template:summer-memory');
    expect(albumSourceTemplateMetadata(album.sourceTemplateProductKey), {
      'sourceTemplate': {'productKey': 'template:summer-memory'},
    });
  });

  test(
    'legacy malformed and non-template identities never fabricate a source',
    () {
      for (final document in [
        '',
        '{broken',
        '[]',
        'null',
        '{"title":"여름 여행"}',
        '{"sourceTemplate":"template:summer-memory"}',
        '{"sourceTemplate":{"productKey":24}}',
        '{"sourceTemplate":{"productKey":""}}',
        '{"sourceTemplate":{"productKey":"material:frame"}}',
        '{"sourceTemplate":{"productKey":"template:bad key"}}',
      ]) {
        expect(
          Album(coverLayersJson: document).sourceTemplateProductKey,
          isNull,
          reason: document,
        );
      }
      expect(albumSourceTemplateMetadata(null), isEmpty);
      expect(
        normalizeAlbumSourceTemplateProductKey('template:${'x' * 300}'),
        isNull,
      );
    },
  );
}

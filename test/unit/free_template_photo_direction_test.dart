import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';

List<String> photos(Map<String, dynamic> page) => [
  for (final layer in page['layers'] as List)
    if (layer['type'] == 'image') layer['imageUrl'] as String,
];

void main() {
  for (final aspect in CollectionAspect.values) {
    test('free photo direction is distinct and editable: ${aspect.name}', () {
      final coverHeroes = <String>{};
      for (final volume in FreeCollectionVolume.values) {
        final document = volume.document(aspect);
        final pages = templateDocumentPages(document);
        expect(document['version'], 4);
        expect(document['accessTier'], 'free');
        expect(document['innerPageCount'], 24);
        final hero = (pages.first['layers'] as List)
            .cast<Map<String, dynamic>>()
            .where((l) => l['type'] == 'image')
            .reduce(
              (a, b) =>
                  (a['w'] as num) * (a['h'] as num) >=
                      (b['w'] as num) * (b['h'] as num)
                  ? a
                  : b,
            );
        expect(
          coverHeroes.add(hero['imageUrl'] as String),
          true,
          reason: volume.id,
        );
        final bookPhotos = pages.expand(photos).toList();
        for (final path in bookPhotos.toSet()) {
          expect(File(path.substring(6)).existsSync(), true, reason: path);
        }
        expect(
          bookPhotos.toSet().length,
          greaterThanOrEqualTo(
            volume.category == '반려동물'
                ? 4
                : volume.category == '성장·육아'
                ? 6
                : 9,
          ),
          reason: volume.id,
        );
        for (var first = 1; first < pages.length; first += 2) {
          final spreadPhotos = [
            ...photos(pages[first]),
            ...photos(pages[first + 1]),
          ];
          expect(
            spreadPhotos.toSet().length,
            spreadPhotos.length,
            reason: '${volume.id}: spread ${(first + 1) ~/ 2}',
          );
        }
        // Construction is deterministic, including after another size is built.
        volume.document(CollectionAspect.square);
        expect(volume.document(aspect), document);
      }
    });
  }
}

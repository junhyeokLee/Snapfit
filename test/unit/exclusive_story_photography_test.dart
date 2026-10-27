import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'story_editions_test.dart' show loadStoryFonts;

/// This is a development audit, never run while a customer opens the store.
Set<String> _photos(Object? value) {
  final result = <String>{};
  void visit(Object? node) {
    if (node is Map) {
      if (node['type'] == 'image') {
        final path = node['imageUrl'];
        if (path is String && path.startsWith('asset:'))
          result.add(path.substring(6));
      }
      for (final child in node.values) {
        visit(child);
      }
    } else if (node is List) {
      for (final child in node) {
        visit(child);
      }
    }
  }

  visit(value);
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStoryFonts);

  test(
    'all new stories use edition-exclusive photography in every size and page',
    () {
      final legacy = originalStoryEditions.map((e) => e.id).toSet();
      final manifest =
          jsonDecode(
                File(
                  'tool/template_studio/exclusive_story_editions_2026.json',
                ).readAsStringSync(),
              )
              as Map;
      final legacyCatalogIds =
          (manifest['legacyPhotoSharingCatalogIds'] as List)
              .cast<int>()
              .toSet();
      expect(
        legacyCatalogIds,
        hasLength(103),
        reason: 'Never expand the legacy sharing exception',
      );
      expect(
        publishedCreationTemplates
            .where((t) => !legacyCatalogIds.contains(t.id))
            .map((t) => t.id)
            .toSet(),
        photographyExclusiveStoryEditions.map((e) => e.catalogId).toSet(),
        reason:
            'New editions in any catalog must join the exclusive photo audit',
      );
      for (final e in storyEditions.where((e) => !legacy.contains(e.id))) {
        expect(
          e.exclusivePhotography,
          true,
          reason: 'Future editions must not silently resume sharing stock',
        );
        expect(e.photoAssets.toSet(), hasLength(5));
        expect(e.notes, hasLength(12));
        for (final aspect in CollectionAspect.printable) {
          final document = storyEditionDocument(e, aspect);
          expect(_photos(document), e.photoAssets.toSet());
          expect(document['photoReusePolicy'], 'edition-exclusive');
          expect(
            document['samplePhotography'],
            'exclusive-generated-editorial-samples',
          );
        }
      }
    },
  );

  test(
    'paths, encoded files and renamed/reencoded pixels cannot cross editions',
    () async {
      final exclusive = photographyExclusiveStoryEditions
          .map((e) => e.catalogId)
          .toSet();
      final owners = <String, Set<int>>{};
      for (final template in publishedCreationTemplates) {
        for (final path in _photos(jsonDecode(template.templateJson!))) {
          final canonical = File(path).resolveSymbolicLinksSync();
          (owners[canonical] ??= {}).add(template.id);
        }
      }
      final hashes = <String, Set<int>>{};
      final fingerprints = <String, Uint8List>{};
      var exclusiveCount = 0;
      var exclusiveBytes = 0;
      for (final entry in owners.entries) {
        final file = File(entry.key);
        final bytes = file.readAsBytesSync();
        final digest = sha256.convert(bytes).toString();
        (hashes[digest] ??= {}).addAll(entry.value);
        if (entry.value.any(exclusive.contains)) {
          expect(
            entry.value,
            hasLength(1),
            reason: 'Photo shared across books: ${entry.key}',
          );
          exclusiveCount++;
          exclusiveBytes += bytes.length;
        }
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 32,
          targetHeight: 32,
        );
        try {
          final image = (await codec.getNextFrame()).image;
          try {
            fingerprints[entry.key] = (await image.toByteData())!.buffer
                .asUint8List();
          } finally {
            image.dispose();
          }
        } finally {
          codec.dispose();
        }
      }
      for (final entry in hashes.entries) {
        if (entry.value.any(exclusive.contains)) {
          expect(
            entry.value,
            hasLength(1),
            reason: 'Renamed duplicate bytes: ${entry.key}',
          );
        }
      }
      final paths = fingerprints.keys.toList();
      for (var a = 0; a < paths.length; a++) {
        for (var b = a + 1; b < paths.length; b++) {
          final firstOwners = owners[paths[a]]!;
          final secondOwners = owners[paths[b]]!;
          if (!firstOwners.any(exclusive.contains) &&
              !secondOwners.any(exclusive.contains))
            continue;
          // Repeated uses inside a book point to a single canonical source;
          // distinct sources must also have genuinely different image content.
          final first = fingerprints[paths[a]]!;
          final second = fingerprints[paths[b]]!;
          var sum = 0;
          for (var i = 0; i < first.length; i += 4) {
            for (var c = 0; c < 3; c++) {
              sum += (first[i + c] - second[i + c]).abs();
            }
          }
          expect(
            sum / (first.length / 4 * 3),
            greaterThan(2),
            reason: 'Visually repeated photo: ${paths[a]} / ${paths[b]}',
          );
        }
      }
      expect(exclusiveCount, photographyExclusiveStoryEditions.length * 5);
      expect(
        exclusiveBytes,
        lessThan(photographyExclusiveStoryEditions.length * 4 * 1024 * 1024),
      );
    },
  );

  test(
    'photo provenance covers all sources and no untracked bitmap is bundled',
    () {
      final jobs = <Map>[
        for (final name in [
          'exclusive_story_editions_2026',
          'club_story_editions_2026',
          'activity_story_editions_2026',
        ])
          ...(jsonDecode(
                    File('tool/template_studio/$name.json').readAsStringSync(),
                  )['jobs']
                  as List)
              .cast<Map>(),
      ];
      final expected = {
        for (final e in photographyExclusiveStoryEditions) ...e.photoAssets,
      };
      expect(jobs, hasLength(expected.length));
      expect(jobs.map((j) => j['assetPath']).toSet(), expected);
      for (final job in jobs) {
        final file = File(job['assetPath'] as String);
        expect(
          sha256.convert(file.readAsBytesSync()).toString(),
          job['sha256'],
        );
        expect(job['prompt'], isNotEmpty);
        expect(job['sourcePath'], isNotEmpty);
      }
      final actual = <String>{
        for (final directory in [
          'exclusive_editions_2026',
          'club_editions_2026',
          'activity_editions_2026',
        ])
          ...Directory(
            'assets/templates/$directory',
          ).listSync(recursive: true).whereType<File>().map((f) => f.path),
      };
      expect(actual, expected);
    },
  );
}

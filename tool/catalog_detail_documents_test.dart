import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/data/catalog_detail_artwork_revisions.g.dart';
import 'package:snap_fit/core/data/catalog_detail_assets.dart';
import 'package:snap_fit/core/templates/published_premium_templates.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';

// Export native font layouts without running an app build:
// flutter test --dart-define=UPDATE_CATALOG_DETAILS=true tool/catalog_detail_documents_test.dart
// Update only reviewed products, verifying every other document stays current:
// ... --dart-define=CATALOG_DETAIL_IDS=-9422,-9443,-9451
const _versionedArtworkIds = {
  '-9801',
  '-9802',
  '-9803',
  '-9804',
  '-9805',
  '-9806',
  '-9807',
  '-9808',
  '-9809',
  '-9810',
  '-9811',
  '-9812',
  '-9813',
  '-9814',
  '-9815',
  '-9816',
  '-9817',
  '-9818',
  '-9819',
  '-9820',
  '-9821',
  '-9822',
  '-9823',
  '-9824',
  '-9825',
  '-9826',
  '-9827',
  '-9828',
  '-9829',
  '-9830',
  '-9831',
  '-9832',
  '-9833',
  '-9834',
  '-9835',
  '-9836',
  '-9837',
  '-9838',
  '-9839',
  '-9840',
  '-9841',
  '-9842',
  '-9843',
  '-9844',
  '-9422',
  '-9443',
  '-9451',
  '-9761',
  '-9762',
  '-9771',
  '-9772',
  '-9773',
  '-9774',
  '-9775',
  '-9776',
  '-9777',
  '-9778',
  '-9779',
  '-9780',
  '-9781',
  '-9782',
  '-9783',
  '-9784',
  '-9785',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('full detail documents preserve published artwork and native fonts', () async {
    const update = bool.fromEnvironment('UPDATE_CATALOG_DETAILS');
    final selected = const String.fromEnvironment(
      'CATALOG_DETAIL_IDS',
    ).split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    final directory = Directory('assets/templates/detail_documents');
    if (update) directory.createSync(recursive: true);
    final manifestSource = await rootBundle.loadString('FontManifest.json');
    final fontHashes = <String>[manifestSource];
    for (final font in jsonDecode(manifestSource) as List) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        final path = asset['asset'] as String;
        final bytes = await rootBundle.load(path);
        final data = bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
        fontHashes.add('$path:${sha256.convert(data)}');
        loader.addFont(Future.value(bytes));
      }
      await loader.load();
    }
    final sources = <String, String>{};
    for (final template in publishedCreationTemplates) {
      sources['${template.id}'] = template.templateJson!;
      final volume = publishedPremiumVolume(template.id);
      if (volume != null) {
        for (final count in volume.pageCounts) {
          sources['${template.id}-$count'] = jsonEncode(
            premiumCatalogDocument(volume, innerPages: count),
          );
        }
      }
    }
    expect(
      sources.keys.toSet().containsAll(selected),
      isTrue,
      reason: 'Unknown IDs must not silently skip the requested export.',
    );
    final hashes = {
      for (final entry in sources.entries)
        entry.key: sha256.convert(utf8.encode(entry.value)).toString(),
    };
    final revisions = Map<String, String>.from(catalogDetailArtworkRevisions);
    for (final id in _versionedArtworkIds) {
      final fingerprint = hashes[id]!.substring(0, 16);
      if (update && (selected.isEmpty || selected.contains(id))) {
        revisions[id] = fingerprint;
      } else {
        expect(
          revisions[id],
          fingerprint,
          reason:
              'Detail artwork URL for $id is stale. Regenerate its full document.',
        );
      }
    }
    bool writes(String id) =>
        update && (selected.isEmpty || selected.contains(id));
    final stale = <Map<String, String>>[];
    var verified = 0;
    // Preflight every untouched book before writing any selected output. A
    // partially refreshed manifest must never hide other stale original assets.
    for (final entry in sources.entries.where((e) => !writes(e.key))) {
      final path =
          '${directory.path}/${catalogDetailFileName(entry.key, artworkRevision: revisions[entry.key])}';
      final file = File(path);
      String? problem;
      if (!file.existsSync()) {
        problem = 'missing';
      } else {
        try {
          final bytes = GZipDecoder().decodeBytes(file.readAsBytesSync());
          if (sha256.convert(bytes).toString() != hashes[entry.key]) {
            problem = 'stale artwork';
          }
        } on Object {
          problem = 'invalid gzip';
        }
      }
      if (problem != null) {
        stale.add({'id': entry.key, 'path': path, 'problem': problem});
      } else {
        verified++;
      }
    }
    expect(
      stale,
      isEmpty,
      reason:
          '${stale.length} full detail documents differ from current native artwork: ${jsonEncode(stale)}. No files have been written.',
    );
    final updated = <String>[];
    for (final entry in sources.entries.where((e) => writes(e.key))) {
      final file = File(
        '${directory.path}/${catalogDetailFileName(entry.key, artworkRevision: revisions[entry.key])}',
      );
      file.writeAsBytesSync(GZipEncoder().encode(utf8.encode(entry.value)));
      updated.add(entry.key);
    }
    // ignore: avoid_print
    print(
      'SNAPFIT_DETAIL_DOCUMENT_PREFLIGHT:${jsonEncode({'verifiedUnchangedDocuments': verified, 'updatedDocuments': updated, 'totalDocuments': sources.length})}',
    );
    final manifest = {
      'layoutRevision': catalogDetailLayoutRevision,
      'artworkRevisions': revisions,
      'fontDigest': sha256
          .convert(utf8.encode(fontHashes.join('\n')))
          .toString(),
      'documents': hashes,
    };
    final file = File('${directory.path}/manifest.json');
    if (update) {
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );
      String literal(String value) => jsonEncode(value).replaceAll(r'$', r'\$');
      File(
        'lib/core/data/catalog_detail_artwork_revisions.g.dart',
      ).writeAsStringSync(
        '// Generated by tool/catalog_detail_documents_test.dart. Do not edit.\n'
        '// Content fingerprints prevent cached detail books from diverging from cards.\n'
        'const catalogDetailArtworkRevisions = <String, String>{\n'
        '${revisions.entries.map((e) => '  ${literal(e.key)}: ${literal(e.value)},').join('\n')}\n'
        '};\n',
      );
    } else {
      expect(jsonDecode(file.readAsStringSync()), manifest);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

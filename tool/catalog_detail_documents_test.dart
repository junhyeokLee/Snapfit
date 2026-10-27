import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/published_premium_templates.dart';
import 'package:snap_fit/core/data/catalog_detail_assets.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';

// Export native font layouts without running an app build:
// flutter test --dart-define=UPDATE_CATALOG_DETAILS=true tool/catalog_detail_documents_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'full detail documents preserve published artwork and native fonts',
    () async {
      const update = bool.fromEnvironment('UPDATE_CATALOG_DETAILS');
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
      final hashes = <String, String>{};
      void verify(String name, String source) {
        final bytes = utf8.encode(source);
        hashes[name] = sha256.convert(bytes).toString();
        final file = File('${directory.path}/${catalogDetailFileName(name)}');
        if (update) {
          file.writeAsBytesSync(GZipEncoder().encode(bytes));
        } else {
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Missing detail document $name',
          );
          expect(
            utf8.decode(GZipDecoder().decodeBytes(file.readAsBytesSync())),
            source,
            reason:
                'Stale detail artwork $name; regenerate the native font snapshots.',
          );
        }
      }

      for (final template in publishedCreationTemplates) {
        verify('${template.id}', template.templateJson!);
        final volume = publishedPremiumVolume(template.id);
        if (volume != null) {
          for (final count in volume.pageCounts) {
            verify(
              '${template.id}-$count',
              jsonEncode(premiumCatalogDocument(volume, innerPages: count)),
            );
          }
        }
      }
      final manifest = {
        'layoutRevision': catalogDetailLayoutRevision,
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
      } else {
        expect(jsonDecode(file.readAsStringSync()), manifest);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

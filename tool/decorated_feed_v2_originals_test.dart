// Local standard photo-upload preparation only; preserves each source file.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/moments/data/moment_photo_codec.dart';

void main() {
  testWidgets('prepare four selected original upload copies', (tester) async {
    await tester.runAsync(() async {
      final manifestFile = File(
        'output/decorated-feed-20261103-v2/manifest.json',
      );
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final records = <Map<String, dynamic>>[];
      for (final entry in manifest['posts'] as List<dynamic>) {
        final post = Map<String, dynamic>.from(entry as Map);
        final source = File(post['originalPath'] as String);
        final prepared = await prepareMomentPhoto(await source.readAsBytes());
        final output = File(post['preparedOriginalPath'] as String);
        await output.writeAsBytes(prepared.bytes, flush: true);
        expect(prepared.width, 1122);
        expect(prepared.height, 1402);
        records.add({
          'id': post['id'],
          'originalPath': source.path,
          'preparedOriginalPath': output.path,
          'width': prepared.width,
          'height': prepared.height,
          'bytes': prepared.bytes.length,
          'codec': 'prepareMomentPhoto',
        });
      }
      expect(records.length, 4);
      await File(
        'output/decorated-feed-20261103-v2/originals-report.json',
      ).writeAsString(
        '${const JsonEncoder.withIndent('  ').convert({'originals': records})}\n',
        flush: true,
      );
    });
    expect(tester.takeException(), isNull);
  });
}

// Standard local profile-photo preparation; source photos remain untouched.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/social/data/social_profile_photo.dart';

void main() {
  testWidgets('prepare four selected profile-photo copies', (tester) async {
    await tester.runAsync(() async {
      final manifestFile = File(
        'output/decorated-feed-20261103-v2/manifest.json',
      );
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final records = <Map<String, dynamic>>[];
      for (final entry in manifest['posts'] as List<dynamic>) {
        final post = entry as Map<String, dynamic>;
        final source = File(post['originalPath'] as String);
        final prepared = await prepareSocialProfilePhoto(
          await source.readAsBytes(),
        );
        final path =
            'output/decorated-feed-20261103-v2/${post['id']}.avatar.png';
        await File(path).writeAsBytes(prepared, flush: true);
        final pngHeader = ByteData.sublistView(prepared);
        post['avatarPath'] = path;
        records.add({
          'id': post['id'],
          'avatarPath': path,
          'width': pngHeader.getUint32(16),
          'height': pngHeader.getUint32(20),
          'bytes': prepared.length,
          'codec': 'prepareSocialProfilePhoto',
        });
      }
      expect(records.length, 4);
      await File(
        'output/decorated-feed-20261103-v2/avatars-report.json',
      ).writeAsString(
        '${const JsonEncoder.withIndent('  ').convert({'avatars': records})}\n',
        flush: true,
      );
      // Retain all current publication/status fields; only add avatar paths.
      await manifestFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
        flush: true,
      );
    });
    expect(tester.takeException(), isNull);
  });
}

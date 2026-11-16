// Local preparation only. Reads selected original sample pixels and editable
// documents, then invokes the same bounded renderer as feed publication.
// No network, account creation, engagement, or database writes are performed.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/social/data/social_album_snapshot.dart';

void main() {
  testWidgets('render four editable decorated feed candidates', (tester) async {
    await tester.runAsync(() async {
      final manifestFile = File(
        'output/decorated-feed-20261103-v2/manifest.json',
      );
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final posts = manifest['posts'] as List<dynamic>;
      expect(posts.length, 4);
      final renderRecords = <Map<String, dynamic>>[];

      // Sequential by design: at most one original and one exported image are
      // decoded at once on this 8 GB host.
      for (final entry in posts) {
        final post = Map<String, dynamic>.from(entry as Map);
        final savedJson = Map<String, dynamic>.from(post['design'] as Map);
        final designFile = jsonDecode(
          await File(post['designPath'] as String).readAsString(),
        );
        expect(designFile, equals(savedJson));
        final design = MomentPhotoDesign.fromJson(savedJson);
        expect(design.toJson(), equals(savedJson));
        expect(design.canvasSize, const Size(500, 625));
        final photoBytes = await File(
          post['originalPath'] as String,
        ).readAsBytes();
        final renderer = SocialSnapshotRenderer(
          loader: (source) async {
            if (source != momentPhotoOriginalSource) {
              throw StateError('Unreviewed external source: $source');
            }
            return Uint8List.fromList(photoBytes);
          },
        );
        final page = PrintAlbumPage(
          index: 0,
          isCover: false,
          canvasSize: design.canvasSize,
          layers: design.layersForPhoto(momentPhotoOriginalSource),
          backgroundColor: design.backgroundColor,
        );
        await renderer.prepareFonts([page]);
        final png = await renderer.renderPage(
          page,
          theme: SnapFitTheme.light(),
        );
        final output = File(post['renderPath'] as String);
        await output.writeAsBytes(png, flush: true);

        final codec = await ui.instantiateImageCodec(png);
        late final int width;
        late final int height;
        try {
          final image = (await codec.getNextFrame()).image;
          try {
            width = image.width;
            height = image.height;
          } finally {
            image.dispose();
          }
        } finally {
          codec.dispose();
        }
        expect(width, 1152);
        expect(height, 1440);
        renderRecords.add({
          'id': post['id'],
          'renderPath': output.path,
          'width': width,
          'height': height,
          'bytes': png.length,
          'layers': page.layers.length,
          'fontFamilies': design.fontFamilies.toList()..sort(),
          'renderer': 'SocialSnapshotRenderer',
          'editableDocumentValidated': true,
        });
      }

      await File(
        'output/decorated-feed-20261103-v2/render-report.json',
      ).writeAsString(
        '${const JsonEncoder.withIndent('  ').convert({'publicationStatus': 'prepared', 'renders': renderRecords})}\n',
        flush: true,
      );
    });
    expect(tester.takeException(), isNull);
  });
}

import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/story_edition_catalog.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/shared/widgets/story_edition_stationery.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_application_preview.dart';

void main() {
  testWidgets(
    '130 print materials have distinct native artwork without image allocations',
    (tester) async {
      final hashes = <String>{};
      for (final spec in storyEditionDecorations) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 300,
                  height: 240,
                  child: StudioDecoration(spec: spec),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(StoryEditionStationery), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        await tester.runAsync(() async {
          final bitmap =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          try {
            final data = await bitmap.toByteData(
              format: ui.ImageByteFormat.png,
            );
            expect(
              hashes.add(sha256.convert(data!.buffer.asUint8List()).toString()),
              true,
              reason: 'Duplicate material ${spec.id}',
            );
          } finally {
            bitmap.dispose();
          }
        });
        expect(tester.takeException(), isNull);
      }
      expect(hashes, hasLength(130));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'paper application keeps the matching photo above its backing and recovers on reopen',
    (tester) async {
      final cache = PaintingBinding.instance.imageCache;
      final oldBytes = cache.maximumSizeBytes;
      cache.maximumSizeBytes = 12 * 1024 * 1024;
      addTearDown(() {
        cache.maximumSizeBytes = oldBytes;
        cache.clear();
      });
      for (final e in storyEditions) {
        for (final dark in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              home: Center(
                child: SizedBox(
                  width: 330,
                  height: 480,
                  child: MaterialApplicationPreview(
                    productKey: 'sticker:${e.paperId}',
                    type: '종이',
                    material: StudioDecoration(
                      spec: studioDecorationById(e.paperId)!,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final imageFinder = find.byKey(const ValueKey('application-photo'));
          expect(imageFinder, findsOneWidget);
          final image = tester.widget<Image>(imageFinder);
          final provider = image.image as ResizeImage;
          expect(
            (provider.imageProvider as AssetImage).assetName,
            e.coverAsset,
          );
          await tester.runAsync(
            () => precacheImage(image.image, tester.element(imageFinder)),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<RawImage>(
                  find.descendant(
                    of: imageFinder,
                    matching: find.byType(RawImage),
                  ),
                )
                .image,
            isNotNull,
          );
          expect(tester.takeException(), isNull, reason: e.id);
        }
        await tester.pumpWidget(const SizedBox());
        expect(
          cache.currentSizeBytes,
          lessThanOrEqualTo(cache.maximumSizeBytes),
        );
      }
      await tester.pumpAndSettle();
      cache.clear();
      expect(cache.pendingImageCount, 0);
      expect(cache.liveImageCount, 0);
    },
  );
}

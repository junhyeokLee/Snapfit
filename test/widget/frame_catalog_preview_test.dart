import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/frame_preview_photos.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

void main() {
  setUpAll(loadCreationFonts);
  test('every non-default frame has a unique existing photo', () {
    final frames = imageFrameStyles.where((f) => f.key.isNotEmpty).toList();
    expect(framePreviewPhotos.keys.toSet(), frames.map((f) => f.key).toSet());
    final hashes = frames
        .map(
          (f) => sha256
              .convert(File(framePreviewPhotos[f.key]!).readAsBytesSync())
              .toString(),
        )
        .toSet();
    expect(hashes.length, frames.length);
  });
  testWidgets('all catalog frames render photographs and legacy shapes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final frames = imageFrameStyles.where((f) => f.key.isNotEmpty).toList();
    for (var offset = 0; offset < frames.length; offset += 12) {
      await tester.pumpWidget(const SizedBox.shrink());
      final batch = frames.skip(offset).take(12).toList();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(800, 960),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                key: boundary,
                child: ColoredBox(
                  color: const Color(0xFFE8ECEB),
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    children: [
                      for (final frame in batch)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Expanded(
                                child: ImageFramePreview(
                                  style: frame,
                                  child: Image.asset(
                                    framePreviewPhotos[frame.key]!,
                                    key: ValueKey('photo-${frame.key}'),
                                    fit: BoxFit.cover,
                                    cacheWidth: 384,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                frame.label,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final frame in batch) {
          await precacheImage(
            ResizeImage(AssetImage(framePreviewPhotos[frame.key]!), width: 384),
            boundary.currentContext!,
          );
        }
      });
      await tester.pumpAndSettle();
      for (final frame in batch) {
        final preview = find.byKey(ValueKey('photo-${frame.key}'));
        final photo = find.descendant(
          of: preview,
          matching: find.byType(RawImage),
        );
        expect(photo, findsOneWidget, reason: frame.key);
        expect(
          tester.widget<RawImage>(photo).image,
          isNotNull,
          reason: frame.key,
        );
        expect(
          tester.getSize(photo).shortestSide,
          greaterThan(40),
          reason: frame.key,
        );
      }
      expect(
        tester.takeException(),
        isNull,
        reason: batch.map((f) => f.key).join(','),
      );
      if (const bool.fromEnvironment('FRAME_QA')) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('output/frame-preview-qa')
            ..createSync(recursive: true);
          File(
            '${directory.path}/batch-$offset.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}

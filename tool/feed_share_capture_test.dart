import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/moments/data/moment_photo_share_exporter.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/social/data/social_album_snapshot.dart';
import 'package:snap_fit/shared/sharing/feed_share_sheet.dart';

import '../test/helpers/load_moment_capture_fonts.dart';

void main() {
  const enabled = bool.fromEnvironment('EXPORT_FEED_SHARE_REVIEW');
  if (enabled) setUpAll(loadMomentCaptureFonts);
  testWidgets('share sheet visual proof at phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final images = <String, Uint8List>{};
    for (final entry in {
      'sunset': 'jeju_sunset.jpg',
      'coast': 'jeju_rocky_coast.jpg',
    }.entries) {
      final source =
          'supabase://album-assets/users/review/moments/${entry.key}.jpg';
      final design = MomentPhotoDesign.fromLayers(
        canvasSize: const Size(400, 400),
        backgroundColor: const Color(0xFFFFFBF3),
        photoSource: source,
        layers: [
          LayerModel(
            id: 'photo',
            type: LayerType.image,
            position: const Offset(16, 16),
            width: 368,
            height: 244,
            originalUrl: source,
            imageTemplate: 'free',
          ),
          LayerModel(
            id: 'note',
            type: LayerType.text,
            position: const Offset(24, 285),
            width: 330,
            height: 48,
            text: entry.key == 'sunset' ? '바다가 건넨 하루' : '천천히 걸었던 해변',
            zIndex: 1,
            textStyle: const TextStyle(
              fontFamily: 'Eulyoo',
              fontSize: 25,
              color: Color(0xFF253B37),
            ),
          ),
          LayerModel(
            id: 'star',
            type: LayerType.decoration,
            position: const Offset(334, 344),
            width: 32,
            height: 32,
            imageBackground: 'stickerBlueStar',
            zIndex: 2,
          ),
        ],
      );
      final png = await tester.runAsync(() async {
        final bytes = await rootBundle.load(
          'assets/templates/jeju_travel/images/figma_small/${entry.value}',
        );
        final exporter = MomentPhotoShareExporter(
          renderer: SocialSnapshotRenderer(
            loader: (_) async => bytes.buffer.asUint8List(
              bytes.offsetInBytes,
              bytes.lengthInBytes,
            ),
          ),
        );
        final result = await exporter.export(
          photo: MomentPhoto(
            id: entry.key,
            path: 'users/review/moments/${entry.key}.jpg',
            url: '',
            width: 1200,
            height: 800,
            design: design,
          ),
          theme: SnapFitTheme.light(),
        );
        return result.bytes;
      });
      images[entry.key] = png!;
    }
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedImageShareWriterProvider.overrideWithValue(
            (_, _, _) async =>
                const ShareResult('', ShareResultStatus.dismissed),
          ),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SnapFitTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('오늘의 기록')),
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('잠깐 멈춰 바라본, 오늘의 바다.'),
                      const SizedBox(height: 20),
                      Image.memory(
                        images['sunset']!,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                      TextButton.icon(
                        key: const ValueKey('review-open-share'),
                        onPressed: () => showFeedShareSheet(
                          context,
                          title: '11월 5일 기록 공유',
                          caption: '잠깐 멈춰 바라본, 오늘의 바다.',
                          photos: [
                            for (final entry in images.entries)
                              FeedSharePhoto(
                                id: entry.key,
                                preview: (_) => Image.memory(
                                  entry.value,
                                  fit: BoxFit.contain,
                                ),
                                render: (_, _) async => entry.value,
                              ),
                          ],
                          isActive: () => true,
                          note: '사진만 공유해요. 기록의 공개 범위는 바뀌지 않아요.',
                        ),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('공유하기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-open-share')));
    await tester.pumpAndSettle();
    bool decodedShareImages() =>
        [
          'feed-share-preview',
          'feed-share-photo-sunset',
          'feed-share-photo-coast',
        ].every(
          (key) => tester
              .widgetList<RawImage>(
                find.descendant(
                  of: find.byKey(ValueKey(key)),
                  matching: find.byType(RawImage),
                ),
              )
              .any((image) => image.image != null),
        );
    for (var attempt = 0; attempt < 40; attempt++) {
      if (decodedShareImages()) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      decodedShareImages(),
      isTrue,
      reason: 'The PNG and both thumbnails must decode before visual review.',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('사진 공유하기'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('feed-share-image')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    boundary.markNeedsPaint();
    // Flush retained button paragraphs after asynchronous PNG decoding too.
    for (final paragraph in tester.renderObjectList<RenderParagraph>(
      find.descendant(
        of: find.byKey(const ValueKey('feed-share-image')),
        matching: find.byType(RichText),
      ),
    )) {
      paragraph.markNeedsPaint();
    }
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        const output = String.fromEnvironment('FEED_SHARE_REVIEW_OUTPUT');
        if (output.isEmpty)
          throw StateError('External review directory required');
        final file = File('$output/feed-share-390-light.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } finally {
        image.dispose();
      }
    });
    await tester.tap(find.byKey(const ValueKey('feed-share-close')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  }, skip: !enabled);
}

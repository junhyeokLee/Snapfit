import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/photo_crop_sheet.dart';
import 'package:snap_fit/shared/widgets/photo_crop_viewport.dart';

Future<BrowserPhotoAsset> _memoryPortrait(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 80, 100),
        Paint()..color = const Color(0xFFDBE8E4),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 80, 20),
        Paint()..color = const Color(0xFF32564C),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 80, 80, 20),
        Paint()..color = const Color(0xFFB77842),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(80, 100);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = Uint8List.fromList(
          data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        return await BrowserPhotoAsset.fromBytes(
          ownerId: 'local-crop-test',
          name: 'portrait.png',
          bytes: bytes,
        );
      } finally {
        image.dispose();
        picture.dispose();
      }
    }))!;

Future<void> _ready(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    final apply = find.byKey(const ValueKey('photo-crop-apply'));
    if (apply.evaluate().isNotEmpty &&
        tester.widget<ElevatedButton>(apply).onPressed != null) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('The local memory photograph did not become ready.');
}

Widget _host(
  LayerModel layer,
  ValueChanged<LayerModel> capture, {
  EdgeInsets photoPadding = EdgeInsets.zero,
}) => MaterialApp(
  home: Scaffold(
    body: PhotoCropSheet(
      layer: layer,
      frameBuilder: (draft, photo) {
        capture(draft);
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, constraints.maxHeight);
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: Padding(
                  padding: photoPadding,
                  child: ClipOval(
                    child: SizedBox.expand(
                      key: const ValueKey('actual-crop-aperture'),
                      child: PhotoCropViewport(layer: draft, child: photo),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  ),
);

LayerModel _layer(BrowserPhotoAsset asset) => LayerModel(
  id: 'framed-portrait',
  type: LayerType.image,
  position: const Offset(25, 35),
  width: 250,
  height: 350,
  imageBackground: 'circle',
  asset: asset,
  imageOffset: const Offset(50, -35),
);

void main() {
  testWidgets(
    'circle anchors follow its square aperture rather than the layer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final original = _layer(await _memoryPortrait(tester));
      late LayerModel draft;
      await tester.pumpWidget(_host(original, (value) => draft = value));
      await _ready(tester);
      expect(
        tester.getSize(find.byKey(const ValueKey('actual-crop-aperture'))),
        const Size(250, 250),
      );
      expect(find.text('위쪽'), findsOneWidget);
      expect(find.text('아래쪽'), findsOneWidget);
      expect(find.text('왼쪽'), findsNothing);
      expect(find.text('오른쪽'), findsNothing);
      await tester.tap(find.text('위쪽'));
      await tester.pumpAndSettle();
      expect(draft.imageAlignment.y, -1);
      expect(draft.imageAlignment.x, closeTo(.4, .0001));
      await tester.tap(find.text('아래쪽'));
      await tester.pumpAndSettle();
      expect(draft.imageAlignment.y, 1);
      expect(draft.imageAlignment.x, closeTo(.4, .0001));
      expect(original.imageOffset, const Offset(50, -35));
      expect(draft.position, original.position);
      expect(draft.width, original.width);
      expect(draft.height, original.height);
      expect(draft.imageBackground, original.imageBackground);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'zoom and rotation retain the frame aperture and selected anchor',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final original = _layer(await _memoryPortrait(tester));
      late LayerModel draft;
      await tester.pumpWidget(_host(original, (value) => draft = value));
      await _ready(tester);
      tester
          .widget<Slider>(find.byKey(const ValueKey('photo-crop-zoom')))
          .onChanged!(1.5);
      await tester.pumpAndSettle();
      expect(draft.imageZoom, 1.5);
      expect(find.text('위쪽'), findsOneWidget);
      await tester.tap(find.text('아래쪽'));
      await tester.pumpAndSettle();
      final selectedOffset = draft.imageOffset;
      expect(draft.imageAlignment, const Alignment(.4, 1));
      await tester.binding.setSurfaceSize(const Size(844, 390));
      await _ready(tester);
      expect(
        tester.getSize(find.byKey(const ValueKey('actual-crop-aperture'))),
        const Size(250, 250),
      );
      expect(find.text('위쪽'), findsOneWidget);
      expect(find.text('아래쪽'), findsOneWidget);
      expect(draft.imageZoom, 1.5);
      expect(draft.imageOffset, selectedOffset);
      await tester.tap(find.text('중앙'));
      await tester.pumpAndSettle();
      expect(draft.imageAlignment.y, 0);
      expect(draft.imageAlignment.x, closeTo(.4, .0001));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'frame padding uses the inner photograph bounds for anchor axes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final original = _layer(await _memoryPortrait(tester));
      late LayerModel draft;
      await tester.pumpWidget(
        _host(
          original,
          (value) => draft = value,
          photoPadding: const EdgeInsets.symmetric(horizontal: 50),
        ),
      );
      await _ready(tester);
      expect(
        tester.getSize(find.byKey(const ValueKey('actual-crop-aperture'))),
        const Size(150, 250),
      );
      expect(find.text('왼쪽'), findsOneWidget);
      expect(find.text('오른쪽'), findsOneWidget);
      expect(find.text('위쪽'), findsNothing);
      expect(find.text('아래쪽'), findsNothing);
      final originalY = draft.imageAlignment.y;
      await tester.tap(find.text('오른쪽'));
      await tester.pumpAndSettle();
      expect(draft.imageAlignment.x, 1);
      expect(draft.imageAlignment.y, originalY);
      expect(original.imageOffset, const Offset(50, -35));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

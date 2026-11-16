import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_format.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';

MomentPhotoDesign _legacy() => MomentPhotoDesign.fromLayers(
  canvasSize: const Size(400, 600),
  backgroundColor: const Color(0xFFF2E8DC),
  photoSource: momentPhotoOriginalSource,
  layers: [
    LayerModel(
      id: 'original',
      type: LayerType.image,
      position: const Offset(-20, 30),
      width: 420,
      height: 540,
      originalUrl: momentPhotoOriginalSource,
      imageTemplate: 'free',
      imageZoom: 1.8,
      imageOffset: const Offset(12, -18),
      rotation: 8,
      scale: 1.2,
      canvasClip: const Rect.fromLTWH(10, 20, 350, 560),
    ),
    LayerModel(
      id: 'lettering',
      type: LayerType.text,
      position: const Offset(30, 490),
      width: 280,
      height: 60,
      text: '그날의 문장',
      zIndex: 1,
      textStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 28,
        letterSpacing: 1.5,
        shadows: [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 3)),
        ],
      ),
    ),
    LayerModel(
      id: 'paper',
      type: LayerType.decoration,
      position: const Offset(-35, 100),
      width: 80,
      height: 50,
      imageBackground: 'stickerTapeBeige',
      decorationBorderWidth: 3,
      decorationCornerRadius: .15,
      rotation: 30,
      zIndex: 2,
    ),
  ],
);

void main() {
  test(
    'new records use all five actual album formats in the existing v1 shape',
    () {
      for (final cover in coverSizes) {
        final design = newMomentPhotoDesign(
          photoSize: const Size(1200, 1800),
          cover: cover,
          photoSource: 'a-private-source',
        );
        expect(design.canvasSize, coverCanvasBaseSize(cover));
        expect(momentCoverForDesign(design), same(cover));
        expect(design.toJson().keys.toSet(), {
          'version',
          'canvas',
          'backgroundColor',
          'layers',
        });
        expect(design.toJson()['version'], 1);
        expect(
          jsonEncode(design.toJson()),
          isNot(contains('a-private-source')),
        );
        final photo = design.layersForPhoto('another-original').single;
        expect(photo.originalUrl, 'another-original');
        expect(photo.width / photo.height, closeTo(2 / 3, .000001));
        expect(photo.imageZoom, 1);
        expect(photo.imageOffset, isNull);
        expect(photo.rotation, 0);
      }
    },
  );

  test(
    'new portrait, landscape and panoramic photos fit completely and centrally',
    () {
      for (final size in const [
        Size(600, 1800),
        Size(1800, 600),
        Size(4000, 200),
      ]) {
        final design = newMomentPhotoDesign(
          photoSize: size,
          cover: coverSizes[1],
        );
        final canvas = design.canvasSize;
        final photo = design.layersForPhoto(momentPhotoOriginalSource).single;
        expect(photo.position.dx, greaterThanOrEqualTo(-.000001));
        expect(photo.position.dy, greaterThanOrEqualTo(-.000001));
        expect(
          photo.position.dx * 2 + photo.width,
          closeTo(canvas.width, .000001),
        );
        expect(
          photo.position.dy * 2 + photo.height,
          closeTo(canvas.height, .000001),
        );
        expect(photo.width / photo.height, closeTo(size.aspectRatio, .000001));
        expect(
          math.max(photo.width / canvas.width, photo.height / canvas.height),
          closeTo(1, .000001),
        );
      }
    },
  );

  test(
    'old canvases are never silently identified or rewritten as an official format',
    () {
      final design = _legacy();
      final before = design.toJson();
      expect(momentCoverForDesign(null), isNull);
      expect(momentCoverForDesign(design), isNull);
      expect(design.canvasSize, const Size(400, 600));
      expect(design.toJson(), before);
      final square = MomentPhotoDesign.fromLayers(
        canvasSize: const Size(500, 500),
        backgroundColor: Colors.white,
        layers: design.layersForPhoto(momentPhotoOriginalSource),
        photoSource: momentPhotoOriginalSource,
      );
      expect(momentCoverForDesign(square), isNull);
    },
  );

  test(
    'explicit format changes uniformly preserve crop, clipping, lettering and decoration',
    () {
      final source = _legacy();
      final before = source.toJson();
      final result = resizeMomentPhotoDesign(source, coverSizes[1]);
      final canvas = coverCanvasBaseSize(coverSizes[1]);
      final scale = canvas.height / 600;
      final origin = Offset((canvas.width - 400 * scale) / 2, 0);
      final layers = result.layersForPhoto(momentPhotoOriginalSource);
      final photo = layers[0];
      expect(result.canvasSize, canvas);
      expect(result.backgroundColor, source.backgroundColor);
      expect(photo.position.dx, closeTo(origin.dx - 20 * scale, .000001));
      expect(photo.position.dy, closeTo(30 * scale, .000001));
      expect(photo.width, closeTo(420 * scale, .000001));
      expect(photo.height, closeTo(540 * scale, .000001));
      expect(photo.imageZoom, 1.8);
      expect(photo.imageOffset!.dx, closeTo(12 * scale, .000001));
      expect(photo.imageOffset!.dy, closeTo(-18 * scale, .000001));
      expect(photo.rotation, 8);
      expect(photo.scale, 1.2);
      expect(photo.canvasClip!.left, closeTo(origin.dx + 10 * scale, .000001));
      expect(photo.canvasClip!.top, closeTo(20 * scale, .000001));
      expect(photo.canvasClip!.width, closeTo(350 * scale, .000001));
      expect(photo.canvasClip!.height, closeTo(560 * scale, .000001));
      final text = layers[1];
      expect(text.text, '그날의 문장');
      expect(text.textStyle!.fontFamily, 'NotoSans');
      expect(text.textStyle!.fontSize, closeTo(28 * scale, .000001));
      expect(text.textStyle!.letterSpacing, closeTo(1.5 * scale, .000001));
      expect(
        text.textStyle!.shadows!.single.blurRadius,
        closeTo(4 * scale, .000001),
      );
      expect(
        text.textStyle!.shadows!.single.offset.dy,
        closeTo(3 * scale, .000001),
      );
      expect(layers[2].decorationBorderWidth, closeTo(3 * scale, .000001));
      expect(layers[2].decorationCornerRadius, .15);
      expect(layers[2].rotation, 30);
      // Overflow that was hidden at the old canvas edge stays hidden in margins.
      expect(layers[2].position.dx, lessThan(layers[2].canvasClip!.left));
      expect(layers[2].canvasClip!.left, closeTo(origin.dx, .000001));
      expect(source.toJson(), before);
    },
  );

  test(
    'absolute decoration dimensions stay subpixel instead of turning into percentages',
    () {
      final source = MomentPhotoDesign.fromLayers(
        canvasSize: const Size(4000, 4000),
        backgroundColor: Colors.white,
        photoSource: momentPhotoOriginalSource,
        layers: [
          LayerModel(
            id: 'original',
            type: LayerType.image,
            position: Offset.zero,
            width: 4000,
            height: 4000,
            originalUrl: momentPhotoOriginalSource,
          ),
          LayerModel(
            id: 'paper',
            type: LayerType.decoration,
            position: const Offset(50, 50),
            width: 400,
            height: 300,
            imageBackground: 'stickerTapeBeige',
            decorationBorderWidth: 3,
            decorationCornerRadius: 4,
            decorationFillColor: '#FFFFFFFF',
            zIndex: 1,
          ),
        ],
      );
      final result = resizeMomentPhotoDesign(source, defaultCoverSize);
      final paper = result.layersForPhoto(momentPhotoOriginalSource)[1];
      final scale = result.canvasSize.width / 4000;
      final border = paper.decorationBorderWidth!;
      final radius = paper.decorationCornerRadius!;
      final borderPixels = border <= 1 ? border * paper.width : border;
      final radiusPixels = radius <= 1
          ? radius * math.min(paper.width, paper.height)
          : radius;
      expect(borderPixels, closeTo(3 * scale, .000001));
      expect(radiusPixels, closeTo(4 * scale, .000001));
    },
  );

  test(
    'choosing the current official size is lossless and does not add layers',
    () {
      final source = newMomentPhotoDesign(photoSize: const Size(1500, 1000));
      expect(resizeMomentPhotoDesign(source, defaultCoverSize), same(source));
      final resized = resizeMomentPhotoDesign(source, coverSizes[4]);
      expect(resized.layersForPhoto(momentPhotoOriginalSource), hasLength(1));
      expect(momentCoverForDesign(resized), same(coverSizes[4]));
    },
  );

  test(
    'formatting leaves original pixel dimensions and portable source intact',
    () {
      final photo = MomentPhoto(
        id: 'photo',
        path: 'owner/moments/record/photo.png',
        width: 900,
        height: 1600,
      );
      final formatted = photo.withDesign(
        newMomentPhotoDesign(photoSize: const Size(900, 1600)),
      );
      expect(photo.aspectRatio, 900 / 1600);
      expect(formatted.aspectRatio, 1);
      expect(formatted.width, 900);
      expect(formatted.height, 1600);
      expect(formatted.path, photo.path);
      expect(photo.design, isNull);
    },
  );
}

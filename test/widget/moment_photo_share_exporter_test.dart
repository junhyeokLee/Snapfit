import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/moments/data/moment_photo_share_exporter.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/social/data/social_album_snapshot.dart';

Uint8List _png(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

const _photo = MomentPhoto(
  id: 'selected-photo',
  path: 'owner/moments/record/selected-photo.png',
  url: 'https://expired.invalid/private.png?token=stale',
  width: 120,
  height: 80,
);

MomentPhotoDesign _design() => MomentPhotoDesign.fromLayers(
  canvasSize: const Size(200, 300),
  backgroundColor: const Color(0xFFF8EEDC),
  photoSource: _photo.storageUri,
  layers: [
    LayerModel(
      id: 'original',
      type: LayerType.image,
      position: const Offset(20, 20),
      width: 160,
      height: 200,
      imageTemplate: 'free',
      imageZoom: 1.5,
      imageOffset: const Offset(8, -4),
      canvasClip: const Rect.fromLTWH(10, 10, 180, 220),
      originalUrl: _photo.storageUri,
      previewUrl: _photo.storageUri,
      imageUrl: _photo.storageUri,
    ),
    LayerModel(
      id: 'note',
      type: LayerType.text,
      position: const Offset(20, 235),
      width: 150,
      height: 35,
      text: '오늘의 기록',
      textStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 20,
        color: Colors.black,
      ),
      zIndex: 1,
    ),
    LayerModel(
      id: 'star',
      type: LayerType.decoration,
      position: const Offset(145, 260),
      width: 35,
      height: 35,
      imageBackground: 'stickerBlueStar',
      zIndex: 2,
    ),
  ],
);

class _Renderer extends SocialSnapshotRenderer {
  _Renderer(this.result);
  Uint8List result;
  final events = <String>[];
  PrintAlbumPage? page;
  Completer<void>? fontsGate;
  Completer<Uint8List>? renderGate;
  Object? failure;

  @override
  Future<void> prepareFonts(Iterable<PrintAlbumPage> pages) async {
    events.add('fonts');
    page = pages.single;
    await fontsGate?.future;
  }

  @override
  Future<Uint8List> renderPage(
    PrintAlbumPage page, {
    required ThemeData theme,
    bool watermark = false,
  }) async {
    events.add('render');
    this.page = page;
    if (failure case final error?) throw error;
    return renderGate == null ? result : renderGate!.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'old originals share the exact default square composition with the full photo contained',
    () async {
      final renderer = _Renderer(_png(144, 144));
      final image = await MomentPhotoShareExporter(
        renderer: renderer,
      ).export(photo: _photo, theme: ThemeData.light());
      expect(renderer.events, ['fonts', 'render']);
      final page = renderer.page!;
      expect(page.isCover, isFalse);
      expect(page.canvasSize, coverCanvasBaseSize(defaultCoverSize));
      final layer = page.layers.single;
      expect(layer.width / layer.height, 1.5);
      expect(
        layer.position.dx * 2 + layer.width,
        closeTo(page.canvasSize.width, .000001),
      );
      expect(
        layer.position.dy * 2 + layer.height,
        closeTo(page.canvasSize.height, .000001),
      );
      expect(layer.originalUrl, _photo.storageUri);
      expect(layer.previewUrl, _photo.storageUri);
      expect(image.width, 144);
      expect(image.height, 144);
      expect(image.mimeType, 'image/png');
      expect(image.fileName, 'snapfit-moment.png');
      expect(_photo.design, isNull);
      expect(_photo.width, 120);
      expect(_photo.height, 80);
    },
  );

  test(
    'a selected legacy design preserves its exact artboard, crop, text and sticker without stale URLs',
    () async {
      final design = _design();
      final saved = design.toJson();
      final renderer = _Renderer(_png(200, 300));
      final image = await MomentPhotoShareExporter(
        renderer: renderer,
      ).export(photo: _photo.withDesign(design), theme: ThemeData.dark());
      final page = renderer.page!;
      expect(page.canvasSize, const Size(200, 300));
      expect(page.backgroundColor, design.backgroundColor);
      expect(page.layers, hasLength(3));
      final photo = page.layers[0];
      expect(photo.originalUrl, _photo.storageUri);
      expect(photo.imageOffset, const Offset(8, -4));
      expect(photo.imageZoom, 1.5);
      final clip = photo.canvasClip!;
      expect(clip.left, closeTo(10, .000001));
      expect(clip.top, closeTo(10, .000001));
      expect(clip.width, closeTo(180, .000001));
      expect(clip.height, closeTo(220, .000001));
      expect(page.layers[1].text, '오늘의 기록');
      expect(page.layers[1].textStyle!.fontFamily, 'NotoSans');
      expect(page.layers[2].imageBackground, 'stickerBlueStar');
      expect(image.aspectRatio, 2 / 3);
      expect(latin1.decode(image.bytes), isNot(contains('expired.invalid')));
      expect(latin1.decode(image.bytes), isNot(contains(_photo.path)));
      expect(design.toJson(), saved);
    },
  );

  test(
    'cancellation before preparation starts performs no rendering',
    () async {
      final renderer = _Renderer(_png(10, 10));
      await expectLater(
        MomentPhotoShareExporter(renderer: renderer).export(
          photo: _photo,
          theme: ThemeData.light(),
          isActive: () => false,
        ),
        throwsA(isA<MomentShareExportCancelled>()),
      );
      expect(renderer.events, isEmpty);
    },
  );

  test(
    'an owner change while fonts prepare prevents the image render',
    () async {
      final renderer = _Renderer(_png(10, 10))..fontsGate = Completer<void>();
      var active = true;
      final result = MomentPhotoShareExporter(
        renderer: renderer,
      ).export(photo: _photo, theme: ThemeData.light(), isActive: () => active);
      final checked = expectLater(
        result,
        throwsA(isA<MomentShareExportCancelled>()),
      );
      active = false;
      renderer.fontsGate!.complete();
      await checked;
      expect(renderer.events, ['fonts']);
    },
  );

  test(
    'cancelled in-flight pixels are not delivered and concurrent instances receive an explicit busy error',
    () async {
      final renderer = _Renderer(_png(10, 10))
        ..renderGate = Completer<Uint8List>();
      final exporter = MomentPhotoShareExporter(renderer: renderer);
      var active = true;
      final pending = exporter.export(
        photo: _photo,
        theme: ThemeData.light(),
        isActive: () => active,
      );
      final cancelled = expectLater(
        pending,
        throwsA(isA<MomentShareExportCancelled>()),
      );
      await Future<void>.delayed(Duration.zero);
      active = false;
      final second = _Renderer(_png(10, 10));
      await expectLater(
        MomentPhotoShareExporter(
          renderer: second,
        ).export(photo: _photo, theme: ThemeData.light()),
        throwsA(isA<MomentShareExportBusy>()),
      );
      expect(second.events, isEmpty);
      renderer.renderGate!.complete(renderer.result);
      await cancelled;
      final next = await MomentPhotoShareExporter(
        renderer: second,
      ).export(photo: _photo, theme: ThemeData.light());
      expect(next.width, 10);
    },
  );

  test(
    'render failures release the lock and do not reuse an earlier image',
    () async {
      final renderer = _Renderer(_png(10, 10))
        ..failure = StateError('pixel-load-failed');
      final exporter = MomentPhotoShareExporter(renderer: renderer);
      await expectLater(
        exporter.export(photo: _photo, theme: ThemeData.light()),
        throwsStateError,
      );
      renderer.failure = null;
      renderer.result = _png(20, 20);
      final next = await exporter.export(
        photo: _photo,
        theme: ThemeData.light(),
      );
      expect(next.width, 20);
      expect(next.height, 20);
    },
  );

  test(
    'one-pixel renderer rounding is normalized to the image size limit',
    () async {
      final image = await MomentPhotoShareExporter(
        renderer: _Renderer(_png(1441, 1441)),
      ).export(photo: _photo, theme: ThemeData.light());
      expect(image.width, MomentPhotoShareExporter.maximumOutputEdge);
      expect(image.height, MomentPhotoShareExporter.maximumOutputEdge);
    },
  );

  test(
    'malformed, oversized or stretched output is never passed to the share host',
    () async {
      for (final bytes in [
        Uint8List.fromList([1, 2, 3]),
        Uint8List(MomentPhotoShareExporter.maximumOutputBytes + 1),
        _png(1442, 1),
        _png(20, 40),
      ]) {
        await expectLater(
          MomentPhotoShareExporter(
            renderer: _Renderer(bytes),
          ).export(photo: _photo, theme: ThemeData.light()),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'actual export waits for original pixels and renders saved photo, font and sticker at bounded resolution',
    () async {
      final input = img.Image(width: 120, height: 80);
      img.fill(input, color: img.ColorRgb8(181, 51, 59));
      final bytes = Uint8List.fromList(img.encodePng(input));
      final sources = <String>[];
      final renderer = SocialSnapshotRenderer(
        loader: (source) async {
          sources.add(source);
          return bytes;
        },
      );
      final image = await MomentPhotoShareExporter(renderer: renderer).export(
        photo: _photo.withDesign(_design()),
        theme: ThemeData.light(),
        isActive: () => true,
      );
      expect(sources, [_photo.storageUri]);
      expect(image.width, 960);
      expect(image.height, 1440);
      expect(
        image.bytes.length,
        lessThanOrEqualTo(MomentPhotoShareExporter.maximumOutputBytes),
      );
      final codec = await ui.instantiateImageCodec(image.bytes);
      final pixels = (await codec.getNextFrame()).image;
      try {
        final rgba = (await pixels.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        Color at(int x, int y) {
          final offset = (y * image.width + x) * 4;
          return Color.fromARGB(
            rgba.getUint8(offset + 3),
            rgba.getUint8(offset),
            rgba.getUint8(offset + 1),
            rgba.getUint8(offset + 2),
          );
        }

        expect(at(5, 5).toARGB32(), const Color(0xFFF8EEDC).toARGB32());
        expect(
          at(480, 480).toARGB32(),
          const Color.fromARGB(255, 181, 51, 59).toARGB32(),
        );
        expect(at(780, 1332).toARGB32(), const Color(0xFF2E4FB2).toARGB32());
        var darkTextPixels = 0;
        for (var y = 1128; y < 1275; y += 2) {
          for (var x = 96; x < 760; x += 2) {
            final color = at(x, y);
            if (color.r < .2 && color.g < .2 && color.b < .2) darkTextPixels++;
          }
        }
        expect(darkTextPixels, greaterThan(80));
      } finally {
        pixels.dispose();
        codec.dispose();
      }
    },
  );
}

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/social/data/social_album_snapshot.dart';

const _source = 'memory:private-original-photo';

Album _photoAlbum() => Album(
  id: 86,
  userId: 'synthetic-owner',
  title: '사진이 담긴 저장 표지',
  ratio: '1:1',
  coverLayersJson: jsonEncode({
    'pages': [
      {
        'index': 0,
        'isCover': true,
        'backgroundColor': 0xffffffff,
        'layers': [
          {
            'id': 'saved-cover-photo',
            'type': 'IMAGE',
            'x': .1,
            'y': .1,
            'width': .8,
            'height': .8,
            'scale': 1,
            'zIndex': 0,
            'payload': {'originalUrl': _source},
          },
        ],
      },
    ],
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final jpeg in [false, true]) {
    test(
      'saved photo cover renders actual ${jpeg ? 'JPEG' : 'PNG'} pixels on this platform',
      () async {
        final source = img.Image(width: 2400, height: 1600);
        img.fill(source, color: img.ColorRgb8(71, 113, 92));
        final input = Uint8List.fromList(
          jpeg ? img.encodeJpg(source) : img.encodePng(source),
        );
        final album = _photoAlbum();
        final originalDocument = album.coverLayersJson;
        final snapshot = SocialAlbumSnapshot.fromAlbum(album);
        final requested = <String>[];
        final renderer = SocialSnapshotRenderer(
          loader: (source) async {
            requested.add(source);
            return input;
          },
        );

        final png = await renderer.renderPage(
          snapshot.pages.single,
          theme: ThemeData.light(),
        );

        expect(requested, [_source]);
        expect(album.coverLayersJson, originalDocument);
        expect(snapshot.pages.single.layers.single.originalUrl, _source);
        expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        expect(latin1.decode(png), isNot(contains(_source)));
        final codec = await ui.instantiateImageCodec(png);
        final image = (await codec.getNextFrame()).image;
        try {
          expect(image.height, 1440);
          expect(
            image.width / image.height,
            closeTo(snapshot.pages.single.canvasSize.aspectRatio, .002),
          );
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final pixels = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          final center =
              ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
          expect(pixels[center], closeTo(71, 4));
          expect(pixels[center + 1], closeTo(113, 4));
          expect(pixels[center + 2], closeTo(92, 4));
          expect(pixels[center + 3], 255);
        } finally {
          image.dispose();
          codec.dispose();
        }
      },
    );
  }
}

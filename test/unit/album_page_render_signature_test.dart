import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/album_page_render_signature.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';

void main() {
  final layer = LayerModel(
    id: 'photo',
    type: LayerType.image,
    position: Offset.zero,
    width: 200,
    height: 300,
    previewUrl: 'https://image.test/photo.jpg',
  );
  final page = AlbumPage(id: 'page', pageIndex: 1, layers: [layer]);

  test(
    'identical content does not invalidate the book on ordinary rebuilds',
    () {
      expect(
        albumPageRenderSignature(page.copyWith(layers: [layer.copyWith()])),
        albumPageRenderSignature(page),
      );
    },
  );

  test(
    'crop, frame, typography, photo and background changes invalidate cached page pixels',
    () {
      for (final updated in [
        layer.copyWith(imageZoom: 1.2),
        layer.copyWith(imageOffset: const Offset(30, -10)),
        layer.copyWith(imageBackground: 'circle'),
        layer.copyWith(textStyle: const TextStyle(fontSize: 20)),
        layer.copyWith(previewUrl: 'https://image.test/replaced.jpg'),
        layer.copyWith(decorationFillColor: '#112233'),
      ]) {
        expect(
          albumPageRenderSignature(page.copyWith(layers: [updated])),
          isNot(albumPageRenderSignature(page)),
        );
      }
      expect(
        albumPageRenderSignature(page.copyWith(backgroundColor: 0xFF112233)),
        isNot(albumPageRenderSignature(page)),
      );
    },
  );
}

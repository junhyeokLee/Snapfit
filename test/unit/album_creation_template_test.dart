import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';

void main() {
  test('separate cover precedes inner pages without duplication', () {
    final cover = {
      'layers': [
        {'id': 'cover'},
      ],
    };
    final inner = {
      'layers': [
        {'id': 'page1'},
      ],
    };
    expect(
      templateDocumentPages({
        'cover': cover,
        'pages': [inner],
      }),
      [cover, inner],
    );
    expect(
      templateDocumentPages({
        'cover': cover,
        'pages': [cover, inner],
      }),
      [cover, inner],
    );
    expect(
      templateDocumentPages({
        'pages': [cover, inner],
      }),
      [cover, inner],
    );
  });

  for (final cover in coverSizes) {
    test(
      '${cover.name} retains the whole design and removes sample photos',
      () {
        final size = coverCanvasBaseSize(cover);
        final original = LayerModel(
          id: 'photo',
          type: LayerType.image,
          position: Offset(size.width * .1, size.height * .2),
          width: size.width * .8,
          height: size.height * .5,
          rotation: .04,
          imageTemplate: 'free',
          imageBackground: 'polaroid',
          previewUrl: 'demo.jpg',
          originalUrl: 'demo-original.jpg',
        );
        final text = LayerModel(
          id: 'text',
          type: LayerType.text,
          position: const Offset(20, 30),
          text: 'Our days',
          textStyle: const TextStyle(fontSize: 18),
        );
        final sticker = LayerModel(
          id: 'sticker',
          type: LayerType.sticker,
          position: Offset.zero,
          imageUrl: 'art.png',
        );
        final result = AlbumCreationTemplate.preparePages(
          [
            [original, text, sticker],
          ],
          sourceCanvas: size,
          cover: cover,
        ).single;
        expect(result[0].previewUrl, isNull);
        expect(result[0].originalUrl, isNull);
        expect(result[0].position, original.position);
        expect(result[0].width, original.width);
        expect(result[0].height, original.height);
        expect(result[0].rotation, .04);
        expect(result[0].imageBackground, 'polaroid');
        expect(result[1].textStyle!.fontSize, 18);
        expect(result[2].imageUrl, 'art.png');
        expect(original.previewUrl, 'demo.jpg');
        expect(original.copyWith().previewUrl, 'demo.jpg');
      },
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/utils/text_shadow_codec.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';

void main() {
  test('photographic text shadows survive JSON save and canvas resize', () {
    final layers = DataTemplateEngine.buildLayersFromJson({
      'strictLayout': true,
      'designWidth': 500,
      'designHeight': 500,
      'layers': [
        {
          'id': 'cover-title',
          'type': 'text',
          'text': '여행의 결',
          'x': .1,
          'y': .1,
          'w': .8,
          'h': .2,
          'style': {
            'fontSize': 40,
            'color': '#FFF9EE',
            'shadows': [
              {
                'color': '#66000000',
                'blurRadius': 2,
                'offset': {'dx': 0, 'dy': 1},
              },
            ],
          },
        },
      ],
    }, const Size(250, 250));
    final text = layers.single;
    expect(text.textStyle!.shadows!.single.blurRadius, 1);
    expect(text.textStyle!.shadows!.single.offset, const Offset(0, .5));
    final saved = Map<String, dynamic>.from(
      jsonDecode(
            jsonEncode(
              LayerExportMapper.toJson(text, canvasSize: const Size(250, 250)),
            ),
          )
          as Map,
    );
    final restored = LayerExportMapper.fromJson(
      saved,
      canvasSize: const Size(500, 500),
    );
    final shadow = restored.textStyle!.shadows!.single;
    expect(shadow.color, const Color(0x66000000));
    expect(shadow.blurRadius, 2);
    expect(shadow.offset, const Offset(0, 1));
    expect(restored.textStyle!.fontSize, 40);
    expect(restored.text, text.text);
      final cover = defaultCoverSize;
    final target = coverCanvasBaseSize(cover);
    final prepared = AlbumCreationTemplate.preparePages(
      [
        [text],
      ],
      sourceCanvas: const Size(250, 250),
      cover: cover,
    ).single.single;
    final scale =
        (target.width < target.height ? target.width : target.height) / 250;
    expect(
      prepared.textStyle!.shadows!.single.blurRadius,
      closeTo(scale, .0001),
    );
    expect(
      prepared.textStyle!.shadows!.single.offset.dy,
      closeTo(.5 * scale, .0001),
    );
  });

  test('legacy text gains no shadow or new saved fields', () {
    final text = LayerModel(
      id: 'legacy',
      type: LayerType.text,
      position: Offset.zero,
      width: 100,
      height: 50,
      text: '원래 글씨',
      textStyle: const TextStyle(fontSize: 16),
    );
    final saved = LayerExportMapper.toJson(
      text,
      canvasSize: const Size(500, 500),
    );
    expect(
      ((saved['payload'] as Map)['textStyle'] as Map).containsKey('shadows'),
      isFalse,
    );
    expect(
      LayerExportMapper.fromJson(
        saved,
        canvasSize: const Size(500, 500),
      ).textStyle!.shadows,
      isNull,
    );
    expect(TextShadowCodec.decode(null), isNull);
  });

  test('invalid shadows cannot add malformed paint effects', () {
    expect(
      TextShadowCodec.decode([
        {'color': 'bad-color', 'blurRadius': 2},
        {'color': '#66000000', 'blurRadius': -1},
        {'color': '#66000000', 'blurRadius': double.infinity},
      ]),
      isNull,
    );
  });
}

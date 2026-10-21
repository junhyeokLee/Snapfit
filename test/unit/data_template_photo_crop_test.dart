import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';

const _original = 'https://example.test/print-original.jpg';
const _preview = 'https://example.test/screen-preview.jpg';

Map<String, dynamic> _layer({
  Map<String, dynamic> fields = const {},
  Map<String, dynamic> payload = const {},
}) => {
  'id': 'photo',
  'type': 'image',
  'x': .1,
  'y': .15,
  'w': .6,
  'h': .6,
  'imageUrl': 'asset:assets/sample.jpg',
  ...fields,
  'payload': payload,
};

LayerModel _build(
  Map<String, dynamic> layer, {
  Size canvas = const Size(500, 700),
  Map<String, dynamic> spec = const {},
}) => DataTemplateEngine.buildLayersFromJson({
  'strictLayout': true,
  'designWidth': 500,
  'designHeight': 700,
  ...spec,
  'layers': [layer],
}, canvas).single;

void _alignment(LayerModel layer, Alignment expected) {
  expect(layer.imageAlignment.x, closeTo(expected.x, 1e-9));
  expect(layer.imageAlignment.y, closeTo(expected.y, 1e-9));
}

void main() {
  for (final canvas in [
    const Size(500, 700),
    const Size(600, 600),
    const Size(1000, 500),
  ]) {
    test(
      'saved crop and print original survive the engine round trip $canvas',
      () {
        final source = LayerModel(
          id: 'saved-photo',
          type: LayerType.image,
          position: const Offset(50, 105),
          width: 300,
          height: 420,
          imageZoom: 2.3,
          imageOffset: const Offset(45, -63),
          imageBackground: 'archSoft',
          imageTemplate: '4:3',
          originalUrl: _original,
          previewUrl: _preview,
          imageUrl: _preview,
        );
        final saved =
            jsonDecode(
                  jsonEncode(
                    LayerExportMapper.toJson(
                      source,
                      canvasSize: const Size(500, 700),
                    ),
                  ),
                )
                as Map<String, dynamic>;
        final compiled = _build(saved, canvas: canvas);
        expect(compiled.imageZoom, 2.3);
        expect(compiled.imageBackground, 'archSoft');
        expect(compiled.imageTemplate, '4:3');
        expect(compiled.originalUrl, _original);
        expect(compiled.previewUrl, _preview);
        expect(compiled.imageUrl, _preview);
        _alignment(compiled, const Alignment(.3, .3));
        expect(compiled.imageOffset!.dx, closeTo(compiled.width * .15, 1e-9));
        expect(compiled.imageOffset!.dy, closeTo(compiled.height * -.15, 1e-9));

        final exported = LayerExportMapper.toJson(compiled, canvasSize: canvas);
        final restored = LayerExportMapper.fromJson(
          exported,
          canvasSize: canvas,
        );
        expect(restored.originalUrl, _original);
        expect(restored.previewUrl, _preview);
        expect(restored.imageZoom, 2.3);
        expect(restored.imageOffset, compiled.imageOffset);
        _alignment(restored, const Alignment(.3, .3));
      },
    );
  }

  test(
    'aspect-specific raw crop overrides saved payload before global scaling',
    () {
      final layer = _build(
        _layer(
          fields: {
            'aspectOverrides': {
              'landscape': {
                'imageZoom': 1.8,
                'imageOffsetRatio': {'x': -.2, 'y': .3},
                'previewUrl': 'https://example.test/wide-preview.jpg',
              },
            },
          },
          payload: {
            'imageZoom': 3.4,
            'imageOffsetRatio': {'x': .1, 'y': -.1},
            'originalUrl': _original,
            'previewUrl': _preview,
          },
        ),
        canvas: const Size(1000, 500),
        spec: {
          'variants': {
            'landscape': {'scale': .8, 'offsetX': .05, 'offsetY': -.03},
          },
        },
      );
      expect(layer.width, 480);
      expect(layer.height, 240);
      expect(layer.imageZoom, 1.8);
      expect(layer.imageOffset, const Offset(-96, 72));
      expect(layer.originalUrl, _original);
      expect(layer.previewUrl, 'https://example.test/wide-preview.jpg');
      _alignment(layer, const Alignment(-.4, -.6));
    },
  );

  for (final ratioCoordinates in [false, true]) {
    for (final keys in [('x', 'y'), ('dx', 'dy')]) {
      test(
        'legacy authored-pixel crop scales with the slot ratio=$ratioCoordinates $keys',
        () {
          final layer = _build(
            _layer(
              fields: {
                'x': ratioCoordinates ? .1 : 50,
                'y': ratioCoordinates ? .15 : 105,
                'w': ratioCoordinates ? .6 : 300,
                'h': ratioCoordinates ? .6 : 420,
                'imageOffset': {keys.$1: 30, keys.$2: -42},
                'imageZoom': 1.7,
              },
            ),
            canvas: const Size(1000, 350),
            spec: {
              'variants': {
                'landscape': {'scale': .8},
              },
            },
          );
          expect(layer.width, 480);
          expect(layer.height, 168);
          expect(layer.imageOffset, const Offset(48, -16.8));
          expect(layer.imageZoom, 1.7);
          _alignment(layer, const Alignment(.2, .2));
        },
      );
    }
  }

  test('payload legacy offset is read when no normalized crop exists', () {
    final layer = _build(
      _layer(
        payload: {
          'imageOffset': {'x': 30, 'y': -42},
          'imageZoom': 2,
        },
      ),
    );
    expect(layer.imageOffset, const Offset(30, -42));
    expect(layer.imageZoom, 2);
    _alignment(layer, const Alignment(.2, .2));
  });

  test('normalized offset takes precedence over legacy pixel offset', () {
    final layer = _build(
      _layer(
        fields: {
          'imageOffset': {'dx': 999, 'dy': 999},
        },
        payload: {
          'imageOffsetRatio': {'x': -.1, 'y': .2},
        },
      ),
    );
    expect(layer.imageOffset, const Offset(-30, 84));
    _alignment(layer, const Alignment(-.2, -.4));
  });

  for (final autoFit in [true, false]) {
    test(
      'automatic fitting and canvas clamp retain crop alignment fit=$autoFit',
      () {
        final layer = _build(
          _layer(
            fields: {'x': 0, 'y': 0, 'w': 1000, 'h': 500},
            payload: {
              'imageOffsetRatio': {'x': .2, 'y': -.1},
              'imageZoom': 2.1,
            },
          ),
          canvas: const Size(400, 400),
          spec: {
            'strictLayout': false,
            'autoFit': autoFit,
            'designWidth': 400,
            'designHeight': 400,
          },
        );
        expect(layer.width, 396);
        expect(layer.height, autoFit ? 200 : 396);
        expect(layer.imageZoom, 2.1);
        expect(layer.imageOffset!.dx, closeTo(layer.width * .2, 1e-9));
        expect(layer.imageOffset!.dy, closeTo(layer.height * -.1, 1e-9));
        _alignment(layer, const Alignment(.4, .2));
      },
    );
  }

  test('minimum slot enlargement preserves authored legacy crop alignment', () {
    final layer = _build(
      _layer(
        fields: {
          'w': .02,
          'h': .02,
          'imageOffset': {'x': 2, 'y': -2.8},
        },
      ),
    );
    expect(layer.width, 26);
    expect(layer.height, 26);
    expect(layer.imageOffset!.dx, closeTo(5.2, 1e-9));
    expect(layer.imageOffset!.dy, closeTo(-5.2, 1e-9));
    _alignment(layer, const Alignment(.4, .4));
  });

  test(
    'invalid normalized crops default to center instead of reviving legacy offsets',
    () {
      for (final invalid in [
        null,
        'bad',
        {},
        {'x': .1},
        {'x': '.1', 'y': .2},
        {'x': double.nan, 'y': .2},
        {'x': .1, 'y': double.infinity},
        {'x': 1e308, 'y': .2},
      ]) {
        final layer = _build(
          _layer(
            fields: {
              'imageOffset': {'x': 30, 'y': 42},
            },
            payload: {'imageOffsetRatio': invalid},
          ),
        );
        expect(layer.imageOffset, isNull, reason: '$invalid');
        expect(layer.imageAlignment, Alignment.center);
      }
    },
  );

  test('non-finite legacy offsets and invalid zoom are inert', () {
    for (final invalid in [
      null,
      '2',
      double.nan,
      double.infinity,
      -double.infinity,
    ]) {
      final layer = _build(
        _layer(
          payload: {
            'imageZoom': invalid,
            'imageOffset': {'dx': double.infinity, 'dy': 10},
          },
        ),
      );
      expect(layer.imageZoom, 1, reason: '$invalid');
      expect(layer.imageOffset, isNull);
    }
    for (final (raw, expected) in [(-10, 1), (0, 1), (1.6, 1.6), (8, 4)]) {
      expect(_build(_layer(fields: {'imageZoom': raw})).imageZoom, expected);
    }
    expect(
      _build(
        _layer(fields: {'imageZoom': null}, payload: {'imageZoom': 3}),
      ).imageZoom,
      1,
    );
  });

  for (final type in ['image', 'sticker']) {
    test('$type retains distinct original and preview source fields', () {
      final layer = _build(
        _layer(
          fields: {
            'type': type,
            'originalUrl': _original,
            'previewUrl': _preview,
            'imageUrl': 'https://example.test/legacy.jpg',
          },
        ),
      );
      expect(layer.originalUrl, _original);
      expect(layer.previewUrl, _preview);
      expect(layer.imageUrl, 'https://example.test/legacy.jpg');
    });
  }

  test(
    'empty preview falls back safely and a raw original alone remains printable',
    () {
      final layer = _build(
        _layer(
          fields: {'imageUrl': '', 'previewUrl': ' ', 'originalUrl': _original},
        ),
      );
      expect(layer.originalUrl, _original);
      expect(layer.previewUrl, isNull);
      expect(layer.imageUrl, _original);
    },
  );

  test('crop fields do not affect text, decorations or stickers', () {
    for (final type in ['text', 'decoration', 'sticker']) {
      final layer = _build(
        _layer(
          fields: {
            'type': type,
            if (type == 'decoration') 'style': 'plain',
            'text': '사진 설명',
            'imageZoom': 3.5,
            'imageOffsetRatio': {'x': .2, 'y': -.2},
          },
        ),
      );
      expect(layer.imageZoom, 1);
      expect(layer.imageOffset, isNull);
    }
  });

  test(
    'legacy templates without crop metadata retain their geometry and center',
    () {
      final layer = _build(_layer());
      expect(layer.position, const Offset(50, 105));
      expect(layer.width, 300);
      expect(layer.height, 420);
      expect(layer.imageUrl, 'asset:assets/sample.jpg');
      expect(layer.previewUrl, isNull);
      expect(layer.originalUrl, isNull);
      expect(layer.imageZoom, 1);
      expect(layer.imageOffset, isNull);
      expect(layer.imageAlignment, Alignment.center);
    },
  );
}

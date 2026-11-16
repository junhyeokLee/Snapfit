import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';

LayerModel _textLayer({
  String id = 'layer-1',
  Offset position = const Offset(10, 20),
  double width = 100,
  double height = 50,
  double scale = 1.0,
  double rotation = 0.0,
  String? text,
  TextAlign? textAlign,
  TextStyleType? textStyleType,
}) {
  return LayerModel(
    id: id,
    type: LayerType.text,
    position: position,
    text: text ?? 'Hello',
    width: width,
    height: height,
    scale: scale,
    rotation: rotation,
    textAlign: textAlign,
    textStyleType: textStyleType,
  );
}

void main() {
  const canvasSize = Size(400, 300);

  test(
    'artboard crop survives save, resize, copies and deliberate removal',
    () {
      const clip = Rect.fromLTWH(30, 10, 320, 250);
      final source = _textLayer().copyWith(canvasClip: clip);
      final json = LayerExportMapper.toJson(source, canvasSize: canvasSize);
      expect(json['canvasClip'], {
        'x': 30 / 400,
        'y': 10 / 300,
        'width': 320 / 400,
        'height': 250 / 300,
      });
      final restored = LayerExportMapper.fromJson(
        json,
        canvasSize: canvasSize * 2,
      );
      expect(restored.canvasClip, const Rect.fromLTWH(60, 20, 640, 500));
      expect(restored.copyWith(text: '이어서 편집').canvasClip, restored.canvasClip);
      expect(restored.copyWith(clearCanvasClip: true).canvasClip, isNull);
      final legacy = LayerExportMapper.toJson(
        _textLayer(),
        canvasSize: canvasSize,
      );
      expect(legacy.containsKey('canvasClip'), isFalse);
      expect(
        LayerExportMapper.fromJson(legacy, canvasSize: canvasSize).canvasClip,
        isNull,
      );
    },
  );

  test(
    'cover artboard crop follows the same spine conversion as its content',
    () {
      const editorCanvas = Size(500, 500);
      const clip = Rect.fromLTWH(38, 143, 438, 331);
      final json = LayerExportMapper.toJson(
        _textLayer().copyWith(canvasClip: clip),
        canvasSize: editorCanvas,
        isCover: true,
      );
      expect(
        LayerExportMapper.fromJson(
          json,
          canvasSize: editorCanvas,
          isCover: true,
        ).canvasClip,
        clip,
      );
      final document = PrintAlbumDocument.fromSnapshot({
        'album': {
          'ratio': '1',
          'cover_theme': 'classic',
          'cover_layers_json': {
            'pages': [
              {
                'index': 0,
                'isCover': true,
                'backgroundColor': 0xFFFFFFFF,
                'layers': [json],
              },
            ],
          },
        },
      });
      expect(
        document.cover.layers.single.canvasClip,
        const Rect.fromLTWH(24, 143, 438, 331),
      );
    },
  );

  test('malformed artboard crops fail before reaching the painter', () {
    for (final clip in [
      'invalid',
      {},
      {'x': 0, 'y': 0, 'width': 0, 'height': 1},
      {'x': 0, 'y': 0, 'width': 1, 'height': -1},
      {'x': double.nan, 'y': 0, 'width': 1, 'height': 1},
      {'x': double.maxFinite, 'y': 0, 'width': 1, 'height': 1},
      {'x': 0, 'y': 0, 'width': 1, 'height': 1, 'other': 'invalid'},
    ]) {
      final json = LayerExportMapper.toJson(
        _textLayer(),
        canvasSize: canvasSize,
      )..['canvasClip'] = clip;
      expect(
        () => LayerExportMapper.fromJson(json, canvasSize: canvasSize),
        throwsFormatException,
      );
    }
  });

  test(
    'example flags survive reopening and saving without becoming personal',
    () {
      for (final flag in ['isSample', 'isPlaceholder']) {
        for (final inPayload in [true, false]) {
          final json = LayerExportMapper.toJson(
            _textLayer(),
            canvasSize: canvasSize,
          );
          (inPayload ? json['payload'] as Map : json)[flag] = true;
          final restored = LayerExportMapper.fromJson(
            json,
            canvasSize: canvasSize,
          );
          expect(restored.isTemplateContent, isTrue);
          final saved = LayerExportMapper.toJson(
            restored,
            canvasSize: canvasSize,
          );
          expect(saved['templateContent'], isTrue);
          expect(
            LayerExportMapper.fromJson(
              saved,
              canvasSize: canvasSize,
            ).isTemplateContent,
            isTrue,
          );
          expect(
            restored.copyWith(text: '직접 작성한 기록').isTemplateContent,
            isFalse,
          );
        }
      }
    },
  );

  test('template, personal and unverified provenance survives round trips', () {
    for (final marker in [true, false, null]) {
      final source = LayerModel(
        id: 'provenance',
        type: LayerType.text,
        position: Offset.zero,
        text: '문구',
        isTemplateContent: marker,
      );
      final json = LayerExportMapper.toJson(source, canvasSize: canvasSize);
      expect(json.containsKey('templateContent'), marker != null);
      expect(json['templateContent'], marker);
      final restored = LayerExportMapper.fromJson(json, canvasSize: canvasSize);
      expect(restored.isTemplateContent, marker);
      expect(restored.copyWith(width: 200).isTemplateContent, marker);
    }
  });

  test('malformed legacy markers are never silently converted to personal', () {
    for (final marker in [null, 'false', 0, [], {}]) {
      final json = LayerExportMapper.toJson(
        _textLayer(),
        canvasSize: canvasSize,
      )..['templateContent'] = marker;
      final restored = LayerExportMapper.fromJson(json, canvasSize: canvasSize);
      expect(restored.isTemplateContent, isNull);
      expect(
        LayerExportMapper.toJson(
          restored,
          canvasSize: canvasSize,
        ).containsKey('templateContent'),
        isFalse,
      );
    }
  });

  group('LayerExportMapper.toJson', () {
    test('텍스트 레이어를 상대 좌표 JSON으로 변환', () {
      final layer = _textLayer(
        position: const Offset(100, 150),
        width: 80,
        height: 40,
      );
      final json = LayerExportMapper.toJson(layer, canvasSize: canvasSize);

      expect(json['type'], 'TEXT');
      expect(json['x'], 100 / 400);
      expect(json['y'], 150 / 300);
      expect(json['width'], 80 / 400);
      expect(json['height'], 40 / 300);
      expect(json['rotation'], 0.0);
      expect(json['payload'], isA<Map<String, dynamic>>());
      expect((json['payload'] as Map)['text'], 'Hello');
    });

    test('scale 반영된 width/height 저장', () {
      final layer = _textLayer(width: 50, height: 50, scale: 2.0);
      final json = LayerExportMapper.toJson(layer, canvasSize: canvasSize);

      expect(json['width'], 50 / 400);
      expect(json['height'], 50 / 300);
      expect(json['scale'], 2.0);
    });
  });

  group('LayerExportMapper.fromJson', () {
    test('JSON에서 레이어 복원 시 비율로 절대 좌표 계산', () {
      final json = {
        'type': 'TEXT',
        'x': 0.25,
        'y': 0.5,
        'width': 0.2,
        'height': 0.1,
        'rotation': 0.0,
        'payload': {
          'text': 'Hi',
          'textAlign': 'CENTER',
          'textStyleType': 'NONE',
          'textBackground': null,
          'bubbleColor': null,
          'imageUrl': null,
          'imageBackground': null,
        },
      };
      final layer = LayerExportMapper.fromJson(json, canvasSize: canvasSize);

      expect(layer.type, LayerType.text);
      expect(layer.position.dx, 400 * 0.25);
      expect(layer.position.dy, 300 * 0.5);
      expect(layer.width, 400 * 0.2);
      expect(layer.height, 300 * 0.1);
      expect(layer.text, 'Hi');
      expect(layer.scale, 1.0);
    });
  });

  group('round-trip', () {
    test(
      'photo crop survives resize and defaults safely for legacy payloads',
      () {
        final layer = LayerModel(
          id: 'crop',
          type: LayerType.image,
          position: Offset.zero,
          width: 160,
          height: 120,
          imageZoom: 2.4,
          imageOffset: const Offset(40, -20),
          imageBackground: 'circle',
        );
        final json = LayerExportMapper.toJson(layer, canvasSize: canvasSize);
        final restored = LayerExportMapper.fromJson(
          json,
          canvasSize: canvasSize * 2,
        );
        expect(restored.imageZoom, 2.4);
        expect(restored.imageOffset, const Offset(80, -40));
        expect(restored.imageAlignment, layer.imageAlignment);
        expect(restored.imageBackground, 'circle');
        final payload = json['payload'] as Map;
        for (final invalid in [null, double.nan, 'bad']) {
          payload['imageZoom'] = invalid;
          expect(
            LayerExportMapper.fromJson(json, canvasSize: canvasSize).imageZoom,
            1,
          );
        }
        payload['imageZoom'] = 8;
        expect(
          LayerExportMapper.fromJson(json, canvasSize: canvasSize).imageZoom,
          4,
        );
        expect(layer.copyWith(clearImage: true).imageZoom, 1);
        expect(layer.copyWith(clearImage: true).imageOffset, isNull);
        expect(layer.copyWith(clearImage: true).imageBackground, 'circle');
      },
    );
    test(
      'line height is dimensionless, preserved on resize and optional for old albums',
      () {
        final layer = _textLayer().copyWith(
          textStyle: const TextStyle(
            fontFamily: 'Eulyoo',
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.45,
          ),
        );
        final json = LayerExportMapper.toJson(layer, canvasSize: canvasSize);
        final restored = LayerExportMapper.fromJson(
          json,
          canvasSize: canvasSize * 2,
        );
        expect(restored.textStyle!.height, 1.45);
        expect(restored.textStyle!.fontSize, closeTo(56, .001));
        expect(restored.textStyle!.fontFamily, 'Eulyoo');
        expect(restored.textStyle!.fontWeight, FontWeight.w800);
        final style = (json['payload'] as Map)['textStyle'] as Map;
        for (final invalid in [null, 0, -1, double.nan, '1.3']) {
          style['height'] = invalid;
          expect(
            LayerExportMapper.fromJson(
              json,
              canvasSize: canvasSize,
            ).textStyle!.height,
            isNull,
          );
        }
        style.remove('height');
        expect(
          LayerExportMapper.fromJson(
            json,
            canvasSize: canvasSize,
          ).textStyle!.height,
          isNull,
        );
      },
    );

    test('toJson → fromJson 시 position, size, type 유지 (id 제외)', () {
      final layer = _textLayer(
        position: const Offset(50, 100),
        width: 120,
        height: 60,
        scale: 1.5,
        rotation: 0.1,
        text: 'Round',
      );
      final json = LayerExportMapper.toJson(layer, canvasSize: canvasSize);
      final restored = LayerExportMapper.fromJson(json, canvasSize: canvasSize);

      expect(restored.type, layer.type);
      expect(restored.position.dx, closeTo(layer.position.dx, 0.001));
      expect(restored.position.dy, closeTo(layer.position.dy, 0.001));
      expect(restored.width, closeTo(layer.width, 0.001));
      expect(restored.height, closeTo(layer.height, 0.001));
      expect(restored.scale, closeTo(layer.scale, 0.001));
      expect(restored.text, layer.text);
    });
  });
}

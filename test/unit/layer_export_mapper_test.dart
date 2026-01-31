import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';

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

  group('LayerExportMapper.toJson', () {
    test('텍스트 레이어를 상대 좌표 JSON으로 변환', () {
      final layer = _textLayer(position: const Offset(100, 150), width: 80, height: 40);
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

      expect(json['width'], (50 * 2) / 400);
      expect(json['height'], (50 * 2) / 300);
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
      expect(restored.width, closeTo(layer.width * layer.scale, 0.001));
      expect(restored.height, closeTo(layer.height * layer.scale, 0.001));
      expect(restored.text, layer.text);
    });
  });
}

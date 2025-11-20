import 'dart:ui';

import 'layer.dart';


class LayerDto {
  final String id;
  final String type;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  LayerDto({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
  });

  factory LayerDto.fromJson(Map<String, dynamic> json) {
    return LayerDto(
      id: json['id'] as String,
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      scale: (json['scale'] as num).toDouble(),
      rotation: (json['rotation'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
    };
  }

  /// DTO → Domain 변환
  LayerModel toEntity() {
    return LayerModel(
      id: id,
      type: type == 'image' ? LayerType.image : LayerType.text,
      position: Offset(x, y),
      scale: scale,
      rotation: rotation,
    );
  }

  /// Domain → DTO 변환
  factory LayerDto.fromEntity(LayerModel entity) {
    return LayerDto(
      id: entity.id,
      type: entity.type == LayerType.image ? 'image' : 'text',
      x: entity.position.dx,
      y: entity.position.dy,
      scale: entity.scale,
      rotation: entity.rotation,
    );
  }
}
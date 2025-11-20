// lib/features/album/data/models/album_page_dto.dart
import 'album_page.dart';
import 'layer_dto.dart';

class AlbumPageDto {
  final String id;
  final int index;
  final bool isCover;
  final List<LayerDto> layers;

  AlbumPageDto({
    required this.id,
    required this.index,
    required this.isCover,
    required this.layers,
  });

  factory AlbumPageDto.fromJson(Map<String, dynamic> json) {
    return AlbumPageDto(
      id: json['id'] as String,
      index: json['index'] as int,
      isCover: json['is_cover'] as bool? ?? false,
      layers: (json['layers'] as List<dynamic>)
          .map((e) => LayerDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'index': index,
      'is_cover': isCover,
      'layers': layers.map((e) => e.toJson()).toList(),
    };
  }

  AlbumPage toEntity() {
    return AlbumPage(
      id: id,
      pageIndex: index,
      isCover: isCover,
      layers: layers.map((e) => e.toEntity()).toList(),
    );
  }

  factory AlbumPageDto.fromEntity(AlbumPage entity) {
    return AlbumPageDto(
      id: entity.id,
      index: entity.pageIndex,
      isCover: entity.isCover,
      layers: entity.layers.map(LayerDto.fromEntity).toList(),
    );
  }
}
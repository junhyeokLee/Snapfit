// lib/features/album/data/models/album_dto.dart
import 'album_page.dart';
import 'album_page_dto.dart';
import 'album.dart';
import 'cover_size.dart';

class AlbumDto {
  final String id;
  final String title;
  final String createdAt;
  final String coverSize; // 'vertical' / 'horizontal' / 'square'
  final List<AlbumPageDto> pages;

  AlbumDto({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.coverSize,
    required this.pages,
  });

  factory AlbumDto.fromJson(Map<String, dynamic> json) {
    return AlbumDto(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: json['created_at'] as String,
      coverSize: json['cover_size'] as String,
      pages: (json['pages'] as List<dynamic>)
          .map((e) => AlbumPageDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt,
      'cover_size': coverSize,
      'pages': pages.map((e) => e.toJson()).toList(),
    };
  }

  /// 서버 문자열 → 도메인 CoverSize 매핑
  CoverSize _mapCoverSize() {
    switch (coverSize) {
      case 'vertical':
        return coverSizes[0]; // 세로형
      case 'horizontal':
        return coverSizes[1]; // 가로형
      case 'square':
        return coverSizes[2]; // 정사각형
      default:
        return coverSizes[0];
    }
  }

  Album toEntity() {
    return Album(
      albumId: id,
      title: title,
      createdAt: DateTime.parse(createdAt),
      coverSize: _mapCoverSize(),
      pages: pages.map<AlbumPage>((e) => e.toEntity()).toList(),
    );
  }

  factory AlbumDto.fromEntity(Album entity) {
    String _coverSizeToString(CoverSize size) {
      if (size.name == '세로형') return 'vertical';
      if (size.name == '가로형') return 'horizontal';
      return 'square';
    }

    return AlbumDto(
      id: entity.albumId,
      title: entity.title,
      createdAt: entity.createdAt.toIso8601String(),
      coverSize: _coverSizeToString(entity.coverSize),
      pages: entity.pages.map(AlbumPageDto.fromEntity).toList(),
    );
  }
}
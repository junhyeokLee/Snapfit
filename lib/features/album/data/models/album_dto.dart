// lib/features/album/data/models/album_dto.dart
import 'album_page.dart';
import 'album_page_dto.dart';

// lib/features/album/data/models/album_dto.dart
import 'album_page_dto.dart';

class AlbumDto {
  final String id;

  /// 커버 전체 레이어 상태 (Flutter 편집 결과 그대로)
  final String coverLayersJson;

  /// 커버 비율 (vertical / horizontal / square)
  final String coverRatio;

  final String createdAt;
  final String updatedAt;

  /// 상세 조회 시만 사용 (nullable)
  final List<AlbumPageDto>? pages;

  AlbumDto({
    required this.id,
    required this.coverLayersJson,
    required this.coverRatio,
    required this.createdAt,
    required this.updatedAt,
    this.pages,
  });

  factory AlbumDto.fromJson(Map<String, dynamic> json) {
    return AlbumDto(
      id: json['id'] as String,
      coverLayersJson: json['coverLayersJson'] as String,
      coverRatio: json['coverRatio'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      pages: json['pages'] == null
          ? null
          : (json['pages'] as List)
          .map((e) => AlbumPageDto.fromJson(e))
          .toList(),
    );
  }
}
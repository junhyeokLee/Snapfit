import 'package:snap_fit/features/album/domain/entities/album.dart';

/// 테스트용 Album fixture.
Album fakeAlbum({
  int id = 1,
  String coverLayersJson = '{}',
  String ratio = '0.75',
  String? coverImageUrl,
  String? coverThumbnailUrl,
  int totalPages = 1,
  String createdAt = '2025-01-01T00:00:00',
  String updatedAt = '2025-01-01T00:00:00',
}) {
  return Album(
    id: id,
    coverLayersJson: coverLayersJson,
    ratio: ratio,
    coverImageUrl: coverImageUrl,
    coverThumbnailUrl: coverThumbnailUrl,
    totalPages: totalPages,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

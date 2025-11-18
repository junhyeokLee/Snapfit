import 'album_page.dart';
import 'cover_size.dart';

class Album {
  final String albumId;
  final CoverSize coverSize;
  final List<AlbumPage> pages;
  final DateTime createdAt;
  final String title;

  Album({
    required this.albumId,
    required this.coverSize,
    required this.pages,
    required this.createdAt,
    required this.title,
  });
}
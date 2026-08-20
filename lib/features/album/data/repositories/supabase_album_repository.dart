import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/interceptors/token_storage.dart';
import '../../domain/entities/album.dart';
import '../../domain/repositories/album_repository.dart';
import '../dto/request/create_album_request.dart';

class SupabaseAlbumRepository implements AlbumRepository {
  SupabaseAlbumRepository(this.client, {required this.tokenStorage});

  final SupabaseClient client;
  final TokenStorage tokenStorage;

  Future<String> _userId() async {
    final id = await tokenStorage.getResolvedUserId();
    if (id == null || id.trim().isEmpty) {
      throw Exception('로그인이 만료되었습니다. 다시 로그인 후 시도해주세요.');
    }
    return id.trim();
  }

  @override
  Future<Album> createAlbum(CreateAlbumRequest request) async {
    final userId = await _userId();
    final row = await client
        .from('albums')
        .insert({
          'owner_id': userId,
          'title': request.title,
          'ratio': request.ratio,
          'cover_layers_json': request.coverLayersJson,
          'cover_image_url': request.coverImageUrl,
          'cover_thumbnail_url': request.coverThumbnailUrl,
          'cover_original_url': request.coverOriginalUrl,
          'cover_preview_url': request.coverPreviewUrl,
          'cover_theme': request.coverTheme,
          'target_pages': request.targetPages,
        })
        .select()
        .single();
    return _fromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<Album> updateAlbum(int albumId, CreateAlbumRequest request) async {
    final userId = await _userId();
    final row = await client
        .from('albums')
        .update({
          'title': request.title,
          'ratio': request.ratio,
          'cover_layers_json': request.coverLayersJson,
          'cover_image_url': request.coverImageUrl,
          'cover_thumbnail_url': request.coverThumbnailUrl,
          'cover_original_url': request.coverOriginalUrl,
          'cover_preview_url': request.coverPreviewUrl,
          'cover_theme': request.coverTheme,
          'target_pages': request.targetPages,
        })
        .eq('id', albumId)
        .eq('owner_id', userId)
        .select()
        .single();
    return _fromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<Album> fetchAlbum(String albumId) async {
    final row = await client.from('albums').select().eq('id', albumId).single();
    return _fromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<Album>> fetchMyAlbums() async {
    final userId = await _userId();
    final rows = await client
        .from('albums')
        .select()
        .eq('owner_id', userId)
        .order('sort_order')
        .order('updated_at', ascending: false);
    return rows
        .map<Album>((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<void> deleteAlbum(int albumId) async {
    final userId = await _userId();
    await client
        .from('albums')
        .delete()
        .eq('id', albumId)
        .eq('owner_id', userId);
  }

  @override
  Future<void> reorderAlbums(List<int> albumIds) async {
    final userId = await _userId();
    for (var i = 0; i < albumIds.length; i++) {
      await client
          .from('albums')
          .update({'sort_order': i})
          .eq('id', albumIds[i])
          .eq('owner_id', userId);
    }
  }

  @override
  Future<void> lockAlbum(int albumId) async {
    final userId = await _userId();
    await client
        .from('albums')
        .update({'locked_by_id': userId})
        .eq('id', albumId);
  }

  @override
  Future<void> unlockAlbum(int albumId) async {
    final userId = await _userId();
    await client
        .from('albums')
        .update({'locked_by_id': null, 'locked_by': null})
        .eq('id', albumId)
        .eq('locked_by_id', userId);
  }

  Album _fromRow(Map<String, dynamic> row) => Album.fromJson({
    'albumId': row['id'],
    'coverLayersJson': row['cover_layers_json']?.toString() ?? '',
    'ratio': row['ratio']?.toString() ?? '',
    'title': row['title']?.toString() ?? '',
    'coverImageUrl': row['cover_image_url'],
    'coverThumbnailUrl': row['cover_thumbnail_url'],
    'coverOriginalUrl': row['cover_original_url'],
    'coverPreviewUrl': row['cover_preview_url'],
    'coverTheme': row['cover_theme'],
    'totalPages': row['total_pages'],
    'targetPages': row['target_pages'],
    'orders': row['sort_order'],
    'lockedBy': row['locked_by'],
    'lockedById': row['locked_by_id']?.toString(),
    'userId': row['owner_id']?.toString() ?? '',
    'createdAt': row['created_at']?.toString() ?? '',
    'updatedAt': row['updated_at']?.toString() ?? '',
  });
}

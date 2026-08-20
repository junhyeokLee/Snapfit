import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/interceptors/token_storage.dart';
import '../../../album/domain/entities/album.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/entities/template_summary_page.dart';
import '../../domain/repositories/template_repository.dart';

class SupabaseTemplateRepository implements TemplateRepository {
  SupabaseTemplateRepository(this.client, {required this.tokenStorage});

  final SupabaseClient client;
  final TokenStorage tokenStorage;

  Future<String> _userId() async {
    return (await tokenStorage.getResolvedUserId())?.trim() ?? '';
  }

  PremiumTemplate _fromRow(Map<String, dynamic> row, {bool isLiked = false}) {
    final likeCount =
        (row['like_count'] as num?)?.toInt() ??
        (row['template_likes'] is List
            ? (row['template_likes'] as List).length
            : 0);
    final previewRaw = row['preview_images'];
    final tagsRaw = row['tags'];
    final newUntil = DateTime.tryParse(row['new_until']?.toString() ?? '');
    return PremiumTemplate(
      id: (row['id'] as num?)?.toInt() ?? -1,
      title: row['title']?.toString() ?? '',
      subTitle: row['sub_title']?.toString(),
      description: row['description']?.toString(),
      coverImageUrl: row['cover_image_url']?.toString() ?? '',
      previewImages: previewRaw is List
          ? previewRaw
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      pageCount: (row['page_count'] as num?)?.toInt() ?? 0,
      likeCount: likeCount,
      userCount: (row['user_count'] as num?)?.toInt() ?? 0,
      category: row['category']?.toString(),
      tags: tagsRaw is List
          ? tagsRaw.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      weeklyScore: (row['weekly_score'] as num?)?.toInt() ?? 0,
      isNew:
          row['is_new'] == true ||
          (newUntil != null && newUntil.isAfter(DateTime.now())),
      isBest: row['is_best'] == true,
      isPremium: row['is_premium'] == true,
      isLiked: isLiked,
      templateJson: row['template_json']?.toString(),
      createdAt: row['created_at']?.toString(),
    );
  }

  @override
  Future<List<PremiumTemplate>> getTemplates() async {
    final userId = await _userId();
    final rows = await client
        .from('templates')
        .select('*, template_likes(user_id)')
        .eq('is_active', true)
        .order('weekly_score', ascending: false)
        .order('created_at', ascending: false);
    return rows
        .map<PremiumTemplate>((row) {
          final likes = row['template_likes'];
          final isLiked =
              userId.isNotEmpty &&
              likes is List &&
              likes.any(
                (like) => like is Map && like['user_id']?.toString() == userId,
              );
          return _fromRow(Map<String, dynamic>.from(row), isLiked: isLiked);
        })
        .toList(growable: false);
  }

  @override
  Future<TemplateSummaryPage> getTemplateSummaries({
    int page = 0,
    int size = 20,
  }) async {
    final all = await getTemplates();
    final start = (page * size).clamp(0, all.length).toInt();
    final end = (start + size).clamp(0, all.length).toInt();
    final content = all.sublist(start, end);
    return TemplateSummaryPage(
      content: content,
      page: page,
      size: size,
      totalPages: size <= 0 ? 0 : ((all.length + size - 1) ~/ size),
      totalElements: all.length,
      hasNext: end < all.length,
    );
  }

  @override
  Future<PremiumTemplate> getTemplate(int id) async {
    final userId = await _userId();
    final row = await client
        .from('templates')
        .select('*, template_likes(user_id)')
        .eq('id', id)
        .single();
    final likes = row['template_likes'];
    final isLiked =
        userId.isNotEmpty &&
        likes is List &&
        likes.any(
          (like) => like is Map && like['user_id']?.toString() == userId,
        );
    return _fromRow(Map<String, dynamic>.from(row), isLiked: isLiked);
  }

  @override
  Future<void> likeTemplate(int id) async {
    final userId = await _userId();
    if (userId.isEmpty) throw Exception('로그인이 필요합니다.');
    final existing = await client
        .from('template_likes')
        .select('template_id')
        .eq('template_id', id)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing == null) {
      await client.from('template_likes').insert({
        'template_id': id,
        'user_id': userId,
      });
    } else {
      await client
          .from('template_likes')
          .delete()
          .eq('template_id', id)
          .eq('user_id', userId);
    }
  }

  @override
  Future<Album> createAlbumFromTemplate(
    int id, {
    Map<String, String>? replacements,
  }) async {
    final userId = await _userId();
    if (userId.isEmpty) throw Exception('로그인이 필요합니다.');
    final template = await getTemplate(id);
    final inserted = await client
        .from('albums')
        .insert({
          'owner_id': userId,
          'title': template.title,
          'ratio': '1:1',
          'cover_image_url': template.coverImageUrl,
          'cover_preview_url': template.coverImageUrl,
          'total_pages': template.pageCount,
          'target_pages': template.pageCount,
          'cover_layers_json': template.templateJson ?? '',
        })
        .select()
        .single();
    await client
        .from('templates')
        .update({'user_count': template.userCount + 1})
        .eq('id', id);
    return Album.fromJson(_albumRowToJson(Map<String, dynamic>.from(inserted)));
  }

  Map<String, dynamic> _albumRowToJson(Map<String, dynamic> row) => {
    'albumId': row['id'],
    'userId': row['owner_id']?.toString() ?? '',
    'title': row['title']?.toString() ?? '',
    'ratio': row['ratio']?.toString() ?? '',
    'coverLayersJson': row['cover_layers_json']?.toString() ?? '',
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
    'createdAt': row['created_at']?.toString() ?? '',
    'updatedAt': row['updated_at']?.toString() ?? '',
  };
}

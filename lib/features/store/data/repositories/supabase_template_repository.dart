import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/interceptors/token_storage.dart';
import '../../../../core/templates/retired_store_templates.dart';
import '../../../album/domain/entities/album.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/entities/template_summary_page.dart';
import '../../domain/repositories/template_repository.dart';

typedef _SummaryQuery = ({
  int page,
  int size,
  String? category,
  String? query,
  bool? isPaid,
});

class SupabaseTemplateRepository
    implements TemplateRepository, TemplateSessionSource {
  SupabaseTemplateRepository(this.client, {required this.tokenStorage});

  final SupabaseClient client;
  final TokenStorage tokenStorage;

  @override
  String? get currentTemplateUserId => client.auth.currentUser?.id;

  @override
  Stream<String?> get templateUserChanges => client.auth.onAuthStateChange
      .map((event) => event.session?.user.id)
      .distinct();

  // Browse and search own separate feed state, but can await the same read.
  // Retain only pending requests, with a fixed limit on tracked query keys.
  static const _maxSharedSummaryRequests = 32;
  final _summaryRequests = <_SummaryQuery, Future<TemplateSummaryPage>>{};
  Session? _summarySession;
  String? _summaryUserId;

  void _clearSummaryRequests() {
    _summaryRequests.clear();
    _summarySession = null;
    _summaryUserId = null;
  }

  Future<String> _userId() async {
    return client.auth.currentUser?.id.trim() ?? '';
  }

  String? _document(Map<String, dynamic> row) {
    final document = row['template_json'];
    return document is String || document == null
        ? document as String?
        : jsonEncode(document);
  }

  bool _retiredRow(Map<String, dynamic> row) => RetiredStoreTemplates.matches(
    id: (row['id'] as num?)?.toInt(),
    title: row['title']?.toString(),
    templateId: row['template_id']?.toString(),
    templateJson: _document(row),
  );

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
      templateJson: _document(row),
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
        .where((row) => !_retiredRow(Map<String, dynamic>.from(row)))
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
    String? category,
    String? query,
    bool? isPaid,
  }) {
    final session = client.auth.currentSession;
    final userId = client.auth.currentUser?.id.trim() ?? '';
    // A restored/refreshed session must not join work from an earlier login,
    // even when the account ID (or token contents) happens to be the same.
    if (!identical(session, _summarySession) || userId != _summaryUserId) {
      _clearSummaryRequests();
      _summarySession = session;
      _summaryUserId = userId;
    }
    final key = (
      page: page,
      size: size,
      category: category == null || category.isEmpty || category == '전체'
          ? null
          : category,
      query: query == null || query.isEmpty ? null : query,
      isPaid: isPaid,
    );
    final pending = _summaryRequests[key];
    if (pending != null) return pending;

    late final Future<TemplateSummaryPage> request;
    request = _fetchTemplateSummaries(key, userId: userId).whenComplete(() {
      // An older completion cannot remove a newer request after an account
      // change or a write invalidated sharing. Errors release the entry too.
      if (identical(_summaryRequests[key], request)) {
        _summaryRequests.remove(key);
        if (_summaryRequests.isEmpty) _clearSummaryRequests();
      }
    });
    if (_summaryRequests.length < _maxSharedSummaryRequests) {
      _summaryRequests[key] = request;
    }
    return request;
  }

  Future<TemplateSummaryPage> _fetchTemplateSummaries(
    _SummaryQuery key, {
    required String userId,
  }) async {
    final (:page, :size, :category, :query, :isPaid) = key;
    final from = page * size;
    final to = from + size - 1;

    // Build the query with server-side filtering — avoids fetching all rows.
    var q = client
        .from('templates')
        .select('*, template_likes(user_id)')
        .eq('is_active', true);

    if (category != null && category.isNotEmpty && category != '전체') {
      q = q.eq('category', category);
    }
    if (query != null && query.isNotEmpty) {
      q = q.ilike('title', '%$query%');
    }
    if (isPaid != null) {
      q = q.eq('is_premium', isPaid);
    }

    final rows = await q
        .order('weekly_score', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);

    // Sharing must not let one consumer replace rows seen by another feed.
    final content = List<PremiumTemplate>.unmodifiable(
      rows.where((row) => !_retiredRow(Map<String, dynamic>.from(row))).map((
        row,
      ) {
        final likes = row['template_likes'];
        final isLiked =
            userId.isNotEmpty &&
            likes is List &&
            likes.any(
              (like) => like is Map && like['user_id']?.toString() == userId,
            );
        return _fromRow(Map<String, dynamic>.from(row), isLiked: isLiked);
      }),
    );

    // hasNext: if we got a full page there are likely more items.
    // A separate count query is only needed when displaying total pages UI.
    // A page containing retired rows may still precede valid later rows.
    final hasNext = rows.length >= size;
    final estimatedTotal = hasNext
        ? from + content.length + 1
        : from + content.length;
    final totalPages = size <= 0 ? 0 : ((estimatedTotal + size - 1) ~/ size);

    return TemplateSummaryPage(
      content: content,
      page: page,
      size: size,
      totalPages: totalPages,
      totalElements: estimatedTotal,
      hasNext: hasNext,
    );
  }

  @override
  Future<PremiumTemplate> getTemplate(int id) async {
    if (RetiredStoreTemplates.matches(id: id)) {
      throw StateError('retired_store_template');
    }
    final userId = await _userId();
    final row = await client
        .from('templates')
        .select('*, template_likes(user_id)')
        .eq('id', id)
        .eq('is_active', true)
        .single();
    if (_retiredRow(Map<String, dynamic>.from(row))) {
      throw StateError('retired_store_template');
    }
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
    if (RetiredStoreTemplates.matches(id: id)) {
      throw StateError('retired_store_template');
    }
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
    // A refresh after changing a like must not join a pre-write snapshot.
    _clearSummaryRequests();
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
    await client.rpc(
      'increment_template_user_count',
      params: {'p_template_id': id},
    );
    _clearSummaryRequests();
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

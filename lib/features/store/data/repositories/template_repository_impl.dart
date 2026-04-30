import '../../domain/repositories/template_repository.dart';
import '../../../album/domain/entities/album.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/entities/template_summary_page.dart';
import '../api/template_api.dart';
import '../../../../core/interceptors/token_storage.dart';

class TemplateRepositoryImpl implements TemplateRepository {
  final TemplateApi api;
  final TokenStorage tokenStorage;

  TemplateRepositoryImpl(this.api, {required this.tokenStorage});

  Future<String> _getUserId() async {
    final id = await tokenStorage.getResolvedUserId();
    return id ?? '';
  }

  String? _normalizeCategory(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return value;
    switch (value.toLowerCase()) {
      case 'travel':
        return '여행';
      case 'wedding':
        return '웨딩';
      case 'kids':
      case 'kid':
        return '키즈';
      case 'poster':
        return '포스터';
      case 'brand':
        return '브랜드';
      case 'romance':
      case 'romantic':
        return '로맨스';
      case 'magazine':
        return '매거진';
      case 'family':
        return '가족';
      case 'graduation':
        return '졸업';
      case 'retro':
        return '레트로';
      case 'general':
      case 'default':
        return '일반';
      default:
        return value;
    }
  }

  @override
  Future<List<PremiumTemplate>> getTemplates() async {
    final userId = await _getUserId();
    return api.getTemplates(userId.isEmpty ? null : userId);
  }

  @override
  Future<TemplateSummaryPage> getTemplateSummaries({
    int page = 0,
    int size = 20,
  }) async {
    final userId = await _getUserId();
    final response = await api.getTemplateSummaries(
      userId.isEmpty ? null : userId,
      page,
      size,
    );
    final raw = response is Map
        ? Map<String, dynamic>.from(response)
        : const {};

    final contentRaw = raw['content'];
    final content = <PremiumTemplate>[];
    if (contentRaw is List) {
      for (final item in contentRaw) {
        if (item is! Map<String, dynamic>) continue;
        final tagsRaw = item['tags'];
        final tags = tagsRaw is List
            ? tagsRaw.map((e) => e.toString()).toList(growable: false)
            : const <String>[];
        final previewRaw = item['previewImages'];
        final previewImages = previewRaw is List
            ? previewRaw
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toList(growable: false)
            : const <String>[];
        content.add(
          PremiumTemplate(
            id: (item['id'] as num?)?.toInt() ?? -1,
            title: (item['title'] ?? '').toString(),
            subTitle: (item['subTitle'] ?? item['subtitle'])?.toString(),
            description: (item['description'])?.toString(),
            coverImageUrl: (item['coverImageUrl'] ?? '').toString(),
            previewImages: previewImages,
            pageCount: (item['pageCount'] as num?)?.toInt() ?? 0,
            likeCount: (item['likeCount'] as num?)?.toInt() ?? 0,
            userCount: (item['userCount'] as num?)?.toInt() ?? 0,
            category: _normalizeCategory((item['category'])?.toString()),
            tags: tags,
            weeklyScore: (item['weeklyScore'] as num?)?.toInt() ?? 0,
            isPremium: item['isPremium'] == true,
            isBest: item['isBest'] == true,
            isNew: item['isNew'] == true,
            isLiked: item['isLiked'] == true,
            templateJson: (item['templateJson'])?.toString(),
            createdAt:
                (item['createdAt'] ??
                        item['created_at'] ??
                        item['registeredAt'] ??
                        item['registered_at'])
                    ?.toString(),
          ),
        );
      }
    }

    return TemplateSummaryPage(
      content: content,
      page: (raw['page'] as num?)?.toInt() ?? page,
      size: (raw['size'] as num?)?.toInt() ?? size,
      totalPages: (raw['totalPages'] as num?)?.toInt() ?? 0,
      totalElements: (raw['totalElements'] as num?)?.toInt() ?? 0,
      hasNext: raw['hasNext'] == true,
    );
  }

  @override
  Future<PremiumTemplate> getTemplate(int id) async {
    final userId = await _getUserId();
    return api.getTemplate(id, userId.isEmpty ? null : userId);
  }

  @override
  Future<void> likeTemplate(int id) async {
    final userId = await _getUserId();
    if (userId.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    await api.likeTemplate(id, userId);
  }

  @override
  Future<Album> createAlbumFromTemplate(
    int id, {
    Map<String, String>? replacements,
  }) async {
    final userId = await _getUserId();
    return api.createAlbumFromTemplate(id, userId, replacements);
  }
}

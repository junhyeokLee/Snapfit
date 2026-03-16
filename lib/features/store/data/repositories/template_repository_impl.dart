import '../../domain/repositories/template_repository.dart';
import '../../../album/domain/entities/album.dart';
import '../../domain/entities/premium_template.dart';
import '../api/template_api.dart';
import '../../../../core/interceptors/token_storage.dart';

class TemplateRepositoryImpl implements TemplateRepository {
  final TemplateApi api;
  final TokenStorage tokenStorage;

  TemplateRepositoryImpl(this.api, {required this.tokenStorage});

  Future<String> _getUserId() async {
    final id = await tokenStorage.getUserId();
    return id ?? '';
  }

  @override
  Future<List<PremiumTemplate>> getTemplates() async {
    final userId = await _getUserId();
    return api.getTemplates(userId.isEmpty ? null : userId);
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

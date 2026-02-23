import '../../../album/domain/entities/album.dart';
import '../../domain/entities/premium_template.dart';

abstract class TemplateRepository {
  Future<List<PremiumTemplate>> getTemplates();
  Future<PremiumTemplate> getTemplate(int id);
  Future<void> likeTemplate(int id);
  Future<Album> createAlbumFromTemplate(int id, {Map<String, String>? replacements});
}

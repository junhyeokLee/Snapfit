import '../../../album/domain/entities/album.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/entities/template_summary_page.dart';

abstract class TemplateRepository {
  Future<List<PremiumTemplate>> getTemplates();
  Future<TemplateSummaryPage> getTemplateSummaries({
    int page = 0,
    int size = 20,
  });
  Future<PremiumTemplate> getTemplate(int id);
  Future<void> likeTemplate(int id);
  Future<Album> createAlbumFromTemplate(
    int id, {
    Map<String, String>? replacements,
  });
}

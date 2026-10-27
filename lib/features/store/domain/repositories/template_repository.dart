import '../../../album/domain/entities/album.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/entities/template_summary_page.dart';

/// Optional identity source for repositories serving account-specific metadata.
abstract interface class TemplateSessionSource {
  String? get currentTemplateUserId;
  Stream<String?> get templateUserChanges;
}

abstract class TemplateRepository {
  Future<List<PremiumTemplate>> getTemplates();
  Future<TemplateSummaryPage> getTemplateSummaries({
    int page = 0,
    int size = 20,
    String? category,
    String? query,
    bool? isPaid,
  });
  Future<PremiumTemplate> getTemplate(int id);
  Future<void> likeTemplate(int id);
  Future<Album> createAlbumFromTemplate(
    int id, {
    Map<String, String>? replacements,
  });
}

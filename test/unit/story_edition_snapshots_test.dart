import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/data/catalog_preview.dart';
import 'package:snap_fit/core/templates/story_edition_catalog.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/presentation/utils/template_detail_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    '65 story books load exported previews and detail assets; preview LRU stays bounded',
    () async {
      CatalogPreviews.clearCache();
      addTearDown(CatalogPreviews.clearCache);
      final templates = storyEditions
          .map(
            (e) => publishedCreationTemplates.singleWhere(
              (t) => t.id == e.catalogId,
            ),
          )
          .toList();
      for (final t in templates) {
        final preview = await CatalogPreviews.request(t);
        expect(preview, isNotNull, reason: t.title);
        expect(preview!.profile.innerPageCount, 24);
        expect(preview.cover, isNotEmpty);
        expect(preview.spread, hasLength(2));
        final request = TemplateDetailDocuments.acquire(t);
        try {
          final detail = await request.future;
          expect(detail, isNotNull, reason: t.title);
        } finally {
          request.cancel();
        }
      }
      expect(
        CatalogPreviews.acquireCached(templates.first),
        isNull,
        reason: 'First preview must leave the 18-entry LRU after 65 books',
      );
      final last = CatalogPreviews.acquireCached(templates.last);
      expect(last, isNotNull);
      last!.release();
      CatalogPreviews.clearCache();
      expect(CatalogPreviews.acquireCached(templates.last), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/data/catalog_preview.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/published_premium_templates.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/widgets/catalog_edition_artwork.dart';

PremiumTemplate _template(int id, {String Function()? document}) =>
    PremiumTemplate(
      id: id,
      title: 'Metadata only',
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 24,
      userCount: 0,
      documentBuilder: document,
    );

class _ReadCountCatalog extends ListBase<PremiumTemplate> {
  _ReadCountCatalog(this.items);
  final List<PremiumTemplate> items;
  int reads = 0;
  @override
  int get length => items.length;
  @override
  set length(int value) => throw UnsupportedError('Immutable catalog');
  @override
  PremiumTemplate operator [](int index) {
    reads++;
    return items[index];
  }

  @override
  void operator []=(int index, PremiumTemplate value) =>
      throw UnsupportedError('Immutable catalog');
}

void main() {
  test(
    'unchanged favorite metadata retains existing template artwork identity',
    () {
      final result = withBundledCreationTemplates([
        for (final template in publishedCreationTemplates)
          template.copyWith(
            title: 'Stale title',
            isPremium: !template.isPremium,
          ),
      ]);
      for (var i = 0; i < result.length; i++) {
        expect(result[i], same(publishedCreationTemplates[i]));
      }
    },
  );
  test(
    'refresh reads each source row only once, including a large legacy tail',
    () {
      final source = _ReadCountCatalog([
        for (var id = 100000; id < 102000; id++) _template(id),
        ...publishedCreationTemplates.reversed,
      ]);
      final result = withBundledCreationTemplates(source);
      expect(
        result.map((t) => t.id),
        publishedCreationTemplates.map((t) => t.id),
      );
      expect(source.reads, source.length);
    },
  );
  test(
    'published IDs are unique and lookups preserve canonical builder identity',
    () {
      final ids = publishedCreationTemplates.map((t) => t.id).toSet();
      expect(ids.length, publishedCreationTemplates.length);
      var documentReads = 0;
      for (final canonical in publishedCreationTemplates) {
        expect(publishedCreationTemplateById(canonical.id), same(canonical));
        final liked = canonical.copyWith(isLiked: true);
        expect(canonicalCatalogPreviewId(liked), canonical.id);
        expect(
          catalogEditorialSpread(liked),
          catalogEditorialSpread(canonical),
        );
        final impostor = _template(
          canonical.id,
          document: () {
            documentReads++;
            throw StateError('Identity must not build documents');
          },
        );
        expect(isPublishedCreationTemplate(impostor), isTrue);
        expect(canonicalCatalogPreviewId(impostor), isNull);
        expect(catalogEditorialSpread(impostor), isNull);
        expect(pointShopTemplateKey(impostor), pointShopTemplateKey(canonical));
      }
      expect(documentReads, 0);
      expect(publishedCreationTemplateById(42), isNull);
      expect(canonicalCatalogPreviewId(null), isNull);
      expect(isBundledCreationTemplate(_template(42)), isFalse);
    },
  );

  test('free, paid, retired and arbitrary server keys remain distinct', () {
    final expected = <int, String>{};
    void add(int id, String key) {
      expect(
        expected.containsKey(id),
        isFalse,
        reason: 'Duplicate catalog ID $id',
      );
      expected[id] = key;
    }

    for (final edition in storyEditions) {
      add(edition.catalogId, edition.productKey);
      expect(
        publishedPremiumProductKey(edition.catalogId),
        edition.isPremium ? edition.productKey : isNull,
      );
    }
    for (final edition in StudioEdition.values.where((e) => e.premium)) {
      add(edition.catalogId, edition.productKey);
    }
    for (final edition in AtelierEdition.values) {
      add(edition.catalogId, edition.productKey);
    }
    for (final entry in premiumVolumeCatalogIds.entries) {
      add(entry.value, 'template:${entry.key.id}');
    }
    for (final entry in conceptVolumeCatalogIds.entries) {
      add(entry.value, 'template:${entry.key.id}');
    }
    for (final collection in [
      ...authoredCollections,
      ...retiredAuthoredCollections,
    ]) {
      add(collection.bundledId, pointShopAuthoredTemplateKey(collection));
    }
    for (final entry in expected.entries) {
      expect(pointShopTemplateKey(_template(entry.key)), entry.value);
    }
    for (final collection in retiredAuthoredCollections) {
      expect(
        isBundledCreationTemplate(_template(collection.bundledId)),
        isTrue,
      );
      expect(
        isPublishedCreationTemplate(_template(collection.bundledId)),
        isFalse,
      );
    }
    for (var id = 100000; id < 101000; id++) {
      expect(pointShopTemplateKey(_template(id)), 'template:server-$id');
      expect(publishedPremiumProductKey(id), isNull);
      expect(publishedCreationTemplateById(id), isNull);
    }
  });

  test(
    'refresh merge preserves first favorite row, local design and pricing',
    () {
      final canonical = publishedCreationTemplates.first;
      var reads = 0;
      final stale =
          _template(
            canonical.id,
            document: () {
              reads++;
              throw StateError('Remote documents must not be read');
            },
          ).copyWith(
            title: 'Stale',
            isLiked: true,
            likeCount: 123,
            isPremium: !canonical.isPremium,
          );
      final result = withBundledCreationTemplates([
        _template(100000),
        stale,
        stale.copyWith(isLiked: false, likeCount: 0),
      ]);
      expect(
        result.map((t) => t.id),
        publishedCreationTemplates.map((t) => t.id),
      );
      final merged = result.firstWhere((t) => t.id == canonical.id);
      expect(merged.title, canonical.title);
      expect(merged.isPremium, canonical.isPremium);
      expect(merged.documentBuilder, same(canonical.documentBuilder));
      expect(merged.isLiked, isTrue);
      expect(merged.likeCount, 123);
      expect(reads, 0);
    },
  );
}

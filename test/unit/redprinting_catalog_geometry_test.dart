import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/data/catalog_detail_assets.dart';
import 'package:snap_fit/core/constants/design_templates.dart'
    show TemplateAspect;
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/store/presentation/utils/template_detail_document.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all selectable soft/hard sizes use the exact official print ratio', () {
    expect(CollectionAspect.printable.map((a) => a.name), [
      'square',
      'landscape4x3',
      'landscape5x4',
    ]);
    expect(
      CollectionAspect.printable,
      isNot(contains(CollectionAspect.portrait)),
    );
    for (final cover in coverSizes) {
      for (final type in PrintCoverType.values) {
        final selected = cover.withCoverType(type);
        final key = AlbumCreationTemplate.aspectKey(selected);
        final layout = CollectionAspect.printable.singleWhere(
          (a) => a.name == key,
        );
        expect(
          layout.canvas.aspectRatio,
          closeTo(selected.realSize.aspectRatio, 1e-10),
        );
        expect(
          selected.printProduct!['trimWidthMm'],
          (cover.realSize.width * 10).round(),
        );
        expect(
          selected.printProduct!['trimHeightMm'],
          (cover.realSize.height * 10).round(),
        );
      }
    }
    expect(templateVariantForCover(coverSizes[1]), 'landscape4x3');
    expect(templateVariantForCover(coverSizes[2]), 'landscape5x4');
    for (final layout in CollectionAspect.printable.where(
      (a) => a.isLandscape,
    )) {
      final parsed = DataTemplateEngine.templateFromJson({
        'aspect': layout.name,
      });
      expect(parsed.aspect, TemplateAspect.landscape);
    }
    final archived = resolveCoverSize(ratio: .75);
    expect(archived.productId, isNull);
    expect(archived.ratio, .75);
    expect(newAlbumCoverSize(archived), defaultCoverSize);
  });

  test('every shipped book has only printable variants and all five sizes', () {
    final manifest =
        jsonDecode(
              File(
                'assets/templates/detail_documents/manifest.json',
              ).readAsStringSync(),
            )
            as Map;
    final documents = manifest['documents'] as Map;
    expect(
      documents.length,
      greaterThanOrEqualTo(publishedCreationTemplates.length),
    );
    for (final name in documents.keys.cast<String>()) {
      final file = File(catalogDetailAssetPath(name));
      final document =
          jsonDecode(
                utf8.decode(GZipDecoder().decodeBytes(file.readAsBytesSync())),
              )
              as Map<String, dynamic>;
      final variants = document['variants'] as Map;
      expect(
        variants.keys,
        unorderedEquals(['square', 'landscape4x3', 'landscape5x4']),
        reason: name,
      );
      expect(
        (document['designWidth'] as num) / (document['designHeight'] as num),
        1,
        reason: name,
      );
      final count = templateDocumentPages(document).length;
      for (final cover in coverSizes) {
        final variant = Map<String, dynamic>.from(
          variants[templateVariantForCover(cover)] as Map,
        );
        final ratio =
            (variant['designWidth'] as num) / (variant['designHeight'] as num);
        expect(
          ratio,
          closeTo(cover.ratio, 1e-10),
          reason: '$name / ${cover.displayName}',
        );
        expect(templateDocumentPages(variant), hasLength(count), reason: name);
      }
      final facts = PublicTemplateFacts.fromDocument(
        int.parse(name.split('-').where((s) => s.isNotEmpty).first) * -1,
        document,
      );
      expect(
        facts.printSizes.map((s) => s.productId),
        coverSizes.map((s) => s.productId),
        reason: name,
      );
      expect(facts.designShapes, ['정사각형', '가로형'], reason: name);
    }
  });

  test(
    'store analysis rejects portrait books and omits stale portrait variants',
    () {
      Map<String, dynamic> book(double width, double height) => {
        'designWidth': width,
        'designHeight': height,
        'pages': [
          {
            'layers': [
              {'type': 'text', 'id': 'title', 'text': '기록'},
            ],
          },
        ],
      };
      final unsupported = analyzeTemplateDetailDocument({
        'id': 2000,
        'source': jsonEncode(book(300, 400)),
      });
      expect(unsupported, isNull);
      final supported = analyzeTemplateDetailDocument({
        'id': 2000,
        'source': jsonEncode({
          ...book(500, 500),
          'variants': {
            'portrait': book(300, 400),
            'square': book(500, 500),
            'landscape4x3': book(500, 375),
            'landscape5x4': book(500, 400),
          },
        }),
      });
      expect(supported, isNotNull);
      expect(
        supported!.variants.keys,
        unorderedEquals(['square', 'landscape4x3', 'landscape5x4']),
      );
      expect(supported.facts.printSizes, hasLength(5));
    },
  );
}

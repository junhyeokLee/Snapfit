import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/data/catalog_detail_assets.dart';
import 'package:snap_fit/core/data/catalog_template_metadata.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/template_design_profile.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'refined single-photo covers show current photo counts in every catalog label',
    () {
      for (final entry in {-9422: 30, -9443: 33, -9451: 31}.entries) {
        final template = publishedCreationTemplateById(entry.key)!;
        final profile = TemplateDesignProfile.of(template);
        expect(
          profile.photoSlotCount,
          entry.value,
          reason: '${entry.key} photo slots',
        );
        expect(publishedTemplatePhotoCount(template), entry.value);
        expect(profile.compositionLabel, startsWith('사진 넣는 ${entry.value}곳 ·'));
        expect(profile.briefLabel, '사진 ${entry.value}장 구성 · 내지 24쪽');
      }
    },
  );

  test(
    'all exported catalog facts match the actual shipped complete books',
    () async {
      for (final template in publishedCreationTemplates) {
        final metadata = canonicalTemplateMetadata(template);
        expect(metadata, isNotNull, reason: '${template.id}');
        final bytes = await rootBundle.load(
          catalogDetailAssetPath('${template.id}'),
        );
        final document = Map<String, dynamic>.from(
          jsonDecode(
                utf8.decode(
                  GZipDecoder().decodeBytes(
                    bytes.buffer.asUint8List(
                      bytes.offsetInBytes,
                      bytes.lengthInBytes,
                    ),
                  ),
                ),
              )
              as Map,
        );
        final expected = TemplateDesignProfile.fromDocument(document);
        final actual = TemplateDesignProfile.of(template);
        expect(
          actual.photoSlotCount,
          expected.photoSlotCount,
          reason: '${template.id} photos',
        );
        expect(
          actual.innerPhotoSlotCount,
          expected.innerPhotoSlotCount,
          reason: '${template.id} inner photos',
        );
        expect(
          actual.innerPageCount,
          expected.innerPageCount,
          reason: '${template.id} pages',
        );
        expect(
          actual.photoPageCount,
          expected.photoPageCount,
          reason: '${template.id} photo pages',
        );
        expect(
          actual.recordPageCount,
          expected.recordPageCount,
          reason: '${template.id} record pages',
        );
        expect(publishedTemplatePhotoCount(template), expected.photoSlotCount);
        final expectedFacts = PublicTemplateFacts.fromDocument(
          template.id,
          document,
        );
        final actualFacts = PublicTemplateFacts.fromTemplate(template);
        expect(
          actualFacts.innerPageCount,
          expectedFacts.innerPageCount,
          reason: '${template.id} facts pages',
        );
        expect(
          actualFacts.designShapes,
          expectedFacts.designShapes,
          reason: '${template.id} shapes',
        );
        expect(
          actualFacts.printSizes.map((size) => size.productId),
          expectedFacts.printSizes.map((size) => size.productId),
          reason: '${template.id} print sizes',
        );
        expect(
          actualFacts.availablePageCounts,
          expectedFacts.availablePageCounts,
        );
      }
    },
  );

  test(
    'an unrelated document with a canonical ID never receives bundled facts',
    () {
      final canonical = publishedCreationTemplates.first;
      final remote = PremiumTemplate(
        id: canonical.id,
        title: 'Remote custom book',
        coverImageUrl: '',
        previewImages: const [],
        pageCount: 1,
        userCount: 0,
        templateJson: jsonEncode({
          'designWidth': 500,
          'designHeight': 500,
          'pages': [
            {
              'isCover': true,
              'layers': [
                {'type': 'image', 'editable': true},
              ],
            },
            {
              'layers': [
                {'type': 'image', 'editable': true},
              ],
            },
          ],
        }),
      );
      expect(canonicalTemplateMetadata(remote), isNull);
      expect(TemplateDesignProfile.of(remote).innerPageCount, 1);
      expect(TemplateDesignProfile.of(remote).photoSlotCount, 2);
      expect(PublicTemplateFacts.fromTemplate(remote).innerPageCount, 1);
      expect(
        canonicalTemplateMetadata(canonical.copyWith(isLiked: true)),
        isNotNull,
      );
    },
  );
}

import 'dart:convert';

import '../../features/store/domain/entities/premium_template.dart';
import '../../features/store/domain/template_design_profile.dart';
import '../templates/template_document_pages.dart';

/// Retain exact authored geometry, typography, images, and content for only the
/// three catalog pages. The profile still describes the whole default edition.
Map<String, dynamic>? compactCatalogPreviewDocument(String source) {
  final document = jsonDecode(source);
  if (document is! Map<String, dynamic>) return null;
  final metadata = document['metadata'] as Map? ?? const {};
  final width =
      (document['designWidth'] as num? ??
              metadata['designWidth'] as num? ??
              500)
          .toDouble();
  final height =
      (document['designHeight'] as num? ??
              metadata['designHeight'] as num? ??
              500)
          .toDouble();
  if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
    return null;
  }
  final pages = templateDocumentPages(document);
  final profile = TemplateDesignProfile.of(
    PremiumTemplate(
      id: 0,
      title: '',
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 0,
      userCount: 0,
      templateJson: source,
    ),
  );
  return {
    'width': width,
    'height': height,
    'cover': pages.firstOrNull?['layers'] ?? const [],
    'spread': [
      for (final page in pages.skip(3).take(2)) page['layers'] ?? const [],
    ],
    'profile': {
      'photoSlotCount': profile.photoSlotCount,
      'innerPhotoSlotCount': profile.innerPhotoSlotCount,
      'innerPageCount': profile.innerPageCount,
      'photoPageCount': profile.photoPageCount,
      'recordPageCount': profile.recordPageCount,
      'compositionLabel': profile.compositionLabel,
      'briefLabel': profile.briefLabel,
    },
  };
}

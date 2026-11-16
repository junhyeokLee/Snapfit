import 'catalog_detail_artwork_revisions.g.dart';

/// Version the asset path itself: Flutter asset keys encode query separators.
/// Old browsers must not reuse books with the retired orientation geometry.
const catalogDetailLayoutRevision = 'redp-five-sizes-v1';

String catalogDetailFileName(String documentId, {String? artworkRevision}) {
  final artwork = artworkRevision ?? catalogDetailArtworkRevisions[documentId];
  final revision = artwork == null
      ? catalogDetailLayoutRevision
      : '$catalogDetailLayoutRevision.$artwork';
  return '$documentId.$revision.json.gz';
}

String catalogDetailAssetPath(String documentId) =>
    'assets/templates/detail_documents/${catalogDetailFileName(documentId)}';

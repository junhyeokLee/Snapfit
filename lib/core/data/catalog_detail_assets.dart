/// Version the asset path itself: Flutter asset keys encode query separators.
/// Old browsers must not reuse books with the retired orientation geometry.
const catalogDetailLayoutRevision = 'redp-five-sizes-v1';

String catalogDetailFileName(String documentId) =>
    '$documentId.$catalogDetailLayoutRevision.json.gz';

String catalogDetailAssetPath(String documentId) =>
    'assets/templates/detail_documents/${catalogDetailFileName(documentId)}';

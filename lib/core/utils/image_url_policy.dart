enum ImageVariant { thumb, detail }

String? bundledTemplateAssetPath(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('asset:')) return trimmed.substring('asset:'.length);
  return null;
}

String imageUrlByVariant(
  String url, {
  ImageVariant variant = ImageVariant.thumb,
}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;

  Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return trimmed;
  }

  if (!uri.hasScheme || uri.host.isEmpty) return trimmed;
  // Storage references are object identities, not image-CDN endpoints. A
  // query appended to supabase:// becomes part of the persisted object path
  // when the storage resolver signs it, producing a different missing object.
  if (uri.scheme != 'https' && uri.scheme != 'http') return trimmed;
  // Preserve signed/private and already transformed Supabase URLs verbatim,
  // including projects served through a custom storage domain.
  if (uri.path.startsWith('/storage/v1/object/') ||
      uri.path.startsWith('/storage/v1/render/image/')) {
    return trimmed;
  }
  if (trimmed.startsWith('asset:')) return trimmed;
  if (uri.host.contains('figma.com')) return trimmed;
  if (uri.host.contains('firebasestorage.googleapis.com')) return trimmed;
  if (uri.host.contains('storage.googleapis.com')) return trimmed;

  final width = variant == ImageVariant.thumb ? 480 : 1400;
  final quality = variant == ImageVariant.thumb ? 72 : 85;

  final next = Map<String, String>.from(uri.queryParameters);

  // Unsplash and most image CDNs accept these query params.
  next['w'] = '$width';
  next['q'] = '$quality';
  if (uri.host.contains('unsplash.com')) {
    next['auto'] = 'format';
    next['fit'] = 'crop';
  }

  return uri.replace(queryParameters: next).toString();
}

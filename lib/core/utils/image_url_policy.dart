enum ImageVariant { thumb, detail }

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
  if (trimmed.startsWith('asset:')) return trimmed;
  if (uri.host.contains('figma.com')) return trimmed;

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

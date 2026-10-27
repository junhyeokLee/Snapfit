/// Provenance is only an official product identity. It never contains a source
/// user's album, photos, text, or editable document.
String? normalizeAlbumSourceTemplateProductKey(Object? value) {
  if (value is! String) return null;
  final key = value.trim();
  if (!key.startsWith('template:') ||
      key.length <= 'template:'.length ||
      key.length > 256 ||
      RegExp(r'\s|[\x00-\x1f\x7f]').hasMatch(key)) {
    return null;
  }
  return key;
}

String? readAlbumSourceTemplateProductKey(Object? document) {
  if (document is! Map) return null;
  final source = document['sourceTemplate'];
  return source is Map
      ? normalizeAlbumSourceTemplateProductKey(source['productKey'])
      : null;
}

Map<String, dynamic> albumSourceTemplateMetadata(String? productKey) {
  final key = normalizeAlbumSourceTemplateProductKey(productKey);
  return key == null
      ? const {}
      : {
          'sourceTemplate': {'productKey': key},
        };
}

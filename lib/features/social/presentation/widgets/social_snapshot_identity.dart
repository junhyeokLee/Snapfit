/// Capability renewal keeps the same artwork; all resource selectors and
/// transforms remain part of its identity. Other URL families stay exact.
String socialSnapshotIdentity(String source) {
  final uri = Uri.tryParse(source);
  if (uri == null || !const ['http', 'https'].contains(uri.scheme))
    return source;
  final known =
      uri.path.startsWith('/storage/v1/object/sign/') ||
      uri.path.startsWith('/storage/v1/render/image/sign/') ||
      uri.path == '/functions/v1/social-media';
  if (!known) return source;
  final query = Map<String, List<String>>.of(uri.queryParametersAll)
    ..remove('token');
  return uri.replace(queryParameters: query).toString();
}

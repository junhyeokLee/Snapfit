String? albumInviteTokenFromUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'snapfit' ||
      uri.host.toLowerCase() != 'invite' ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return null;
  }
  final tokens = uri.queryParametersAll['token'];
  if (tokens == null || tokens.length != 1) return null;
  final token = tokens.single;
  return RegExp(r'^[A-Za-z0-9_-]{1,256}$').hasMatch(token) ? token : null;
}

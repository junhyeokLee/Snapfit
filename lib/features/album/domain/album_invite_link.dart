/// Invitation capabilities are accepted only from the app scheme or this app's
/// public hosts. Other HTTPS URLs must never become an invitation by their path.
String? albumInviteTokenFromUri(Uri uri) {
  try {
    return _albumInviteTokenFromUri(uri);
  } on FormatException {
    return null;
  }
}

String? _albumInviteTokenFromUri(Uri uri) {
  if (uri.userInfo.isNotEmpty) return null;
  if (uri.scheme.toLowerCase() == 'snapfit') {
    if (uri.host.toLowerCase() != 'invite' ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasPort ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final tokens = uri.queryParametersAll['token'];
    if (tokens == null || tokens.length != 1) return null;
    return _validToken(tokens.single) ? tokens.single : null;
  }

  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final production =
      scheme == 'https' &&
      const {
        'snapfit-c719d.web.app',
        'snapfit-c719d.firebaseapp.com',
      }.contains(host) &&
      (!uri.hasPort || uri.port == 443);
  final local =
      (scheme == 'http' || scheme == 'https') &&
      const {'localhost', '127.0.0.1', '::1'}.contains(host);
  if ((!production && !local) || uri.hasQuery) return null;

  var route = uri;
  if (uri.hasFragment) {
    if ((uri.path.isNotEmpty && uri.path != '/') ||
        !uri.fragment.startsWith('/')) {
      return null;
    }
    final fragment = Uri.tryParse(uri.fragment);
    if (fragment == null ||
        fragment.hasScheme ||
        fragment.hasAuthority ||
        fragment.hasQuery ||
        fragment.hasFragment) {
      return null;
    }
    route = fragment;
  }
  final parts = route.pathSegments;
  if (parts.length != 2 || parts.first != 'invite') return null;
  return _validToken(parts[1]) ? parts[1] : null;
}

bool _validToken(String token) =>
    RegExp(r'^[A-Za-z0-9_-]{1,256}$').hasMatch(token);

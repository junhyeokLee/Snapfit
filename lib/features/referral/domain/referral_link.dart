/// Referral codes are shareable identifiers, never account or album access
/// capabilities. The server verifies eligibility and grants all rewards.
String? normalizeReferralCode(String value) {
  final code = value.trim().toUpperCase();
  return RegExp(r'^[A-HJKMNP-Z2-9]{10}$').hasMatch(code) ? code : null;
}

/// Accept only SnapFit's own HTTPS hosts or its explicit native friend route.
/// Album collaboration keeps its separate `/invite` and `snapfit://invite` URLs.
String? referralCodeFromUri(Uri uri) {
  try {
    return _referralCodeFromUri(uri);
  } on FormatException {
    return null;
  }
}

String? _referralCodeFromUri(Uri uri) {
  if (uri.userInfo.isNotEmpty) return null;
  if (uri.scheme.toLowerCase() == 'snapfit') {
    if (uri.host.toLowerCase() != 'friends' ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasPort ||
        uri.hasFragment) {
      return null;
    }
    return _queryCode(uri);
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
  if (!production && !local) return null;

  var route = uri;
  if (uri.hasFragment) {
    if (uri.hasQuery ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !uri.fragment.startsWith('/')) {
      return null;
    }
    final fragment = Uri.tryParse(uri.fragment);
    if (fragment == null ||
        fragment.hasScheme ||
        fragment.hasAuthority ||
        fragment.hasFragment) {
      return null;
    }
    route = fragment;
  }
  final parts = route.pathSegments;
  if (parts.length == 2 && parts.first == 'friends' && !route.hasQuery) {
    return normalizeReferralCode(parts[1]);
  }
  if (parts.length == 1 && parts.single == 'friends') {
    return _queryCode(route);
  }
  return null;
}

String? _queryCode(Uri uri) {
  final parameters = uri.queryParametersAll;
  if (parameters.length != 1 || parameters['code']?.length != 1) return null;
  return normalizeReferralCode(parameters['code']!.single);
}

Uri referralShareUri(String code) {
  final normalized = normalizeReferralCode(code);
  if (normalized == null) {
    throw ArgumentError.value(code, 'code', 'Invalid SnapFit referral code');
  }
  return Uri.https('snapfit-c719d.web.app', '/friends/$normalized');
}

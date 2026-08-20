import '../../config/env.dart';

class LegacyBackendDisabledException implements Exception {
  const LegacyBackendDisabledException([
    this.message = 'Legacy Spring backend fallback is disabled.',
  ]);

  final String message;

  @override
  String toString() => message;
}

void assertLegacyBackendFallbackAllowed({String? feature}) {
  if (Env.enableLegacyBackendFallback) return;
  final suffix = feature == null || feature.trim().isEmpty ? '' : ' ($feature)';
  throw LegacyBackendDisabledException(
    'Legacy Spring backend fallback is disabled$suffix. Supabase migration is required.',
  );
}

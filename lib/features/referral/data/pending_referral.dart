import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/referral_link.dart';

class PendingReferral {
  const PendingReferral(this.code, this.receivedAt);
  final String code;
  final DateTime receivedAt;
}

/// A separate store survives OAuth redirects and email confirmation without
/// treating a referral code as an album collaboration invitation.
class PendingReferralStore {
  PendingReferralStore({
    FlutterSecureStorage? storage,
    DateTime Function()? now,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _now = now ?? DateTime.now;

  static const key = 'snapfit_pending_friend_referral_v1';
  static const lifetime = Duration(days: 7);
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  Future<PendingReferral?> read() async {
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final storedCode = data['code'] as String;
      final code = normalizeReferralCode(storedCode);
      final receivedAt = DateTime.parse(data['receivedAt'] as String);
      final age = _now().difference(receivedAt);
      if (code == null || age.isNegative || age >= lifetime) return null;
      return PendingReferral(code, receivedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(PendingReferral? referral) => referral == null
      ? _storage.delete(key: key)
      : _storage.write(
          key: key,
          value: jsonEncode({
            'code': referral.code,
            'receivedAt': referral.receivedAt.toUtc().toIso8601String(),
          }),
        );
}

final pendingReferralStoreProvider = Provider<PendingReferralStore>(
  (_) => PendingReferralStore(),
);
final pendingReferralProvider =
    NotifierProvider<PendingReferralController, PendingReferral?>(
      PendingReferralController.new,
    );

class PendingReferralController extends Notifier<PendingReferral?> {
  Future<void> _writes = Future.value();
  int _revision = 0;
  bool _restored = false;
  bool _disposed = false;

  /// Callers that leave the app for authentication can await the captured code
  /// being persisted. Storage failures never prevent login or app startup.
  Future<void> get persisted => _writes;

  @override
  PendingReferral? build() {
    ref.onDispose(() => _disposed = true);
    return null;
  }

  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    if (state != null) return;
    final revision = _revision;
    try {
      final saved = await ref.read(pendingReferralStoreProvider).read();
      if (!_disposed && revision == _revision) {
        state = saved;
        if (saved == null) _persist(null);
      }
    } catch (_) {
      // A locked/unavailable store must not prevent login or startup.
    }
  }

  bool receive(Uri uri) {
    final code = referralCodeFromUri(uri);
    if (code == null) return false;
    _revision++;
    state = PendingReferral(code, DateTime.now());
    _persist(state);
    return true;
  }

  void clearIfCurrent(PendingReferral referral) {
    if (!identical(state, referral)) return;
    _revision++;
    state = null;
    _persist(null);
  }

  void _persist(PendingReferral? referral) {
    final store = ref.read(pendingReferralStoreProvider);
    // Keep receive/clear ordering even when native storage completes slowly.
    _writes = _writes
        .then((_) => store.write(referral))
        .catchError((Object _) {});
  }
}

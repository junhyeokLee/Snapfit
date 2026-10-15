import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/album_invite_link.dart';

class PendingAlbumInvite {
  const PendingAlbumInvite(this.token, this.receivedAt);
  final String token;
  final DateTime receivedAt;
}

class PendingAlbumInviteStore {
  PendingAlbumInviteStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  static const key = 'snapfit_pending_album_invite_v1';
  final FlutterSecureStorage _storage;

  Future<PendingAlbumInvite?> read() async {
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final token = data['token'] as String;
      final receivedAt = DateTime.parse(data['receivedAt'] as String);
      final age = DateTime.now().difference(receivedAt);
      if (age.isNegative ||
          age > const Duration(days: 14) ||
          albumInviteTokenFromUri(
                Uri(
                  scheme: 'snapfit',
                  host: 'invite',
                  queryParameters: {'token': token},
                ),
              ) ==
              null) {
        return null;
      }
      return PendingAlbumInvite(token, receivedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(PendingAlbumInvite? invite) => invite == null
      ? _storage.delete(key: key)
      : _storage.write(
          key: key,
          value: jsonEncode({
            'token': invite.token,
            'receivedAt': invite.receivedAt.toUtc().toIso8601String(),
          }),
        );
}

final pendingAlbumInviteStoreProvider = Provider<PendingAlbumInviteStore>(
  (_) => PendingAlbumInviteStore(),
);
final pendingAlbumInviteProvider =
    NotifierProvider<PendingAlbumInviteController, PendingAlbumInvite?>(
      PendingAlbumInviteController.new,
    );

class PendingAlbumInviteController extends Notifier<PendingAlbumInvite?> {
  Future<void> _writes = Future.value();
  int _revision = 0;
  bool _restored = false;
  bool _disposed = false;

  @override
  PendingAlbumInvite? build() {
    ref.onDispose(() => _disposed = true);
    return null;
  }

  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    if (state != null) return;
    final revision = _revision;
    try {
      final saved = await ref.read(pendingAlbumInviteStoreProvider).read();
      if (!_disposed && revision == _revision) {
        state = saved;
        if (saved == null) _persist(null);
      }
    } catch (_) {
      // An unavailable secure store must not block app startup or login.
    }
  }

  bool receive(Uri uri) {
    final token = albumInviteTokenFromUri(uri);
    if (token == null) return false;
    if (state?.token == token) return true;
    _revision++;
    state = PendingAlbumInvite(token, DateTime.now());
    _persist(state);
    return true;
  }

  void clearIfCurrent(PendingAlbumInvite invite) {
    if (!identical(state, invite)) return;
    _revision++;
    state = null;
    _persist(null);
  }

  void _persist(PendingAlbumInvite? invite) {
    final store = ref.read(pendingAlbumInviteStoreProvider);
    // Preserve receive/clear ordering when native storage completes out of order.
    _writes = _writes
        .then((_) => store.write(invite))
        .catchError((Object _) {});
  }
}

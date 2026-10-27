import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';

typedef AlbumEditorOwnerReader = String? Function();

/// A live reader, rather than a cached provider value, guards every async step.
final albumEditorOwnerReaderProvider = Provider<AlbumEditorOwnerReader>((ref) {
  try {
    final client = ref.read(supabaseClientProvider);
    return () => client.auth.currentUser?.id;
  } catch (_) {
    // A disconnected/local fixture has no authenticated write capability.
    return () => null;
  }
});

final albumEditorOwnerChangesProvider = StreamProvider<String?>((ref) {
  try {
    final client = ref.watch(supabaseClientProvider);
    return client.auth.onAuthStateChange.map((event) => event.session?.user.id);
  } catch (_) {
    return const Stream.empty();
  }
});

final albumCurrentSessionOwnerProvider = Provider<String?>((ref) {
  ref.watch(albumEditorOwnerChangesProvider);
  return ref.watch(albumEditorOwnerReaderProvider)();
});

enum AlbumEditSyncKind { current, remoteChanged, accessRevoked, offline }

class AlbumEditSyncStatus {
  const AlbumEditSyncStatus({
    this.albumId,
    this.kind = AlbumEditSyncKind.current,
  });

  final int? albumId;
  final AlbumEditSyncKind kind;
}

final albumEditSyncStatusProvider =
    NotifierProvider<AlbumEditSyncStatusNotifier, AlbumEditSyncStatus>(
      AlbumEditSyncStatusNotifier.new,
    );

class AlbumEditSyncStatusNotifier extends Notifier<AlbumEditSyncStatus> {
  @override
  AlbumEditSyncStatus build() => const AlbumEditSyncStatus();

  void update(int? albumId, AlbumEditSyncKind kind) {
    if (state.albumId == albumId && state.kind == kind) return;
    state = AlbumEditSyncStatus(albumId: albumId, kind: kind);
  }
}

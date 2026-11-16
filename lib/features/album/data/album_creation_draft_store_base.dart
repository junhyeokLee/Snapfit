import '../domain/entities/album_creation_draft.dart';

abstract class AlbumCreationDraftStore {
  Future<AlbumCreationDraft?> load(String owner);
  Future<void> save(String owner, AlbumCreationDraft draft);
  Future<void> remove(String owner, String draftId);
  Future<bool> updateLinked(
    String owner,
    String draftId,
    int albumId,
    AlbumCreationDraft Function(AlbumCreationDraft) update,
  );
}

/// Optimistic concurrency for a creation flow's exact durable draft version.
abstract interface class AlbumCreationDraftWriteSession {
  Future<void> beginDraftWriteSession(
    String owner,
    String draftId, {
    AlbumCreationDraft? restoring,
  });
}

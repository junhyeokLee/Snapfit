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

/// Optional optimistic concurrency support for browser creation flows.
/// Native stores retain their existing lifecycle and do not implement this.
abstract interface class AlbumCreationDraftWriteSession {
  Future<void> beginDraftWriteSession(
    String owner,
    String draftId, {
    AlbumCreationDraft? restoring,
  });
}

import 'package:snap_fit/features/moments/data/moment_draft_store.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';

/// Committed in-memory storage for widget tests; production durability is
/// covered separately against the disk and IndexedDB implementations.
class MemoryMomentDraftStore extends MomentDraftStore {
  final Map<(String, String), MomentDraft> drafts = {};
  int writes = 0, removals = 0;
  int _version = 0;
  Object? loadError, writeError, removeError;
  Future<void> Function()? beforeSave;
  Future<void> Function()? beforeLoad;

  void seed(MomentDraft draft) {
    drafts[(draft.ownerId, draft.recordId)] = draft.version == null
        ? draft.copyWith(version: 'seed-${++_version}')
        : draft;
  }

  @override
  Future<MomentDraft?> load(String owner, String recordId) async {
    await beforeLoad?.call();
    if (loadError case final error?) throw error;
    return drafts[(owner, recordId)];
  }

  @override
  Future<List<MomentDraft>> list(String owner) async {
    await beforeLoad?.call();
    if (loadError case final error?) throw error;
    return sortedMomentDrafts(
      drafts.entries
          .where((entry) => entry.key.$1 == owner)
          .map((entry) => entry.value),
    );
  }

  @override
  Future<MomentDraft> save(
    String owner,
    MomentDraft draft, {
    required String? expectedVersion,
  }) async {
    await beforeSave?.call();
    if (writeError case final error?) throw error;
    validateMomentDraft(owner, draft);
    final key = (owner, draft.recordId);
    if (drafts[key]?.version != expectedVersion) {
      throw const MomentDraftConflictException();
    }
    final saved = draft.copyWith(version: 'memory-${++_version}');
    drafts[key] = saved;
    writes++;
    return saved;
  }

  @override
  Future<bool> remove(
    String owner,
    String recordId, {
    required String? expectedVersion,
  }) async {
    if (removeError case final error?) throw error;
    final key = (owner, recordId);
    final current = drafts[key];
    if (current == null) return false;
    if (current.version != expectedVersion) {
      throw const MomentDraftConflictException();
    }
    drafts.remove(key);
    removals++;
    return true;
  }
}

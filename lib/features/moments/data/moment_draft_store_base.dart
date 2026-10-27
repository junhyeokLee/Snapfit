import '../domain/moment_draft.dart';

const momentDraftMaximumPhotoBytes = 20 * 1024 * 1024;
const momentDraftMaximumDrafts = 10;
const momentDraftMaximumOwnerBytes = 256 * 1024 * 1024;

class MomentDraftException implements Exception {
  const MomentDraftException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MomentDraftConflictException extends MomentDraftException {
  const MomentDraftConflictException()
    : super('다른 창에서 작성 중인 기록이 바뀌었어요. 다시 열어 최신 내용을 확인해 주세요.');
}

abstract class MomentDraftStore {
  Future<MomentDraft?> load(String owner, String recordId);
  Future<List<MomentDraft>> list(String owner);

  Future<List<MomentDraftSummary>> summaries(String owner) async =>
      (await list(owner))
          .map((draft) => MomentDraftSummary.fromMetadata(draft.toMetadata()))
          .toList(growable: false);

  Future<MomentDraft?> latestNew(String owner) async {
    for (final draft in await summaries(owner)) {
      if (draft.isEditing) continue;
      final current = await load(owner, draft.recordId);
      if (current != null) return current;
    }
    return null;
  }

  /// null asserts that no draft exists. Existing drafts require their token.
  Future<MomentDraft> save(
    String owner,
    MomentDraft draft, {
    required String? expectedVersion,
  });

  /// Removes only the version saved by this editor. Missing drafts return false.
  Future<bool> remove(
    String owner,
    String recordId, {
    required String? expectedVersion,
  });
}

void validateMomentDraft(String owner, MomentDraft draft) {
  validateMomentDraftIdentity(owner, draft.recordId);
  if (draft.ownerId != owner ||
      draft.caption.length > 2000 ||
      draft.existingPhotos.length + draft.uploads.length > 3 ||
      (draft.originalRecord != null &&
          draft.originalRecord!.id != draft.recordId) ||
      (draft.version != null && draft.version!.isEmpty)) {
    throw const MomentDraftException('임시 저장할 기록 정보를 확인하지 못했어요.');
  }
  final ids = <String>{};
  for (final photo in draft.existingPhotos) {
    if (photo.id.isEmpty || photo.path.isEmpty || !ids.add(photo.id)) {
      throw const MomentDraftException('임시 저장할 사진 정보를 확인하지 못했어요.');
    }
  }
  for (final photo in draft.uploads) {
    if (photo.id.isEmpty ||
        photo.filename.length > 1024 ||
        photo.bytes.isEmpty ||
        photo.bytes.length > momentDraftMaximumPhotoBytes ||
        !ids.add(photo.id)) {
      throw const MomentDraftException('사진은 한 장에 20MB까지 임시 저장할 수 있어요.');
    }
  }
}

void validateMomentDraftIdentity(String owner, [String? recordId]) {
  if (owner.trim().isEmpty ||
      owner.length > 256 ||
      (recordId != null &&
          (recordId.trim().isEmpty || recordId.length > 256))) {
    throw const MomentDraftException('기록을 작성한 계정을 확인해 주세요.');
  }
}

List<MomentDraft> sortedMomentDrafts(Iterable<MomentDraft> drafts) =>
    List.unmodifiable(
      drafts.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );

void validateMomentDraftCapacity(
  Iterable<MomentDraftSummary> existing,
  MomentDraft draft,
) {
  final others = existing
      .where((value) => value.recordId != draft.recordId)
      .toList();
  final bytes =
      others.fold<int>(0, (sum, value) => sum + value.photoBytes) +
      draft.uploads.fold<int>(0, (sum, photo) => sum + photo.bytes.length);
  if (others.length >= momentDraftMaximumDrafts ||
      bytes > momentDraftMaximumOwnerBytes) {
    throw const MomentDraftException(
      '작성 중인 기록이 많아 임시 저장 공간이 가득 찼어요. 남겨 둔 기록을 저장하거나 정리한 뒤 다시 시도해 주세요.',
    );
  }
}

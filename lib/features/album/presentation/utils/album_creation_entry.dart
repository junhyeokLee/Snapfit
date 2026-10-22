import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../data/album_creation_draft_store.dart';
import '../../domain/entities/album_creation_draft.dart';

/// A non-null decision either resumes the current draft or starts a new album.
/// A null result leaves the caller and every saved draft unchanged.
class AlbumCreationEntryDecision {
  const AlbumCreationEntryDecision._({
    this.draft,
    required String owner,
    required _DraftRevision? expectedRevision,
  }) : _owner = owner,
       _expectedRevision = expectedRevision;

  final AlbumCreationDraft? draft;
  final String _owner;
  final _DraftRevision? _expectedRevision;
}

enum _CreationEntryChoice { resume, startNew }

typedef _DraftRevision = ({String id, DateTime updatedAt, int? createdAlbumId});

_DraftRevision? _revision(AlbumCreationDraft? draft) => draft == null
    ? null
    : (
        id: draft.id,
        updatedAt: draft.updatedAt,
        createdAlbumId: draft.createdAlbumId,
      );

void _changedDraftNotice(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(
      content: Text('임시 저장한 앨범이 변경되었거나 삭제되었어요. 최신 목록에서 다시 선택해 주세요.'),
    ),
  );
}

void _draftReadFailure(
  BuildContext context,
  WidgetRef ref,
  bool Function() active,
) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: const Text('임시 저장한 앨범을 확인하지 못했어요. 다시 확인해 주세요.'),
      action: SnackBarAction(
        label: '다시 확인',
        onPressed: () {
          if (active()) ref.invalidate(albumCreationDraftProvider);
        },
      ),
    ),
  );
}

/// Rechecks the decision after asynchronous setup and before opening a flow.
/// A newer draft never becomes permission to replace an unseen revision.
Future<bool> validateAlbumCreationEntry(
  BuildContext context,
  WidgetRef ref,
  AlbumCreationEntryDecision decision, {
  bool Function()? isStillCurrent,
}) async {
  if (!context.mounted) return false;
  final route = ModalRoute.of(context);
  bool active() =>
      context.mounted &&
      route?.isCurrent != false &&
      ref.read(visibleOrderOwnerProvider) == decision._owner &&
      (isStillCurrent?.call() ?? true);
  if (!active()) return false;
  try {
    final latest = await ref
        .read(albumCreationDraftStoreProvider)
        .load(decision._owner);
    if (!active()) return false;
    if (_revision(latest) != decision._expectedRevision) {
      _changedDraftNotice(context);
      return false;
    }
    return true;
  } catch (_) {
    if (active()) _draftReadFailure(context, ref, active);
    return false;
  }
}

/// Resolves entry before opening a new editor or requesting a design purchase.
/// Callers keep their own in-flight guard and must act only on a non-null result.
Future<AlbumCreationEntryDecision?> resolveAlbumCreationEntry(
  BuildContext context,
  WidgetRef ref, {
  String? selectedDesignTitle,
  String? requestedDraftId,
  bool Function()? isStillCurrent,
}) async {
  if (!context.mounted) return null;
  final route = ModalRoute.of(context);
  bool currentRoute() =>
      context.mounted &&
      route?.isCurrent != false &&
      (isStillCurrent?.call() ?? true);
  if (!currentRoute()) return null;
  String? owner;
  try {
    owner = (await ref.read(authViewModelProvider.future))?.id;
  } catch (_) {
    if (currentRoute()) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.')),
      );
    }
    return null;
  }
  if (!currentRoute()) return null;
  if (owner == null || owner.isEmpty) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('로그인 상태를 확인한 뒤 다시 시작해 주세요.')));
    return null;
  }
  if (ref.read(visibleOrderOwnerProvider) != owner) return null;

  bool active() =>
      currentRoute() && ref.read(visibleOrderOwnerProvider) == owner;

  Future<AlbumCreationDraft?> latestDraft() {
    // Read the captured, validated account directly. An account-dependent
    // provider future may be cancelled by auth restoration or an account switch.
    return ref.read(albumCreationDraftStoreProvider).load(owner!);
  }

  try {
    final draft = await latestDraft();
    if (!active()) return null;
    if (requestedDraftId != null && draft?.id == requestedDraftId) {
      return AlbumCreationEntryDecision._(
        draft: draft,
        owner: owner,
        expectedRevision: _revision(draft),
      );
    }
    if (draft == null) {
      if (requestedDraftId != null) {
        _changedDraftNotice(context);
        return null;
      }
      return AlbumCreationEntryDecision._(owner: owner, expectedRevision: null);
    }

    final design = selectedDesignTitle?.trim();
    final hasDesign = design != null && design.isNotEmpty;
    final requestedChanged = requestedDraftId != null;
    final choice = await showDialog<_CreationEntryChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('album-creation-entry-dialog'),
        scrollable: true,
        title: Text(requestedChanged ? '임시 저장한 앨범이 변경되었어요' : '만들던 앨범이 있어요'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(draft.title.trim().isEmpty ? '제목 없는 앨범' : draft.title),
            const SizedBox(height: 12),
            if (requestedChanged) ...[
              const Text('지금 저장된 앨범을 확인하고 이어서 만들 수 있어요.'),
              const SizedBox(height: 12),
            ],
            Text(
              hasDesign
                  ? '‘$design’ 디자인으로 새 앨범을 임시 저장하면 기존 임시 저장을 대체해요.'
                  : '새 앨범을 임시 저장하면 기존 임시 저장을 대체해요.',
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('album-creation-entry-cancel'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            key: const ValueKey('album-creation-entry-new'),
            onPressed: () =>
                Navigator.pop(dialogContext, _CreationEntryChoice.startNew),
            child: Text(hasDesign ? '이 디자인으로 새로 만들기' : '새 앨범 만들기'),
          ),
          FilledButton(
            key: const ValueKey('album-creation-entry-resume'),
            onPressed: () =>
                Navigator.pop(dialogContext, _CreationEntryChoice.resume),
            child: const Text('이어서 만들기'),
          ),
        ],
      ),
    );
    if (!active() || choice == null) return null;

    // Another tab or a background save can change the stored album while its
    // title is being considered. Never resume or replace that unseen revision.
    final latest = await latestDraft();
    if (!active()) return null;
    if (_revision(draft) != _revision(latest)) {
      _changedDraftNotice(context);
      return null;
    }
    return AlbumCreationEntryDecision._(
      draft: choice == _CreationEntryChoice.resume ? latest : null,
      owner: owner,
      expectedRevision: _revision(latest),
    );
  } catch (_) {
    if (active()) {
      _draftReadFailure(context, ref, active);
    }
    return null;
  }
}

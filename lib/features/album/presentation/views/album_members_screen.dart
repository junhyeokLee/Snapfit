import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../data/api/album_provider.dart';
import '../../data/dto/album_member_response.dart';
import '../../domain/entities/album.dart';
import '../../service/album_collaboration_session.dart';
import '../viewmodels/home_view_model.dart';
import 'album_invite_screen.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

final albumMembersProvider = FutureProvider.autoDispose
    .family<List<AlbumMemberResponse>, int>((ref, albumId) async {
      ref.watch(albumCollaborationActorProvider);
      return ref.read(albumMemberRepositoryProvider).fetchMembers(albumId);
    }, retry: (_, __) => null);

/// Membership identity and permissions come from the server, never the saved
/// album document or the legacy integer user identifier.
class AlbumMembersScreen extends ConsumerStatefulWidget {
  const AlbumMembersScreen({super.key, required this.album});
  final Album album;
  @override
  ConsumerState<AlbumMembersScreen> createState() => _AlbumMembersScreenState();
}

class _AlbumMembersScreenState extends ConsumerState<AlbumMembersScreen> {
  bool _busy = false, _sessionChanged = false;
  int _revision = 0;
  String? _message;

  bool _current(String? actor, int revision) =>
      mounted &&
      !_sessionChanged &&
      _revision == revision &&
      ref.read(albumCollaborationActorProvider) == actor;

  Future<void> _openInvite() async {
    if (!mounted || _busy || _sessionChanged) return;
    final actor = ref.read(albumCollaborationActorProvider);
    if (actor == null || ModalRoute.of(context)?.isCurrent == false) return;
    final album = widget.album;
    final revision = ++_revision;
    setState(() => _busy = true);
    try {
      await Navigator.push<void>(
        context,
        snapFitRoute<void>(page: AlbumInviteScreen(
            albumId: album.id,
            albumTitle: album.title,
            album: album,
          )),
      );
      if (_current(actor, revision) &&
          widget.album.id == album.id &&
          ModalRoute.of(context)?.isCurrent != false) {
        ref.invalidate(albumMembersProvider(album.id));
      }
    } finally {
      if (_current(actor, revision)) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String copy, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(copy),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _change(AlbumMemberResponse member, String action) async {
    if (_busy || _sessionChanged) return;
    final actor = ref.read(albumCollaborationActorProvider);
    if (actor == null) return;
    final revision = ++_revision;
    final leave = action == 'leave';
    final remove = action == 'remove';
    final revoke = action == 'revoke';
    final name = member.userName?.trim().isNotEmpty == true
        ? member.userName!
        : '앨범 참여자';
    final confirmed = await _confirm(
      revoke
          ? '미사용 초대 링크를 취소할까요?'
          : leave
          ? '공유 앨범에서 나갈까요?'
          : remove
          ? '멤버를 내보낼까요?'
          : '멤버 권한을 변경할까요?',
      revoke
          ? '아직 참여하지 않은 초대 링크만 취소해요. 현재 멤버의 참여와 권한은 유지돼요.'
          : leave
          ? '이 앨범을 더 이상 열거나 편집할 수 없어요. 다시 참여하려면 새 초대가 필요해요. 원본 앨범은 삭제되지 않아요.'
          : remove
          ? '$name 님은 이 앨범을 더 이상 열거나 편집할 수 없어요.'
          : action == 'VIEWER'
          ? '$name 님은 앨범을 볼 수 있고 편집은 할 수 없어요.'
          : '$name 님이 사진과 문구를 함께 편집할 수 있어요.',
      revoke
          ? '링크 취소하기'
          : leave
          ? '앨범에서 나가기'
          : remove
          ? '내보내기'
          : '변경하기',
    );
    if (!confirmed || !_current(actor, revision)) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final repository = ref.read(albumMemberRepositoryProvider);
    int? revokedCount;
    try {
      if (revoke) {
        revokedCount = await repository.revokeInvites(widget.album.id);
      } else if (leave) {
        await repository.leave(widget.album.id);
      } else {
        final target = member.userUuid;
        if (target == null || target.isEmpty || member.isOwner) return;
        if (remove) {
          await repository.removeMember(widget.album.id, target);
        } else {
          await repository.setMemberRole(widget.album.id, target, action);
        }
      }
      if (!_current(actor, revision)) return;
      ref.invalidate(homeViewModelProvider);
      ref.invalidate(albumMembersProvider(widget.album.id));
      if (leave) {
        Navigator.pop(context, true);
        return;
      }
      setState(
        () => _message = revoke
            ? revokedCount == 0
                  ? '취소할 미사용 초대 링크가 없어요.'
                  : '미사용 초대 링크 $revokedCount개를 취소했어요. 현재 멤버는 유지돼요.'
            : remove
            ? '멤버를 내보냈어요.'
            : '권한을 변경했어요.',
      );
    } catch (_) {
      if (!_current(actor, revision)) return;
      // A committed response may be lost; reconcile before another action.
      ref.invalidate(albumMembersProvider(widget.album.id));
      ref.invalidate(homeViewModelProvider);
      setState(() => _message = '요청 결과를 확인하지 못했어요. 최신 멤버 상태를 다시 확인해 주세요.');
    } finally {
      if (_current(actor, revision)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(albumCollaborationActorProvider, (previous, next) {
      if (previous != next)
        setState(() {
          _revision++;
          _busy = false;
          _sessionChanged = true;
          _message = null;
        });
    });
    final actor = ref.watch(albumCollaborationActorProvider);
    final members = ref.watch(albumMembersProvider(widget.album.id));
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: ExperienceHeader(title: '함께하는 멤버', showNotifications: false),
      body: _sessionChanged
          ? _empty('계정이 변경되었어요', '현재 계정의 앨범에서 멤버를 다시 확인해 주세요.')
          : members.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _empty(
                '멤버를 확인할 수 없어요',
                '앨범 접근 권한이나 연결 상태를 확인한 뒤 다시 시도해 주세요.',
                retry: true,
              ),
              data: (rows) {
                final self = rows
                    .where((m) => m.userUuid == actor && m.status == 'ACCEPTED')
                    .firstOrNull;
                if (actor == null || self == null)
                  return _empty(
                    '참여 정보를 확인할 수 없어요',
                    '현재 계정의 공유 앨범 목록을 다시 불러와 주세요.',
                    retry: true,
                  );
                final owner = self.isOwner;
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(albumMembersProvider(widget.album.id));
                    await ref.read(
                      albumMembersProvider(widget.album.id).future,
                    );
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    children: [
                      Text(
                        widget.album.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '소유자는 멤버와 초대를 관리해요. 편집 멤버는 함께 편집하고, 보기 전용 멤버는 감상할 수 있어요.',
                        style: TextStyle(height: 1.7),
                      ),
                      const SizedBox(height: 20),
                      if (owner)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _openInvite,
                            icon: const ExperienceIcon('UserPlus', size: 20),
                            label: const Text('멤버 초대'),
                          ),
                        ),
                      if (owner) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _change(self, 'revoke'),
                            icon: const ExperienceIcon('Unlink', size: 20),
                            label: const Text('미사용 초대 링크 취소'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_message != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _message!,
                            style: const TextStyle(height: 1.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      for (final member in rows)
                        _memberRow(member, actor, owner),
                      if (!owner) ...[
                        const SizedBox(height: 28),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _change(self, 'leave'),
                          child: const Text('공유 앨범에서 나가기'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _memberRow(AlbumMemberResponse member, String actor, bool owner) {
    final self = member.userUuid == actor;
    final label = member.isOwner
        ? '소유자'
        : member.role == 'EDITOR'
        ? '함께 편집'
        : member.role == 'VIEWER'
        ? '보기 전용'
        : '권한 확인 필요';
    final actionable =
        owner &&
        !member.isOwner &&
        !self &&
        member.userUuid?.isNotEmpty == true &&
        member.status == 'ACCEPTED';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 14),
            child: ExperienceIcon('UserRound', size: 24),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${member.userName?.trim().isNotEmpty == true ? member.userName : '앨범 참여자'}${self ? ' · 나' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '$label${member.status == 'ACCEPTED'
                      ? ''
                      : member.status == 'PENDING'
                      ? ' · 참여 대기'
                      : ' · 참여 상태 확인 필요'}',
                ),
              ],
            ),
          ),
          if (actionable)
            PopupMenuButton<String>(
              tooltip: '멤버 관리',
              enabled: !_busy,
              onSelected: (action) => _change(member, action),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: member.role == 'EDITOR' ? 'VIEWER' : 'EDITOR',
                  child: Text(
                    member.role == 'EDITOR' ? '보기 전용으로 변경' : '편집 권한 허용',
                  ),
                ),
                const PopupMenuItem(value: 'remove', child: Text('멤버 내보내기')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _empty(String title, String copy, {bool retry = false}) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(copy, textAlign: TextAlign.center),
          if (retry) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () =>
                  ref.invalidate(albumMembersProvider(widget.album.id)),
              child: const Text('다시 확인'),
            ),
          ],
        ],
      ),
    ),
  );
}

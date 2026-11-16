import '../../../social/data/social_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../social/presentation/social_actions.dart';
import '../../../social/presentation/views/social_work_detail_screen.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../data/moment_publication_repository.dart';
import '../../domain/moment_record.dart';
import '../providers/moment_publication_providers.dart';
import '../providers/moments_providers.dart';
import 'moments_widgets.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

/// The saved record is fixed here. Publishing or retrying never saves it again
/// and never changes the separately created monthly album.
class MomentPublicationPanel extends ConsumerStatefulWidget {
  const MomentPublicationPanel({
    super.key,
    required this.record,
    this.allowPublishing = true,
  });
  final MomentRecord record;
  final bool allowPublishing;

  @override
  ConsumerState<MomentPublicationPanel> createState() =>
      _MomentPublicationPanelState();
}

class _MomentPublicationPanelState
    extends ConsumerState<MomentPublicationPanel> {
  late final String? _owner;
  bool _busy = false, _sessionChanged = false;
  String? _photoId, _error;
  String _requestId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _owner = ref.read(momentsCurrentUserIdProvider);
    if (widget.record.photos.length == 1)
      _photoId = widget.record.photos.single.id;
  }

  bool get _current =>
      mounted &&
      !_sessionChanged &&
      _owner != null &&
      ref.read(momentsCurrentUserIdProvider) == _owner;

  Future<void> _publish(MomentPublicationState state) async {
    if (!_current || _busy || !widget.allowPublishing) return;
    final photo = state.isPending ? state.photoId : _photoId;
    if (photo == null) {
      setState(() => _error = '피드에 보여줄 사진 한 장을 골라 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(momentPublicationRepositoryProvider)
          .publish(
            record: widget.record,
            photoId: photo,
            requestId: state.isPending && state.requestId != null
                ? state.requestId!
                : _requestId,
            context: context,
            canContinue: () =>
                _current && ModalRoute.of(context)?.isCurrent != false,
          );
      if (!_current) return;
      invalidateSocial(ref);
      ref.invalidate(momentPublicationStateProvider(widget.record.id));
    } catch (error) {
      if (_current) {
        setState(
          () => _error = socialActionMessage(
            error,
            fallback: '기록은 저장돼 있어요. 피드 공개를 다시 시도하거나 나만 보기로 바꿔 주세요.',
          ),
        );
        ref.invalidate(momentPublicationStateProvider(widget.record.id));
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _makePrivate() async {
    if (!_current || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(momentPublicationRepositoryProvider)
          .makePrivate(widget.record.id);
      if (!_current) return;
      _requestId = const Uuid().v4();
      invalidateSocial(ref);
      ref.invalidate(momentPublicationStateProvider(widget.record.id));
    } catch (_) {
      if (_current) setState(() => _error = '공개 상태가 바뀌었어요. 다시 확인한 뒤 눌러 주세요.');
      if (_current)
        ref.invalidate(momentPublicationStateProvider(widget.record.id));
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(momentsCurrentUserIdProvider, (previous, next) {
      if (previous != next) {
        _sessionChanged = true;
        _photoId = null;
        _error = null;
      }
    });
    if (!_current) return const SizedBox.shrink();
    final state = ref.watch(momentPublicationStateProvider(widget.record.id));
    return Container(
      key: const ValueKey('moment-publication-panel'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SocialStyle.paper(context),
        border: Border.all(color: SocialStyle.line(context)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: state.when(
        loading: () => const Text('피드 공개 상태를 확인하고 있어요…'),
        error: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('기록은 저장됐어요. 피드 공개 상태를 다시 확인해 주세요.'),
            TextButton(
              key: const ValueKey('moment-publication-reload'),
              onPressed: () => ref.invalidate(
                momentPublicationStateProvider(widget.record.id),
              ),
              child: const Text('공개 상태 다시 확인'),
            ),
          ],
        ),
        data: (publication) {
          if (publication == null)
            return const Text('이 기록이 변경됐어요. 나의 기록에서 다시 확인해 주세요.');
          final published = publication.isPublished;
          final stale = publication.recordRevision != widget.record.revision;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    published
                        ? Icons.public_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                    color: SocialStyle.accent(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      published
                          ? '선택한 한 장을 피드에 공개했어요'
                          : publication.isPending
                          ? '피드 공개를 마저 준비할까요?'
                          : '나만 보는 기록으로 저장했어요',
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (published && !stale) ...[
                if (widget.record.photos
                        .where((photo) => photo.id == publication.photoId)
                        .firstOrNull
                    case final photo?) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    key: const ValueKey('moment-saved-published-photo'),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MomentPhotoView(
                        photo: photo,
                        aspectRatio: momentPhotoAspect(photo),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ],
              if (stale) ...[
                const SizedBox(height: 10),
                const Text('기록이 수정됐어요. 나의 기록에서 최신 내용을 확인해 주세요.'),
              ] else if (!published) ...[
                const SizedBox(height: 10),
                Text(
                  '사진 한 장과 이 글만 공개해요. 월간 앨범은 그대로 간직해요.',
                  style: ExperienceFormStyle.text(
                    context,
                    12,
                    secondary: true,
                  ).copyWith(height: 1.6),
                ),
                if (!publication.isPending) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in widget.record.photos.indexed)
                        ChoiceChip(
                          key: ValueKey(
                            'moment-saved-public-photo-${entry.$2.id}',
                          ),
                          label: Text('${entry.$1 + 1}번째 사진'),
                          selected: _photoId == entry.$2.id,
                          onSelected: _busy || !widget.allowPublishing
                              ? null
                              : (_) => setState(() {
                                  _photoId = entry.$2.id;
                                  _requestId = const Uuid().v4();
                                  _error = null;
                                }),
                        ),
                    ],
                  ),
                ],
                if (widget.record.photos
                        .where(
                          (photo) =>
                              photo.id ==
                              (publication.isPending
                                  ? publication.photoId
                                  : _photoId),
                        )
                        .firstOrNull
                    case final photo?) ...[
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MomentPhotoView(
                        photo: photo,
                        aspectRatio: momentPhotoAspect(photo),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const ValueKey('moment-saved-publish'),
                  onPressed: _busy || !widget.allowPublishing
                      ? null
                      : () => _publish(publication),
                  child: Text(
                    _busy
                        ? '공개 사진을 준비하고 있어요…'
                        : !widget.allowPublishing
                        ? '변경한 기록을 먼저 저장해 주세요'
                        : publication.isPending
                        ? '피드 공개 다시 시도'
                        : '선택한 한 장 피드에 공개',
                  ),
                ),
              ],
              if (published && publication.workId != null)
                TextButton(
                  key: const ValueKey('moment-saved-open-publication'),
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push<void>(
                          snapFitRoute<void>(page: SocialWorkDetailScreen(
                              workId: publication.workId!,
                            )),
                        ),
                  child: const Text('공개한 기록 보기'),
                ),
              if (published || publication.isPending)
                TextButton(
                  key: const ValueKey('moment-saved-make-private'),
                  onPressed: _busy ? null : _makePrivate,
                  child: const Text('나만 보기로 바꾸기'),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                MomentErrorNotice(message: _error!),
              ],
            ],
          );
        },
      ),
    );
  }
}

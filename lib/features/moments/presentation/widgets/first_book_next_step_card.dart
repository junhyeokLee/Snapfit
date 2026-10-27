import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/snapfit_image.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../album/domain/entities/album.dart';
import '../../../album/presentation/utils/album_progress.dart';
import '../../../album/presentation/widgets/home/home_album_helpers.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_draft.dart';
import '../providers/moments_providers.dart';

/// One useful next step, without decoding the library's documents in build.
class FirstBookNextStepCard extends ConsumerStatefulWidget {
  const FirstBookNextStepCard({
    super.key,
    required this.ownerId,
    required this.albums,
    required this.onMoments,
    required this.onDraft,
    required this.onContinueAlbum,
    this.creationDraftTitle,
    this.onResumeCreation,
    this.compact = false,
  });

  final String ownerId;
  final List<Album> albums;
  final VoidCallback onMoments;
  final ValueChanged<MomentDraftSummary> onDraft;
  final ValueChanged<Album> onContinueAlbum;
  final String? creationDraftTitle;
  final VoidCallback? onResumeCreation;
  final bool compact;

  @override
  ConsumerState<FirstBookNextStepCard> createState() =>
      _FirstBookNextStepCardState();
}

class _FirstBookNextStepCardState extends ConsumerState<FirstBookNextStepCard>
    with WidgetsBindingObserver {
  Album? _album;
  AlbumProgressInfo? _progress;
  AlbumProgressRequest? _request;
  int _generation = 0;
  bool _visible = false, _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (_visible == visible) return;
    _visible = visible;
    _selectAlbum();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _selectAlbum(notify: true);
  }

  @override
  void didUpdateWidget(covariant FirstBookNextStepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId ||
        !identical(oldWidget.albums, widget.albums) ||
        (oldWidget.onResumeCreation != null) !=
            (widget.onResumeCreation != null)) {
      _selectAlbum();
    }
  }

  bool _draftHasPriority(AsyncValue<List<MomentDraftSummary>>? state) =>
      state?.isLoading == true || state?.asData?.value.isNotEmpty == true;

  void _selectAlbum({bool notify = false}) {
    _request?.cancel();
    _request = null;
    final generation = ++_generation;
    _album = null;
    _progress = null;
    if (notify) setState(() {});
    if (!_visible ||
        !_foreground ||
        widget.ownerId.isEmpty ||
        widget.onResumeCreation != null)
      return;
    final drafts = ref.read(
      momentDraftSummariesForOwnerProvider(widget.ownerId),
    );
    // Draft recovery is more useful and does not need album document work.
    // Wait for its small metadata lookup before starting progress analysis.
    if (_draftHasPriority(drafts)) return;
    DateTime time(Album album) =>
        DateTime.tryParse(album.updatedAt) ??
        DateTime.tryParse(album.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final candidates = <({Album album, DateTime updated})>[];
    for (final album in widget.albums) {
      if (album.userId != widget.ownerId ||
          !album.allowsEditing ||
          album.id <= 0 ||
          isDraftAlbum(album)) {
        continue;
      }
      candidates.add((album: album, updated: time(album)));
    }
    candidates.sort((a, b) {
      final updated = b.updated.compareTo(a.updated);
      return updated != 0 ? updated : b.album.id.compareTo(a.album.id);
    });
    unawaited(
      _findFirstIncomplete(
        candidates.map((candidate) => candidate.album),
        generation,
      ),
    );
  }

  Future<void> _findFirstIncomplete(
    Iterable<Album> candidates,
    int generation,
  ) async {
    AlbumProgressInfo? latestCompleted;
    for (final album in candidates) {
      if (!mounted || generation != _generation) return;
      var progress = cachedAlbumProgress(album);
      if (progress == null) {
        // Only one candidate is requested at a time. Completed newer books do
        // not hide an older unfinished book, and unmount/list/account changes
        // cancel any queued work through the shared loader.
        final request = AlbumProgressLoader.request(album);
        _request = request;
        progress = await request.result;
        if (!mounted || generation != _generation) return;
        _request = null;
      }
      if (progress == null) return;
      if (!progress.isCompleted) {
        setState(() {
          _album = album;
          _progress = progress;
        });
        return;
      }
      latestCompleted ??= progress;
    }
    if (!mounted || generation != _generation) return;
    setState(() => _progress = latestCompleted);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _request?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draftState = widget.ownerId.isEmpty
        ? null
        : ref.watch(momentDraftSummariesForOwnerProvider(widget.ownerId));
    if (widget.ownerId.isNotEmpty) {
      ref.listen(momentDraftSummariesForOwnerProvider(widget.ownerId), (
        previous,
        next,
      ) {
        if (_draftHasPriority(previous) != _draftHasPriority(next)) {
          _selectAlbum(notify: true);
        }
      });
    }
    final draft = draftState?.asData?.value.firstOrNull;
    final album = _album;
    final resumeAlbum =
        album != null && _progress != null && !_progress!.isCompleted;
    final resumeCreation = widget.onResumeCreation != null;
    final title = draft != null
        ? '남기던 순간 이어 쓰기'
        : resumeCreation
        ? '이어서 만들기'
        : resumeAlbum
        ? (album.title.trim().isEmpty ? '만들던 앨범 이어가기' : album.title)
        : _progress?.isCompleted == true
        ? '다음 한 권의 시작'
        : '한 장에서 나의 첫 한 권까지';
    final remaining = _progress == null
        ? 0
        : _progress!.targetPages - _progress!.completedPages;
    final description = draft != null
        ? '사진과 글을 이 기기에 보관했어요.'
        : resumeCreation
        ? (widget.creationDraftTitle?.trim().isNotEmpty == true
              ? widget.creationDraftTitle!
              : '골라둔 사진과 구성을 이어서 완성해요.')
        : resumeAlbum
        ? (remaining > 0
              ? '남은 $remaining쪽부터 이어 만들어요.'
              : '사진과 글을 채워 한 권을 마무리해요.')
        : '사진을 남기고, 모아둔 순간을 한 권으로 만나보세요.';
    final VoidCallback action = draft != null
        ? () => widget.onDraft(draft)
        : resumeCreation
        ? widget.onResumeCreation!
        : resumeAlbum
        ? () => widget.onContinueAlbum(album)
        : widget.onMoments;
    final cover = resumeAlbum
        ? album.coverThumbnailUrl ??
              album.coverPreviewUrl ??
              album.coverImageUrl
        : null;
    final icon = draft != null
        ? Icons.edit_note_rounded
        : resumeCreation || resumeAlbum
        ? Icons.auto_stories_outlined
        : Icons.add_photo_alternate_outlined;
    final shortCompact =
        widget.compact && MediaQuery.sizeOf(context).height < 600;
    return Material(
      color: SocialStyle.paper(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: SocialStyle.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('first-book-next-step'),
        onTap: action,
        child: shortCompact
            ? ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ExperienceFormStyle.text(
                            context,
                            14,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: SocialStyle.accent(context),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: EdgeInsets.all(widget.compact ? 12 : 18),
                child: Row(
                  children: [
                    Container(
                      width: widget.compact ? 48 : 72,
                      height: widget.compact ? 62 : 88,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: SocialStyle.accent(
                          context,
                        ).withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(7),
                        border: Border(
                          left: BorderSide(
                            color: SocialStyle.accent(
                              context,
                            ).withValues(alpha: .4),
                            width: 3,
                          ),
                        ),
                      ),
                      child: cover?.isNotEmpty == true
                          ? SnapfitImage(
                              urlOrGs: cover!,
                              fit: BoxFit.cover,
                              error: Icon(icon),
                            )
                          : Icon(
                              icon,
                              color: SocialStyle.accent(context),
                              size: 25,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ExperienceFormStyle.text(
                              context,
                              widget.compact ? 14 : 17,
                              weight: FontWeight.w600,
                            ).copyWith(height: 1.35),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: ExperienceFormStyle.text(
                              context,
                              widget.compact ? 11 : 13,
                              secondary: true,
                            ).copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: SocialStyle.accent(context),
                      size: 20,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

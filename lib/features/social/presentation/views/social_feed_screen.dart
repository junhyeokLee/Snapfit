import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/web/web_design.dart'
    show WebNavigationScope, WebPageLayout;
import '../../../../shared/web/web_photo_layout.dart';
import '../../../notification/presentation/views/notification_screen.dart';
import '../../domain/social_models.dart';
import '../../../moments/presentation/moments_navigation.dart';
import '../providers/social_providers.dart';
import '../social_page_boundaries.dart';
import '../social_actions.dart';
import '../social_navigation.dart';
import '../widgets/social_widgets.dart';
import '../widgets/social_web_frame.dart';
import '../widgets/social_page_header.dart';
import '../widgets/social_feed_artwork.dart';
import '../widgets/social_report_sheet.dart';
import '../widgets/social_work_share_sheet.dart';
import '../../data/social_repository.dart';
import 'social_saved_works_screen.dart';
import 'social_search_screen.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../../shared/widgets/snapfit_shimmer.dart';

class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});
  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen> {
  bool _following = false;
  final _queries = <SocialFeedQuery>[const SocialFeedQuery()];
  int _revision = 0;
  final _boundaries = SocialPageBoundaries<SocialFeedQuery>();
  bool _reconciling = false;
  SocialFeedQuery? _nextToLoad;
  late final ScrollController _scrollController = ScrollController()
    ..addListener(_onScroll);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 500) return;
    final next = _nextToLoad;
    if (next == null) return;
    _nextToLoad = null;
    setState(() => _queries.add(next));
  }

  void _resetPages() {
    _revision++;
    _boundaries.clear();
    _reconciling = false;
    _queries
      ..clear()
      ..add(SocialFeedQuery(following: _following));
  }

  bool _reconcilePages(List<AsyncValue<SocialWorkPage>> pages) {
    if (_reconciling) return true;
    final keep = _boundaries.observe(_queries, [
      for (final result in pages)
        if (!result.isLoading && !result.hasError && result.asData != null)
          _pageBoundary(result.asData!.value)
        else
          null,
    ]);
    if (keep != null) {
      _reconciling = true;
      final revision = ++_revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _revision) return;
        setState(() {
          _queries.removeRange(keep, _queries.length);
          _reconciling = false;
        });
      });
    }
    return _reconciling;
  }

  String _pageBoundary(SocialWorkPage page) => socialPageBoundary(
    nextCursor: page.nextCursor,
    nextOffset: page.nextOffset,
    hasMore: page.hasMore,
    itemKeys: page.items.map((work) => work.id),
  );

  SocialFeedQuery? _next(SocialFeedQuery query, SocialWorkPage page) {
    if (!page.hasMore) return null;
    final cursor = page.nextCursor;
    if (cursor != null) {
      final next = SocialFeedQuery(
        following: _following,
        limit: query.limit,
        cursor: cursor,
      );
      return _queries.contains(next) ? null : next;
    }
    if (page.nextOffset <= query.offset) return null;
    final next = SocialFeedQuery(
      following: _following,
      limit: query.limit,
      offset: page.nextOffset,
    );
    return _queries.contains(next) ? null : next;
  }

  bool _current(int revision, String? viewer, SocialFeedQuery query) =>
      mounted &&
      revision == _revision &&
      ref.read(socialCurrentUserIdProvider) == viewer &&
      query.following == _following &&
      _queries.contains(query);

  void _filter({required bool following}) {
    setState(() {
      _following = following;
      _resetPages();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next && mounted) {
        final previousQueries = List<SocialFeedQuery>.of(_queries);
        setState(_resetPages);
        for (final query in previousQueries)
          ref.invalidate(socialFeedProvider(query));
      }
    });
    final user = ref.watch(socialCurrentUserIdProvider);
    final shownWorkIds = <String>{};
    final pages = _following && user == null
        ? [
            for (final _ in _queries)
              const AsyncData(
                SocialWorkPage(items: [], hasMore: false, nextOffset: 0),
              ),
          ]
        : [for (final query in _queries) ref.watch(socialFeedProvider(query))];
    final first = pages.first;
    final reconciling = _reconcilePages(pages);
    final visiblePages = first.isLoading || first.hasError || reconciling
        ? 1
        : _queries.length;
    // Update auto-load target — read-only, no setState
    final lastIdx = visiblePages - 1;
    if (lastIdx >= 0 &&
        lastIdx < pages.length &&
        pages[lastIdx].hasValue &&
        !pages[lastIdx].isLoading) {
      _nextToLoad = _next(_queries[lastIdx], pages[lastIdx].requireValue);
    } else {
      _nextToLoad = null;
    }
    final hasGlobalNotifications =
        kIsWeb && WebNavigationScope.maybeOf(context)?.onNotifications != null;
    final webInset = WebPageLayout.horizontalInset(
      MediaQuery.sizeOf(context).width,
    );
    final headerActions = <Widget>[
      IconButton(
        tooltip: '기록·앨범·사용자 검색',
        icon: const ExperienceIcon('Search', size: 22),
        onPressed: () => Navigator.push(
          context,
          snapFitRoute(page: const SocialSearchScreen()),
        ),
      ),
      IconButton(
        tooltip: '저장한 기록·앨범',
        icon: const ExperienceIcon('Bookmark'),
        onPressed: () async {
          if (await requireSocialLogin(context, ref) && context.mounted) {
            Navigator.push(
              context,
              snapFitRoute(page: const SocialSavedWorksScreen()),
            );
          }
        },
      ),
      if (!hasGlobalNotifications)
        IconButton(
          tooltip: '알림',
          icon: const ExperienceIcon('Bell'),
          onPressed: () async {
            if (await requireSocialLogin(context, ref) && context.mounted) {
              Navigator.push(
                context,
                snapFitRoute(page: const NotificationScreen()),
              );
            }
          },
        ),
      IconButton(
        tooltip: '한 장의 기록 남기기',
        icon: const ExperienceIcon('Plus', size: 22),
        onPressed: () async {
          if (await requireSocialLogin(context, ref) && context.mounted) {
            openMomentCompose(context, ref);
          }
        },
      ),
    ];
    return SocialWebFrame(
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: SocialPageHeader(
          title: '피드',
          back: false,
          actions: [
            for (final action in headerActions)
              SizedBox(width: 44, height: 44, child: action),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(socialFeedProvider);
            setState(_resetPages);
            try {
              await ref.read(
                socialFeedProvider(
                  SocialFeedQuery(following: _following),
                ).future,
              );
            } catch (_) {
              // The provider renders its retry state on failure.
            }
          },
          child: SocialContent(
            maxWidth: kIsWeb ? WebPageLayout.maxWidth : 1120,
            child: ListView(
              cacheExtent: 800,
              controller: _scrollController,
              key: ValueKey((
                'social-feed-scroll',
                _following,
                user,
                _revision,
              )),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: kIsWeb
                  ? EdgeInsets.fromLTRB(webInset, 0, webInset, 32)
                  : EdgeInsets.zero,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    kIsWeb ? 0 : 16,
                    0,
                    kIsWeb ? 0 : 16,
                    6,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: SocialStyle.line(context)),
                      ),
                    ),
                    child: Wrap(
                      spacing: 26,
                      runSpacing: 4,
                      children: [
                        _tab(
                          '최신',
                          !_following,
                          () => _filter(following: false),
                        ),
                        _tab('팔로잉', _following, () => _filter(following: true)),
                      ],
                    ),
                  ),
                ),
                if (_following && user == null)
                  SocialEmpty(
                    title: '좋아하는 기록을 가까이 두세요.',
                    message: '로그인하고 팔로우한 사람의 새로운 기록을 만나보세요.',
                    action: FilledButton(
                      onPressed: () => requireSocialLogin(context, ref),
                      child: const Text('로그인'),
                    ),
                  )
                else
                  for (var index = 0; index < visiblePages; index++)
                    _feedPage(index, shownWorkIds),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) => Semantics(
    selected: selected,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? SocialStyle.accent(context)
            : SnapFitColors.textSecondaryOf(context),
        padding: EdgeInsets.zero,
        minimumSize: const Size(48, 44),
        shape: const RoundedRectangleBorder(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                letterSpacing: -.3,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          AnimatedContainer(
            duration: SnapFitMotion.duration(context, SnapFitMotion.fast),
            curve: Curves.easeOut,
            height: 2,
            width: selected ? 24 : 0,
            decoration: BoxDecoration(
              color: SocialStyle.accent(context),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _feedPage(int index, Set<String> shownWorkIds) {
    final query = _queries[index];
    final revision = _revision;
    final viewer = ref.read(socialCurrentUserIdProvider);
    final page = ref.watch(socialFeedProvider(query));
    return page.when(
      skipLoadingOnRefresh: true,
      loading: () => index == 0
          ? const SnapFitShimmerSocialFeed()
          : const SocialLoading(message: '다음 기록을 불러오고 있어요.'),
      error: (_, _) => index == 0
          ? SocialFailure(onRetry: () => ref.invalidate(socialFeedProvider))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('다음 기록을 불러오지 못했어요.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(socialFeedProvider),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
      data: (result) => Column(
        children: [
          if (!result.items.any((item) => item.isMoment) && index == 0)
            SocialEmpty(
              title: _following ? '새로운 기록을 기다리고 있어요.' : '오늘의 첫 장면을 남겨보세요.',
              message: _following
                  ? '팔로우한 사람의 공개 기록이 이곳에 모여요.'
                  : '월간 앨범을 채우며 남긴 사진과 글, 공개한 한 장만 함께 나눠요.',
              action: _following
                  ? OutlinedButton(
                      onPressed: () => _filter(following: false),
                      child: const Text('최신 피드 보기'),
                    )
                  : FilledButton(
                      style: SocialStyle.primary(context),
                      onPressed: () async {
                        if (await requireSocialLogin(context, ref) &&
                            context.mounted) {
                          openMomentCompose(context, ref);
                        }
                      },
                      child: const Text('한 장의 기록 남기기'),
                    ),
            ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: WebPhotoColumns(
                children: [
                  for (final work in result.items.where(
                    (item) => item.isMoment,
                  ))
                    if (shownWorkIds.add(work.id))
                      SocialFeedCard(key: ValueKey(work.id), work: work),
                ],
              ),
            )
          else
            for (final work in result.items.where((item) => item.isMoment))
              if (shownWorkIds.add(work.id))
                SocialFeedCard(key: ValueKey(work.id), work: work),
          if (index == _queries.length - 1 && _next(query, result) != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: OutlinedButton(
                key: const ValueKey('social-feed-more'),
                onPressed: page.isLoading
                    ? null
                    : () {
                        if (!_current(revision, viewer, query) ||
                            index != _queries.length - 1 ||
                            _queries[index] != query)
                          return;
                        final next = _next(query, result);
                        if (next != null) setState(() => _queries.add(next));
                      },
                child: const Text('기록 더 보기'),
              ),
            ),
        ],
      ),
    );
  }
}

class SocialFeedCard extends ConsumerStatefulWidget {
  const SocialFeedCard({
    super.key,
    required this.work,
    this.webLayout = kIsWeb,
    this.onRetry,
  });
  final SocialWork work;
  final bool webLayout;
  final VoidCallback? onRetry;
  @override
  ConsumerState<SocialFeedCard> createState() => _SocialFeedCardState();
}

class _SocialFeedCardState extends ConsumerState<SocialFeedCard> {
  bool _busy = false;
  bool _sharing = false;
  int _sharePage = 0;
  int _mutationRevision = 0;

  Future<void> _share() async {
    if (_sharing) return;
    final work = widget.work;
    final revision = _mutationRevision;
    setState(() => _sharing = true);
    try {
      await showSocialWorkShareSheet(
        context,
        work: work,
        initialPage: _sharePage,
        isActive: () =>
            mounted &&
            revision == _mutationRevision &&
            sameSocialWorkShareSnapshot(work, widget.work),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _report() async {
    final work = widget.work;
    final actor = ref.read(socialCurrentUserIdProvider);
    final revision = _mutationRevision;
    if (_busy ||
        !work.isPublished ||
        actor == work.author.userId ||
        !await requireSocialLogin(context, ref) ||
        !mounted ||
        actor == null ||
        revision != _mutationRevision ||
        ref.read(socialCurrentUserIdProvider) != actor ||
        widget.work.id != work.id)
      return;
    bool current() =>
        mounted &&
        revision == _mutationRevision &&
        ref.read(socialCurrentUserIdProvider) == actor &&
        widget.work.id == work.id;
    final sent = await showSocialReportSheet(
      context,
      title: '기록 신고',
      ownerId: actor,
      onSubmit: (reason, detail, requestId) async {
        if (!current()) throw StateError('report_target_changed');
        await ref
            .read(socialRepositoryProvider)
            .reportContent(
              targetKind: 'work',
              targetId: work.id,
              reason: reason,
              details: detail,
              requestId: requestId,
            );
      },
    );
    if (sent && current())
      socialError(context, message: '신고를 접수했어요. 운영자가 확인할게요.');
  }

  Future<void> _react(bool save) async {
    if (_busy) return;
    final actor = ref.read(socialCurrentUserIdProvider);
    if (!await requireSocialLogin(context, ref) ||
        !mounted ||
        _busy ||
        actor == null ||
        ref.read(socialCurrentUserIdProvider) != actor)
      return;
    final revision = ++_mutationRevision;
    final work = widget.work;
    setState(() => _busy = true);
    try {
      final repo = ref.read(socialRepositoryProvider);
      if (save) {
        await repo.setSaved(work.id, !work.isSaved);
      } else {
        await repo.setLiked(work.id, !work.isLiked);
      }
      if (mounted &&
          revision == _mutationRevision &&
          ref.read(socialCurrentUserIdProvider) == actor) {
        invalidateSocial(ref, workId: work.id);
      }
    } catch (error) {
      if (mounted &&
          revision == _mutationRevision &&
          ref.read(socialCurrentUserIdProvider) == actor) {
        invalidateSocial(ref, workId: work.id);
        socialError(
          context,
          message: socialActionMessage(
            error,
            fallback: '요청 결과를 확인하지 못했어요. 최신 상태를 다시 확인할게요.',
          ),
        );
      }
    } finally {
      if (mounted && revision == _mutationRevision)
        setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next) {
        _mutationRevision++;
        if (mounted && _busy) setState(() => _busy = false);
      }
    });
    final w = widget.work;
    return Padding(
      padding: widget.webLayout
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 4, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SocialAuthorLine(
                  author: w.author,
                  compact: true,
                  onTap: () => openSocialProfile(context, w.author.userId),
                ),
              ),
              if (w.isPublished &&
                  ref.watch(socialCurrentUserIdProvider) != w.author.userId)
                PopupMenuButton<String>(
                  key: ValueKey('social-feed-more-${w.id}'),
                  tooltip: '기록 더보기',
                  icon: ExperienceIcon('MoreHorizontal', color: SnapFitColors.textSecondaryOf(context),
                  ),
                  onSelected: (_) => _report(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'report', child: Text('기록 신고')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 5),
          SocialFeedArtwork(
            work: w,
            webLayout: widget.webLayout,
            onOpen: (page) => openSocialWork(context, w.id, initialPage: page),
            onRetry: widget.onRetry ?? () => ref.invalidate(socialFeedProvider),
            onPageChanged: (page) => _sharePage = page,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SocialReactions(
                        work: w,
                        busy: _busy,
                        compact: true,
                        onLike: () => _react(false),
                        onSave: () => _react(true),
                        onComments: () =>
                            openSocialWork(context, w.id, showComments: true),
                      ),
                    ),
                    if (w.isPublished && !w.isRestricted)
                      IconButton(
                        key: ValueKey('social-feed-share-${w.id}'),
                        tooltip: '공유',
                        onPressed: _sharing ? null : _share,
                        icon: const ExperienceIcon('Share2'),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Semantics(
                  button: true,
                  label: '${w.title}, ${w.isMoment ? '기록' : '앨범'} 자세히 보기',
                  onTap: () => openSocialWork(context, w.id),
                  excludeSemantics: true,
                  child: InkWell(
                    key: ValueKey('social-feed-open-${w.id}'),
                    onTap: () => openSocialWork(context, w.id),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          w.title,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.45,
                            letterSpacing: -.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (w.caption.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    w.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: SocialStyle.ink(context),
                    ),
                  ),
                ],
                if (w.commentCount > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: ValueKey('social-feed-comments-link-${w.id}'),
                      onPressed: () =>
                          openSocialWork(context, w.id, showComments: true),
                      style: TextButton.styleFrom(
                        foregroundColor: SnapFitColors.textSecondaryOf(context),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '댓글 ${w.commentCount}개 모두 보기',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                SizedBox(height: w.commentCount > 0 ? 1 : 10),
                SocialWorkMetadata(work: w),
              ],
            ),
          ),
          if (!widget.webLayout)
            Divider(height: 1, thickness: .7, color: SocialStyle.line(context)),
        ],
      ),
    );
  }
}

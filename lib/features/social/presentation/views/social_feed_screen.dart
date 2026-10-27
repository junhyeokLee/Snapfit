import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/web/web_design.dart'
    show WebNavigationScope, WebPageHeading, WebPageLayout;
import '../../../../shared/web/web_photo_layout.dart';
import '../../../notification/presentation/views/notification_screen.dart';
import '../../domain/social_models.dart';
import '../../domain/social_topics.dart';
import '../providers/social_providers.dart';
import '../social_actions.dart';
import '../social_navigation.dart';
import '../widgets/social_widgets.dart';
import '../widgets/social_web_frame.dart';
import 'social_saved_works_screen.dart';
import 'social_search_screen.dart';

class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});
  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen> {
  bool _following = false;
  String? _topic;
  int _pageCount = 1;
  final _topicsScroll = ScrollController();
  final _selectedTopicKey = GlobalKey();

  @override
  void dispose() {
    _topicsScroll.dispose();
    super.dispose();
  }

  void _filter({bool? following, String? topic, bool changeTopic = false}) {
    setState(() {
      if (following != null) _following = following;
      if (changeTopic) _topic = topic;
      _pageCount = 1;
    });
    if (changeTopic) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_topicsScroll.hasClients) return;
        final target = _selectedTopicKey.currentContext?.findRenderObject();
        if (target != null) {
          _topicsScroll.position.ensureVisible(
            target,
            alignment: .5,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _showTopics() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: SocialStyle.background(context),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '어떤 기록을 만나볼까요?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final topic in ['전체', ...socialTopicLabels])
                    _topicChip(
                      topic,
                      onSelected: () {
                        _filter(
                          topic: topic == '전체' ? null : topic,
                          changeTopic: true,
                        );
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _topicChip(String topic, {VoidCallback? onSelected}) => ChoiceChip(
    label: Text(topic),
    selected: (topic == '전체' ? null : topic) == _topic,
    showCheckmark: false,
    selectedColor: Theme.of(context).colorScheme.primary,
    backgroundColor: SocialStyle.background(context),
    side: BorderSide(
      color: (topic == '전체' ? null : topic) == _topic
          ? Theme.of(context).colorScheme.primary
          : SocialStyle.line(context),
    ),
    shape: const StadiumBorder(),
    labelStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: (topic == '전체' ? null : topic) == _topic
          ? Theme.of(context).colorScheme.onPrimary
          : SocialStyle.ink(context),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    onSelected: (_) => onSelected != null
        ? onSelected()
        : _filter(topic: topic == '전체' ? null : topic, changeTopic: true),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next && mounted) setState(() => _pageCount = 1);
    });
    final user = ref.watch(socialCurrentUserIdProvider);
    final shownWorkIds = <String>{};
    final hasGlobalNotifications =
        kIsWeb && WebNavigationScope.maybeOf(context)?.onNotifications != null;
    final webInset = WebPageLayout.horizontalInset(
      MediaQuery.sizeOf(context).width,
    );
    final headerActions = <Widget>[
      if (kIsWeb)
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SocialSearchScreen()),
          ),
          icon: const Icon(Icons.search, size: 18),
          label: const Text('검색'),
        )
      else
        IconButton(
          tooltip: '작품·사용자 검색',
          icon: const Icon(Icons.search),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SocialSearchScreen()),
          ),
        ),
      IconButton(
        tooltip: '저장한 작품',
        icon: const Icon(Icons.bookmark_border),
        onPressed: () async {
          if (await requireSocialLogin(context, ref) && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SocialSavedWorksScreen()),
            );
          }
        },
      ),
      if (!hasGlobalNotifications)
        IconButton(
          tooltip: '알림',
          icon: const Icon(Icons.notifications_none),
          onPressed: () async {
            if (await requireSocialLogin(context, ref) && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            }
          },
        ),
      if (kIsWeb)
        FilledButton.icon(
          style: SocialStyle.primary(context),
          onPressed: () async {
            if (await requireSocialLogin(context, ref) && context.mounted)
              openSocialPublish(context);
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('작품 공개'),
        )
      else
        IconButton(
          tooltip: '기존 앨범에서 작품 공개',
          icon: const Icon(Icons.add),
          onPressed: () async {
            if (await requireSocialLogin(context, ref) && context.mounted) {
              openSocialPublish(context);
            }
          },
        ),
    ];
    return SocialWebFrame(
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: kIsWeb
            ? null
            : AppBar(
                title: const Text(
                  '피드',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                automaticallyImplyLeading: false,
                actions: headerActions,
              ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(socialFeedProvider);
            setState(() => _pageCount = 1);
            try {
              await ref.read(
                socialFeedProvider(
                  SocialFeedQuery(following: _following, topic: _topic),
                ).future,
              );
            } catch (_) {
              // The provider renders its retry state on failure.
            }
          },
          child: SocialContent(
            maxWidth: kIsWeb ? WebPageLayout.maxWidth : 1120,
            child: ListView(
              key: const PageStorageKey('social-feed-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: kIsWeb
                  ? EdgeInsets.fromLTRB(webInset, 32, webInset, 32)
                  : EdgeInsets.zero,
              children: [
                if (kIsWeb) ...[
                  WebPageHeading(
                    title: '피드',
                    description: '다른 사람의 시선에서, 내 앨범의 영감을 만나보세요.',
                    trailing: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: headerActions,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Padding(
                  padding: EdgeInsets.fromLTRB(kIsWeb ? 0 : 16, 4, 16, 0),
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 4,
                    children: [
                      _tab('추천', !_following, () => _filter(following: false)),
                      _tab('팔로잉', _following, () => _filter(following: true)),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: SocialStyle.line(context)),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(kIsWeb ? 0 : 16, 8, 8, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _topicsScroll,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final topic in ['전체', ...socialTopicLabels])
                                Padding(
                                  key: (topic == '전체' ? null : topic) == _topic
                                      ? _selectedTopicKey
                                      : null,
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _topicChip(topic),
                                ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '모든 주제 보기',
                        onPressed: _showTopics,
                        icon: const Icon(Icons.tune_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                if (_following && user == null)
                  SocialEmpty(
                    title: '좋아하는 기록을 가까이 두세요.',
                    message: '로그인하고 창작자를 팔로우하면 새 작품을 모아 볼 수 있어요.',
                    action: FilledButton(
                      onPressed: () => requireSocialLogin(context, ref),
                      child: const Text('로그인'),
                    ),
                  )
                else
                  for (var index = 0; index < _pageCount; index++)
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
        minimumSize: const Size(48, 52),
        shape: const RoundedRectangleBorder(),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: selected
                  ? SocialStyle.accent(context)
                  : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 21,
            letterSpacing: -.6,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );

  Widget _feedPage(int index, Set<String> shownWorkIds) {
    final query = SocialFeedQuery(
      following: _following,
      topic: _topic,
      offset: index * 12,
    );
    final page = ref.watch(socialFeedProvider(query));
    return page.when(
      skipLoadingOnRefresh: true,
      loading: () => SocialLoading(
        message: index == 0 ? '공개 작품을 불러오고 있어요.' : '다음 작품을 불러오고 있어요.',
      ),
      error: (_, _) => index == 0
          ? SocialFailure(
              onRetry: () => ref.invalidate(socialFeedProvider(query)),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('다음 작품을 불러오지 못했어요.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(socialFeedProvider(query)),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
      data: (result) => Column(
        children: [
          if (result.items.isEmpty && index == 0)
            SocialEmpty(
              title: _topic != null
                  ? '아직 이 주제의 작품이 없어요.'
                  : _following
                  ? '새로운 기록을 기다리고 있어요.'
                  : '첫 기록을 기다리고 있어요.',
              message: _topic != null
                  ? '다른 주제에서도 마음에 드는 기록을 찾아보세요.'
                  : _following
                  ? '창작자를 팔로우하고 새로운 작품을 만나보세요.'
                  : '예전에 만든 앨범도 피드의 작품으로 공개할 수 있어요.',
              action: _topic != null
                  ? OutlinedButton(
                      onPressed: () => _filter(topic: null, changeTopic: true),
                      child: const Text('모든 주제로 보기'),
                    )
                  : _following
                  ? OutlinedButton(
                      onPressed: () => _filter(following: false),
                      child: const Text('추천 피드 보기'),
                    )
                  : FilledButton(
                      style: SocialStyle.primary(context),
                      onPressed: () async {
                        if (await requireSocialLogin(context, ref) &&
                            context.mounted) {
                          openSocialPublish(context);
                        }
                      },
                      child: const Text('내 앨범에서 공개하기'),
                    ),
            ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: WebPhotoColumns(
                children: [
                  for (final work in result.items)
                    if (shownWorkIds.add(work.id))
                      SocialFeedCard(key: ValueKey(work.id), work: work),
                ],
              ),
            )
          else
            for (final work in result.items)
              if (shownWorkIds.add(work.id))
                SocialFeedCard(key: ValueKey(work.id), work: work),
          if (index == _pageCount - 1 && result.hasMore)
            Padding(
              padding: const EdgeInsets.all(20),
              child: OutlinedButton(
                onPressed: () => setState(() => _pageCount++),
                child: const Text('작품 더 보기'),
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
  });
  final SocialWork work;
  final bool webLayout;
  @override
  ConsumerState<SocialFeedCard> createState() => _SocialFeedCardState();
}

class _SocialFeedCardState extends ConsumerState<SocialFeedCard> {
  bool _busy = false;
  int _mutationRevision = 0;
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
    } catch (_) {
      if (mounted &&
          revision == _mutationRevision &&
          ref.read(socialCurrentUserIdProvider) == actor) {
        invalidateSocial(ref, workId: work.id);
        socialError(context, message: '요청 결과를 확인하지 못했어요. 최신 상태를 다시 확인할게요.');
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
          : const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SocialAuthorLine(
            author: w.author,
            onTap: () => openSocialProfile(context, w.author.userId),
          ),
          const SizedBox(height: 6),
          Semantics(
            button: true,
            label: '${w.title}, ${w.imageUrls.length}쪽 작품 보기',
            onTap: () => openSocialWork(context, w.id),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: SocialStyle.paper(context),
                child: InkWell(
                  excludeFromSemantics: true,
                  onTap: () => openSocialWork(context, w.id),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      key: ValueKey('social-feed-artwork-${w.id}'),
                      width: double.infinity,
                      height: socialArtworkHeight(
                        constraints.maxWidth,
                        w.aspectRatio,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: SocialStyle.paper(context),
                            child: w.imageUrls.isEmpty
                                ? const SocialArtworkPlaceholder()
                                : SocialWorkImage(
                                    key: ValueKey('social-feed-image-${w.id}'),
                                    url: w.imageUrls.first,
                                    label: '${w.title} 대표 페이지',
                                    excludeImageSemantics: true,
                                    onRetry: () =>
                                        ref.invalidate(socialFeedProvider),
                                  ),
                          ),
                          if (w.imageUrls.length > 1)
                            Positioned(
                              top: 14,
                              right: 14,
                              child: ExcludeSemantics(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: SocialStyle.background(
                                      context,
                                    ).withValues(alpha: .94),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: SocialStyle.line(context),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 7,
                                    ),
                                    child: Text(
                                      '${w.imageUrls.length}쪽',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SocialReactions(
                  work: w,
                  busy: _busy,
                  onLike: () => _react(false),
                  onSave: () => _react(true),
                  onComments: () =>
                      openSocialWork(context, w.id, showComments: true),
                ),
                SizedBox(height: widget.webLayout ? 6 : 12),
                Text(
                  w.title,
                  style: TextStyle(
                    fontSize: widget.webLayout ? 20 : 22,
                    height: 1.4,
                    letterSpacing: -.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SocialWorkMetadata(work: w),
                if (w.caption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    w.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.75,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => openSocialWork(context, w.id),
                    style: TextButton.styleFrom(
                      foregroundColor: SocialStyle.ink(context),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 12,
                      ),
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 17),
                    label: const Text('작품 자세히 보기'),
                  ),
                ),
              ],
            ),
          ),
          if (!widget.webLayout)
            Divider(height: 1, thickness: 1, color: SocialStyle.line(context)),
        ],
      ),
    );
  }
}

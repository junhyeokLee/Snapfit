import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../album/data/album_creation_catalog_provider.dart';
import '../../../store/presentation/views/template_detail_screen.dart';
import '../../data/social_template_catalog.dart';
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../social_actions.dart';
import '../social_navigation.dart';
import '../widgets/social_widgets.dart';
import '../widgets/social_web_frame.dart';
import '../widgets/social_template_start_card.dart';

class SocialWorkDetailScreen extends ConsumerStatefulWidget {
  const SocialWorkDetailScreen({
    super.key,
    required this.workId,
    this.showComments = false,
  });
  final String workId;
  final bool showComments;
  @override
  ConsumerState<SocialWorkDetailScreen> createState() =>
      _SocialWorkDetailScreenState();
}

class _SocialWorkDetailScreenState
    extends ConsumerState<SocialWorkDetailScreen> {
  final _comment = TextEditingController();
  final _pager = PageController();
  final _commentsKey = GlobalKey();
  bool _busy = false;
  int _page = 0;
  int _mutationRevision = 0;
  final _commentOffsets = <int>[0];
  bool _initialCommentsOpened = false;
  (String, String, String)? _commentRequestFingerprint;
  String? _commentRequestId;
  DialogRoute<void>? _artworkRoute;
  List<String>? _viewerUrls;
  ValueNotifier<List<String>>? _viewerImageUrls;
  String? _viewerStatus;
  String? _viewerAuthorId;
  int _viewerRevision = 0;
  bool _openingTemplate = false;
  int _templateRevision = 0;
  @override
  void initState() {
    super.initState();
    _comment.addListener(_resetChangedCommentRequest);
  }

  void _resetChangedCommentRequest() {
    if (_commentRequestFingerprint != null &&
        _comment.text.trim() != _commentRequestFingerprint!.$3) {
      _commentRequestFingerprint = null;
      _commentRequestId = null;
    }
  }

  @override
  void didUpdateWidget(covariant SocialWorkDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workId != widget.workId) {
      _templateRevision++;
      _openingTemplate = false;
      _dismissArtworkViewer();
      _mutationRevision++;
      _busy = false;
      _comment.clear();
      _commentRequestFingerprint = null;
      _commentRequestId = null;
      _initialCommentsOpened = false;
      _page = 0;
      _commentOffsets
        ..clear()
        ..add(0);
      final workId = widget.workId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.workId == workId && _pager.hasClients) {
          _pager.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _templateRevision++;
    _dismissArtworkViewer();
    _comment.dispose();
    _pager.dispose();
    super.dispose();
  }

  bool _sameRequest(String actor, int revision) =>
      mounted &&
      revision == _mutationRevision &&
      ref.read(socialCurrentUserIdProvider) == actor;

  Future<void> _openSourceTemplate(SocialWork work) async {
    final source = work.sourceTemplate;
    if (_openingTemplate || source == null || !work.isPublished) return;
    // A retry should show its latest result immediately, rather than queue it
    // behind an error from the previous attempt.
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    final actor = ref.read(socialCurrentUserIdProvider);
    final revision = ++_templateRevision;
    final workId = widget.workId;
    bool current() =>
        mounted &&
        revision == _templateRevision &&
        widget.workId == workId &&
        ref.read(socialCurrentUserIdProvider) == actor &&
        ref.read(socialWorkProvider(workId)).value?.isPublished == true &&
        ref
                .read(socialWorkProvider(workId))
                .value
                ?.sourceTemplate
                ?.productKey ==
            source.productKey &&
        ModalRoute.of(context)?.isCurrent != false;
    setState(() => _openingTemplate = true);
    try {
      final fresh = await ref
          .read(socialRepositoryProvider)
          .resolveWorkTemplate(workId);
      if (!current()) return;
      if (fresh == null || fresh.productKey != source.productKey) {
        ref.invalidate(socialWorkProvider(workId));
        socialError(context, message: '지금은 이 작품의 템플릿을 이용할 수 없어요.');
        return;
      }
      final catalog = await ref.read(albumCreationCatalogProvider.future);
      if (!current()) return;
      final template = socialSourceCatalogTemplate(fresh, catalog);
      if (template == null) {
        ref.invalidate(socialWorkProvider(workId));
        socialError(context, message: '현재 제공 중인 템플릿을 찾지 못했어요.');
        return;
      }
      // The normal detail and checkout flow remains authoritative for price,
      // ownership and preparation of clean sample-free creation pages.
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          settings: WebAppRouteSettings(
            WebAppLocation(WebAppPage.template, '${template.id}'),
          ),
          builder: (_) => TemplateDetailScreen(template: template),
        ),
      );
    } catch (_) {
      if (current()) {
        socialError(context, message: '템플릿을 확인하지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && revision == _templateRevision) {
        setState(() => _openingTemplate = false);
      }
    }
  }

  void _refreshComments() {
    setState(
      () => _commentOffsets
        ..clear()
        ..add(0),
    );
    ref.invalidate(socialCommentsPageProvider);
    ref.invalidate(socialCommentsProvider(widget.workId));
  }

  Future<void> _mutate(
    Future<void> Function() write, {
    bool refreshComments = false,
  }) async {
    if (_busy) return;
    final actor = ref.read(socialCurrentUserIdProvider);
    final workId = widget.workId;
    final intentRevision = _mutationRevision;
    if (!await requireSocialLogin(context, ref) ||
        !mounted ||
        _busy ||
        actor == null ||
        intentRevision != _mutationRevision ||
        ref.read(socialCurrentUserIdProvider) != actor ||
        widget.workId != workId)
      return;
    final revision = ++_mutationRevision;
    setState(() => _busy = true);
    try {
      await write();
      if (_sameRequest(actor, revision)) {
        if (refreshComments) _refreshComments();
        invalidateSocial(ref, workId: widget.workId);
      }
    } catch (_) {
      if (_sameRequest(actor, revision)) {
        if (refreshComments) _refreshComments();
        invalidateSocial(ref, workId: widget.workId);
        socialError(context, message: '요청 결과를 확인하지 못했어요. 최신 상태를 다시 확인할게요.');
      }
    } finally {
      if (mounted && revision == _mutationRevision)
        setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    final actor = ref.read(socialCurrentUserIdProvider);
    final workId = widget.workId;
    final intentRevision = _mutationRevision;
    if (text.isEmpty ||
        _busy ||
        !await requireSocialLogin(context, ref) ||
        !mounted ||
        _busy ||
        actor == null ||
        intentRevision != _mutationRevision ||
        ref.read(socialCurrentUserIdProvider) != actor ||
        widget.workId != workId)
      return;
    final fingerprint = (actor, workId, text);
    if (_commentRequestFingerprint != fingerprint) {
      _commentRequestFingerprint = fingerprint;
      _commentRequestId = const Uuid().v4();
    }
    final requestId = _commentRequestId!;
    final revision = ++_mutationRevision;
    setState(() => _busy = true);
    try {
      await ref
          .read(socialRepositoryProvider)
          .addComment(workId, text, requestId: requestId);
      if (!_sameRequest(actor, revision)) return;
      _comment.clear();
      _commentRequestFingerprint = null;
      _commentRequestId = null;
      _refreshComments();
      invalidateSocial(ref, workId: workId);
    } catch (_) {
      if (_sameRequest(actor, revision)) {
        _refreshComments();
        invalidateSocial(ref, workId: workId);
        socialError(
          context,
          message: '전송 결과를 확인하지 못했어요. 작성한 내용으로 다시 시도할 수 있어요.',
        );
      }
    } finally {
      if (mounted && revision == _mutationRevision)
        setState(() => _busy = false);
    }
  }

  void _openComments() {
    final section = _commentsKey.currentContext;
    if (section != null)
      Scrollable.ensureVisible(
        section,
        duration: const Duration(milliseconds: 200),
      );
  }

  void _dismissArtworkViewer() {
    _viewerRevision++;
    final route = _artworkRoute;
    _artworkRoute = null;
    _viewerUrls = null;
    _viewerImageUrls = null;
    _viewerStatus = null;
    _viewerAuthorId = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (navigator != null && route.isActive) navigator.removeRoute(route);
    });
  }

  bool _sameArtworkAssets(List<String>? previous, List<String> next) {
    if (previous == null || previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      if (previous[index] == next[index]) continue;
      final before = Uri.tryParse(previous[index]);
      final after = Uri.tryParse(next[index]);
      if (before == null ||
          after == null ||
          !const ['http', 'https'].contains(before.scheme) ||
          before.scheme != after.scheme ||
          before.host != after.host ||
          before.port != after.port ||
          before.userInfo != after.userInfo ||
          before.path != after.path) {
        return false;
      }
    }
    return true;
  }

  void _updateArtworkViewer(SocialWork work) {
    final route = _artworkRoute;
    if (route == null) return;
    if (work.id != widget.workId ||
        _viewerStatus != work.status ||
        _viewerAuthorId != work.author.userId ||
        !_sameArtworkAssets(_viewerUrls, work.imageUrls)) {
      _dismissArtworkViewer();
      return;
    }
    if (listEquals(_viewerUrls, work.imageUrls)) return;
    final urls = List<String>.unmodifiable(work.imageUrls);
    final imageUrls = _viewerImageUrls!;
    final revision = _viewerRevision;
    _viewerUrls = urls;
    // The overlay is outside this build subtree. Update it after this frame
    // while retaining its page, transformation and image recovery state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          revision == _viewerRevision &&
          identical(_artworkRoute, route) &&
          identical(_viewerImageUrls, imageUrls) &&
          identical(_viewerUrls, urls)) {
        imageUrls.value = urls;
      }
    });
  }

  void _openArtworkViewer(SocialWork work) {
    if (_artworkRoute != null || work.imageUrls.isEmpty) return;
    final actor = ref.read(socialCurrentUserIdProvider);
    if (widget.workId != work.id ||
        (!work.isPublished && actor != work.author.userId)) {
      return;
    }
    final revision = ++_viewerRevision;
    final initialPage = _page.clamp(0, work.imageUrls.length - 1).toInt();
    final urls = List<String>.unmodifiable(work.imageUrls);
    final imageUrls = ValueNotifier<List<String>>(urls);
    _viewerUrls = urls;
    _viewerImageUrls = imageUrls;
    _viewerStatus = work.status;
    _viewerAuthorId = work.author.userId;
    final route = DialogRoute<void>(
      context: context,
      useSafeArea: false,
      builder: (context) => ValueListenableBuilder<List<String>>(
        valueListenable: imageUrls,
        builder: (context, urls, _) => _ArtworkViewer(
          workId: work.id,
          title: work.title,
          urls: urls,
          initialPage: initialPage,
          onPageChanged: (page) {
            if (!mounted ||
                revision != _viewerRevision ||
                widget.workId != work.id ||
                ref.read(socialCurrentUserIdProvider) != actor) {
              return;
            }
            setState(() => _page = page);
            if (_pager.hasClients) _pager.jumpToPage(page);
          },
          onRetry: () {
            if (mounted &&
                revision == _viewerRevision &&
                widget.workId == work.id &&
                ref.read(socialCurrentUserIdProvider) == actor) {
              ref.invalidate(socialWorkProvider(work.id));
            }
          },
        ),
      ),
    );
    _artworkRoute = route;
    Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
      if (identical(_artworkRoute, route)) {
        _artworkRoute = null;
        _viewerUrls = null;
        _viewerImageUrls = null;
        _viewerStatus = null;
        _viewerAuthorId = null;
      }
    });
    route.completed.then((_) => imageUrls.dispose());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next) {
        _templateRevision++;
        _openingTemplate = false;
        _dismissArtworkViewer();
        _comment.clear();
        _commentRequestFingerprint = null;
        _commentRequestId = null;
        _mutationRevision++;
        _commentOffsets
          ..clear()
          ..add(0);
        if (mounted && _busy) setState(() => _busy = false);
      }
    });
    final result = ref.watch(socialWorkProvider(widget.workId));
    return SocialWebFrame(
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: AppBar(title: const Text('작품')),
        body: result.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: SocialLoading()),
          error: (_, _) {
            _dismissArtworkViewer();
            return SocialFailure(
              onRetry: () => ref.invalidate(socialWorkProvider(widget.workId)),
            );
          },
          data: (work) {
            if (work == null) {
              _dismissArtworkViewer();
              return _unavailable();
            }
            return _body(work);
          },
        ),
      ),
    );
  }

  Widget _unavailable() => const SocialContent(
    child: SocialEmpty(
      title: '현재 볼 수 없는 작품이에요.',
      message: '공개가 종료되었거나 접근할 수 없는 작품이에요.',
    ),
  );

  Widget _body(SocialWork w) {
    final own = ref.watch(socialCurrentUserIdProvider) == w.author.userId;
    final source = w.sourceTemplate;
    final catalog = source == null
        ? null
        : ref.watch(albumCreationCatalogProvider).value;
    final hasSource =
        w.isPublished &&
        socialSourceCatalogTemplate(source, catalog ?? const []) != null;
    if (!w.isPublished && !own) {
      _dismissArtworkViewer();
      return _unavailable();
    }
    _updateArtworkViewer(w);
    final page = w.imageUrls.isEmpty
        ? 0
        : _page.clamp(0, w.imageUrls.length - 1).toInt();
    if (page != _page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.workId != w.id) return;
        setState(() => _page = page);
        if (_pager.hasClients) _pager.jumpToPage(page);
      });
    }
    if (widget.showComments && w.isPublished && !_initialCommentsOpened) {
      _initialCommentsOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openComments();
      });
    }
    return SocialContent(
      maxWidth: 1120,
      child: RefreshIndicator(
        onRefresh: () async {
          _refreshComments();
          ref.invalidate(socialWorkProvider(w.id));
          try {
            await ref.read(socialWorkProvider(w.id).future);
          } catch (_) {
            // The provider presents the retry state in the screen.
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final inset = wide ? 24.0 : 16.0;
            return SingleChildScrollView(
              key: ValueKey('social-work-scroll-${w.id}'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(inset, wide ? 12 : 0, inset, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Tooltip(
                    message: '작가 프로필 보기',
                    child: Semantics(
                      button: true,
                      label: '${w.author.displayName} 작가 프로필 보기',
                      onTap: () => openSocialProfile(context, w.author.userId),
                      child: ExcludeSemantics(
                        child: SocialAuthorLine(
                          author: w.author,
                          onTap: () =>
                              openSocialProfile(context, w.author.userId),
                        ),
                      ),
                    ),
                  ),
                  if (!w.isPublished) ...[
                    const SizedBox(height: 4),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: SocialStyle.paper(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          '비공개 보관 · 나만 보는 작품',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: SocialStyle.accent(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, artwork) => Container(
                      key: ValueKey('social-detail-artwork-${w.id}'),
                      height: socialArtworkHeight(
                        artwork.maxWidth,
                        w.aspectRatio,
                      ),
                      decoration: BoxDecoration(
                        color: SocialStyle.paper(context),
                        borderRadius: BorderRadius.circular(wide ? 22 : 16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: w.imageUrls.isEmpty
                          ? const SocialArtworkPlaceholder()
                          : PageView.builder(
                              key: ValueKey('social-detail-pages-${w.id}'),
                              controller: _pager,
                              itemCount: w.imageUrls.length,
                              onPageChanged: (index) =>
                                  setState(() => _page = index),
                              itemBuilder: (context, index) => SocialWorkImage(
                                key: ValueKey((w.id, index)),
                                url: w.imageUrls[index],
                                label: '${w.title} ${index + 1}번째 공개 페이지',
                                onRetry: () =>
                                    ref.invalidate(socialWorkProvider(w.id)),
                              ),
                            ),
                    ),
                  ),
                  if (w.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _artworkControls(w, page),
                  ],
                  SizedBox(height: wide ? 28 : 22),
                  Semantics(
                    header: true,
                    child: Text(
                      w.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontSize: wide ? 38 : 29,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            letterSpacing: -.9,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SocialWorkMetadata(work: w),
                  if (w.isPublished) ...[
                    const SizedBox(height: 16),
                    SocialReactions(
                      work: w,
                      busy: _busy,
                      onLike: () => _mutate(
                        () => ref
                            .read(socialRepositoryProvider)
                            .setLiked(w.id, !w.isLiked),
                      ),
                      onSave: () => _mutate(
                        () => ref
                            .read(socialRepositoryProvider)
                            .setSaved(w.id, !w.isSaved),
                      ),
                      onComments: _openComments,
                    ),
                  ],
                  if (w.caption.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    Text(
                      '작가의 기록',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SocialStyle.accent(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Text(
                          w.caption,
                          style: const TextStyle(fontSize: 16, height: 1.85),
                        ),
                      ),
                    ),
                  ],
                  if (own) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => openSocialManage(context),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('내 공개 작품 관리'),
                      ),
                    ),
                  ],
                  if (hasSource) ...[
                    const SizedBox(height: 28),
                    SocialTemplateStartCard(
                      source: source!,
                      busy: _openingTemplate,
                      onPressed: () => _openSourceTemplate(w),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Divider(height: 1, color: SocialStyle.line(context)),
                  if (w.isPublished) _comments(w),
                  const SizedBox(height: 28),
                  Text(
                    '선택해 공개한 페이지만 표시돼요. 원본 앨범은 별도로 보관돼요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.7,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _artworkControls(SocialWork work, int page) => LayoutBuilder(
    builder: (context, constraints) {
      final navigation = Row(
        children: [
          IconButton(
            tooltip: '이전 공개 페이지',
            onPressed: page <= 0
                ? null
                : () => _pager.previousPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  ),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                '${page + 1} / ${work.imageUrls.length}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '다음 공개 페이지',
            onPressed: page >= work.imageUrls.length - 1
                ? null
                : () => _pager.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          ),
        ],
      );
      final expand = Tooltip(
        message: '작품 크게 보기',
        child: TextButton.icon(
          onPressed: () => _openArtworkViewer(work),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            foregroundColor: SocialStyle.ink(context),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(Icons.open_in_full, size: 17),
          label: const Text('확대 감상'),
        ),
      );
      if (constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(13) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            navigation,
            Align(alignment: Alignment.centerRight, child: expand),
          ],
        );
      }
      return Row(
        children: [
          SizedBox(width: 180, child: navigation),
          const Spacer(),
          expand,
        ],
      );
    },
  );

  Widget _comments(SocialWork work) {
    final first = ref.watch(
      socialCommentsPageProvider(SocialCommentsQuery(work.id)),
    );
    return Padding(
      key: _commentsKey,
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              '이 작품에 남긴 이야기',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -.3,
              ),
            ),
          ),
          const SizedBox(height: 18),
          first.when(
            skipLoadingOnRefresh: true,
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => TextButton(
              onPressed: _refreshComments,
              child: const Text('댓글 다시 불러오기'),
            ),
            data: (_) => _commentPages(work),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            maxLength: 300,
            minLines: 1,
            maxLines: 4,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: '작품에 이야기 남기기',
              hintText: '서로의 기록을 존중해 주세요.',
              filled: true,
              fillColor: SocialStyle.paper(context),
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: SocialStyle.line(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: SocialStyle.line(context)),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _send,
              style: SocialStyle.primary(context),
              child: const Text('댓글 남기기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentPages(SocialWork work) {
    final user = ref.watch(socialCurrentUserIdProvider);
    final pages = [
      for (final offset in _commentOffsets)
        ref.watch(
          socialCommentsPageProvider(
            SocialCommentsQuery(work.id, offset: offset),
          ),
        ),
    ];
    final seen = <String>{};
    final newest = <SocialComment>[];
    for (final page in pages) {
      final data = page.whenOrNull(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: false,
        data: (value) => value,
      );
      for (final comment in data?.items ?? const <SocialComment>[]) {
        if (seen.add(comment.id)) newest.add(comment);
      }
    }
    final lastQuery = SocialCommentsQuery(
      work.id,
      offset: _commentOffsets.last,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 1; index < pages.length; index++)
          pages[index].when(
            skipLoadingOnRefresh: true,
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(
                socialCommentsPageProvider(
                  SocialCommentsQuery(work.id, offset: _commentOffsets[index]),
                ),
              ),
              child: const Text('이전 댓글 다시 불러오기'),
            ),
            data: (_) => const SizedBox.shrink(),
          ),
        pages.last.when(
          skipLoadingOnRefresh: true,
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (page) => page.hasMore && page.nextOffset > lastQuery.offset
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      if (_commentOffsets.last != lastQuery.offset ||
                          _commentOffsets.contains(page.nextOffset))
                        return;
                      setState(() => _commentOffsets.add(page.nextOffset));
                    },
                    icon: const Icon(Icons.expand_less_rounded),
                    label: const Text('이전 댓글 더 보기'),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (newest.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '첫 이야기를 남겨보세요.',
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: SnapFitColors.textSecondaryOf(context),
              ),
            ),
          ),
        for (final comment in newest.reversed)
          ListTile(
            key: ValueKey('social-comment-${comment.id}'),
            contentPadding: EdgeInsets.zero,
            title: TextButton(
              onPressed: () =>
                  openSocialProfile(context, comment.author.userId),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              child: Text(comment.author.displayName),
            ),
            subtitle: Text(comment.body, style: const TextStyle(height: 1.7)),
            trailing: user == comment.author.userId
                ? IconButton(
                    tooltip: '내 댓글 삭제',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _busy
                        ? null
                        : () => _mutate(
                            () => ref
                                .read(socialRepositoryProvider)
                                .deleteComment(comment.id),
                            refreshComments: true,
                          ),
                  )
                : null,
          ),
      ],
    );
  }
}

class _ArtworkViewer extends StatefulWidget {
  const _ArtworkViewer({
    required this.workId,
    required this.title,
    required this.urls,
    required this.initialPage,
    required this.onPageChanged,
    required this.onRetry,
  });

  final String workId;
  final String title;
  final List<String> urls;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onRetry;

  @override
  State<_ArtworkViewer> createState() => _ArtworkViewerState();
}

class _ArtworkViewerState extends State<_ArtworkViewer> {
  late final PageController _pager;
  final _transformation = TransformationController();
  late int _page;
  double _scale = 1;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _pager = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pager.dispose();
    _transformation.dispose();
    super.dispose();
  }

  void _changePage(int page) {
    _transformation.value = Matrix4.identity();
    setState(() {
      _page = page;
      _scale = 1;
    });
    widget.onPageChanged(page);
  }

  void _turnPage(int delta) {
    final next = _page + delta;
    if (next < 0 || next >= widget.urls.length || !_pager.hasClients) return;
    _pager.animateToPage(
      next,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _zoom(double factor) {
    final next = (_transformation.value.getMaxScaleOnAxis() * factor)
        .clamp(1.0, 4.0)
        .toDouble();
    _transformation.value = Matrix4.diagonal3Values(next, next, 1)
      ..setTranslationRaw(
        (1 - next) * _viewport.width / 2,
        (1 - next) * _viewport.height / 2,
        0,
      );
    setState(() => _scale = next);
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        brightness: Brightness.dark,
        colorScheme: base.colorScheme.copyWith(
          brightness: Brightness.dark,
          surface: const Color(0xff111714),
          onSurface: Colors.white,
          primary: SnapFitColors.actionAccent,
          onPrimary: SnapFitColors.onAccent,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      child: Dialog.fullscreen(
        key: ValueKey('social-artwork-viewer-${widget.workId}'),
        backgroundColor: const Color(0xff111714),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '확대 감상 닫기',
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewport = constraints.biggest;
                    return PageView.builder(
                      controller: _pager,
                      itemCount: widget.urls.length,
                      physics: _scale > 1.01
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      onPageChanged: _changePage,
                      itemBuilder: (context, index) => InteractiveViewer(
                        key: ValueKey('social-fullscreen-artwork-$index'),
                        transformationController: _transformation,
                        minScale: 1,
                        maxScale: 4,
                        onInteractionEnd: (_) => setState(
                          () => _scale = _transformation.value
                              .getMaxScaleOnAxis(),
                        ),
                        child: SizedBox.expand(
                          child: SocialWorkImage(
                            key: ValueKey((widget.workId, index)),
                            url: widget.urls[index],
                            label:
                                '${widget.title} ${index + 1}번째 공개 페이지 확대 감상',
                            onRetry: widget.onRetry,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: '이전 확대 페이지',
                          color: Colors.white,
                          disabledColor: Colors.white30,
                          onPressed: _page == 0 ? null : () => _turnPage(-1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              '${_page + 1} / ${widget.urls.length}',
                              key: const ValueKey(
                                'social-fullscreen-page-count',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '다음 확대 페이지',
                          color: Colors.white,
                          disabledColor: Colors.white30,
                          onPressed: _page == widget.urls.length - 1
                              ? null
                              : () => _turnPage(1),
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: '작품 축소',
                          color: Colors.white,
                          disabledColor: Colors.white30,
                          onPressed: _scale <= 1.01
                              ? null
                              : () => _zoom(1 / 1.5),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Flexible(
                          child: Semantics(
                            liveRegion: true,
                            label: '확대 비율',
                            value: '${(_scale * 100).round()}%',
                            child: ExcludeSemantics(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  '${(_scale * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '작품 확대',
                          color: Colors.white,
                          disabledColor: Colors.white30,
                          onPressed: _scale >= 3.99 ? null : () => _zoom(1.5),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

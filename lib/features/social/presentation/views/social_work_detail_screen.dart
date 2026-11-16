import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../album/data/album_creation_catalog_provider.dart';
import '../../../moments/presentation/providers/moments_providers.dart';
import '../../../moments/presentation/views/moment_compose_screen.dart';
import '../../../store/presentation/views/template_detail_screen.dart';
import '../../data/social_template_catalog.dart';
import '../../data/social_repository.dart'
    show SocialActionException, socialActionMessage;
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../social_actions.dart';
import '../social_navigation.dart';
import '../widgets/social_widgets.dart';
import '../widgets/social_web_frame.dart';
import '../widgets/social_page_header.dart';
import '../widgets/social_template_start_card.dart';
import '../widgets/social_report_sheet.dart';
import '../widgets/social_snapshot_identity.dart';
import '../widgets/social_comment_widgets.dart';
import '../widgets/social_work_share_sheet.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

class SocialWorkDetailScreen extends ConsumerStatefulWidget {
  const SocialWorkDetailScreen({
    super.key,
    required this.workId,
    this.showComments = false,
    this.initialPage = 0,
  });
  final String workId;
  final bool showComments;
  final int initialPage;
  @override
  ConsumerState<SocialWorkDetailScreen> createState() =>
      _SocialWorkDetailScreenState();
}

class _SocialWorkDetailScreenState
    extends ConsumerState<SocialWorkDetailScreen> {
  final _comment = TextEditingController();
  final _commentFocus = FocusNode();
  final _composerKey = GlobalKey();
  late final PageController _pager;
  final _commentsKey = GlobalKey();
  bool _busy = false;
  bool _sharing = false;
  bool _sendingComment = false;
  int _page = 0;
  int _mutationRevision = 0;

  Future<void> _share(SocialWork work) async {
    if (_sharing) return;
    final revision = _mutationRevision;
    setState(() => _sharing = true);
    try {
      await showSocialWorkShareSheet(
        context,
        work: work,
        initialPage: _page,
        isActive: () =>
            mounted &&
            revision == _mutationRevision &&
            widget.workId == work.id &&
            sameSocialWorkShareSnapshot(
              work,
              ref.read(socialWorkProvider(work.id)).asData?.value,
            ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  final _commentOffsets = <int>[0];
  bool _initialCommentsOpened = false;
  (String, String, String, String?)? _commentRequestFingerprint;
  String? _commentRequestId;
  SocialComment? _replyTarget;
  Timer? _mentionDebounce;
  int _mentionRevision = 0;
  TextRange? _mentionRange;
  String? _mentionQuery;
  List<SocialProfile> _mentionSuggestions = const [];
  bool _mentionLoading = false;
  bool _mentionFailed = false;
  bool _composerUpdateQueued = false;
  DialogRoute<void>? _artworkRoute;
  List<String>? _viewerUrls;
  ValueNotifier<List<String>>? _viewerImageUrls;
  String? _viewerStatus;
  String? _viewerAuthorId;
  int _viewerRevision = 0;
  bool _openingTemplate = false;
  int _templateRevision = 0;
  DialogRoute<bool>? _privateDialogRoute;
  @override
  void initState() {
    super.initState();
    _page = widget.initialPage < 0 ? 0 : widget.initialPage;
    _pager = PageController(initialPage: _page);
    _comment.addListener(_resetChangedCommentRequest);
    _commentFocus.addListener(_queueComposerUpdate);
  }

  void _resetChangedCommentRequest() {
    if (_commentRequestFingerprint != null &&
        _comment.text.trim() != _commentRequestFingerprint!.$3) {
      _commentRequestFingerprint = null;
      _commentRequestId = null;
    }
    _queueComposerUpdate();
  }

  void _queueComposerUpdate() {
    if (_composerUpdateQueued) return;
    _composerUpdateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composerUpdateQueued = false;
      if (mounted) _updateMentionQuery();
    });
  }

  void _clearMentionSearch() {
    _mentionDebounce?.cancel();
    _mentionRevision++;
    _mentionRange = null;
    _mentionQuery = null;
    _mentionSuggestions = const [];
    _mentionLoading = false;
    _mentionFailed = false;
  }

  List<SocialProfile> _knownMentionProfiles(String query) {
    final found = <String, SocialProfile>{};
    void add(SocialProfile profile) {
      if (profile.handle.toLowerCase().startsWith(query)) {
        found[profile.userId] = profile;
      }
    }

    final work = ref.read(socialWorkProvider(widget.workId)).asData?.value;
    if (work != null) add(work.author);
    if (_replyTarget != null) add(_replyTarget!.author);
    for (final offset in _commentOffsets) {
      final page = ref
          .read(
            socialCommentsPageProvider(
              SocialCommentsQuery(widget.workId, offset: offset),
            ),
          )
          .asData
          ?.value;
      for (final comment in page?.items ?? const <SocialComment>[]) {
        add(comment.author);
      }
    }
    return found.values.take(5).toList();
  }

  void _updateMentionQuery({bool force = false}) {
    final token = _commentFocus.hasFocus && !_busy
        ? socialMentionToken(_comment.value)
        : null;
    if (token == null) {
      setState(_clearMentionSearch);
      return;
    }
    final query = token.query;
    final range = token.range;
    if (!force && query == _mentionQuery && range == _mentionRange) {
      setState(() {});
      return;
    }
    _mentionDebounce?.cancel();
    final revision = ++_mentionRevision;
    final actor = ref.read(socialCurrentUserIdProvider);
    final workId = widget.workId;
    setState(() {
      _mentionQuery = query;
      _mentionRange = range;
      _mentionSuggestions = _knownMentionProfiles(query);
      _mentionLoading = query.isNotEmpty;
      _mentionFailed = false;
    });
    if (query.isEmpty) return;
    _mentionDebounce = Timer(const Duration(milliseconds: 240), () async {
      bool current() =>
          mounted &&
          revision == _mentionRevision &&
          workId == widget.workId &&
          actor == ref.read(socialCurrentUserIdProvider) &&
          _commentFocus.hasFocus;
      try {
        final profiles = await ref
            .read(socialRepositoryProvider)
            .searchProfiles(query);
        if (!current()) return;
        final unique = <String, SocialProfile>{
          for (final profile in _knownMentionProfiles(query))
            profile.userId: profile,
          for (final profile in profiles) profile.userId: profile,
        };
        setState(() {
          _mentionSuggestions = unique.values.take(5).toList();
          _mentionLoading = false;
          _mentionFailed = false;
        });
      } catch (_) {
        if (!current()) return;
        setState(() {
          _mentionLoading = false;
          _mentionFailed = true;
        });
      }
    });
  }

  void _selectMention(SocialProfile profile) {
    final token = socialMentionToken(_comment.value);
    if (token == null ||
        token.query != _mentionQuery ||
        token.range != _mentionRange) {
      _queueComposerUpdate();
      return;
    }
    final range = token.range;
    final trailing = _comment.text.substring(range.end);
    final replacement = '@${profile.handle}${trailing.isEmpty ? ' ' : ''}';
    final text = _comment.text.replaceRange(
      range.start,
      range.end,
      replacement,
    );
    if (text.characters.length > 300) return;
    _comment.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset:
            range.start +
            replacement.length +
            (trailing.startsWith(' ') ? 1 : 0),
      ),
    );
    setState(_clearMentionSearch);
    _commentFocus.requestFocus();
  }

  void _replyTo(SocialComment comment) {
    if (_busy) return;
    setState(() {
      if (_replyTarget?.id != comment.id) {
        _commentRequestFingerprint = null;
        _commentRequestId = null;
      }
      _replyTarget = comment;
    });
    _commentFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final composer = _composerKey.currentContext;
      if (mounted && composer != null) {
        Scrollable.ensureVisible(
          composer,
          alignment: 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _cancelReply() => setState(() {
    _replyTarget = null;
    _commentRequestFingerprint = null;
    _commentRequestId = null;
  });

  @override
  void didUpdateWidget(covariant SocialWorkDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workId != widget.workId) {
      _templateRevision++;
      _openingTemplate = false;
      _dismissArtworkViewer();
      _dismissPrivateDialog();
      _mutationRevision++;
      _busy = false;
      _sendingComment = false;
      _comment.clear();
      _commentRequestFingerprint = null;
      _commentRequestId = null;
      _replyTarget = null;
      _clearMentionSearch();
      _initialCommentsOpened = false;
      _page = widget.initialPage < 0 ? 0 : widget.initialPage;
      _commentOffsets
        ..clear()
        ..add(0);
      final workId = widget.workId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.workId == workId && _pager.hasClients) {
          _pager.jumpToPage(_page);
        }
      });
    }
  }

  @override
  void dispose() {
    _templateRevision++;
    _dismissArtworkViewer();
    _dismissPrivateDialog();
    _mentionDebounce?.cancel();
    _commentFocus.dispose();
    _comment.dispose();
    _pager.dispose();
    super.dispose();
  }

  bool _sameRequest(String actor, int revision) =>
      mounted &&
      revision == _mutationRevision &&
      ref.read(socialCurrentUserIdProvider) == actor;

  void _dismissPrivateDialog() {
    final route = _privateDialogRoute;
    _privateDialogRoute = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  bool _currentOwnerMoment(SocialWork work, String actor, int revision) {
    final latest = ref.read(socialWorkProvider(work.id)).asData?.value;
    return _sameRequest(actor, revision) &&
        widget.workId == work.id &&
        latest?.isMoment == true &&
        latest?.isPublished == true &&
        latest?.author.userId == actor &&
        latest?.publicationRevision == work.publicationRevision;
  }

  Future<void> _makeMomentPrivate(SocialWork work) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (_busy ||
        actor == null ||
        !work.isMoment ||
        !work.isPublished ||
        work.author.userId != actor)
      return;
    final publicationRevision = work.publicationRevision;
    if (publicationRevision == null) {
      ref.invalidate(socialWorkProvider(work.id));
      socialError(context, message: '공개 상태를 새로 확인한 뒤 다시 눌러 주세요.');
      return;
    }
    final revision = ++_mutationRevision;
    setState(() {
      _busy = true;
      _clearMentionSearch();
    });
    try {
      final route = DialogRoute<bool>(
        context: context,
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            ref.watch(socialCurrentUserIdProvider);
            ref.watch(socialWorkProvider(work.id));
            if (!_currentOwnerMoment(work, actor, revision)) {
              _dismissPrivateDialog();
              return const SizedBox.shrink();
            }
            return AlertDialog(
              title: const Text('나만 보는 기록으로 바꿀까요?'),
              content: const Text('피드와 공개 프로필에서 내려가요. 내 사진과 월간 앨범은 그대로 남아요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  key: const ValueKey('social-moment-private-confirm'),
                  onPressed: () => Navigator.pop(context, true),
                  style: SocialStyle.primary(context),
                  child: const Text('나만 보기로 바꾸기'),
                ),
              ],
            );
          },
        ),
      );
      _privateDialogRoute = route;
      final confirmed = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      if (identical(_privateDialogRoute, route)) _privateDialogRoute = null;
      if (confirmed != true || !_currentOwnerMoment(work, actor, revision))
        return;
      await ref
          .read(socialRepositoryProvider)
          .setMomentPublicationVisibility(
            work.id,
            false,
            expectedPublicationRevision: publicationRevision,
          );
      if (!_sameRequest(actor, revision)) return;
      _dismissArtworkViewer();
      invalidateSocial(ref, workId: work.id);
      final fresh = await ref.read(socialWorkProvider(work.id).future);
      if (!_sameRequest(actor, revision)) return;
      if (fresh?.isPublished == true) {
        throw StateError('publication_changed');
      }
      socialError(context, message: '나만 보는 기록으로 바꿨어요.');
    } catch (error) {
      if (_sameRequest(actor, revision)) {
        invalidateSocial(ref, workId: work.id);
        socialError(
          context,
          message: socialActionMessage(
            error,
            fallback: '공개 상태를 확인하지 못했어요. 최신 상태를 확인한 뒤 다시 시도해 주세요.',
          ),
        );
      }
    } finally {
      if (mounted && revision == _mutationRevision)
        setState(() => _busy = false);
    }
  }

  Future<void> _editMoment(SocialWork work) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (_busy || actor == null || !work.isMoment || work.author.userId != actor)
      return;
    final revision = ++_mutationRevision;
    setState(() {
      _busy = true;
      _clearMentionSearch();
    });
    try {
      final record = await ref
          .read(socialRepositoryProvider)
          .fetchOwnMomentRecord(work.id);
      if (!_sameRequest(actor, revision)) return;
      if (record == null || ref.read(momentsCurrentUserIdProvider) != actor) {
        socialError(
          context,
          message: '원본 기록을 확인하지 못했어요. 최신 상태를 확인한 뒤 다시 눌러 주세요.',
        );
        return;
      }
      await Navigator.of(context).push<Object?>(
        snapFitRoute(page: MomentComposeScreen(record: record)),
      );
      if (!_sameRequest(actor, revision)) return;
      ref.invalidate(momentsMonthProvider);
      ref.invalidate(momentDraftsProvider);
      ref.invalidate(momentDraftSummariesForOwnerProvider(actor));
      invalidateSocial(ref, workId: work.id);
    } catch (error) {
      if (_sameRequest(actor, revision)) {
        socialError(
          context,
          message: socialActionMessage(
            error,
            fallback: '원본 기록을 불러오지 못했어요. 다시 시도해 주세요.',
          ),
        );
      }
    } finally {
      if (mounted && revision == _mutationRevision)
        setState(() => _busy = false);
    }
  }

  Future<void> _report(SocialWork work, {SocialComment? comment}) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    final revision = _mutationRevision;
    final workId = widget.workId;
    if (!work.isPublished ||
        actor == (comment?.author.userId ?? work.author.userId) ||
        !await requireSocialLogin(context, ref) ||
        actor == null ||
        !_sameRequest(actor, revision) ||
        widget.workId != workId)
      return;
    final sent = await showSocialReportSheet(
      context,
      title: comment == null ? (work.isMoment ? '기록 신고' : '앨범 신고') : '댓글 신고',
      ownerId: actor,
      onSubmit: (reason, detail, requestId) async {
        if (!_sameRequest(actor, revision) || widget.workId != workId) {
          throw StateError('report_target_changed');
        }
        await ref
            .read(socialRepositoryProvider)
            .reportContent(
              targetKind: comment == null ? 'work' : 'comment',
              targetId: comment?.id ?? work.id,
              reason: reason,
              details: detail,
              requestId: requestId,
            );
      },
    );
    if (sent && _sameRequest(actor, revision))
      socialError(context, message: '신고를 접수했어요. 운영자가 확인할게요.');
  }

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
        socialError(context, message: '지금은 이 앨범의 템플릿을 이용할 수 없어요.');
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
        snapFitRoute<void>(page: TemplateDetailScreen(template: template), settings: WebAppRouteSettings(
            WebAppLocation(WebAppPage.template, '${template.id}'),
          )),
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
    setState(() {
      _busy = true;
      _clearMentionSearch();
    });
    try {
      await write();
      if (_sameRequest(actor, revision)) {
        if (refreshComments) _refreshComments();
        invalidateSocial(ref, workId: widget.workId);
      }
    } catch (error) {
      if (_sameRequest(actor, revision)) {
        if (refreshComments) _refreshComments();
        invalidateSocial(ref, workId: widget.workId);
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

  Future<void> _deleteComment(SocialComment comment) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    final workId = widget.workId;
    final revision = _mutationRevision;
    await _mutate(() async {
      await ref.read(socialRepositoryProvider).deleteComment(comment.id);
      if (!mounted ||
          widget.workId != workId ||
          ref.read(socialCurrentUserIdProvider) != actor ||
          _mutationRevision != revision + 1) {
        return;
      }
      if (_replyTarget?.id == comment.id ||
          _replyTarget?.rootCommentId == comment.id) {
        _cancelReply();
      }
    }, refreshComments: true);
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    final parentCommentId = _replyTarget?.id;
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
        widget.workId != workId ||
        _replyTarget?.id != parentCommentId ||
        _comment.text.trim() != text)
      return;
    final fingerprint = (actor, workId, text, parentCommentId);
    if (_commentRequestFingerprint != fingerprint) {
      _commentRequestFingerprint = fingerprint;
      _commentRequestId = const Uuid().v4();
    }
    final requestId = _commentRequestId!;
    final revision = ++_mutationRevision;
    setState(() {
      _busy = true;
      _sendingComment = true;
      _clearMentionSearch();
    });
    try {
      final repository = ref.read(socialRepositoryProvider);
      if (parentCommentId == null) {
        await repository.addComment(workId, text, requestId: requestId);
      } else {
        await repository.addComment(
          workId,
          text,
          requestId: requestId,
          parentCommentId: parentCommentId,
        );
      }
      if (!_sameRequest(actor, revision)) return;
      _comment.clear();
      _commentRequestFingerprint = null;
      _commentRequestId = null;
      _replyTarget = null;
      _clearMentionSearch();
      _refreshComments();
      invalidateSocial(ref, workId: workId);
    } catch (error) {
      if (_sameRequest(actor, revision)) {
        if (error is SocialActionException &&
            error.code == 'social_comment_parent_unavailable' &&
            _replyTarget?.id == parentCommentId) {
          _cancelReply();
        }
        _refreshComments();
        invalidateSocial(ref, workId: workId);
        socialError(
          context,
          message: socialActionMessage(
            error,
            fallback: '전송 결과를 확인하지 못했어요. 작성한 내용으로 다시 시도할 수 있어요.',
          ),
        );
      }
    } finally {
      if (mounted && revision == _mutationRevision)
        setState(() {
          _busy = false;
          _sendingComment = false;
        });
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
    return previous != null &&
        listEquals(
          previous.map(socialSnapshotIdentity).toList(),
          next.map(socialSnapshotIdentity).toList(),
        );
  }

  void _updateArtworkViewer(SocialWork work) {
    final route = _artworkRoute;
    if (route == null) return;
    if (work.isRestricted ||
        work.id != widget.workId ||
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
    if (_artworkRoute != null || work.isRestricted || work.imageUrls.isEmpty)
      return;
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
        _dismissPrivateDialog();
        _comment.clear();
        _commentRequestFingerprint = null;
        _commentRequestId = null;
        _replyTarget = null;
        _clearMentionSearch();
        _mutationRevision++;
        _commentOffsets
          ..clear()
          ..add(0);
        if (mounted && _busy) {
          setState(() {
            _busy = false;
            _sendingComment = false;
          });
        }
      }
    });
    final result = ref.watch(socialWorkProvider(widget.workId));
    return SocialWebFrame(
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: SocialPageHeader(
          title: result.value == null
              ? '기록·앨범'
              : result.value!.isMoment
              ? '한 장의 기록'
              : '앨범',
          actions: [
            if (result.asData?.value case final work?)
              if (work.isPublished && !work.isRestricted)
                IconButton(
                  key: const ValueKey('social-work-share'),
                  tooltip: '공유',
                  onPressed: _sharing ? null : () => _share(work),
                  icon: const ExperienceIcon('Share2'),
                ),
            if (result.asData?.value case final work?)
              if (work.isPublished &&
                  ref.watch(socialCurrentUserIdProvider) != work.author.userId)
                IconButton(
                  key: const ValueKey('social-work-report'),
                  tooltip: work.isMoment ? '기록 신고' : '앨범 신고',
                  onPressed: () => _report(work),
                  icon: const ExperienceIcon('Flag'),
                ),
          ],
        ),
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
      title: '현재 볼 수 없는 기록·앨범이에요.',
      message: '공개가 종료되었거나 접근할 수 없는 기록·앨범이에요.',
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
        !w.isRestricted &&
        socialSourceCatalogTemplate(source, catalog ?? const []) != null;
    if ((!w.isPublished || w.isRestricted) && !own) {
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
    if (widget.showComments &&
        w.isPublished &&
        !w.isRestricted &&
        !_initialCommentsOpened) {
      _initialCommentsOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openComments();
      });
    }
    return SocialContent(
      maxWidth: 820,
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
                          compact: true,
                          onTap: () =>
                              openSocialProfile(context, w.author.userId),
                        ),
                      ),
                    ),
                  ),
                  if (w.isRestricted || !w.isPublished) ...[
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
                          w.isRestricted
                              ? '공개가 제한된 ${w.isMoment ? '기록' : '앨범'}이에요. 원본은 그대로 보관돼요.'
                              : w.isMoment
                              ? '비공개 보관 · 나만 보는 기록'
                              : '비공개 보관 · 나만 보는 앨범',
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
                      child: w.isRestricted || w.imageUrls.isEmpty
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
                  if (!w.isRestricted && w.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _artworkControls(w, page),
                  ],
                  if (w.isPublished && !w.isRestricted) ...[
                    const SizedBox(height: 8),
                    SocialReactions(
                      work: w,
                      compact: true,
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
                  SizedBox(height: wide ? 20 : 14),
                  Semantics(
                    header: true,
                    child: Text(
                      w.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontSize: w.isMoment
                                ? (wide ? 26 : 23)
                                : (wide ? 34 : 28),
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            letterSpacing: -.6,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SocialWorkMetadata(work: w),
                  if (w.caption.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    if (!w.isMoment) ...[
                      Text(
                        '작가의 기록',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SocialStyle.accent(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Text(
                          w.caption,
                          style: const TextStyle(fontSize: 15, height: 1.75),
                        ),
                      ),
                    ),
                  ],
                  if (own) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('social-owner-edit'),
                          onPressed: _busy
                              ? null
                              : () => w.isMoment
                                    ? _editMoment(w)
                                    : openSocialManage(context),
                          icon: const ExperienceIcon('SlidersHorizontal', size: 18),
                          label: Text(w.isMoment ? '이 기록 수정' : '내 공개 앨범 관리'),
                        ),
                        if (w.isMoment && w.isPublished)
                          TextButton.icon(
                            key: const ValueKey('social-moment-make-private'),
                            onPressed: _busy
                                ? null
                                : () => _makeMomentPrivate(w),
                            icon: const ExperienceIcon('Lock', size: 18),
                            label: const Text('나만 보기로 바꾸기'),
                          ),
                      ],
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
                  if (w.isPublished && !w.isRestricted) _comments(w),
                  const SizedBox(height: 28),
                  Text(
                    w.isMoment
                        ? '선택해 공개한 사진 한 장과 글만 보여요. 내 기록과 월간 앨범은 별도로 보관돼요.'
                        : '선택해 공개한 페이지만 표시돼요. 원본 앨범은 별도로 보관돼요.',
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
            icon: const ExperienceIcon('ArrowLeft', size: 20),
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
            icon: const ExperienceIcon('ArrowRight', size: 20),
          ),
        ],
      );
      final expand = Tooltip(
        message: '${work.isMoment ? '기록' : '앨범'} 크게 보기',
        child: TextButton.icon(
          onPressed: () => _openArtworkViewer(work),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            foregroundColor: SocialStyle.ink(context),
            textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const ExperienceIcon('Maximize2', size: 17),
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
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    work.isMoment ? '이 기록에 남긴 이야기' : '이 앨범에 남긴 이야기',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.4,
                    ),
                  ),
                ),
              ),
              if (work.commentCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SocialStyle.paper(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${work.commentCount}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SocialStyle.accent(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          first.when(
            skipLoadingOnRefresh: true,
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Semantics(
                  label: '댓글 불러오는 중',
                  child: const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
            error: (_, _) => Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _refreshComments,
                icon: const ExperienceIcon('RefreshCw', size: 17),
                label: const Text('댓글 다시 불러오기'),
              ),
            ),
            data: (_) => _commentPages(work),
          ),
          const SizedBox(height: 18),
          _commentComposer(work),
        ],
      ),
    );
  }

  Widget _commentComposer(SocialWork work) {
    final muted = SnapFitColors.textSecondaryOf(context);
    final reply = _replyTarget;
    return Column(
      key: _composerKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mentionQuery != null)
          SocialMentionSuggestions(
            profiles: _mentionSuggestions,
            query: _mentionQuery!,
            loading: _mentionLoading,
            failed: _mentionFailed,
            onSelect: _selectMention,
            onRetry: () => _updateMentionQuery(force: true),
          ),
        Container(
          decoration: BoxDecoration(
            color: SocialStyle.paper(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _commentFocus.hasFocus
                  ? SocialStyle.accent(context).withValues(alpha: .35)
                  : SocialStyle.line(context).withValues(alpha: .65),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reply != null)
                Container(
                  key: const ValueKey('social-comment-reply-target'),
                  padding: const EdgeInsets.fromLTRB(14, 3, 4, 3),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: SocialStyle.line(context)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 16,
                        color: SocialStyle.accent(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${reply.author.displayName}님에게 답글 남기는 중',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: SocialStyle.accent(context),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('social-comment-cancel-reply'),
                        tooltip: '답글 취소',
                        onPressed: _busy ? null : _cancelReply,
                        icon: const ExperienceIcon('X', size: 17),
                      ),
                    ],
                  ),
                ),
              TextField(
                key: const ValueKey('social-comment-input'),
                controller: _comment,
                focusNode: _commentFocus,
                maxLength: 300,
                minLines: 2,
                maxLines: 5,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                scrollPadding: const EdgeInsets.only(bottom: 140, top: 32),
                decoration: InputDecoration(
                  labelText: reply != null
                      ? '답글 남기기'
                      : work.isMoment
                      ? '기록에 이야기 남기기'
                      : '앨범에 이야기 남기기',
                  hintText: '@아이디로 함께 이야기할 사람을 불러보세요.',
                  hintStyle: TextStyle(fontSize: 13, color: muted),
                  labelStyle: TextStyle(fontSize: 14, color: muted),
                  floatingLabelStyle: TextStyle(
                    fontSize: 13,
                    color: SocialStyle.accent(context),
                  ),
                  filled: false,
                  counterText: '',
                  alignLabelWithHint: true,
                  contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 10, 10),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const ValueKey('social-comment-mention'),
                          tooltip: '사용자 멘션하기',
                          onPressed: _busy ? null : _insertMention,
                          icon: ExperienceIcon('AtSign', size: 21, color: muted),
                        ),
                        Text(
                          '${_comment.text.characters.length}/300',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      key: const ValueKey('social-comment-send'),
                      onPressed: _busy || _comment.text.trim().isEmpty
                          ? null
                          : _send,
                      style: SocialStyle.primary(context).copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                      icon: _sendingComment
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const ExperienceIcon('ArrowUp', size: 16),
                      label: Text(reply == null ? '댓글 남기기' : '답글 보내기'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _insertMention() {
    final selection = _comment.selection;
    final from = selection.isValid ? selection.start : _comment.text.length;
    final to = selection.isValid ? selection.end : from;
    final prefix = from > 0 && _comment.text[from - 1].trim().isNotEmpty
        ? ' '
        : '';
    final insertion = '$prefix@';
    final next = _comment.text.replaceRange(from, to, insertion);
    if (next.characters.length > 300) return;
    _comment.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: from + insertion.length),
    );
    _commentFocus.requestFocus();
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
                    icon: const ExperienceIcon('ChevronUp'),
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
        for (final comment in socialThreadedComments(newest))
          SocialCommentTile(
            key: ValueKey('social-comment-${comment.id}'),
            comment: comment,
            workAuthorId: work.author.userId,
            onProfile: (profile) => openSocialProfile(context, profile.userId),
            onReply: _busy ? null : () => _replyTo(comment),
            action: user == comment.author.userId
                ? IconButton(
                    tooltip: '내 댓글 삭제',
                    icon: ExperienceIcon('Trash2', size: 17, color: SnapFitColors.textMutedOf(context),
                    ),
                    onPressed: _busy ? null : () => _deleteComment(comment),
                  )
                : IconButton(
                    key: ValueKey('social-comment-report-${comment.id}'),
                    tooltip: '댓글 신고',
                    icon: ExperienceIcon('MoreHorizontal', size: 19, color: SnapFitColors.textMutedOf(context),
                    ),
                    onPressed: _busy
                        ? null
                        : () => _report(work, comment: comment),
                  ),
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
                      icon: const ExperienceIcon('X'),
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
                          icon: const ExperienceIcon('ArrowLeft'),
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
                          icon: const ExperienceIcon('ArrowRight'),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: '사진 축소',
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
                          tooltip: '사진 확대',
                          color: Colors.white,
                          disabledColor: Colors.white30,
                          onPressed: _scale >= 3.99 ? null : () => _zoom(1.5),
                          icon: const ExperienceIcon('Plus'),
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

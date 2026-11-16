import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/web/web_design.dart';
import '../widgets/web/web_design_detail_layout.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../core/constants/snapfit_colors.dart';

import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/album_stage_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../core/cache/snapfit_cache_manager.dart';
import '../../../album/presentation/widgets/cover/album_spine_image.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart'
    show imageFrameStyles;
import '../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../core/templates/catalog_preview_assets.g.dart';
import '../../../../core/templates/studio_phrase_catalog.dart';
import '../../../../core/templates/studio_word_art_catalog.dart';
import '../../../../shared/widgets/catalog_favorite_widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/image_url_policy.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../../core/templates/retired_store_templates.dart';
import '../../../../core/templates/published_premium_templates.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../auth/presentation/providers/public_template_return_intent.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/repositories/template_repository.dart';
import '../../domain/template_design_profile.dart';
import '../../domain/store_template_discovery.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../../../point_shop/presentation/point_shop_artwork.dart';
import '../../data/api/template_provider.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/album_creation_template.dart';
import '../../../album/data/bundled_creation_templates.dart';
import '../widgets/template_page_renderer.dart';
import '../widgets/template_book_artwork.dart';
import '../widgets/template_purchase_overview.dart';
import '../widgets/template_material_gallery.dart';
import '../widgets/template_related_section.dart';
import '../widgets/template_design_profile_summary.dart';
import '../widgets/public_template_information.dart';
import '../widgets/template_edition_sheet.dart';
import '../widgets/material_original_preview.dart';
import 'template_full_screen_view.dart';
import 'material_detail_screen.dart';
import '../../../album/presentation/views/album_create_flow_screen.dart';
import '../../../album/presentation/utils/album_creation_entry.dart';
import '../../../album/presentation/widgets/create_flow/creation_template_preview.dart';
import '../widgets/store_detail_workspace.dart';
import '../widgets/store_detail_gallery.dart';
import '../utils/published_template_share_uri.dart';
import '../utils/template_detail_pages.dart';
import '../utils/template_detail_document.dart';
import '../../../../shared/widgets/catalog_cover_skeleton.dart';
import '../../../../shared/widgets/catalog_artwork_hero.dart';

class TemplateDetailScreen extends ConsumerStatefulWidget {
  final PremiumTemplate template;
  final bool selectForCreation;
  final Object? heroTag;
  final bool guestPreview;

  const TemplateDetailScreen({
    super.key,
    required this.template,
    this.selectForCreation = false,
    this.heroTag,
    this.guestPreview = false,
  });

  @override
  ConsumerState<TemplateDetailScreen> createState() =>
      _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends ConsumerState<TemplateDetailScreen>
    with WidgetsBindingObserver {
  late PremiumTemplate _template;
  bool _isUsing = false;
  bool _isLikeSubmitting = false;
  int _likeRevision = 0;
  int _likeStateRevision = 0;
  bool _isTemplateHydrating = false;
  bool _isFullScreenPreviewOpen = false;
  final _spreadController = PageController();
  final _spreadListController = ScrollController();
  final _spreadPagerKey = GlobalKey();
  final _spreadListKey = GlobalKey();
  int _lastInnerSpread = 1;
  bool _documentPending = true;
  bool _documentScheduled = false;
  bool _documentFailed = false;
  int _documentRevision = 0;
  TemplateDetailDocumentRequest? _documentRequest;
  PublicTemplateFacts? _publicFacts;
  bool _retired = false;
  ({String? variant, int page, Object? document})? _pendingPreviewRestore;
  bool _previewRestoreScheduled = false;
  Animation<double>? _entryAnimation;
  final _pageCache = TemplateDetailPageCache();
  String? _parsedSource;
  Object? _documentIdentity;
  TemplateDesignProfile _designProfile = TemplateDesignProfile.fromDocument({});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.isCurrentOf(context) == false || !TickerMode.of(context)) {
      _documentRevision++;
      _documentRequest?.cancel();
      _documentRequest = null;
    } else {
      _scheduleDocumentPreparation();
    }
    _schedulePreviewRestore();
    // Keep the selected thumbnail visible after the list changes its axis.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerSpreadThumbnail(animated: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entryAnimation?.removeStatusListener(_onEntryStatus);
    _likeRevision++;
    _documentRevision++;
    _documentRequest?.cancel();
    _documentRequest = null;
    _pageCache.clear();
    _spreadController.dispose();
    _spreadListController.dispose();
    super.dispose();
  }

  // Parsed template data: List of pages, each page is a list of layers
  List<List<LayerModel>> _parsedPages = [];
  Map<String, List<List<LayerModel>>> _parsedPagesByAspect = const {};
  Size _designCanvasSize = const Size(500, 500);
  final Map<String, Size> _variantCanvasSizes = {};

  CoverSize? _previewPrintSize;

  List<CoverSize> get _availablePrintSizes => [
    for (final size in coverSizes)
      if ([
        _designCanvasSize,
        ..._variantCanvasSizes.values,
      ].any((canvas) => (canvas.aspectRatio - size.ratio).abs() < .0001))
        size,
  ];

  CoverSize _initialCoverSizeForTemplate() =>
      _previewPrintSize ??
      _availablePrintSizes
          .where(
            (size) => (size.ratio - _shownCanvas.aspectRatio).abs() < .0001,
          )
          .firstOrNull ??
      defaultCoverSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _template = normalizeTemplateLikeStateForDisplay(widget.template);
  }

  void _onEntryStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _scheduleDocumentPreparation();
  }

  void _scheduleDocumentPreparation() {
    if (!_documentPending || _documentScheduled || _documentRequest != null)
      return;
    _documentScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _documentScheduled = false;
      if (!mounted || !_documentPending) return;
      final route = ModalRoute.of(context);
      if (route?.isCurrent == false || !TickerMode.of(context)) return;
      final animation = route?.animation;
      if (animation != null && animation.status != AnimationStatus.completed) {
        if (!identical(_entryAnimation, animation)) {
          _entryAnimation?.removeStatusListener(_onEntryStatus);
          _entryAnimation = animation..addStatusListener(_onEntryStatus);
        }
        return;
      }
      _entryAnimation?.removeStatusListener(_onEntryStatus);
      _entryAnimation = null;
      _retired = RetiredStoreTemplates.matches(
        id: _template.id,
        title: _template.title,
      );
      if (_retired) {
        setState(() => _documentPending = false);
        return;
      }
      unawaited(() async {
        await _loadDocument(_template);
        if (mounted &&
            !_documentPending &&
            !_retired &&
            ModalRoute.isCurrentOf(context) != false) {
          await _refreshTemplate();
        }
      }());
    });
  }

  @override
  void didHaveMemoryPressure() => _pageCache.clear();

  String _normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

  String _coverPreviewUrl(PremiumTemplate template) {
    final cover = template.coverImageUrl.trim();
    if (cover.isNotEmpty) return cover;
    final previews = template.previewImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (previews.isNotEmpty) return previews.first;
    return '';
  }

  PremiumTemplate _mergeWithLocalArtwork(
    PremiumTemplate local,
    PremiumTemplate remote,
  ) {
    return remote.copyWith(
      subTitle: (local.subTitle ?? '').trim().isNotEmpty
          ? local.subTitle
          : remote.subTitle,
      description: (local.description ?? '').trim().isNotEmpty
          ? local.description
          : remote.description,
      coverImageUrl: local.coverImageUrl.trim().isNotEmpty
          ? local.coverImageUrl
          : remote.coverImageUrl,
      previewImages: local.previewImages.isNotEmpty
          ? local.previewImages
          : remote.previewImages,
      pageCount: local.pageCount > 0 ? local.pageCount : remote.pageCount,
      category: (local.category ?? '').trim().isNotEmpty
          ? local.category
          : remote.category,
      tags: (local.tags != null && local.tags!.isNotEmpty)
          ? local.tags
          : remote.tags,
      templateJson: local.documentBuilder == null
          ? local.templateJson
          : remote.documentBuilder == null
          ? remote.templateJson
          : null,
    );
  }

  Future<PremiumTemplate?> _findRemoteMatchByTitle({
    TemplateRepository? repository,
  }) async {
    try {
      final TemplateRepository source =
          repository ?? ref.read(templateRepositoryProvider);
      final session = source is TemplateSessionSource
          ? source as TemplateSessionSource
          : null;
      final owner = session?.currentTemplateUserId;
      final local = _template;
      final parsedSource = _parsedSource;
      final remoteList = await source.getTemplates();
      if (!mounted ||
          !identical(ref.read(templateRepositoryProvider), source) ||
          (session != null && session.currentTemplateUserId != owner) ||
          remoteList.isEmpty)
        return null;

      final key = _normalizeTitle(local.title);
      for (final t in remoteList) {
        if (isRetiredStoreTemplate(t)) continue;
        if (t.id == local.id || _normalizeTitle(t.title) == key) {
          final merged = t.copyWith(
            previewImages: local.previewImages.isNotEmpty
                ? local.previewImages
                : t.previewImages,
            templateJson:
                t.documentBuilder == null &&
                    (t.templateJson?.isNotEmpty ?? false)
                ? t.templateJson
                : parsedSource,
          );
          return normalizeTemplateLikeStateForDisplay(
            _mergeWithLocalArtwork(local, merged),
          );
        }
      }
    } catch (_) {
      // ignore and fallback
    }
    return null;
  }

  Future<PremiumTemplate?> _findPublishedMatchByTitle() async {
    try {
      final key = _normalizeTitle(_template.title);
      final templates = await loadCanonicalStoreTemplatesForRuntime();
      for (final t in templates) {
        if (_normalizeTitle(t.title) == key) {
          return normalizeTemplateLikeStateForDisplay(t);
        }
      }
    } catch (_) {
      // ignore and fallback
    }
    return null;
  }

  Future<bool> _loadDocument(
    PremiumTemplate source, {
    int? innerPages,
    PremiumTemplate? displayTemplate,
  }) async {
    if (!mounted ||
        ModalRoute.isCurrentOf(context) == false ||
        !TickerMode.of(context))
      return false;
    if (!_documentPending &&
        innerPages == null &&
        source.documentBuilder == null &&
        _parsedSource != null &&
        source.templateJson == _parsedSource) {
      setState(() => _template = displayTemplate ?? source);
      return true;
    }
    final likeRevision = _likeStateRevision;
    final revision = ++_documentRevision;
    _documentRequest?.cancel();
    final request = TemplateDetailDocuments.acquire(
      source,
      innerPages: innerPages,
    );
    _documentRequest = request;
    final document = await request.future;
    if (!mounted || revision != _documentRevision) return false;
    _documentRequest = null;
    if (ModalRoute.isCurrentOf(context) == false || !TickerMode.of(context))
      return false;
    if (document == null) {
      setState(() {
        _documentPending = false;
        _documentFailed = _parsedPages.isEmpty;
      });
      return false;
    }
    if (document.book.pages.isEmpty && _parsedPages.isNotEmpty) return false;
    setState(() {
      _retired = document.retired;
      _documentPending = false;
      _documentFailed = false;
      _pageCache.clear();
      _parsedPages = TemplateDetailPages(
        pages: document.book.pages,
        canvas: document.book.canvas,
        cache: _pageCache,
      );
      _designCanvasSize = document.book.canvas;
      _parsedPagesByAspect = {
        for (final entry in document.variants.entries)
          entry.key: TemplateDetailPages(
            pages: entry.value.pages,
            canvas: entry.value.canvas,
            cache: _pageCache,
          ),
      };
      _variantCanvasSizes
        ..clear()
        ..addAll({
          for (final entry in document.variants.entries)
            entry.key: entry.value.canvas,
        });
      _designProfile = document.profile;
      _publicFacts = document.facts;
      _cachedMaterialKeys = document.materials;
      _parsedSource = document.source;
      _documentIdentity = revision;
      _template = _preserveNewerLikeState(
        (displayTemplate ?? source).copyWith(
          templateJson: document.source,
          pageCount: innerPages,
        ),
        likeRevision,
      );
    });
    return !document.retired;
  }

  Future<void> _refreshTemplate() async {
    if (widget.guestPreview || isBundledCreationTemplate(_template)) {
      _isTemplateHydrating = false;
      return;
    }
    final likeRevision = _likeStateRevision;
    try {
      final localGenerated = await _findPublishedMatchByTitle();
      PremiumTemplate? updated = await _findRemoteMatchByTitle();

      if (updated == null && localGenerated == null) return;
      if (updated == null && localGenerated != null) {
        updated = localGenerated;
      } else if (updated != null && localGenerated != null) {
        updated = _mergeWithLocalArtwork(localGenerated, updated);
      }
      if (updated == null) return;

      final updatedTemplate = _preserveNewerLikeState(
        normalizeTemplateLikeStateForDisplay(
          _mergeWithLocalArtwork(localGenerated ?? _template, updated),
        ),
        likeRevision,
      );
      if (mounted) {
        await _loadDocument(
          localGenerated ?? updatedTemplate,
          displayTemplate: updatedTemplate,
        );
      }
    } catch (e) {
      // Ignore initial fetch error if offline or just rely on passed data
    } finally {
      if (mounted) {
        setState(() {
          _isTemplateHydrating = false;
        });
      }
    }
  }

  Future<void> _retryWebTemplate() async {
    if (_isUsing || _isTemplateHydrating) return;
    setState(() => _isTemplateHydrating = true);
    try {
      await _loadDocument(_template);
      await _refreshTemplate();
    } finally {
      if (mounted) setState(() => _isTemplateHydrating = false);
    }
  }

  PremiumTemplate _preserveNewerLikeState(
    PremiumTemplate incoming,
    int revision,
  ) => _isLikeSubmitting || revision != _likeStateRevision
      ? incoming.copyWith(
          isLiked: _template.isLiked,
          likeCount: _template.likeCount,
        )
      : incoming;

  Future<void> _onLike() async {
    if (!mounted || _isLikeSubmitting) return;
    // Lock before account resolution or hydration yields to a second tap.
    final revision = ++_likeRevision;
    setState(() => _isLikeSubmitting = true);
    TemplateRepository? repository;
    TemplateSessionSource? session;
    String? owner;
    String? userId;
    PremiumTemplate? previous;
    bool isCurrent() =>
        mounted &&
        revision == _likeRevision &&
        (repository == null ||
            identical(ref.read(templateRepositoryProvider), repository)) &&
        (session == null || session!.currentTemplateUserId == owner);

    try {
      final published = isPublishedCreationTemplate(_template);
      if (!published) {
        repository = ref.read(templateRepositoryProvider);
        if (repository is TemplateSessionSource) {
          session = repository as TemplateSessionSource;
          owner = session!.currentTemplateUserId;
        }
      }
      var target = _template;
      if (!published && (_isTemplateHydrating || target.id < 0)) {
        final matched = await _findRemoteMatchByTitle(repository: repository);
        if (!isCurrent()) return;
        if (matched != null) {
          target = _mergeWithLocalArtwork(_template, matched);
        }
      }
      if (!published && target.id < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이 템플릿은 아직 좋아요 서버 연동 전입니다.')),
        );
        return;
      }
      if (session != null) {
        // Use the same live owner as the repository, including signed-out state.
        userId = owner;
      } else {
        try {
          userId = await ref.read(tokenStorageProvider).getResolvedUserId();
        } catch (_) {
          if (!published) rethrow;
          // Published favorites also work offline as a guest.
        }
      }
      if (!isCurrent()) return;
      previous = target;
      final optimistic = normalizeTemplateLikeStateForDisplay(
        target.copyWith(
          isLiked: !target.isLiked,
          likeCount: published
              ? (target.isLiked ? 0 : 1)
              : target.isLiked
              ? (target.likeCount > 0 ? target.likeCount - 1 : 0)
              : target.likeCount + 1,
        ),
      );
      setState(() {
        _likeStateRevision++;
        _template = optimistic;
      });
      if (!published) {
        await repository!.likeTemplate(target.id);
      }
      // A slow preferences write must not delay or cancel the server action.
      // Once confirmed, finish saving its captured account/intent even if the
      // route closed; only UI updates and follow-up reads require a live view.
      await persistTemplateLikeState(optimistic, userId: userId);
      if (!isCurrent()) return;
      // Reads started during the pending write must not restore pre-write likes.
      _likeStateRevision++;
      ref.invalidate(templateListProvider);
      if (!published) {
        ref.invalidate(storeTemplateFeedProvider);
        unawaited(
          _syncLikeStateAfterToggle(
            userId,
            templateId: target.id,
            repository: repository!,
            isCurrent: isCurrent,
          ),
        );
      }
    } catch (error) {
      if (!isCurrent()) return;
      if (previous != null) {
        final rollback = _template.copyWith(
          isLiked: previous.isLiked,
          likeCount: previous.likeCount,
        );
        setState(() {
          _likeStateRevision++;
          _template = normalizeTemplateLikeStateForDisplay(rollback);
        });
        await persistTemplateLikeState(rollback, userId: userId);
        if (!isCurrent()) return;
      }
      context.showErrorSnack('좋아요 처리에 실패했습니다: $error');
    } finally {
      if (mounted && revision == _likeRevision) {
        setState(() => _isLikeSubmitting = false);
      }
    }
  }

  Future<void> _syncLikeStateAfterToggle(
    String? userId, {
    required int templateId,
    required TemplateRepository repository,
    required bool Function() isCurrent,
  }) async {
    try {
      if (!isCurrent()) return;
      // A successful toggle has already confirmed this exact server ID. Fetch
      // one record rather than every template document just to refresh a like.
      final refreshed = await repository.getTemplate(templateId);
      if (!isCurrent() ||
          refreshed.id != templateId ||
          isRetiredStoreTemplate(refreshed))
        return;
      final updated = normalizeTemplateLikeStateForDisplay(
        _mergeWithLocalArtwork(_template, refreshed),
      );
      setState(() {
        _likeStateRevision++;
        _template = updated;
      });
      await persistTemplateLikeState(updated, userId: userId);
      if (!isCurrent()) return;
      ref.invalidate(templateListProvider);
      ref.invalidate(storeTemplateFeedProvider);
    } catch (_) {
      // optimistic state 유지
    }
  }

  Future<void> _onUse() async {
    if (_retired || _documentPending) return;
    if (_isUsing || ModalRoute.of(context)?.isCurrent == false) return;
    if (widget.guestPreview) {
      final navigate = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
      if (kIsWeb && navigate != null) {
        navigate(WebAppLocation.login);
      } else {
        if (!kIsWeb) {
          ref
              .read(publicTemplateReturnIntentProvider.notifier)
              .remember(_template.id);
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }
    setState(() => _isUsing = true);
    try {
      AlbumCreationEntryDecision? entry;
      if (!widget.selectForCreation) {
        entry = await resolveAlbumCreationEntry(
          context,
          ref,
          selectedDesignTitle: _template.title,
          isStillCurrent: () =>
              mounted && ModalRoute.of(context)?.isCurrent != false,
        );
        if (!mounted ||
            ModalRoute.of(context)?.isCurrent == false ||
            entry == null)
          return;
        if (entry.draft != null) {
          await Navigator.push(
            context,
            snapFitRoute(
              page: AlbumCreateFlowScreen(initialDraft: entry.draft),
              settings: kIsWeb
                  ? const WebAppRouteSettings(WebAppLocation.create)
                  : null,
            ),
          );
          return;
        }
      }
      final volume = publishedPremiumVolume(_template.id);
      if (volume != null && volume.pageCounts.length > 1) {
        final count = await showTemplateEditionSheet(
          context,
          volume: volume,
          title: _template.title,
          productKey: pointShopTemplateKey(_template),
          initialCount: _template.pageCount,
          previewVariant: _previewVariant,
        );
        if (!mounted ||
            ModalRoute.of(context)?.isCurrent == false ||
            count == null)
          return;
        if (count != _template.pageCount) {
          final loaded = await _loadDocument(
            publishedCreationTemplates.firstWhere(
              (item) => item.id == _template.id,
            ),
            innerPages: count,
            displayTemplate: _template.copyWith(pageCount: count),
          );
          if (!loaded || !mounted || ModalRoute.isCurrentOf(context) == false)
            return;
          _boundDetailSpread();
        }
      }

      final pages = _parsedPages;
      if (pages.isEmpty) {
        context.showErrorSnack('템플릿 데이터 준비에 실패했습니다.');
        return;
      }

      // Capture the confirmed artwork before asynchronous price/ownership checks.
      final template = _template;
      final cover = _initialCoverSizeForTemplate();
      final canvas = _designCanvasSize;
      final aspectPages = Map.of(_parsedPagesByAspect);
      final aspectCanvases = Map.of(_variantCanvasSizes);

      // Validate and prepare artwork before checkout, so a malformed unseen page
      // cannot be charged. The selected size reuses its prepared variant.
      final variants = <String, List<List<LayerModel>>>{};
      final variantCanvases = <String, Size>{};
      for (final size in coverSizes) {
        final key = AlbumCreationTemplate.aspectKey(size);
        final source = aspectPages[key];
        final productKey = AlbumCreationTemplate.variantKey(size);
        variants[productKey] = AlbumCreationTemplate.preparePages(
          source != null && source.isNotEmpty ? source : pages,
          sourceCanvas: source != null && source.isNotEmpty
              ? aspectCanvases[key] ?? canvas
              : canvas,
          cover: size,
        );
        variantCanvases[productKey] = coverCanvasBaseSize(size);
      }
      final selection = AlbumCreationTemplate(
        title: template.title,
        sourceTemplateProductKey: pointShopTemplateKey(template),
        previewUrl: _coverPreviewUrl(template),
        isPremium: template.isPremium,
        preserveTypography: isBundledCreationTemplate(template),
        cover: cover,
        pages:
            variants[AlbumCreationTemplate.variantKey(cover)] ??
            AlbumCreationTemplate.preparePages(
              pages,
              sourceCanvas: canvas,
              cover: cover,
            ),
        variants: variants,
        variantCanvasSizes: variantCanvases,
        pagesCanvasSize: coverCanvasBaseSize(cover),
      );

      if (entry != null &&
          !await validateAlbumCreationEntry(context, ref, entry)) {
        return;
      }
      final granted = await ensurePointShopAccess(
        context,
        ref,
        productKey: pointShopTemplateKey(template),
        title: template.title,
      );
      if (!mounted || ModalRoute.of(context)?.isCurrent == false || !granted)
        return;
      if (entry != null &&
          !await validateAlbumCreationEntry(context, ref, entry)) {
        return;
      }
      if (widget.selectForCreation) {
        Navigator.pop(context, selection);
        return;
      }
      if (entry == null) return;
      await Navigator.push(
        context,
        snapFitRoute(
          page: AlbumCreateFlowScreen(initialCreationTemplate: selection),
          settings: kIsWeb
              ? const WebAppRouteSettings(WebAppLocation.create)
              : null,
        ),
      );
    } catch (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('디자인 적용을 준비하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUsing = false);
    }
  }

  Future<void> _onShareTemplate() async {
    final subtitle = _template.subTitle?.trim();
    final publicLink = publishedTemplateShareUri(
      _template.id,
      webBase: kIsWeb ? Uri.base : null,
    );
    final link = publicLink?.toString() ?? _coverPreviewUrl(_template);
    final lines = <String>[
      'SnapFit 템플릿 공유',
      _template.title,
      if (subtitle != null && subtitle.isNotEmpty) subtitle,
      if (link.trim().isNotEmpty) link,
    ];
    final text = lines.join('\n');

    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (kIsWeb && mounted) {
        try {
          await Clipboard.setData(ClipboardData(text: text));
          if (!mounted) return;
          context.showSnack('공유할 템플릿 정보를 복사했어요.');
          return;
        } catch (_) {
          // A browser can also deny clipboard access; retain the visible error.
        }
      }
      if (!mounted) return;
      context.showErrorSnack('공유 기능을 실행할 수 없습니다.');
    }
  }

  Future<void> _openFullScreenView(int initialIndex) async {
    if (!mounted ||
        _isFullScreenPreviewOpen ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final variant = _previewVariant;
    final document = _documentIdentity;
    final pages = _shownPages;
    final previews = _template.previewImages;
    final canvas = _shownCanvas;
    final preserveTypography = isBundledCreationTemplate(_template);
    final pageCount = pages.isNotEmpty ? pages.length : previews.length;
    if (initialIndex < 0 || initialIndex >= pageCount) return;
    var lastViewedPage = initialIndex;
    var viewerActive = true;
    late final PageRoute<void> viewerRoute;
    viewerRoute = snapFitRoute<void>(
      page: TemplateFullScreenView(
        parsedPages: pages,
        previewImages: previews,
        initialIndex: initialIndex,
        designCanvasSize: canvas,
        preserveTypography: preserveTypography,
        onPageChanged: (index) {
          if (!viewerActive ||
              !mounted ||
              !viewerRoute.isCurrent ||
              index < 0 ||
              index >= pageCount) {
            return;
          }
          lastViewedPage = index;
        },
      ),
    );
    setState(() => _isFullScreenPreviewOpen = true);
    await Navigator.push<void>(context, viewerRoute);
    viewerActive = false;
    await viewerRoute.completed;

    if (!mounted) return;
    _pendingPreviewRestore = (
      variant: variant,
      page: lastViewedPage,
      document: document,
    );
    _schedulePreviewRestore();
  }

  void _schedulePreviewRestore({int remainingFrames = 2}) {
    if (_pendingPreviewRestore == null || _previewRestoreScheduled || !mounted)
      return;
    _previewRestoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previewRestoreScheduled = false;
      if (!mounted || _pendingPreviewRestore == null) return;
      // Route dependencies call us again when uncovered. Never poll a covered
      // route on every frame or keep its viewer/pages alive in a closure.
      if (ModalRoute.isCurrentOf(context) != true) return;
      if (_isFullScreenPreviewOpen) {
        setState(() => _isFullScreenPreviewOpen = false);
        _schedulePreviewRestore(remainingFrames: remainingFrames);
        return;
      }
      final pending = _pendingPreviewRestore!;
      final count = _shownPages.isNotEmpty
          ? _shownPages.length
          : _template.previewImages.length;
      if (pending.variant != _previewVariant ||
          pending.document != _documentIdentity ||
          pending.page < 0 ||
          pending.page >= count) {
        _pendingPreviewRestore = null;
        return;
      }
      final positions = _spreadController.positions;
      final thumbnails = _spreadListController.positions;
      if (positions.length != 1 ||
          thumbnails.length != 1 ||
          !positions.single.hasContentDimensions ||
          !thumbnails.single.hasContentDimensions) {
        if (remainingFrames > 0) {
          _schedulePreviewRestore(remainingFrames: remainingFrames - 1);
        }
        return;
      }
      _pendingPreviewRestore = null;
      final spread = (pending.page + 1) ~/ 2;
      setState(() {
        _detailSpread = spread;
        if (spread > 0) _lastInnerSpread = spread;
      });
      _spreadController.jumpToPage(spread);
      _centerSpreadThumbnail(animated: false);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  String? _previewVariant;
  int _detailSpread = 0;
  List<List<LayerModel>> get _shownPages =>
      _parsedPagesByAspect[_previewVariant] ?? _parsedPages;
  Size get _shownCanvas =>
      _variantCanvasSizes[_previewVariant] ?? _designCanvasSize;

  void _boundDetailSpread() {
    final last = ((_shownPages.length.clamp(1, 1000) - 1) / 2).ceil();
    if (_detailSpread <= last) return;
    _updateDetailSpread(last);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _spreadController.hasClients) {
        _spreadController.jumpToPage(_detailSpread);
        _centerSpreadThumbnail(animated: false);
      }
    });
  }

  void _goToSpread(int index, {bool animated = true}) {
    if (!_spreadController.hasClients) return;
    final current = _spreadController.page ?? _detailSpread.toDouble();
    if (!animated ||
        SnapFitMotion.reduced(context) ||
        (current - index).abs() > 1) {
      // Record the selection before the pager notification. A nearby view-tab
      // switch must also bypass the thumbnail animation, without a pending flag.
      _updateDetailSpread(index);
      _spreadController.jumpToPage(index);
      _centerSpreadThumbnail(animated: false);
    } else {
      _spreadController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _spreadChanged(int index) {
    if (index == _detailSpread) return;
    final nearby = (index - _detailSpread).abs() == 1;
    _updateDetailSpread(index);
    _centerSpreadThumbnail(animated: nearby);
  }

  void _updateDetailSpread(int index) {
    if (index == _detailSpread) return;
    setState(() {
      _detailSpread = index;
      if (index > 0) _lastInnerSpread = index;
    });
  }

  void _centerSpreadThumbnail({bool animated = true}) {
    final positions = _spreadListController.positions;
    if (positions.length == 1 && positions.single.hasContentDimensions) {
      final position = positions.single;
      final itemExtent = position.axis == Axis.vertical
          ? 64 + MediaQuery.textScalerOf(context).scale(10) * 1.5
          : 96.0;
      final offset =
          (_detailSpread * itemExtent -
                  position.viewportDimension / 2 +
                  itemExtent / 2)
              .clamp(0.0, position.maxScrollExtent);
      // A manually scrolled strip can be far away even after one page turn.
      // Never build a screenful of intermediate thumbnails to catch up.
      if (!animated ||
          SnapFitMotion.reduced(context) ||
          (offset - position.pixels).abs() > position.viewportDimension) {
        _spreadListController.jumpTo(offset);
      } else {
        _spreadListController.animateTo(
          offset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _spreadArtwork(int index, int pageCount, {bool hero = false}) {
    final left = index == 0 ? 0 : index * 2 - 1;
    final paired = index > 0 && left + 1 < pageCount;
    return TemplateBookArtwork(
      canvas: _shownCanvas,
      firstPage: left,
      paired: paired,
      heroTag: hero && index == 0 && _previewVariant == null
          ? widget.heroTag
          : null,
      showShadow: hero && !kIsWeb,
      onPageTap: hero ? _openFullScreenView : null,
      pageBuilder: (page, wrapSpine) => _experiencePage(
        page,
        wrapSpine: wrapSpine,
        imageDecodeWidth: hero ? 1200 : 192,
      ),
    );
  }

  Widget _buildDetailStage({bool compact = false}) {
    if (_documentFailed && _parsedPages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExperienceIcon('Bookmark', size: 32),
            const SizedBox(height: 12),
            const Text('디자인을 불러오지 못했어요.'),
            TextButton(
              key: const ValueKey('template-document-retry'),
              onPressed: () {
                setState(() {
                  _documentPending = true;
                  _documentFailed = false;
                });
                _scheduleDocumentPreparation();
              },
              child: const Text('다시 불러오기'),
            ),
          ],
        ),
      );
    }
    final sidebar =
        compact &&
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).width -
                MediaQuery.paddingOf(context).horizontal >=
            560;
    final inlineNavigation = compact && !kIsWeb && !sidebar;
    final shortPortrait =
        inlineNavigation && MediaQuery.sizeOf(context).height < 700;
    final thumbnailExtent =
        48 + MediaQuery.textScalerOf(context).scale(10) * 1.5 + 8;
    final pageCount = _shownPages.isNotEmpty
        ? _shownPages.length
        : _template.previewImages.length.clamp(1, 1000);
    final spreadCount = 1 + ((pageCount - 1) / 2).ceil();
    final spread = _detailSpread.clamp(0, spreadCount - 1);
    final left = spread == 0 ? 0 : spread * 2 - 1;
    final paired = spread > 0 && left + 1 < pageCount;
    final pages = Semantics(
      key: _spreadPagerKey,
      container: true,
      child: KeyedSubtree(
        key: PageStorageKey('template-detail-spreads-${_template.id}'),
        child: PageView.builder(
          key: const ValueKey('template-spread-pager'),
          controller: _spreadController,
          itemCount: spreadCount,
          onPageChanged: _spreadChanged,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.all(
              compact ? (kIsWeb ? 0 : (shortPortrait ? 12 : 24)) : 22,
            ),
            child: _spreadArtwork(index, pageCount, hero: true),
          ),
        ),
      ),
    );
    final artwork = Container(
      key: const ValueKey('template-detail-stage'),
      height: compact
          ? null
          : (MediaQuery.sizeOf(context).height * .42).clamp(210, 340),
      decoration: BoxDecoration(
        color: kIsWeb ? WebPalette.of(context).canvas : null,
        gradient: kIsWeb || compact ? null : AlbumStageStyle.gradient(context),
      ),
      child: compact && !kIsWeb
          ? StoreGallerySurface(
              onExpand: () => _openFullScreenView(left),
              expandTooltip: '전체 미리보기',
              child: pages,
            )
          : pages,
    );
    final previous = IconButton(
      constraints: BoxConstraints.tightFor(
        width: inlineNavigation ? 48 : 44,
        height: inlineNavigation ? 48 : 44,
      ),
      padding: EdgeInsets.zero,
      tooltip: '이전 펼침면',
      onPressed: spread > 0 ? () => _goToSpread(spread - 1) : null,
      icon: Transform.flip(
        flipX: true,
        child: const ExperienceIcon('ChevronRight', size: 22),
      ),
    );
    final next = IconButton(
      constraints: BoxConstraints.tightFor(
        width: inlineNavigation ? 48 : 44,
        height: inlineNavigation ? 48 : 44,
      ),
      padding: EdgeInsets.zero,
      tooltip: '다음 펼침면',
      onPressed: spread + 1 < spreadCount
          ? () => _goToSpread(spread + 1)
          : null,
      icon: const ExperienceIcon('ChevronRight', size: 22),
    );
    final navigation = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (kIsWeb) const SizedBox(width: 44),
        previous,
        Expanded(
          child: Text(
            spread == 0
                ? '표지'
                : paired
                ? '$left–${left + 1}쪽'
                : '$left쪽',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExperienceFormStyle.text(
              context,
              12,
              color: ExperienceFormStyle.muted(context),
            ),
          ),
        ),
        next,
        if (kIsWeb)
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            tooltip: '전체 미리보기',
            onPressed: () => _openFullScreenView(left),
            icon: const ExperienceIcon('Expand', size: 19),
          ),
      ],
    );
    String thumbnailLabel(int index) {
      if (index == 0) return '표지';
      final range = index * 2 < pageCount
          ? '${index * 2 - 1}–${index * 2}'
          : '${index * 2 - 1}';
      return inlineNavigation && spread == index ? '${range}쪽' : range;
    }

    final thumbnails = Semantics(
      key: _spreadListKey,
      container: true,
      child: SizedBox(
        width: sidebar ? 64 : null,
        height: sidebar ? null : thumbnailExtent,
        child: KeyedSubtree(
          key: PageStorageKey('template-detail-thumbnails-${_template.id}'),
          child: ListView.builder(
            key: const ValueKey('template-spread-list'),
            controller: _spreadListController,
            scrollDirection: sidebar ? Axis.vertical : Axis.horizontal,
            // Fixed slots keep index offsets exact after rotation/text scaling
            // and let distant jumps skip laying out intermediate thumbnails.
            itemExtent: sidebar ? thumbnailExtent + 8 : 96,
            itemCount: spreadCount,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                right: sidebar ? 0 : 8,
                bottom: sidebar ? 8 : 0,
              ),
              child: Semantics(
                selected: spread == index,
                button: true,
                child: InkWell(
                  key: ValueKey('template-spread-thumb-$index'),
                  onTap: () => _goToSpread(index),
                  child: Container(
                    width: sidebar ? null : 88,
                    height: sidebar ? thumbnailExtent : null,
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: spread == index
                          ? ExperienceFormStyle.selection(context)
                          : null,
                      border: Border.all(
                        width: spread == index ? 1.5 : 1,
                        color: spread == index
                            ? ExperienceStyle.accent
                            : ExperienceFormStyle.line(context),
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(child: _spreadArtwork(index, pageCount)),
                        const SizedBox(height: 4),
                        Text(
                          thumbnailLabel(index),
                          style: ExperienceFormStyle.text(
                            context,
                            10,
                            color: ExperienceFormStyle.muted(context),
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
      ),
    );
    final gallery = Column(
      children: [
        if (compact && !kIsWeb) ...[
          StoreGalleryTabs(
            key: const ValueKey('template-gallery-mode'),
            labels: const ['표지', '내지'],
            selected: spread == 0 ? 0 : 1,
            secondaryEnabled: spreadCount > 1,
            onChanged: (mode) {
              // A view switch preserves the remembered interior and must not
              // compile intermediate spreads or overwrite it while animating.
              _goToSpread(
                mode == 0 ? 0 : _lastInnerSpread.clamp(1, spreadCount - 1),
                animated: false,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        if (sidebar)
          Expanded(
            child: Row(
              children: [
                Expanded(child: artwork),
                const SizedBox(width: 8),
                thumbnails,
              ],
            ),
          )
        else if (compact)
          Expanded(child: artwork)
        else
          artwork,
        // 세로 화면은 이동과 직접 선택을 한 줄에 두어 작품에 높이를 돌려준다.
        if (inlineNavigation)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                previous,
                Expanded(child: thumbnails),
                next,
              ],
            ),
          )
        else
          navigation,
        if (compact && !sidebar && !inlineNavigation)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: thumbnails,
          ),
        if (!compact) ...[
          thumbnails,
          const SizedBox(height: 16),
          _buildSizeSelector(),
        ],
      ],
    );
    return compact && !kIsWeb
        ? Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            child: gallery,
          )
        : gallery;
  }

  Widget _buildSizeSelector() {
    final sizes = _availablePrintSizes;
    if (sizes.isEmpty) return const SizedBox.shrink();
    final selected = _initialCoverSizeForTemplate();
    return DropdownButtonFormField<String>(
      key: ValueKey(
        kIsWeb ? 'web-template-size-selector' : 'template-size-selector',
      ),
      initialValue: selected.sizeProductId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '책 크기',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        for (final size in sizes)
          DropdownMenuItem(
            value: size.sizeProductId,
            child: Text(size.displayName),
          ),
      ],
      onChanged: _isUsing
          ? null
          : (value) {
              final cover = coverSizeForProduct(value);
              if (cover == null) return;
              final key = templateVariantForCover(cover);
              setState(() {
                _previewPrintSize = cover;
                _previewVariant = _parsedPagesByAspect.containsKey(key)
                    ? key
                    : null;
              });
              final count =
                  1 + ((_shownPages.length.clamp(1, 1000) - 1) / 2).ceil();
              if (_detailSpread >= count) _goToSpread(count - 1);
            },
    );
  }

  Set<String> _cachedMaterialKeys = const {};
  Set<String> get _materialKeys => _cachedMaterialKeys;

  Widget _experiencePage(
    int index, {
    bool wrapSpine = false,
    int? imageDecodeWidth,
  }) {
    final canvas = _shownCanvas;
    return AspectRatio(
      aspectRatio: canvas.width / canvas.height,
      child: index < _shownPages.length
          ? FittedBox(
              child: TemplatePageRenderer(
                layers: _shownPages[index],
                width: canvas.width,
                height: canvas.height,
                designCanvasSize: canvas,
                showCanvasChrome: false,
                preserveTypography: isBundledCreationTemplate(_template),
                wrapSpineArtwork: wrapSpine,
                cacheNetworkImages: true,
                imageDecodeWidth: imageDecodeWidth,
              ),
            )
          : _fallbackPage(index, wrapSpine, imageDecodeWidth),
    );
  }

  Widget _fallbackPage(int index, bool wrapSpine, int? decodeWidth) {
    final url = index < _template.previewImages.length
        ? _template.previewImages[index]
        : _coverPreviewUrl(_template);
    final asset =
        bundledTemplateAssetPath(url) ??
        (url.startsWith('asset:') ? url.substring(6) : null);
    if (asset != null) {
      final provider = ResizeImage.resizeIfNeeded(
        decodeWidth,
        null,
        AssetImage(asset),
      );
      return wrapSpine
          ? AlbumSpineImage(image: provider)
          : Image(image: provider, fit: BoxFit.cover);
    }
    if (url.isEmpty)
      return ColoredBox(
        color: kIsWeb ? WebPalette.of(context).canvas : const Color(0xFFF2F3F0),
      );
    return SnapfitImage(
      urlOrGs: imageUrlByVariant(url, variant: ImageVariant.detail),
      fit: BoxFit.cover,
      memCacheWidth: decodeWidth,
      cacheManager: snapfitImageCacheManager,
      imageBuilder: wrapSpine
          ? (context, provider) => AlbumSpineImage(image: provider)
          : null,
    );
  }

  void _openMaterial(String key) {
    if (widget.guestPreview) return;
    Navigator.of(context).push(
      snapFitRoute(
        page: MaterialDetailScreen(
          productKey: key,
          favoriteKey: _materialFavoriteKey(key),
          title: _materialName(key),
          type: _materialKind(key),
          preview: (_) => PointShopArtwork(productKey: key),
        ),
      ),
    );
  }

  Widget _relatedTemplates() {
    final candidates = ref
        .watch(storeTemplateDiscoveryCandidatesProvider)
        .asData
        ?.value;
    if (candidates == null) return const SizedBox.shrink();
    final catalog = widget.guestPreview
        ? ref.watch(publicPointShopCatalogProvider)
        : ref.watch(pointShopCatalogProvider);
    final products = {
      for (final product in catalog.asData?.value ?? const [])
        product.productKey: product,
    };
    final eligible = candidates.where((template) {
      final product = products[pointShopTemplateKey(template)];
      if (product != null)
        return product.isActive && product.pointPrice != null;
      return !template.isPremium && isPublishedCreationTemplate(template);
    });
    final recommendations = recommendRelatedStoreTemplates(_template, eligible);
    if (recommendations.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: TemplateRelatedSection(
        recommendations: recommendations,
        guestPreview: widget.guestPreview,
        onOpen: (template) async {
          final selection = await Navigator.of(context)
              .push<AlbumCreationTemplate>(
                snapFitRoute<AlbumCreationTemplate>(
                  page: TemplateDetailScreen(
                    template: template,
                    selectForCreation: widget.selectForCreation,
                    guestPreview: widget.guestPreview,
                  ),
                  settings: kIsWeb
                      ? WebAppRouteSettings(
                          WebAppLocation(WebAppPage.template, '${template.id}'),
                        )
                      : null,
                ),
              );
          if (mounted &&
              widget.selectForCreation &&
              selection != null &&
              ModalRoute.of(context)?.isCurrent != false) {
            Navigator.of(context).pop(selection);
          }
        },
      ),
    );
  }

  String _materialName(String key) {
    final id = key.split(':').last;
    return (key.startsWith('sticker:')
            ? studioDecorationById(id)?.label
            : null) ??
        studioWordArts
            .where((art) => art.productKey == key)
            .firstOrNull
            ?.label ??
        studioPhrases
            .where((phrase) => 'phrase:${phrase.id}' == key)
            .firstOrNull
            ?.text
            .replaceAll('\n', ' ') ??
        (key.startsWith('frame:')
            ? imageFrameStyles
                  .where((frame) => frame.key == id)
                  .firstOrNull
                  ?.label
            : null) ??
        '꾸밈 소재';
  }

  String _materialFavoriteKey(String key) {
    final spec = key.startsWith('sticker:')
        ? studioDecorationById(key.split(':').last)
        : null;
    if (spec != null)
      return CatalogFavoriteKeys.decoration(spec.insertionValue);
    return studioWordArts
            .where((art) => art.productKey == key)
            .firstOrNull
            ?.favoriteKey ??
        key;
  }

  String _materialKind(String key) => switch (key.split(':').first) {
    'frame' => '사진 프레임',
    'phrase' => '문구',
    'sticker' =>
      studioDecorationById(key.split(':').last)?.category ==
              StudioDecorationCategory.paper
          ? '종이 소재'
          : '스티커',
    _ => '꾸밈 소재',
  };

  Widget _materialArtwork(String key) {
    final thumbnail = catalogPreviewAssets[key];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MaterialOriginalPreview.backgroundFor(key),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: RepaintBoundary(
          child: thumbnail != null
              ? Image.asset(thumbnail, cacheWidth: 256, fit: BoxFit.contain)
              : MaterialOriginalPreview(
                  productKey: key,
                  child: PointShopArtwork(productKey: key),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_documentPending) {
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: const ExperienceHeader(
          title: '템플릿 상세',
          showNotifications: false,
          showDivider: false,
        ),
        body: StoreDetailWorkspace(
          stage: Semantics(
            label: '디자인 불러오는 중',
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: CatalogArtworkHero(
                tag: widget.heroTag,
                child: const CatalogCoverSkeleton(),
              ),
            ),
          ),
          fields: Text(
            _template.title,
            style: ExperienceFormStyle.text(
              context,
              22,
              weight: FontWeight.w600,
            ),
          ),
          actions: const FilledButton(
            key: ValueKey('template-detail-use'),
            onPressed: null,
            child: Text('디자인 준비 중'),
          ),
        ),
      );
    }
    if (_retired) {
      return Scaffold(
        appBar: AppBar(title: const Text('디자인 안내')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('이전 디자인은 더 이상 제공하지 않아요.'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('돌아가기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (widget.selectForCreation && !kIsWeb) {
      return CreationTemplatePreview(
        title: _template.title,
        profileSummary: TemplateDesignProfileSummary(
          key: const ValueKey('creation-template-profile'),
          profile: _designProfile,
        ),
        favoriteKey: CatalogFavoriteKeys.template(_template.id),
        accessBadge: PointShopProductBadge(
          productKey: pointShopTemplateKey(_template),
          unlistedLabel:
              !_template.isPremium && isPublishedCreationTemplate(_template)
              ? '무료'
              : '판매 준비 중',
        ),
        isPremium: _template.isPremium,
        preserveTypography: isBundledCreationTemplate(_template),
        pages: _parsedPages,
        canvas: _designCanvasSize,
        isUsing: _isUsing,
        onUse: _onUse,
        onRetry: _refreshTemplate,
      );
    }
    final materials = _materialKeys;
    final volume = publishedPremiumVolume(_template.id);
    final publicFacts = widget.guestPreview ? _publicFacts : null;
    final profile = TemplateDesignProfileSummary(
      key: const ValueKey('template-detail-profile'),
      profile: _designProfile,
    );
    final overview = widget.guestPreview
        ? PublicTemplateInformation(template: _template, facts: _publicFacts)
        : TemplatePurchaseOverview(
            productKey: pointShopTemplateKey(_template),
            materialKeys: materials,
            isPublishedFree:
                !_template.isPremium && isPublishedCreationTemplate(_template),
          );
    final materialDetails = TemplateMaterialGallery(
      key: const ValueKey('template-gallery-materials'),
      materialKeys: materials,
      name: _materialName,
      kind: _materialKind,
      artwork: _materialArtwork,
      usage: (key) => widget.guestPreview
          ? PublicCatalogPriceLabel(productKey: key)
          : TemplateMaterialReuseLabel(productKey: key),
      onOpen: widget.guestPreview ? null : _openMaterial,
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_template.category ?? '포토북'} 컬렉션',
                style: ExperienceFormStyle.text(
                  context,
                  11,
                  weight: FontWeight.w600,
                  color: ExperienceFormStyle.selectionInk(context),
                ),
              ),
            ),
            if (!widget.guestPreview && kIsWeb)
              CatalogFavoriteButton(
                bookmark: true,
                unframed: true,
                itemKey: CatalogFavoriteKeys.template(_template.id),
                label: _template.title,
              ),
            if (!widget.guestPreview && !isPublishedCreationTemplate(_template))
              IconButton(
                onPressed: _onLike,
                icon: Icon(
                  _template.isLiked ? Icons.favorite : Icons.favorite_border,
                ),
              ),
          ],
        ),
        Text(
          _template.title,
          style: ExperienceFormStyle.text(
            context,
            22,
            weight: FontWeight.w700,
          ).copyWith(height: 1.25),
        ),
        const SizedBox(height: 10),
        Text(
          _template.subTitle ?? _template.description ?? '',
          style: ExperienceFormStyle.text(
            context,
            14,
            color: ExperienceFormStyle.muted(context),
          ),
        ),
        if (kIsWeb) ...[
          const SizedBox(height: 16),
          profile,
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 18),
        if (kIsWeb)
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _webMetric(
                publicFacts?.pageLabel ??
                    (volume == null
                        ? '${_template.pageCount}쪽'
                        : '24 / ${volume.extendedPages}쪽'),
                '페이지 분량',
              ),
              _webMetric('${_availablePrintSizes.length}가지', '앨범 규격'),
              _webMetric('${materials.length}종', '사용한 소재'),
            ],
          )
        else
          Row(
            children: [
              _experienceMetric(
                publicFacts?.pageLabel ??
                    (volume == null
                        ? '${_template.pageCount}쪽'
                        : '24 / ${volume.extendedPages}쪽'),
                '페이지 분량',
              ),
              if (_designProfile.photoSlotCount != null &&
                  _designProfile.recordPageCount != null) ...[
                _experienceMetric(
                  '${_designProfile.photoSlotCount}곳',
                  '사진 넣는 곳',
                ),
                _experienceMetric(
                  '${_designProfile.recordPageCount}쪽',
                  '글쓰기 내지',
                ),
              ] else ...[
                _experienceMetric('${_availablePrintSizes.length}가지', '앨범 규격'),
                _experienceMetric('${materials.length}종', '사용한 소재'),
              ],
            ],
          ),
        const SizedBox(height: 24),
        if (!kIsWeb) ...[_buildSizeSelector(), const SizedBox(height: 20)],
        if (kIsWeb)
          overview
        else
          StoreDetailSection(
            key: const ValueKey('template-gallery-information'),
            title: '디자인 구성 · 사진과 글',
            summary:
                '${_designProfile.pageLabel} · ${_designProfile.compositionLabel}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [profile, const SizedBox(height: 16), overview],
            ),
          ),
        if (materials.isNotEmpty) ...[
          const SizedBox(height: 24),
          materialDetails,
        ],
        const SizedBox(height: 28),
        Text(
          '샘플 사진은 포함되지 않아요. 나의 사진과 문구로 완성할 수 있어요.',
          style: ExperienceFormStyle.text(
            context,
            12,
            color: ExperienceFormStyle.muted(context),
          ),
        ),
        if (kIsWeb)
          TextButton.icon(
            onPressed: _onShareTemplate,
            icon: const ExperienceIcon('Link2', size: 18),
            label: const Text('템플릿 공유'),
          ),
        _relatedTemplates(),
      ],
    );
    if (kIsWeb) return _webDetail(info);
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: ExperienceHeader(
        title: '템플릿 상세',
        showNotifications: false,
        showDivider: false,
        actions: [
          IconButton(
            tooltip: '템플릿 공유',
            onPressed: _onShareTemplate,
            icon: const ExperienceIcon('Share2', size: 20),
          ),
          if (!widget.guestPreview)
            CatalogFavoriteButton(
              bookmark: true,
              unframed: true,
              itemKey: CatalogFavoriteKeys.template(_template.id),
              label: _template.title,
            ),
        ],
      ),
      body: StoreDetailWorkspace(
        freezeLayout: _isFullScreenPreviewOpen,
        stage: _buildDetailStage(compact: true),
        fields: info,
        actions: _buildNativeActions(),
      ),
    );
  }

  Widget _buildNativeActions() => LayoutBuilder(
    builder: (context, bounds) {
      if (widget.guestPreview) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PublicTemplatePriceLabel(template: _template),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('template-detail-use'),
              onPressed: _onUse,
              child: const Text('로그인하고 이 디자인으로 시작'),
            ),
          ],
        );
      }
      final productKey = pointShopTemplateKey(_template);
      final owned =
          ref
              .watch(ownedPointShopKeysProvider)
              .asData
              ?.value
              .contains(productKey) ??
          false;
      final priced =
          ref
              .watch(pointShopCatalogProvider)
              .value
              ?.any(
                (product) =>
                    product.productKey == productKey &&
                    product.isActive &&
                    product.pointPrice != null,
              ) ??
          false;
      final stacked =
          bounds.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(16) > 22.4 ||
          (!owned && !priced);
      final price = PointShopProductBadge(
        key: const ValueKey('template-detail-price'),
        productKey: productKey,
        unlistedLabel:
            !_template.isPremium && isPublishedCreationTemplate(_template)
            ? '무료'
            : '판매 준비 중',
        compact: false,
      );
      final action = _buildNativeUseAction(showArrow: !stacked);
      return stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [price, const SizedBox(height: 8), action],
            )
          : Row(
              children: [
                Flexible(child: price),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: action),
              ],
            );
    },
  );

  Widget _buildNativeUseAction({required bool showArrow}) {
    final productKey = pointShopTemplateKey(_template);
    final catalog = ref.watch(pointShopCatalogProvider);
    final owned =
        ref
            .watch(ownedPointShopKeysProvider)
            .asData
            ?.value
            .contains(productKey) ??
        false;
    final action = owned
        ? (label: '이 디자인으로 시작', ready: true, retry: false)
        : catalog.when(
            loading: () => (label: '가격 확인 중', ready: false, retry: false),
            error: (_, __) => (label: '가격 다시 확인', ready: false, retry: true),
            data: (items) {
              final product = items
                  .where((item) => item.productKey == productKey)
                  .firstOrNull;
              final unavailable = product != null
                  ? !product.isActive || product.pointPrice == null
                  : _template.isPremium ||
                        !isPublishedCreationTemplate(_template);
              return (
                label: unavailable ? '판매 준비 중' : '이 디자인으로 시작',
                ready: !unavailable,
                retry: false,
              );
            },
          );
    return FilledButton(
      key: const ValueKey('template-detail-use'),
      onPressed: _isUsing || _parsedPages.isEmpty
          ? null
          : action.retry
          ? () => ref.invalidate(pointShopCatalogProvider)
          : action.ready
          ? _onUse
          : null,
      style: StoreGalleryStyle.primary(context),
      child: _isUsing
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : action.ready && showArrow
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text('이 디자인으로 시작')),
                SizedBox(width: 8),
                ExperienceIcon(
                  'ArrowRight',
                  size: 20,
                  color: SnapFitColors.onAccent,
                ),
              ],
            )
          : Text(action.label, textAlign: TextAlign.center),
    );
  }

  Widget _webDetail(Widget information) {
    final palette = WebPalette.of(context);
    Widget price() => !widget.guestPreview
        ? PointShopProductBadge(
            productKey: pointShopTemplateKey(_template),
            unlistedLabel:
                !_template.isPremium && isPublishedCreationTemplate(_template)
                ? '무료'
                : '판매 준비 중',
            compact: false,
          )
        : PublicTemplatePriceLabel(template: _template);
    Widget useAction({bool compact = false}) {
      final onPressed = _isUsing || _isTemplateHydrating || _parsedPages.isEmpty
          ? null
          : _onUse;
      final label = Text(
        _isUsing
            ? '준비 중'
            : widget.guestPreview
            ? (compact ? '로그인 후 시작' : '로그인하고 이 디자인으로 시작')
            : (compact ? '이 디자인 사용' : '이 디자인으로 시작'),
        textAlign: TextAlign.center,
      );
      if (compact) {
        return FilledButton(
          key: const ValueKey('template-detail-use'),
          onPressed: onPressed,
          child: _isUsing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : label,
        );
      }
      return FilledButton.icon(
        key: const ValueKey('template-detail-use'),
        onPressed: onPressed,
        icon: _isUsing
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const ExperienceIcon('ArrowRight', size: 18),
        label: label,
      );
    }

    Widget options() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('앨범 모양', style: TextStyle(fontSize: 12, color: palette.muted)),
        const SizedBox(height: 8),
        _buildSizeSelector(),
        const SizedBox(height: 12),
        Text(
          '사진과 글을 바꿔 나의 앨범으로 완성해요.',
          style: TextStyle(fontSize: 13, height: 1.6, color: palette.muted),
        ),
      ],
    );
    final action = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '이 디자인 사용하기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 14),
        price(),
        const SizedBox(height: 16),
        options(),
        const SizedBox(height: 18),
        useAction(),
      ],
    );
    final preview = WebSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '표지 · 내지 미리보기',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isTemplateHydrating
                ? const Center(child: CircularProgressIndicator())
                : _buildDetailStage(compact: true),
          ),
          if (!_isTemplateHydrating && _parsedPages.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '편집할 디자인 정보를 다시 불러와 주세요.',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('web-template-detail-retry'),
                onPressed: _isUsing ? null : _retryWebTemplate,
                icon: const ExperienceIcon('RefreshCw', size: 17),
                label: const Text('디자인 다시 불러오기'),
              ),
            ),
          ],
        ],
      ),
    );
    return SnapFitWebShell(
      section: WebSection.designs,
      showNavigation: !widget.guestPreview,
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.maybePop(context),
          icon: const ExperienceIcon('ArrowLeft', size: 18),
          label: const Text('목록으로'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebPageHeading(title: _template.title),
          const SizedBox(height: 20),
          Expanded(
            child: WebDesignDetailLayout(
              preview: preview,
              action: action,
              stackedAction: options(),
              stackedPreviewHeightForWidth: _webStackedPreviewHeight,
              bottomAction: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  price(),
                  const SizedBox(height: 8),
                  useAction(compact: true),
                ],
              ),
              information: information,
            ),
          ),
        ],
      ),
    );
  }

  double _webStackedPreviewHeight(double width) {
    final pageCount = _shownPages.isNotEmpty
        ? _shownPages.length
        : _template.previewImages.length.clamp(1, 1000);
    final left = _detailSpread == 0 ? 0 : _detailSpread * 2 - 1;
    final paired = _detailSpread > 0 && left + 1 < pageCount;
    final ratio = _shownCanvas.width / _shownCanvas.height * (paired ? 2 : 1);
    final textScaler = MediaQuery.textScalerOf(context);
    // Surface padding, navigation and thumbnail rail.
    // Size the stage from the actual book rather than the viewport's height.
    final artworkHeight = (width - 24).clamp(1.0, double.infinity) / ratio;
    final thumbnailHeight = 48 + textScaler.scale(10) * 1.5 + 8;
    final chrome =
        24 + textScaler.scale(14) * 1.5 + 12 + 44 + thumbnailHeight + 8;
    // Wide, short windows retain the existing vertical thumbnail rail.
    final sidebar =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).width -
                MediaQuery.paddingOf(context).horizontal >=
            560;
    return sidebar
        ? (artworkHeight + chrome).clamp(320.0, 620.0)
        : artworkHeight + chrome;
  }

  Widget _webMetric(String value, String label) => SizedBox(
    width: 132,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: ExperienceFormStyle.text(context, 17, weight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: ExperienceFormStyle.text(
            context,
            12,
            color: ExperienceFormStyle.muted(context),
          ),
        ),
      ],
    ),
  );

  Widget _experienceMetric(String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: ExperienceFormStyle.text(context, 17, weight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: ExperienceFormStyle.text(
            context,
            12,
            color: ExperienceFormStyle.muted(context),
          ),
        ),
      ],
    ),
  );
}

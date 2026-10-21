import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../../../shared/web/web_design.dart';
import '../widgets/web/web_design_detail_layout.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;

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
import '../../../../core/templates/template_visual_material_inventory.dart';
import '../../../../shared/widgets/catalog_favorite_widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../../core/templates/data_template_engine.dart';
import '../../../../core/templates/template_document_pages.dart';
import '../../../../core/templates/published_premium_templates.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../auth/presentation/providers/public_template_return_intent.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/template_design_profile.dart';
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
import '../widgets/template_design_profile_summary.dart';
import '../widgets/public_template_information.dart';
import '../widgets/template_edition_sheet.dart';
import '../widgets/material_original_preview.dart';
import 'template_full_screen_view.dart';
import 'material_detail_screen.dart';
import '../../../album/presentation/views/album_create_flow_screen.dart';
import '../../../album/presentation/widgets/create_flow/creation_template_preview.dart';
import '../widgets/store_detail_workspace.dart';
import '../utils/published_template_share_uri.dart';

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

class _TemplateDetailScreenState extends ConsumerState<TemplateDetailScreen> {
  late PremiumTemplate _template;
  bool _isUsing = false;
  bool _isLikeSubmitting = false;
  bool _isTemplateHydrating = false;
  bool _isFullScreenPreviewOpen = false;
  final _spreadController = PageController();
  final _spreadListController = ScrollController();
  final _spreadPagerKey = GlobalKey();
  final _spreadListKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep the selected thumbnail visible after the list changes its axis.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerSpreadThumbnail(animated: false);
    });
  }

  @override
  void dispose() {
    _spreadController.dispose();
    _spreadListController.dispose();
    super.dispose();
  }

  // Parsed template data: List of pages, each page is a list of layers
  List<List<LayerModel>> _parsedPages = [];
  Map<String, List<List<LayerModel>>> _parsedPagesByAspect = const {};
  Size _designCanvasSize = const Size(500, 500);
  final Map<String, Size> _variantCanvasSizes = {};

  CoverSize _initialCoverSizeForTemplate() {
    if (_previewVariant == 'portrait') {
      return coverSizes.firstWhere(
        (s) => s.name == '세로형',
        orElse: () => coverSizes.first,
      );
    }
    final aspect = _previewVariant == null
        ? _resolveTemplateAspect()
        : _shownCanvas.width / _shownCanvas.height;
    if ((aspect - 1.25).abs() < .0001)
      return coverSizeForProduct('REDP_250X200_SOFT')!;
    if (aspect >= 1.05) {
      return coverSizes.firstWhere(
        (s) => s.name == '가로형',
        orElse: () => coverSizes.last,
      );
    }
    return coverSizes.firstWhere(
      (s) => s.name == '정사각형',
      orElse: () => coverSizes.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _template = normalizeTemplateLikeStateForDisplay(widget.template);
    _parseTemplateJson();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precachePreviewImages();
    });
    _refreshTemplate();
  }

  String _normalizeTitle(String value) {
    String normalize(String raw) =>
        raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

    final key = normalize(value);
    final aliases = <String, String>{
      '제주의기록': 'jejutravel',
      '가족의주말': 'familyweekend',
      '우리의기념일': 'anniversarydays',
      'savethedate': 'savethedate',
      'scrapbook': 'scrapbook',
      'weddingeditorial': 'weddingeditorial',
      '화이트에디토리얼': 'whiteeditorial',
      '필름다이어리': 'filmdiary',
      '소프트베이비북': 'softbabybook',
      '웨딩무드북': '시그니처웨딩',
      '썸머무드북': '썸머커버에디션',
      '스카이무드북': '스카이인비테이션',
      '로즈무드북': '로즈데이',
      '북클럽무드북': '어린이북클럽',
      '제주여름무드북': '우리들의여름제주',
      '오션브리즈무드북': '오션브리즈',
      '시티나이트무드북': '도시의밤',
      '졸업무드북': '빛나는졸업장',
      '패밀리트립무드북': '가족여행일기',
      '이터널러브무드북': '이터널러브',
      '빈티지무드북': '빈티지포커스',
      '링트립무드북': '링트립스토리',
    };

    return aliases[key] ?? key;
  }

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

  PremiumTemplate _mergeWithLocalPriorityForSaveTheDate(
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
      templateJson: local.templateJson,
    );
  }

  Future<PremiumTemplate?> _findRemoteMatchByTitle() async {
    try {
      final repository = ref.read(templateRepositoryProvider);
      final remoteList = await repository.getTemplates();
      if (remoteList.isEmpty) return null;

      final key = _normalizeTitle(_template.title);
      for (final t in remoteList) {
        if (t.id == _template.id || _normalizeTitle(t.title) == key) {
          final merged = t.copyWith(
            previewImages: _template.previewImages.isNotEmpty
                ? _template.previewImages
                : t.previewImages,
            templateJson:
                (t.templateJson != null && t.templateJson!.trim().isNotEmpty)
                ? t.templateJson
                : _template.templateJson,
          );
          return normalizeTemplateLikeStateForDisplay(
            _mergeWithLocalPriorityForSaveTheDate(_template, merged),
          );
        }
      }
    } catch (_) {
      // ignore and fallback
    }
    return null;
  }

  Future<PremiumTemplate?> _findLocalGeneratedMatchByTitle() async {
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

  PremiumTemplate _mergeRemoteWithLocalGenerated(
    PremiumTemplate remote,
    PremiumTemplate local,
  ) {
    final localSub = (local.subTitle ?? '').trim();
    final localDesc = (local.description ?? '').trim();
    final localCover = local.coverImageUrl.trim();
    final localJson = (local.templateJson ?? '').trim();
    final localPreview = local.previewImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return remote.copyWith(
      subTitle: localSub.isNotEmpty ? local.subTitle : remote.subTitle,
      description: localDesc.isNotEmpty
          ? local.description
          : remote.description,
      coverImageUrl: localCover.isNotEmpty ? localCover : remote.coverImageUrl,
      previewImages: localPreview.isNotEmpty
          ? localPreview
          : remote.previewImages,
      pageCount: local.pageCount > 0 ? local.pageCount : remote.pageCount,
      category: (local.category ?? '').trim().isNotEmpty
          ? local.category
          : remote.category,
      tags: (local.tags != null && local.tags!.isNotEmpty)
          ? local.tags
          : remote.tags,
      templateJson: localJson.isNotEmpty
          ? local.templateJson
          : remote.templateJson,
    );
  }

  void _parseTemplateJson({int? maxPages}) {
    if (_template.templateJson == null || _template.templateJson!.isEmpty) {
      // 이미 파싱된 템플릿이 있으면 유지 (리프레시 시 빈 JSON으로 덮이지 않게)
      if (_parsedPages.isEmpty) {
        _parsedPages = [];
      }
      return;
    }

    try {
      final Map<String, dynamic> data = jsonDecode(_template.templateJson!);
      final metadata = (data['metadata'] is Map<String, dynamic>)
          ? (data['metadata'] as Map<String, dynamic>)
          : const <String, dynamic>{};
      final rootDesignWidth =
          (data['designWidth'] as num?)?.toDouble() ??
          (metadata['designWidth'] as num?)?.toDouble() ??
          500.0;
      final rootDesignHeight =
          (data['designHeight'] as num?)?.toDouble() ??
          (metadata['designHeight'] as num?)?.toDouble() ??
          500.0;
      _designCanvasSize = Size(rootDesignWidth, rootDesignHeight);
      final pagesList = templateDocumentPages(data);

      if (pagesList.isNotEmpty) {
        final takeCount = maxPages == null
            ? pagesList.length
            : pagesList.take(maxPages).length;
        final canvasSize = _designCanvasSize;

        _parsedPages = pagesList.take(takeCount).map((p) {
          final map = p;
          final pageSpec = <String, dynamic>{
            'strictLayout': true,
            'designWidth': canvasSize.width,
            'designHeight': canvasSize.height,
            'layers': (map['layers'] as List<dynamic>?) ?? const [],
          };
          return DataTemplateEngine.buildLayersFromJson(pageSpec, canvasSize);
        }).toList();

        // Sort by pageNumber if needed, but array order usually matches
      }

      final variants = data['variants'];
      final parsed = <String, List<List<LayerModel>>>{};
      if (variants is Map) {
        for (final entry in variants.entries) {
          final key = entry.key.toString().toLowerCase();
          final node = entry.value;
          if (node is! Map) continue;
          final variantMap = Map<String, dynamic>.from(node);
          final variantPages = templateDocumentPages(variantMap);
          if (variantPages.isEmpty) continue;

          final variantCanvas = Size(
            (variantMap['designWidth'] as num?)?.toDouble() ??
                (metadata['designWidth'] as num?)?.toDouble() ??
                500.0,
            (variantMap['designHeight'] as num?)?.toDouble() ??
                (metadata['designHeight'] as num?)?.toDouble() ??
                500.0,
          );
          final list = variantPages
              .map((p) {
                final page = p;
                final pageSpec = <String, dynamic>{
                  'strictLayout': true,
                  'designWidth': variantCanvas.width,
                  'designHeight': variantCanvas.height,
                  'layers': (page['layers'] as List<dynamic>?) ?? const [],
                };
                return DataTemplateEngine.buildLayersFromJson(
                  pageSpec,
                  variantCanvas,
                );
              })
              .toList(growable: false);
          if (list.isNotEmpty) {
            parsed[key] = list;
            _variantCanvasSizes[key] = variantCanvas;
          }
        }
      } else if (variants is List) {
        for (final node in variants) {
          if (node is! Map) continue;
          final variantMap = Map<String, dynamic>.from(node);
          final key = (variantMap['aspect'] ?? variantMap['variantId'] ?? '')
              .toString()
              .toLowerCase();
          final variantPages = templateDocumentPages(variantMap);
          if (key.isEmpty || variantPages.isEmpty) {
            continue;
          }

          final normalizedKey = key.endsWith('_portrait')
              ? 'portrait'
              : key.endsWith('_square')
              ? 'square'
              : key.endsWith('_landscape')
              ? 'landscape'
              : key;
          final variantCanvas = Size(
            (variantMap['designWidth'] as num?)?.toDouble() ??
                (metadata['designWidth'] as num?)?.toDouble() ??
                500.0,
            (variantMap['designHeight'] as num?)?.toDouble() ??
                (metadata['designHeight'] as num?)?.toDouble() ??
                500.0,
          );
          final list = variantPages
              .map((p) {
                final page = p;
                final pageSpec = <String, dynamic>{
                  'strictLayout': true,
                  'designWidth': variantCanvas.width,
                  'designHeight': variantCanvas.height,
                  'layers': (page['layers'] as List<dynamic>?) ?? const [],
                };
                return DataTemplateEngine.buildLayersFromJson(
                  pageSpec,
                  variantCanvas,
                );
              })
              .toList(growable: false);
          if (list.isNotEmpty) {
            parsed[normalizedKey] = list;
            _variantCanvasSizes[normalizedKey] = variantCanvas;
          }
        }
      }
      _parsedPagesByAspect = parsed;
    } catch (e) {
      AppLogger.warn('Failed to parse templateJson: $e');
      if (_parsedPages.isEmpty) {
        _parsedPages = [];
      }
      _parsedPagesByAspect = const {};
    }
  }

  Future<void> _precachePreviewImages({int maxCount = 4}) async {
    // Layer-based books load their actual photographs, not redundant montage previews.
    if (!mounted || _parsedPages.isNotEmpty) return;
    final candidates = _template.previewImages
        .where((url) => url.trim().isNotEmpty)
        .take(maxCount)
        .toList(growable: false);
    for (final url in candidates) {
      try {
        final bundledAsset = bundledTemplateAssetPath(url);
        if (bundledAsset != null) {
          await precacheImage(AssetImage(bundledAsset), context);
        } else if (url.startsWith('asset:')) {
          await precacheImage(
            AssetImage(url.substring('asset:'.length)),
            context,
          );
        } else {
          await precacheImage(
            NetworkImage(imageUrlByVariant(url, variant: ImageVariant.detail)),
            context,
          );
        }
      } catch (_) {
        // ignore failed cache warmup
      }
    }
  }

  Future<void> _refreshTemplate() async {
    if (widget.guestPreview || isBundledCreationTemplate(_template)) {
      _isTemplateHydrating = false;
      return;
    }
    try {
      final localGenerated = await _findLocalGeneratedMatchByTitle();
      PremiumTemplate? updated = await _findRemoteMatchByTitle();

      if (updated == null && localGenerated == null) return;
      if (updated == null && localGenerated != null) {
        updated = localGenerated;
      } else if (updated != null && localGenerated != null) {
        updated = _mergeRemoteWithLocalGenerated(updated, localGenerated);
      }
      if (updated == null) return;

      final updatedTemplate = normalizeTemplateLikeStateForDisplay(
        _mergeWithLocalPriorityForSaveTheDate(_template, updated),
      );
      if (mounted) {
        setState(() {
          _template = updatedTemplate;
          _parseTemplateJson();
          _isTemplateHydrating = false;
        });
      }
      await _precachePreviewImages();
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
      _parseTemplateJson();
      await _refreshTemplate();
    } finally {
      if (mounted) setState(() => _isTemplateHydrating = false);
    }
  }

  Future<void> _onLike() async {
    if (_isLikeSubmitting) return;
    if (isPublishedCreationTemplate(_template)) {
      setState(() {
        _isLikeSubmitting = true;
        _template = _template.copyWith(
          isLiked: !_template.isLiked,
          likeCount: _template.isLiked ? 0 : 1,
        );
      });
      try {
        String? userId;
        try {
          userId = await ref.read(tokenStorageProvider).getResolvedUserId();
        } catch (_) {
          // Bundled favorites also work offline as a guest.
        }
        await persistTemplateLikeState(_template, userId: userId);
        if (!mounted) return;
        ref.invalidate(templateListProvider);
      } finally {
        if (mounted) setState(() => _isLikeSubmitting = false);
      }
      return;
    }
    var target = _template;
    // Always validate the server ID when the template hasn't been hydrated yet
    // (e.g. user taps like before _refreshTemplate() completes) OR when the
    // local handoff JSON carries a hardcoded ID that might not exist in the DB.
    if (_isTemplateHydrating || target.id < 0) {
      final matched = await _findRemoteMatchByTitle();
      if (matched != null && mounted) {
        setState(() {
          _template = _mergeWithLocalPriorityForSaveTheDate(_template, matched);
          target = _template;
        });
      }
    }

    if (target.id < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이 템플릿은 아직 좋아요 서버 연동 전입니다.')),
        );
      }
      return;
    }

    final oldStatus = target.isLiked;
    final oldCount = target.likeCount;
    final userId = await ref.read(tokenStorageProvider).getResolvedUserId();
    final optimisticCount = oldStatus
        ? (oldCount > 0 ? oldCount - 1 : 0)
        : oldCount + 1;

    // 1. Optimistic Update
    setState(() {
      _isLikeSubmitting = true;
      _template = normalizeTemplateLikeStateForDisplay(
        target.copyWith(isLiked: !oldStatus, likeCount: optimisticCount),
      );
    });
    await persistTemplateLikeState(_template, userId: userId);

    try {
      // 2. API Call
      await ref.read(templateRepositoryProvider).likeTemplate(target.id);

      // 3. POST 성공 즉시 버튼 잠금을 풀고, 서버 truth 재동기화는 뒤에서 진행
      if (mounted) {
        setState(() => _isLikeSubmitting = false);
      }
      await persistTemplateLikeState(_template, userId: userId);

      // Invalidate list provider so the previous screen updates
      ref.invalidate(templateListProvider);
      ref.invalidate(storeTemplateFeedProvider);
      unawaited(_syncLikeStateAfterToggle(userId));
    } catch (e) {
      // 3. Rollback on failure
      if (mounted) {
        setState(() {
          _isLikeSubmitting = false;
          _template = normalizeTemplateLikeStateForDisplay(
            target.copyWith(isLiked: oldStatus, likeCount: oldCount),
          );
        });
        await persistTemplateLikeState(_template, userId: userId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('좋아요 처리에 실패했습니다: $e')));
      }
    }
  }

  Future<void> _syncLikeStateAfterToggle(String? userId) async {
    try {
      final refreshed = await _findRemoteMatchByTitle();
      if (refreshed == null || !mounted) return;
      setState(() {
        _template = normalizeTemplateLikeStateForDisplay(
          _mergeWithLocalPriorityForSaveTheDate(_template, refreshed),
        );
      });
      await persistTemplateLikeState(_template, userId: userId);
      ref.invalidate(templateListProvider);
      ref.invalidate(storeTemplateFeedProvider);
    } catch (_) {
      // optimistic state 유지
    }
  }

  Future<void> _onUse() async {
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
          setState(() {
            _template = _template.copyWith(
              pageCount: count,
              templateJson: jsonEncode(
                premiumCatalogDocument(volume, innerPages: count),
              ),
            );
            _parseTemplateJson();
          });
          _boundDetailSpread();
        }
      }

      if (_parsedPages.length < _template.pageCount) {
        _parseTemplateJson();
      }
      final pages = _parsedPages;
      if (pages.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('템플릿 데이터 준비에 실패했습니다.')));
        return;
      }

      // Capture the confirmed artwork before asynchronous price/ownership checks.
      final template = _template;
      final cover = _initialCoverSizeForTemplate();
      final normalized = AlbumCreationTemplate.preparePages(
        pages,
        sourceCanvas: _designCanvasSize,
        cover: cover,
      );
      final variants = <String, List<List<LayerModel>>>{};
      final variantCanvases = <String, Size>{};
      for (final size in coverSizes) {
        final key = AlbumCreationTemplate.aspectKey(size);
        final source = _parsedPagesByAspect[key];
        final productKey = AlbumCreationTemplate.variantKey(size);
        variants[productKey] = AlbumCreationTemplate.preparePages(
          source != null && source.isNotEmpty ? source : pages,
          sourceCanvas: source != null && source.isNotEmpty
              ? _variantCanvasSizes[key] ?? _designCanvasSize
              : _designCanvasSize,
          cover: size,
        );
        variantCanvases[productKey] = coverCanvasBaseSize(size);
      }
      final selection = AlbumCreationTemplate(
        title: template.title,
        previewUrl: _coverPreviewUrl(template),
        isPremium: template.isPremium,
        preserveTypography: isBundledCreationTemplate(template),
        cover: cover,
        pages: variants[AlbumCreationTemplate.variantKey(cover)] ?? normalized,
        variants: variants,
        variantCanvasSizes: variantCanvases,
        pagesCanvasSize: coverCanvasBaseSize(cover),
      );

      final granted = await ensurePointShopAccess(
        context,
        ref,
        productKey: pointShopTemplateKey(template),
        title: template.title,
      );
      if (!mounted || ModalRoute.of(context)?.isCurrent == false || !granted)
        return;
      if (widget.selectForCreation) {
        Navigator.pop(context, selection);
        return;
      }
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('공유할 템플릿 정보를 복사했어요.')));
          return;
        } catch (_) {
          // A browser can also deny clipboard access; retain the visible error.
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공유 기능을 실행할 수 없습니다.')));
    }
  }

  Future<void> _openFullScreenView(int initialIndex) async {
    if (!mounted ||
        _isFullScreenPreviewOpen ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final owner = ModalRoute.of(context);
    final variant = _previewVariant;
    final pages = _shownPages;
    final previews = _template.previewImages;
    final canvas = _shownCanvas;
    final preserveTypography = isBundledCreationTemplate(_template);
    final pageCount = pages.isNotEmpty ? pages.length : previews.length;
    if (initialIndex < 0 || initialIndex >= pageCount) return;
    var lastViewedPage = initialIndex;
    var viewerActive = true;
    late final MaterialPageRoute<void> viewerRoute;
    viewerRoute = MaterialPageRoute<void>(
      builder: (context) => TemplateFullScreenView(
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

    bool canRestore() {
      if (!mounted || owner?.isCurrent != true || _previewVariant != variant) {
        return false;
      }
      final currentPageCount = _shownPages.isNotEmpty
          ? _shownPages.length
          : _template.previewImages.length;
      return lastViewedPage >= 0 && lastViewedPage < currentPageCount;
    }

    final spread = (lastViewedPage + 1) ~/ 2;
    void restoreSpread() {
      if (!canRestore()) return;
      final pagerPositions = _spreadController.positions;
      final thumbnailPositions = _spreadListController.positions;
      if (pagerPositions.length != 1 ||
          thumbnailPositions.length != 1 ||
          !pagerPositions.single.hasContentDimensions ||
          !thumbnailPositions.single.hasContentDimensions) {
        WidgetsBinding.instance.addPostFrameCallback((_) => restoreSpread());
        WidgetsBinding.instance.ensureVisualUpdate();
        return;
      }
      setState(() => _detailSpread = spread);
      _spreadController.jumpToPage(spread);
      _centerSpreadThumbnail(animated: false);
    }

    void resumeDetail() {
      if (!mounted) return;
      if (owner?.isCurrent != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => resumeDetail());
        return;
      }
      // Reparent only after the uncovered detail has rebuilt its semantics.
      setState(() => _isFullScreenPreviewOpen = false);
      if (!canRestore()) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreSpread());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => resumeDetail());
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
    setState(() => _detailSpread = last);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _spreadController.hasClients) {
        _spreadController.jumpToPage(_detailSpread);
      }
    });
  }

  void _goToSpread(int index) {
    if (!_spreadController.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _spreadController.jumpToPage(index);
    } else {
      _spreadController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _spreadChanged(int index) {
    setState(() => _detailSpread = index);
    _centerSpreadThumbnail();
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
      if (!animated || MediaQuery.disableAnimationsOf(context)) {
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
    final sidebar =
        compact &&
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).width -
                MediaQuery.paddingOf(context).horizontal >=
            560;
    final thumbnailExtent =
        48 + MediaQuery.textScalerOf(context).scale(10) * 1.5 + 8;
    final pageCount = _shownPages.isNotEmpty
        ? _shownPages.length
        : _template.previewImages.length.clamp(1, 1000);
    final spreadCount = 1 + ((pageCount - 1) / 2).ceil();
    final spread = _detailSpread.clamp(0, spreadCount - 1);
    final left = spread == 0 ? 0 : spread * 2 - 1;
    final paired = spread > 0 && left + 1 < pageCount;
    final artwork = Container(
      key: const ValueKey('template-detail-stage'),
      height: compact
          ? null
          : (MediaQuery.sizeOf(context).height * .42).clamp(210, 340),
      decoration: BoxDecoration(
        color: kIsWeb ? WebPalette.of(context).canvas : null,
        gradient: kIsWeb ? null : AlbumStageStyle.gradient(context),
      ),
      child: Semantics(
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
              padding: EdgeInsets.all(compact ? (kIsWeb ? 0 : 8) : 22),
              child: _spreadArtwork(index, pageCount, hero: true),
            ),
          ),
        ),
      ),
    );
    final navigation = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 44),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          tooltip: '이전 펼침면',
          onPressed: spread > 0 ? () => _goToSpread(spread - 1) : null,
          icon: Transform.flip(
            flipX: true,
            child: const ExperienceIcon('ChevronRight', size: 22),
          ),
        ),
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
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          tooltip: '다음 펼침면',
          onPressed: spread + 1 < spreadCount
              ? () => _goToSpread(spread + 1)
              : null,
          icon: const ExperienceIcon('ChevronRight', size: 22),
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          tooltip: '전체 미리보기',
          onPressed: () => _openFullScreenView(left),
          icon: const ExperienceIcon('Expand', size: 19),
        ),
      ],
    );
    final thumbnails = Semantics(
      key: _spreadListKey,
      container: true,
      child: SizedBox(
        width: sidebar ? 64 : null,
        height: sidebar ? null : thumbnailExtent,
        child: KeyedSubtree(
          key: PageStorageKey('template-detail-thumbnails-${_template.id}'),
          child: ListView.separated(
            key: const ValueKey('template-spread-list'),
            controller: _spreadListController,
            scrollDirection: sidebar ? Axis.vertical : Axis.horizontal,
            itemCount: spreadCount,
            separatorBuilder: (_, __) =>
                SizedBox(width: sidebar ? 0 : 8, height: sidebar ? 8 : 0),
            itemBuilder: (context, index) => Semantics(
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
                    color: spread == index
                        ? ExperienceFormStyle.selection(context)
                        : null,
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: spread == index
                            ? ExperienceStyle.accent
                            : ExperienceFormStyle.line(context),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(child: _spreadArtwork(index, pageCount)),
                      const SizedBox(height: 4),
                      Text(
                        index == 0
                            ? '표지'
                            : index * 2 < pageCount
                            ? '${index * 2 - 1}–${index * 2}'
                            : '${index * 2 - 1}',
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
    );
    return Column(
      children: [
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
        navigation,
        if (compact && !sidebar)
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
  }

  Widget _buildSizeSelector() {
    final variants = _parsedPagesByAspect.keys
        .where((key) => const ['portrait', 'square', 'landscape'].contains(key))
        .toList();
    if (variants.length < 2) {
      if (!kIsWeb) return const SizedBox();
      final ratio = _shownCanvas.width / _shownCanvas.height;
      return Text(
        ratio > 1.05
            ? '가로형'
            : ratio < .95
            ? '세로형'
            : '정사각형',
        style: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
      );
    }
    final selectedVariant =
        _previewVariant ??
        variants
            .where((key) => _variantCanvasSizes[key] == _designCanvasSize)
            .firstOrNull ??
        variants.first;
    if (kIsWeb)
      return DropdownButtonFormField<String>(
        key: const ValueKey('web-template-size-selector'),
        initialValue: selectedVariant,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: [
          for (final key in variants)
            DropdownMenuItem(
              value: key,
              child: Text(
                const {
                  'portrait': '세로형',
                  'square': '정사각형',
                  'landscape': '가로형',
                }[key]!,
              ),
            ),
        ],
        onChanged: _isUsing
            ? null
            : (value) {
                if (value == null) return;
                setState(() => _previewVariant = value);
                final count =
                    1 + ((_shownPages.length.clamp(1, 1000) - 1) / 2).ceil();
                if (_detailSpread >= count) _goToSpread(count - 1);
              },
      );
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        key: const ValueKey('template-size-selector'),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          side: BorderSide.none,
          backgroundColor: ExperienceFormStyle.surface(context),
          foregroundColor: ExperienceFormStyle.ink(context),
          selectedBackgroundColor: ExperienceFormStyle.selection(context),
          selectedForegroundColor: ExperienceFormStyle.selectionInk(context),
          textStyle: ExperienceFormStyle.text(context, 12),
          shape: const StadiumBorder(),
        ),
        segments: [
          for (final key in variants)
            ButtonSegment(
              value: key,
              label: Text(
                const {
                  'portrait': '세로형',
                  'square': '정사각형',
                  'landscape': '가로형',
                }[key]!,
              ),
            ),
        ],
        selected: {selectedVariant},
        onSelectionChanged: _isUsing
            ? null
            : (value) {
                setState(() => _previewVariant = value.single);
                final count =
                    1 + ((_shownPages.length.clamp(1, 1000) - 1) / 2).ceil();
                if (_detailSpread >= count) _goToSpread(count - 1);
              },
      ),
    );
  }

  String? _materialDocument;
  Set<String> _cachedMaterialKeys = const {};

  Set<String> get _materialKeys {
    final document = _template.templateJson;
    // Page changes must not decode every variant just to rebuild the details.
    if (document == _materialDocument) return _cachedMaterialKeys;
    _materialDocument = document;
    try {
      _cachedMaterialKeys = templateVisualMaterialKeys(
        Map<String, dynamic>.from(jsonDecode(document!)),
      );
    } catch (_) {
      _cachedMaterialKeys = const {};
    }
    return _cachedMaterialKeys;
  }

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

  void _showMaterials() {
    final keys = _materialKeys.toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _materialsFrame(
          context,
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: kIsWeb ? 1120 : 760),
                child: ListView.builder(
                  key: const ValueKey('template-material-list'),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  itemCount: keys.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '사용한 소재 ${keys.length}종',
                              style: ExperienceFormStyle.text(
                                context,
                                18,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.guestPreview
                                  ? '디자인 안에 배치된 소재는 그 상태로 사용할 수 있어요. 아래는 다른 앨범에 개별 추가할 때의 공개 가격이며, 로그인 후 보유 여부와 최종 이용 조건을 확인해요.'
                                  : '이 템플릿에 배치된 소재입니다. 무료 또는 이미 구매한 소재는 다른 앨범에서도 사용할 수 있어요. 나머지는 아래에서 개별 이용 범위와 가격을 확인해 주세요.',
                              style: ExperienceFormStyle.text(
                                context,
                                13,
                                secondary: true,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final key = keys[index - 1];
                    return InkWell(
                      key: ValueKey('template-material-row-$key'),
                      onTap: widget.guestPreview
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MaterialDetailScreen(
                                  productKey: key,
                                  favoriteKey: _materialFavoriteKey(key),
                                  title: _materialName(key),
                                  type: _materialKind(key),
                                  preview: (_) =>
                                      PointShopArtwork(productKey: key),
                                ),
                              ),
                            ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: ExperienceFormStyle.line(context),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 84,
                              height: 84,
                              child: _materialArtwork(key),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _materialName(key),
                                    style: ExperienceFormStyle.text(
                                      context,
                                      14,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _materialKind(key),
                                    style: ExperienceFormStyle.text(
                                      context,
                                      12,
                                      secondary: true,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (widget.guestPreview)
                                    PublicCatalogPriceLabel(
                                      productKey: key,
                                      compact: false,
                                    )
                                  else
                                    TemplateMaterialReuseLabel(productKey: key),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (!widget.guestPreview)
                              const ExperienceIcon('ChevronRight', size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
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
    if (widget.selectForCreation && !kIsWeb) {
      return CreationTemplatePreview(
        title: _template.title,
        profileSummary: TemplateDesignProfileSummary(
          key: const ValueKey('creation-template-profile'),
          profile: TemplateDesignProfile.of(_template),
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
    // Introduce different material types before filling the remaining preview slots.
    final previewMaterials = <String>[];
    final previewKinds = <String>{};
    for (final key in materials) {
      if (previewKinds.add(_materialKind(key))) previewMaterials.add(key);
      if (previewMaterials.length == 3) break;
    }
    for (final key in materials) {
      if (previewMaterials.length == 3) break;
      if (!previewMaterials.contains(key)) previewMaterials.add(key);
    }
    final volume = publishedPremiumVolume(_template.id);
    final publicFacts = widget.guestPreview
        ? PublicTemplateFacts.fromTemplate(_template)
        : null;
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
            if (!widget.guestPreview)
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
        const SizedBox(height: 16),
        TemplateDesignProfileSummary(
          key: const ValueKey('template-detail-profile'),
          profile: TemplateDesignProfile.of(_template),
        ),
        const SizedBox(height: 24),
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
              _webMetric(
                '${_parsedPagesByAspect.isEmpty ? 1 : _parsedPagesByAspect.length}가지',
                '앨범 규격',
              ),
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
              _experienceMetric(
                '${_parsedPagesByAspect.isEmpty ? 1 : _parsedPagesByAspect.length}가지',
                '앨범 규격',
              ),
              _experienceMetric('${materials.length}종', '사용한 소재'),
            ],
          ),
        const SizedBox(height: 24),
        if (!kIsWeb) ...[_buildSizeSelector(), const SizedBox(height: 20)],
        if (widget.guestPreview)
          PublicTemplateInformation(template: _template)
        else
          TemplatePurchaseOverview(
            productKey: pointShopTemplateKey(_template),
            materialKeys: materials,
            isPublishedFree:
                !_template.isPremium && isPublishedCreationTemplate(_template),
            onMaterials: _showMaterials,
          ),
        if (materials.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  '디자인에 사용한 꾸밈 소재',
                  style: ExperienceFormStyle.text(
                    context,
                    16,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showMaterials,
                icon: const ExperienceIcon('ArrowRight', size: 16),
                label: Text(
                  '전체 보기',
                  style: ExperienceFormStyle.text(
                    context,
                    12,
                    color: kIsWeb
                        ? WebPalette.of(context).brandInk
                        : ExperienceFormStyle.selectionInk(context),
                  ),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final key in previewMaterials)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      key: ValueKey('template-material-preview-$key'),
                      onTap: _showMaterials,
                      borderRadius: BorderRadius.circular(SnapFitRadius.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: _materialArtwork(key),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _materialName(key),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ExperienceFormStyle.text(context, 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
        TextButton.icon(
          onPressed: _onShareTemplate,
          icon: const ExperienceIcon('Link2', size: 18),
          label: const Text('템플릿 공유'),
        ),
      ],
    );
    if (kIsWeb) return _webDetail(info);
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: const ExperienceHeader(title: '템플릿 상세'),
      body: _isTemplateHydrating
          ? const Center(child: CircularProgressIndicator())
          : StoreDetailWorkspace(
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
              .asData
              ?.value
              .any(
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
      onPressed: _isUsing
          ? null
          : action.retry
          ? () => ref.invalidate(pointShopCatalogProvider)
          : action.ready
          ? _onUse
          : null,
      style: ExperienceFormStyle.primary(context),
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

  Widget _materialsFrame(BuildContext context, {required Widget body}) {
    if (!kIsWeb)
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: const ExperienceHeader(title: '사용한 꾸밈 소재'),
        body: body,
      );
    return SnapFitWebShell(
      section: WebSection.designs,
      showNavigation: !widget.guestPreview,
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('템플릿으로'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebPageHeading(
            eyebrow: 'TEMPLATE / MATERIALS',
            title: '디자인에 사용한 소재',
            description: _template.title,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: WebSurface(padding: EdgeInsets.zero, child: body),
          ),
        ],
      ),
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
            : const Icon(Icons.arrow_forward, size: 18),
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
                icon: const Icon(Icons.refresh, size: 17),
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
          icon: const Icon(Icons.arrow_back, size: 18),
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

  double _resolveTemplateAspect() {
    if (_parsedPages.isNotEmpty) {
      return (_designCanvasSize.width / _designCanvasSize.height).clamp(
        0.6,
        1.8,
      );
    }
    try {
      final raw = _template.templateJson;
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final topW = (data['designWidth'] as num?)?.toDouble();
        final topH = (data['designHeight'] as num?)?.toDouble();
        if (topW != null && topH != null && topW > 1 && topH > 1) {
          return (topW / topH).clamp(0.6, 1.8);
        }
        final metadata = data['metadata'];
        if (metadata is Map) {
          final w = (metadata['designWidth'] as num?)?.toDouble();
          final h = (metadata['designHeight'] as num?)?.toDouble();
          if (w != null && h != null && w > 1 && h > 1) {
            return (w / h).clamp(0.6, 1.8);
          }
        }
      }
    } catch (_) {}
    return 1.0;
  }
}

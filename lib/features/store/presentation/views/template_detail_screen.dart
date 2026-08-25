import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../../core/templates/data_template_engine.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../billing/data/billing_provider.dart';
import '../../domain/entities/premium_template.dart';
import '../../data/api/template_provider.dart';
import '../../../album/domain/entities/layer.dart';
import '../widgets/template_page_renderer.dart';
import '../widgets/template_preview_frame.dart';
import 'template_full_screen_view.dart';
import '../../../album/presentation/views/album_create_flow_screen.dart';

class TemplateDetailScreen extends ConsumerStatefulWidget {
  final PremiumTemplate template;

  const TemplateDetailScreen({super.key, required this.template});

  @override
  ConsumerState<TemplateDetailScreen> createState() =>
      _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends ConsumerState<TemplateDetailScreen> {
  late PremiumTemplate _template;
  bool _isUsing = false;
  bool _isLikeSubmitting = false;
  bool _isTemplateHydrating = false;

  // Parsed template data: List of pages, each page is a list of layers
  List<List<LayerModel>> _parsedPages = [];
  Map<String, List<List<LayerModel>>> _parsedPagesByAspect = const {};
  Size _designCanvasSize = const Size(500, 500);

  CoverSize _initialCoverSizeForTemplate() {
    final aspect = _resolveTemplateAspect();
    if (aspect <= 0.95) {
      return coverSizes.firstWhere(
        (s) => s.name == '세로형',
        orElse: () => coverSizes.first,
      );
    }
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

  Widget _previewImageWidget(
    String url, {
    required BoxFit fit,
    required ImageVariant variant,
    Widget Function()? loading,
    Widget Function()? error,
  }) {
    final trimmed = url.trim();
    final bundledAsset = bundledTemplateAssetPath(trimmed);
    if (bundledAsset != null) {
      return Image.asset(
        bundledAsset,
        fit: fit,
        errorBuilder: (_, __, ___) => error?.call() ?? const SizedBox.shrink(),
      );
    }
    if (trimmed.startsWith('asset:')) {
      return Image.asset(
        trimmed.substring('asset:'.length),
        fit: fit,
        errorBuilder: (_, __, ___) => error?.call() ?? const SizedBox.shrink(),
      );
    }
    return Image.network(
      imageUrlByVariant(trimmed, variant: variant),
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return loading?.call() ?? const SizedBox.shrink();
      },
      errorBuilder: (_, __, ___) => error?.call() ?? const SizedBox.shrink(),
    );
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
      final List<dynamic>? pagesList = data['pages'] as List<dynamic>?;

      if (pagesList != null) {
        final takeCount = maxPages == null
            ? pagesList.length
            : pagesList.take(maxPages).length;
        final canvasSize = _designCanvasSize;

        _parsedPages = pagesList.take(takeCount).map((p) {
          final map = p as Map<String, dynamic>;
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
          final variantPages = variantMap['pages'] as List<dynamic>?;
          if (variantPages == null || variantPages.isEmpty) continue;

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
                final page = p as Map<String, dynamic>;
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
          if (list.isNotEmpty) parsed[key] = list;
        }
      } else if (variants is List) {
        for (final node in variants) {
          if (node is! Map) continue;
          final variantMap = Map<String, dynamic>.from(node);
          final key = (variantMap['aspect'] ?? variantMap['variantId'] ?? '')
              .toString()
              .toLowerCase();
          final variantPages = variantMap['pages'] as List<dynamic>?;
          if (key.isEmpty || variantPages == null || variantPages.isEmpty) {
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
                final page = p as Map<String, dynamic>;
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
          if (list.isNotEmpty) parsed[normalizedKey] = list;
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
    if (!mounted) return;
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

  Future<void> _onLike() async {
    if (_isLikeSubmitting) return;
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
    if (_isUsing) return;
    if (_template.isPremium) {
      final granted = await _ensureSubscriptionForPremium();
      if (!granted) return;
    }

    setState(() => _isUsing = true);
    if (_parsedPages.length < _template.pageCount) {
      _parseTemplateJson();
    }
    final pages = _resolvePagesForCreateFlow();
    if (pages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('템플릿 데이터 준비에 실패했습니다.')));
        setState(() => _isUsing = false);
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      snapFitRoute(
        page: AlbumCreateFlowScreen(
          initialTemplatePages: pages,
          initialTemplatePagesByAspect: _parsedPagesByAspect.isEmpty
              ? null
              : _parsedPagesByAspect,
          initialAlbumTitle: _template.title,
          initialTemplatePreviewImages: _template.previewImages,
          initialCoverSize: _initialCoverSizeForTemplate(),
        ),
      ),
    );
    if (mounted) {
      setState(() => _isUsing = false);
    }
  }

  Future<bool> _ensureSubscriptionForPremium() async {
    try {
      final state = await ref.read(mySubscriptionProvider.future);
      if (state.isActive) return true;
    } catch (_) {}

    if (!mounted) return false;
    final shouldProceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '프리미엄 템플릿 잠금',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '프리미엄 템플릿은 현재 준비중입니다.\n구독/결제 기능이 다시 열리면 사용할 수 있어요.',
                  style: TextStyle(
                    color: SnapFitColors.textSecondaryOf(context),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('준비중'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldProceed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('구독 및 결제 기능은 현재 준비중입니다.')));
    }
    return false;
  }

  Future<void> _onShareTemplate() async {
    final subtitle = _template.subTitle?.trim();
    final lines = <String>[
      'SnapFit 템플릿 공유',
      _template.title,
      if (subtitle != null && subtitle.isNotEmpty) subtitle,
      _coverPreviewUrl(_template),
    ];
    final text = lines.join('\n');

    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공유 기능을 실행할 수 없습니다.')));
    }
  }

  List<List<LayerModel>> _resolvePagesForCreateFlow() {
    final fallback = _buildFallbackTemplatePages();
    if (_parsedPages.isEmpty) return fallback;
    // 피그마 정합 우선:
    // 일부 페이지 수가 부족하더라도 synthetic fallback 레이아웃을 섞으면
    // 이상한 제목 띠/가짜 프레임이 끼어들어 원본 디자인이 망가진다.
    // 실제 파싱된 페이지가 하나라도 있으면 그것만 사용한다.
    return _parsedPages;
  }

  List<({IconData icon, String title, String description})>
  _detailFeatureCards() {
    final category = (_template.category ?? '').toLowerCase();
    final tags = (_template.tags ?? const <String>[])
        .map((e) => e.toLowerCase())
        .join(' ');
    final title = _template.title.toLowerCase();
    final haystack = '$category $tags $title';

    bool hasAny(List<String> needles) =>
        needles.any((needle) => haystack.contains(needle));

    if (title.contains('save the date')) {
      return const [
        (
          icon: Icons.favorite_border,
          title: '청첩장 무드 연출',
          description: '첫 인사부터 날짜 안내까지 차분하고 선명한 흐름으로 이어집니다.',
        ),
        (
          icon: Icons.style_outlined,
          title: '표지 중심 편집',
          description: '커버와 첫 페이지가 자연스럽게 연결되도록 구성된 웨딩 템플릿입니다.',
        ),
      ];
    }

    if (title.contains('wedding editorial')) {
      return const [
        (
          icon: Icons.auto_awesome_outlined,
          title: '에디토리얼 무드',
          description: '브라운과 크림 톤을 중심으로 차분한 화보집 분위기를 담았습니다.',
        ),
        (
          icon: Icons.photo_library_outlined,
          title: '화보형 페이지 흐름',
          description: '단독 컷, 콜라주, 메타 페이지가 리듬감 있게 이어지도록 구성했습니다.',
        ),
      ];
    }

    if (title.contains('제주의 기록')) {
      return const [
        (
          icon: Icons.landscape_outlined,
          title: '풍경 중심 구성',
          description: '여행 사진이 답답하지 않게 보이도록 큰 장면과 여백 흐름을 살렸습니다.',
        ),
        (
          icon: Icons.book_outlined,
          title: '기록형 포토북',
          description: '풍경, 메모, 이동 장면이 한 권의 여행 기록처럼 자연스럽게 이어집니다.',
        ),
      ];
    }

    if (title.contains('가족의 주말')) {
      return const [
        (
          icon: Icons.family_restroom_outlined,
          title: '따뜻한 일상 무드',
          description: '가족 사진과 짧은 기록이 편안하게 어우러지는 포토북 흐름입니다.',
        ),
        (
          icon: Icons.collections_outlined,
          title: '스크랩북 감성',
          description: '사진, 메모, 포인트 장식이 과하지 않게 정리된 가족 앨범 구성입니다.',
        ),
      ];
    }

    if (title.contains('우리의 기념일')) {
      return const [
        (
          icon: Icons.mail_outline,
          title: '편지 같은 페이지',
          description: '사진과 문장이 함께 보이도록 정리된 로맨틱 포토북 레이아웃입니다.',
        ),
        (
          icon: Icons.favorite_outline,
          title: '기념일 포토북 무드',
          description: '100일, 1주년 같은 특별한 순간을 차분하고 사랑스럽게 담아냅니다.',
        ),
      ];
    }

    if (hasAny(const ['웨딩', 'wedding', '브라이덜', '인비테이션'])) {
      return const [
        (
          icon: Icons.auto_awesome_outlined,
          title: '감성 커버 구성',
          description: '표지부터 내지까지 같은 무드로 자연스럽게 이어집니다.',
        ),
        (
          icon: Icons.crop_free_outlined,
          title: '비율별 자동 정렬',
          description: '세로, 정사각형, 가로형에서도 레이아웃 균형을 유지합니다.',
        ),
      ];
    }

    if (hasAny(const ['여행', 'travel', 'trip', '제주'])) {
      return const [
        (
          icon: Icons.map_outlined,
          title: '여행 기록에 어울림',
          description: '풍경 사진과 이동 장면이 자연스럽게 어우러지도록 구성했습니다.',
        ),
        (
          icon: Icons.crop_free_outlined,
          title: '비율별 자동 정렬',
          description: '세로, 정사각형, 가로형에서도 레이아웃 균형을 유지합니다.',
        ),
      ];
    }

    if (hasAny(const ['가족', 'family'])) {
      return const [
        (
          icon: Icons.favorite_border,
          title: '일상 기록에 어울림',
          description: '가족 사진과 메모가 따뜻하게 보이도록 여백과 흐름을 맞췄습니다.',
        ),
        (
          icon: Icons.crop_free_outlined,
          title: '비율별 자동 정렬',
          description: '세로, 정사각형, 가로형에서도 레이아웃 균형을 유지합니다.',
        ),
      ];
    }

    return const [
      (
        icon: Icons.auto_awesome_outlined,
        title: '완성도 높은 페이지 구성',
        description: '표지부터 마지막 페이지까지 같은 무드로 자연스럽게 이어집니다.',
      ),
      (
        icon: Icons.crop_free_outlined,
        title: '비율별 자동 정렬',
        description: '세로, 정사각형, 가로형에서도 레이아웃 균형을 유지합니다.',
      ),
    ];
  }

  String _recommendedPhotoRange() {
    final pages = _template.pageCount <= 0 ? 24 : _template.pageCount;
    final minPhotos = (pages * 1.6).round().clamp(18, 120);
    final maxPhotos = (pages * 2.15).round().clamp(minPhotos + 6, 160);
    return '$minPhotos~$maxPhotos장';
  }

  String _moodLabel() {
    final tags = (_template.tags ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (tags.isNotEmpty) return tags.first;
    final category = (_template.category ?? '').trim();
    if (category.isNotEmpty) return category;
    return '포토북';
  }

  List<String> _templateUseTags() {
    final tags = (_template.tags ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(3)
        .toList(growable: false);
    if (tags.isNotEmpty) return tags;
    final category = (_template.category ?? '').trim();
    return [
      if (category.isNotEmpty) category,
      if (_template.isPremium) 'Premium' else '무료 사용',
      '${_template.pageCount}페이지',
    ];
  }

  Widget _buildTemplateBrief(BuildContext context) {
    final tags = _templateUseTags();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _briefMetric(
                context,
                Icons.auto_stories_outlined,
                '${_template.pageCount}쪽',
                '포토북 분량',
              ),
              SizedBox(width: 10.w),
              _briefMetric(
                context,
                Icons.add_photo_alternate_outlined,
                _recommendedPhotoRange(),
                '추천 사진',
              ),
              SizedBox(width: 10.w),
              _briefMetric(
                context,
                Icons.palette_outlined,
                _moodLabel(),
                '대표 무드',
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: tags
                  .map(
                    (tag) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: SnapFitColors.backgroundOf(context),
                        borderRadius: BorderRadius.circular(999.r),
                        border: Border.all(
                          color: SnapFitColors.overlayLightOf(context),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: SnapFitColors.textSecondaryOf(context),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _briefMetric(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: SnapFitColors.backgroundOf(context),
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18.sp, color: SnapFitColors.accent),
            SizedBox(height: 8.h),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                color: SnapFitColors.textMutedOf(context),
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartPanel(BuildContext context) {
    final reasons = _detailFeatureCards();
    final items = [
      reasons[0],
      reasons[1],
      (
        icon: Icons.touch_app_outlined,
        title: '사진만 넣으면 바로 완성',
        description:
            '${_template.pageCount}쪽 흐름과 ${_recommendedPhotoRange()} 사진 분량에 맞춰 시작할 수 있어요.',
      ),
    ];
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        color: SnapFitColors.surfaceOf(context),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이 템플릿이 좋은 이유',
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '디자인 설명보다 실제로 만들 때 편한 지점을 먼저 정리했어요.',
            style: TextStyle(
              color: SnapFitColors.textSecondaryOf(context),
              fontSize: 13.sp,
              height: 1.45,
            ),
          ),
          SizedBox(height: 16.h),
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.only(
                bottom: item.title == items.last.title ? 0 : 14.h,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34.w,
                    height: 34.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: SnapFitColors.backgroundOf(context),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SnapFitColors.overlayLightOf(context),
                      ),
                    ),
                    child: Icon(
                      item.icon,
                      size: 18.sp,
                      color: SnapFitColors.accent,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: SnapFitColors.textPrimaryOf(context),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          item.description,
                          style: TextStyle(
                            color: SnapFitColors.textMutedOf(context),
                            fontSize: 12.sp,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color? _parseHexColor(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    var hex = value.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  Color _inferredTemplateSurfaceColor(List<LayerModel>? layers) {
    if (layers == null || layers.isEmpty) {
      return Colors.white;
    }

    final canvasW = _designCanvasSize.width <= 0
        ? 1.0
        : _designCanvasSize.width;
    final canvasH = _designCanvasSize.height <= 0
        ? 1.0
        : _designCanvasSize.height;

    LayerModel? best;
    double bestScore = -1;

    for (final layer in layers) {
      if (layer.type != LayerType.decoration) continue;
      final fill = _parseHexColor(layer.decorationFillColor);
      if (fill == null || fill.opacity <= 0.02) continue;

      final areaScore = (layer.width * layer.height) / (canvasW * canvasH);
      if (areaScore < 0.82) continue;
      final zBonus = (1000 - layer.zIndex).clamp(0, 1000) / 1000.0;
      final score = areaScore * 10 + zBonus;
      if (score > bestScore) {
        best = layer;
        bestScore = score;
      }
    }

    return _parseHexColor(best?.decorationFillColor) ?? Colors.white;
  }

  List<List<LayerModel>> _buildFallbackTemplatePages() {
    final preview = _template.previewImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (preview.isEmpty) return const [];
    final pageCount = _template.pageCount < 2 ? 2 : _template.pageCount;
    final pages = <List<LayerModel>>[];

    LayerModel imageLayer({
      required String id,
      required String url,
      required double x,
      required double y,
      required double w,
      required double h,
      String frame = 'photoCard',
      int z = 10,
    }) {
      return LayerModel(
        id: id,
        type: LayerType.image,
        position: Offset(x, y),
        width: w,
        height: h,
        imageBackground: frame,
        previewUrl: url,
        imageUrl: url,
        originalUrl: url,
        zIndex: z,
      );
    }

    pages.add([
      imageLayer(
        id: 'cover_main',
        url: preview.first,
        x: 56,
        y: 82,
        w: 388,
        h: 300,
        frame: 'paperClipCard',
      ),
      LayerModel(
        id: 'cover_title',
        type: LayerType.text,
        position: const Offset(84, 24),
        width: 332,
        height: 44,
        text: _template.title,
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: SnapFitColors.deepCharcoal,
        ),
        zIndex: 20,
      ),
    ]);

    for (int i = 1; i < pageCount; i++) {
      final left = preview[i % preview.length];
      final right = preview[(i + 1) % preview.length];
      pages.add([
        LayerModel(
          id: 'p${i}_title',
          type: LayerType.text,
          position: const Offset(74, 28),
          width: 352,
          height: 36,
          text: _template.title,
          textAlign: TextAlign.center,
          textStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: SnapFitColors.deepCharcoal,
          ),
          zIndex: 24,
        ),
        imageLayer(
          id: 'p${i}_left',
          url: left,
          x: 44,
          y: 86,
          w: 210,
          h: 294,
          frame: 'paperClipCard',
          z: 14,
        ),
        imageLayer(
          id: 'p${i}_right',
          url: right,
          x: 246,
          y: 100,
          w: 210,
          h: 280,
          frame: 'polaroidClassic',
          z: 18,
        ),
        imageLayer(
          id: 'p${i}_accent',
          url: preview[(i + 2) % preview.length],
          x: 168,
          y: 316,
          w: 166,
          h: 128,
          frame: 'softGlow',
          z: 20,
        ),
      ]);
    }
    return pages;
  }

  void _openFullScreenView(int initialIndex) {
    if (_parsedPages.isEmpty && _template.previewImages.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateFullScreenView(
          parsedPages: _parsedPages,
          previewImages: _template.previewImages,
          initialIndex: initialIndex,
          designCanvasSize: _designCanvasSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = SnapFitColors.textPrimaryOf(context);
    final secondaryColor = SnapFitColors.textSecondaryOf(context);
    if (_isTemplateHydrating) {
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: SnapFitColors.surfaceOf(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          platformBackIcon(),
                          size: 20,
                          color: titleColor,
                        ),
                      ),
                    ),
                    Text(
                      '템플릿 상세',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    SizedBox(width: 36.w),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28.w,
                        height: 28.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 14.h),
                      Text(
                        '최신 템플릿을 불러오는 중...',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 36.h),
                    // Minimal lookbook chrome
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: SnapFitColors.surfaceOf(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                platformBackIcon(),
                                size: 20,
                                color: titleColor,
                              ),
                            ),
                          ),
                          Text(
                            '룩북 미리보기',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: SnapFitColors.textMutedOf(context),
                            ),
                          ),
                          GestureDetector(
                            onTap: _onShareTemplate,
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: SnapFitColors.surfaceOf(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.share_outlined,
                                size: 20,
                                color: titleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    _buildHeroImage(context),

                    SizedBox(height: 20.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        children: [
                          Text(
                            _template.title,
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          if ((_template.subTitle ?? _template.description)
                                  ?.trim()
                                  .isNotEmpty ??
                              false)
                            Text(
                              (_template.subTitle ?? _template.description)!
                                  .trim(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                color: secondaryColor,
                                height: 1.45,
                              ),
                            ),
                          SizedBox(height: 16.h),
                          _buildTemplateBrief(context),
                        ],
                      ),
                    ),

                    SizedBox(height: 30.h),

                    _buildQuickStartPanel(context),

                    SizedBox(height: 34.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '페이지 구성 미리보기',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '사진만 넣으면 이 흐름으로 완성돼요 · ${_template.pageCount}페이지',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: SnapFitColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    SizedBox(
                      height: 240.h,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        scrollDirection: Axis.horizontal,
                        itemCount: _template.pageCount,
                        separatorBuilder: (_, __) => SizedBox(width: 16.w),
                        itemBuilder: (context, index) {
                          if (index < _parsedPages.length) {
                            return _buildPageLayoutPreview(
                              context,
                              index,
                              _parsedPages[index],
                            );
                          }
                          if (index < _template.previewImages.length) {
                            return _buildPagePreviewItem(
                              context,
                              _template.previewImages[index],
                            );
                          }
                          return _buildPagePreviewPlaceholder(context, index);
                        },
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12.h),
                        child: Text(
                          '표지 및 프롤로그',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: SnapFitColors.textMutedOf(context),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 40.h),

                    // User Count Badge
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 20.w),
                      padding: EdgeInsets.symmetric(
                        vertical: 16.h,
                        horizontal: 20.w,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? SnapFitColors.surfaceOf(context)
                            : SnapFitColors.accentLight,
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60.w,
                            height: 30.w,
                            child: Stack(
                              children: [
                                _avatar(
                                  context,
                                  0,
                                  isDark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                ),
                                _avatar(
                                  context,
                                  18.w,
                                  isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[400]!,
                                ),
                                _avatar(
                                  context,
                                  36.w,
                                  isDark
                                      ? Colors.grey[800]!
                                      : Colors.grey[500]!,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: SnapFitColors.textSecondaryOf(context),
                                ),
                                children: [
                                  const TextSpan(text: '현재 '),
                                  TextSpan(
                                    text: '${_template.likeCount}명',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: SnapFitColors.accent,
                                    ),
                                  ),
                                  const TextSpan(text: '이 템플릿에 관심을 보이고 있습니다.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 120.h),
                  ],
                ),
              ),
            ],
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 20.h,
                bottom: MediaQuery.of(context).padding.bottom + 20.h,
              ),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context).withOpacity(0.94),
                border: Border(
                  top: BorderSide(color: SnapFitColors.overlayLightOf(context)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SnapFitPressable(
                    onTap: _onLike,
                    pressedScale: 0.90,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _template.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _template.isLiked
                              ? Colors.red
                              : SnapFitColors.textMutedOf(context),
                          size: 28.sp,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${_template.likeCount}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: _template.isLiked
                                ? Colors.red
                                : SnapFitColors.textMutedOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUsing ? null : _onUse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SnapFitColors.accent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isUsing
                          ? SizedBox(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18.w,
                                    height: 18.w,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    '앨범을 준비하고 있어요…',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '이 템플릿으로 시작하기',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    final coverUrl = _coverPreviewUrl(_template);
    final aspect = _resolveTemplateAspect();
    final heroHeight = 384.h;
    final mainWidth = (heroHeight * aspect).clamp(214.w, 296.w).toDouble();
    final sideWidth = (mainWidth * 0.70).clamp(144.w, 208.w).toDouble();
    final sideHeight = (sideWidth / aspect).clamp(176.h, 292.h).toDouble();

    Widget pageCard({
      required int index,
      required double width,
      required double height,
      required double radius,
    }) {
      final layers = index < _parsedPages.length ? _parsedPages[index] : null;
      final previewUrl = index < _template.previewImages.length
          ? _template.previewImages[index]
          : coverUrl;
      return TemplatePreviewFrame(
        borderRadius: radius,
        padding: EdgeInsets.all(5.w),
        child: _buildRenderedTemplateSurface(
          layers: layers,
          previewUrl: previewUrl,
          width: width,
          height: height,
          loading: () => const TemplatePaperPlaceholder(),
          error: () => const TemplatePaperPlaceholder(),
        ),
      );
    }

    return SnapFitFadeIn(
      child: SizedBox(
        width: double.infinity,
        height: heroHeight + 14.h,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 30.w,
              top: 42.h,
              child: Opacity(
                opacity: 0.78,
                child: Transform.rotate(
                  angle: -0.075,
                  child: SizedBox(
                    width: sideWidth,
                    height: sideHeight,
                    child: pageCard(
                      index: 1,
                      width: sideWidth,
                      height: sideHeight,
                      radius: 24,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 26.w,
              bottom: 20.h,
              child: Opacity(
                opacity: 0.72,
                child: Transform.rotate(
                  angle: 0.065,
                  child: SizedBox(
                    width: sideWidth * 0.92,
                    height: sideHeight * 0.92,
                    child: pageCard(
                      index: 2,
                      width: sideWidth * 0.92,
                      height: sideHeight * 0.92,
                      radius: 22,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: SnapFitPressable(
                onTap: () => _openFullScreenView(0),
                pressedScale: 0.985,
                borderRadius: BorderRadius.circular(30.r),
                child: SizedBox(
                  width: mainWidth,
                  height: heroHeight,
                  child: pageCard(
                    index: 0,
                    width: mainWidth,
                    height: heroHeight,
                    radius: 30,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: SnapFitColors.surfaceOf(context).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: SnapFitColors.overlayLightOf(context),
                  ),
                ),
                child: Text(
                  '${_template.pageCount}쪽 · 사진 ${_recommendedPhotoRange()} 추천',
                  style: TextStyle(
                    color: SnapFitColors.textMutedOf(context),
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagePreviewPlaceholder(BuildContext context, int index) {
    return SnapFitPressable(
      onTap: () => _openFullScreenView(index),
      pressedScale: 0.985,
      borderRadius: BorderRadius.circular(22.r),
      child: SizedBox(
        width: 180.w,
        child: Column(
          children: [
            Expanded(
              child: TemplatePreviewFrame(
                borderRadius: 22,
                padding: EdgeInsets.all(5.w),
                child: const TemplatePaperPlaceholder(),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              index == 0 ? 'Cover' : index.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textMutedOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagePreviewItem(BuildContext context, String imageUrl) {
    final aspect = _resolveTemplateAspect();
    final previewHeight = 200.h;
    final previewWidth = (previewHeight * aspect).clamp(110.w, 180.w);
    final index = _template.previewImages.indexOf(imageUrl);
    return SnapFitPressable(
      onTap: () => _openFullScreenView(index < 0 ? 0 : index),
      pressedScale: 0.985,
      borderRadius: BorderRadius.circular(22.r),
      child: SizedBox(
        width: 180.w,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: TemplatePreviewFrame(
                    borderRadius: 22,
                    padding: EdgeInsets.all(5.w),
                    child: _previewImageWidget(
                      imageUrl,
                      fit: BoxFit.cover,
                      variant: ImageVariant.thumb,
                      loading: () => const TemplatePaperPlaceholder(),
                      error: () => const TemplatePaperPlaceholder(),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              index <= 0 ? 'Cover' : index.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textMutedOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageLayoutPreview(
    BuildContext context,
    int index,
    List<LayerModel> layers,
  ) {
    final previewAspect = _resolveTemplateAspect();
    const basePreviewHeight = 140.0;
    final previewHeight = basePreviewHeight.w;
    final previewWidth = (previewHeight * previewAspect).clamp(
      100.0.w,
      200.0.w,
    );
    final previewUrl = index < _template.previewImages.length
        ? _template.previewImages[index]
        : '';
    return SnapFitPressable(
      onTap: () => _openFullScreenView(index),
      pressedScale: 0.985,
      borderRadius: BorderRadius.circular(22.r),
      child: SizedBox(
        width: 180.w,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: TemplatePreviewFrame(
                    borderRadius: 22,
                    padding: EdgeInsets.all(5.w),
                    child: _buildRenderedTemplateSurface(
                      layers: layers,
                      previewUrl: previewUrl,
                      width: previewWidth,
                      height: previewHeight,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              index == 0 ? 'Cover' : index.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textMutedOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenderedTemplateSurface({
    required List<LayerModel>? layers,
    required String previewUrl,
    required double width,
    required double height,
    Widget Function()? loading,
    Widget Function()? error,
  }) {
    final loadingWidget = loading ?? () => const TemplatePaperPlaceholder();
    final errorWidget = error ?? () => const TemplatePaperPlaceholder();

    if (layers != null && layers.isNotEmpty) {
      return ColoredBox(
        color: _inferredTemplateSurfaceColor(layers),
        child: TemplatePageRenderer(
          layers: layers,
          width: width,
          height: height,
          designCanvasSize: _designCanvasSize,
        ),
      );
    }

    if (previewUrl.trim().isNotEmpty) {
      return _previewImageWidget(
        previewUrl,
        fit: BoxFit.cover,
        variant: ImageVariant.detail,
        loading: loadingWidget,
        error: errorWidget,
      );
    }

    return errorWidget();
  }

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

  Widget _avatar(BuildContext context, double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 30.w,
        height: 30.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: SnapFitColors.backgroundOf(context),
            width: 2,
          ),
        ),
        child: Icon(Icons.person, color: Colors.white, size: 16.sp),
      ),
    );
  }
}

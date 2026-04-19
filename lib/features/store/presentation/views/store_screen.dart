import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';
import '../widgets/template_page_renderer.dart';
import 'template_detail_screen.dart';

String _storeCoverPreviewUrl(PremiumTemplate template) {
  final cover = template.coverImageUrl.trim();
  if (cover.isNotEmpty) return cover;
  final previews = template.previewImages
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  if (previews.isNotEmpty) return previews.first;
  return '';
}

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  DateTime? _lastAutoRefreshRequestAt;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _allTemplatesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 520;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(storeTemplateFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(storeTemplateFeedProvider);

    // 화면이 다시 노출될 때 서버 최신 템플릿으로 자연스럽게 동기화한다.
    if (!feedState.isInitialLoading && !feedState.isLoadingMore) {
      final now = DateTime.now();
      final shouldThrottle =
          _lastAutoRefreshRequestAt != null &&
          now.difference(_lastAutoRefreshRequestAt!) <
              const Duration(seconds: 10);
      if (!shouldThrottle) {
        final isStale =
            feedState.lastSyncedAt == null ||
            now.difference(feedState.lastSyncedAt!) >=
                const Duration(seconds: 45);
        if (isStale) {
          _lastAutoRefreshRequestAt = now;
          Future.microtask(() {
            ref.read(storeTemplateFeedProvider.notifier).refreshIfStale();
          });
        }
      }
    }

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      body: SafeArea(
        child: Builder(
          builder: (_) {
            if (feedState.isInitialLoading && feedState.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (feedState.items.isEmpty) {
              return _StoreErrorView(
                onRetry: () =>
                    ref.read(storeTemplateFeedProvider.notifier).refresh(),
              );
            }
            final templates = feedState.items;
            final latestNewIds = _resolveNewTemplateIds(templates);
            final weeklyBest = _resolveWeeklyBest(templates, latestNewIds);
            final sorted = _sortTemplates(templates);

            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(storeTemplateFeedProvider.notifier).refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const _TopBar(),
                        const SizedBox(height: 24),
                        _WeeklyHeader(
                          onMoreTap: weeklyBest.length > 2
                              ? () {
                                  _scrollToAllTemplates();
                                }
                              : null,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 246,
                          child: weeklyBest.isEmpty
                              ? const _EmptyState(message: '추천 템플릿을 준비 중입니다.')
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: weeklyBest.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 14),
                                  itemBuilder: (context, index) {
                                    final template = weeklyBest[index];
                                    return _WeeklyTemplateCard(
                                      template: template,
                                      isNew: latestNewIds.contains(template.id),
                                      onTap: () => _openDetail(template),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 28),
                        const _AllTemplatesHeader(),
                        const SizedBox(height: 14),
                      ]),
                    ),
                  ),
                  SliverPadding(
                    key: _allTemplatesKey,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: sorted.isEmpty
                        ? const SliverToBoxAdapter(
                            child: _EmptyState(message: '템플릿을 준비 중입니다.'),
                          )
                        : SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.62,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final template = sorted[index];
                              return _TemplateGridCard(
                                template: template,
                                onTap: () => _openDetail(template),
                              );
                            }, childCount: sorted.length),
                          ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Center(
                        child: feedState.isLoadingMore
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : (feedState.hasNext
                                  ? const SizedBox.shrink()
                                  : const SizedBox.shrink()),
                      ),
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

  Set<int> _resolveNewTemplateIds(List<PremiumTemplate> templates) {
    return templates
        .where(_isNewWithinOneDay)
        .map((template) => template.id)
        .toSet();
  }

  bool _isNewWithinOneDay(PremiumTemplate template) {
    final createdAt = _parseTemplateCreatedAt(template.createdAt);
    if (createdAt == null) return false;
    final age = DateTime.now().difference(createdAt);
    return !age.isNegative && age <= const Duration(hours: 24);
  }

  DateTime? _parseTemplateCreatedAt(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  List<PremiumTemplate> _resolveWeeklyBest(
    List<PremiumTemplate> templates,
    Set<int> latestTopIds,
  ) {
    final copied = [...templates];
    copied.sort((a, b) {
      final scoreA = _weeklyScore(a, latestTopIds.contains(a.id));
      final scoreB = _weeklyScore(b, latestTopIds.contains(b.id));
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) return byScore;
      return b.id.compareTo(a.id);
    });
    return copied.take(8).toList();
  }

  int _weeklyScore(PremiumTemplate template, bool isNew) {
    if (template.weeklyScore > 0) {
      return template.weeklyScore + (isNew ? 40 : 0);
    }
    final bestBonus = template.isBest ? 120 : 0;
    final newBonus = isNew ? 60 : 0;
    return (template.likeCount * 10) +
        (template.userCount * 3) +
        bestBonus +
        newBonus;
  }

  bool _isSaveTheDate(PremiumTemplate template) {
    final title = template.title.trim().toLowerCase();
    final raw = (template.templateJson ?? '').toLowerCase();
    return title == 'save the date' || raw.contains('save_the_date_v1');
  }

  List<PremiumTemplate> _sortTemplates(List<PremiumTemplate> templates) {
    final copied = [...templates];
    copied.sort((a, b) {
      final aPinned = _isSaveTheDate(a);
      final bPinned = _isSaveTheDate(b);
      if (aPinned != bPinned) {
        return aPinned ? -1 : 1;
      }
      return b.id.compareTo(a.id);
    });
    return copied;
  }

  void _openDetail(PremiumTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateDetailScreen(template: template),
      ),
    );
  }

  void _scrollToAllTemplates() {
    final targetContext = _allTemplatesKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '템플릿 스토어',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyHeader extends StatelessWidget {
  final VoidCallback? onMoreTap;

  const _WeeklyHeader({this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WEEKLY BEST',
          style: TextStyle(
            color: SnapFitColors.accent,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '금주의 인기 템플릿',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
            ),
            TextButton(
              onPressed: onMoreTap,
              style: TextButton.styleFrom(
                foregroundColor: SnapFitColors.textPrimaryOf(context),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '더보기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeeklyTemplateCard extends StatelessWidget {
  final PremiumTemplate template;
  final bool isNew;
  final VoidCallback onTap;

  const _WeeklyTemplateCard({
    required this.template,
    required this.isNew,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.74,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.55,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _StoreTemplateCoverPreview(template: template),
                      if (isNew)
                        const Positioned(
                          top: 12,
                          left: 12,
                          child: _MiniBadge(label: 'NEW'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              template.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              template.subTitle ?? template.description ?? '감성을 담은 템플릿',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: SnapFitColors.textSecondaryOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllTemplatesHeader extends StatelessWidget {
  const _AllTemplatesHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '모든 템플릿',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateGridCard extends StatelessWidget {
  final PremiumTemplate template;
  final VoidCallback onTap;

  const _TemplateGridCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = template.isPremium ? 'PREMIUM' : 'FREE';
    final labelColor = template.isPremium
        ? SnapFitColors.accent
        : SnapFitColors.textSecondaryOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _StoreTemplateCoverPreview(template: template),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.62)
                            : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${template.likeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            template.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SnapFitColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StoreErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _StoreErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '템플릿을 불러오지 못했어요.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: SnapFitColors.textSecondaryOf(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StoreTemplateCoverPreview extends StatelessWidget {
  final PremiumTemplate template;

  const _StoreTemplateCoverPreview({required this.template});

  @override
  Widget build(BuildContext context) {
    final directCoverUrl = _storeCoverPreviewUrl(template);
    if (directCoverUrl.isNotEmpty) {
      return _NetworkImage(url: directCoverUrl, variant: ImageVariant.thumb);
    }
    final parsed = _parseFirstPage(template);
    if (parsed != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final targetAspect = parsed.$2;
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          final drawWidth = math.min(maxWidth, maxHeight * targetAspect);
          final drawHeight = drawWidth / targetAspect;
          return Container(
            color: SnapFitColors.overlayLightOf(context),
            alignment: Alignment.center,
            child: SizedBox(
              width: drawWidth,
              height: drawHeight,
              child: TemplatePageRenderer(
                layers: parsed.$1,
                width: drawWidth,
                height: drawHeight,
                designCanvasSize: parsed.$3,
              ),
            ),
          );
        },
      );
    }
    return _NetworkImage(url: directCoverUrl, variant: ImageVariant.thumb);
  }
}

(List<LayerModel>, double, Size)? _parseFirstPage(PremiumTemplate template) {
  final raw = template.templateJson;
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final metadata =
        (data['metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pages = data['pages'];
    if (pages is! List || pages.isEmpty) return null;
    final page = pages.first;
    if (page is! Map<String, dynamic>) return null;
    final layersJson = page['layers'];
    if (layersJson is! List || layersJson.isEmpty) return null;

    final designWidth =
        (data['designWidth'] as num?)?.toDouble() ??
        (metadata['designWidth'] as num?)?.toDouble() ??
        1080.0;
    final designHeight =
        (data['designHeight'] as num?)?.toDouble() ??
        (metadata['designHeight'] as num?)?.toDouble() ??
        1440.0;
    final canvasSize = Size(designWidth, designHeight);
    final layers = layersJson
        .whereType<Map<String, dynamic>>()
        .map(
          (layer) => LayerExportMapper.fromJson(layer, canvasSize: canvasSize),
        )
        .toList(growable: false);
    if (layers.isEmpty) return null;
    final aspect = (designWidth / designHeight).clamp(0.6, 1.8);
    return (layers, aspect, canvasSize);
  } catch (_) {
    return null;
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;
  final ImageVariant variant;

  const _NetworkImage({required this.url, this.variant = ImageVariant.thumb});

  @override
  Widget build(BuildContext context) {
    final bundledAsset = bundledTemplateAssetPath(url);
    if (bundledAsset != null) {
      return Image.asset(
        bundledAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: SnapFitColors.overlayLightOf(context),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_outlined,
            size: 32,
            color: SnapFitColors.textMutedOf(context),
          ),
        ),
      );
    }
    final transformed = imageUrlByVariant(url, variant: variant);
    if (transformed.startsWith('asset:')) {
      return Image.asset(
        transformed.substring('asset:'.length),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: SnapFitColors.overlayLightOf(context),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_outlined,
            size: 32,
            color: SnapFitColors.textMutedOf(context),
          ),
        ),
      );
    }
    return Image.network(
      transformed,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Container(
        color: SnapFitColors.overlayLightOf(context),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: SnapFitColors.textMutedOf(context),
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: SnapFitColors.overlayLightOf(context),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';
import '../widgets/premium_template_list.dart';
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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = '전체';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templateListProvider);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      body: SafeArea(
        child: templatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _StoreErrorView(
            onRetry: () => ref.invalidate(templateListProvider),
          ),
          data: (templates) {
            final categories = _templateCategories(templates);
            if (!categories.contains(_selectedCategory)) {
              _selectedCategory = '전체';
            }
            final filteredTemplates = _filterTemplates(templates);
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(templateListProvider);
                await ref.read(templateListProvider.future);
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: platformScrollPhysics(alwaysScrollable: true),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _StoreHero(totalCount: templates.length),
                        const SizedBox(height: 22),
                        const PremiumTemplateList(maxItems: 3),
                        const SizedBox(height: 26),
                        _StoreDiscoveryControls(
                          categories: categories,
                          selectedCategory: _selectedCategory,
                          searchController: _searchController,
                          onCategoryChanged: (category) {
                            setState(() => _selectedCategory = category);
                          },
                        ),
                        const SizedBox(height: 18),
                        _AllTemplatesHeader(
                          visibleCount: filteredTemplates.length,
                          totalCount: templates.length,
                          selectedCategory: _selectedCategory,
                        ),
                        const SizedBox(height: 14),
                      ]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: filteredTemplates.isEmpty
                        ? const SliverToBoxAdapter(
                            child: _EmptyState(message: '조건에 맞는 템플릿이 없어요.'),
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
                              final template = filteredTemplates[index];
                              return _TemplateGridCard(
                                template: template,
                                onTap: () => _openDetail(template),
                              );
                            }, childCount: filteredTemplates.length),
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

  List<String> _templateCategories(List<PremiumTemplate> templates) {
    final values =
        templates
            .map((template) => (template.category ?? '').trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['전체', ...values];
  }

  List<PremiumTemplate> _filterTemplates(List<PremiumTemplate> templates) {
    final query = _searchController.text.trim().toLowerCase();
    return templates
        .where((template) {
          final category = (template.category ?? '').trim();
          final categoryMatches =
              _selectedCategory == '전체' || category == _selectedCategory;
          if (!categoryMatches) return false;
          if (query.isEmpty) return true;
          final tags = (template.tags ?? const <String>[]).join(' ');
          final haystack = [
            template.title,
            template.subTitle ?? '',
            template.description ?? '',
            category,
            tags,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _openDetail(PremiumTemplate template) {
    Navigator.push(
      context,
      snapFitRoute(page: TemplateDetailScreen(template: template)),
    );
  }
}

class _StoreHero extends StatelessWidget {
  final int totalCount;

  const _StoreHero({required this.totalCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SnapFitFadeIn(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF101827),
                    Color(0xFF221527),
                    Color(0xFF101114),
                  ]
                : const [
                    Color(0xFFFFF4E4),
                    Color(0xFFEAFBFD),
                    Color(0xFFF7ECFF),
                  ],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.10),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              const Positioned(
                right: -34,
                top: -32,
                child: _StoreHeroOrb(size: 142, color: Color(0x553BDDF2)),
              ),
              const Positioned(
                left: -28,
                bottom: -36,
                child: _StoreHeroOrb(size: 126, color: Color(0x44FFB86B)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: isDark ? 0.10 : 0.70,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            '$totalCount TEMPLATE DROPS',
                            style: TextStyle(
                              color: SnapFitColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: SnapFitColors.primaryGradient,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: SnapFitColors.accent.withValues(
                                  alpha: 0.30,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '스토어에서\n앨범의 분위기를 고르세요',
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '웨딩, 가족, 여행, 일상을 한 번에 완성도 있게 보여주는 감성 템플릿을 골라 바로 앨범 제작을 시작할 수 있어요.',
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 96,
                      child: Stack(
                        children: const [
                          Positioned(
                            left: 0,
                            top: 10,
                            child: _StoreHeroMiniCard(
                              width: 78,
                              colors: [Color(0xFFFFE2C5), Color(0xFFFFF7ED)],
                              angle: -0.12,
                            ),
                          ),
                          Positioned(
                            left: 64,
                            top: 0,
                            child: _StoreHeroMiniCard(
                              width: 88,
                              colors: [Color(0xFFE0F7FF), Color(0xFFFFFFFF)],
                              angle: 0.06,
                            ),
                          ),
                          Positioned(
                            left: 138,
                            top: 16,
                            child: _StoreHeroMiniCard(
                              width: 76,
                              colors: [Color(0xFFF4E7FF), Color(0xFFFFF8FB)],
                              angle: 0.13,
                            ),
                          ),
                        ],
                      ),
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

class _StoreHeroMiniCard extends StatelessWidget {
  const _StoreHeroMiniCard({
    required this.width,
    required this.colors,
    required this.angle,
  });

  final double width;
  final List<Color> colors;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: 86,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreHeroOrb extends StatelessWidget {
  const _StoreHeroOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _StoreDiscoveryControls extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final TextEditingController searchController;
  final ValueChanged<String> onCategoryChanged;

  const _StoreDiscoveryControls({
    required this.categories,
    required this.selectedCategory,
    required this.searchController,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '템플릿, 분위기, 카테고리 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: SnapFitColors.surfaceOf(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final category = categories[index];
              final selected = category == selectedCategory;
              return ChoiceChip(
                label: Text(category),
                selected: selected,
                onSelected: (_) => onCategoryChanged(category),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : SnapFitColors.textSecondaryOf(context),
                ),
                selectedColor: SnapFitColors.accent,
                backgroundColor: SnapFitColors.surfaceOf(context),
                side: BorderSide(
                  color: selected
                      ? SnapFitColors.accent
                      : SnapFitColors.overlayMediumOf(context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: categories.length,
          ),
        ),
      ],
    );
  }
}

class _AllTemplatesHeader extends StatelessWidget {
  final int visibleCount;
  final int totalCount;
  final String selectedCategory;

  const _AllTemplatesHeader({
    required this.visibleCount,
    required this.totalCount,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    final summary = selectedCategory == '전체'
        ? '$visibleCount개 전체 보기'
        : '$selectedCategory · $visibleCount/$totalCount개';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
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
          Text(
            summary,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SnapFitPressable(
      onTap: onTap,
      pressedScale: 0.955,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SnapFitColors.overlayLightOf(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _StoreTemplateCoverPreview(template: template),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.04),
                            Colors.black.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0.58),
                          ],
                          stops: const [0, 0.48, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: labelColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.44),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${template.likeCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_outward_rounded,
                              size: 16,
                              color: SnapFitColors.textPrimaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: SnapFitColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.subTitle ??
                          '${template.pageCount}p · ${template.category ?? '포토북'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SnapFitColors.textMutedOf(context),
                      ),
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

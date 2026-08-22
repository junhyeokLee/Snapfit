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
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF172033), Color(0xFF251A32)]
                : const [Color(0xFFFFF7ED), Color(0xFFEFF6FF)],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$totalCount개의 감성 포토북 템플릿',
                style: TextStyle(
                  color: SnapFitColors.textSecondaryOf(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '오늘의 장면을\n완성도 높은 앨범으로',
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.12,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '웨딩, 가족, 여행, 기념일 템플릿을 고르고 Supabase에 안전하게 저장되는 앨범을 바로 시작하세요.',
              style: TextStyle(
                color: SnapFitColors.textSecondaryOf(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
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

    return SnapFitPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
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
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 3),
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

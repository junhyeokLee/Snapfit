import 'package:flutter/material.dart';
import '../../../album/data/bundled_creation_templates.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/templates/template_catalog_categories.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';
import '../widgets/premium_template_list.dart';
import '../widgets/template_preview_frame.dart';
import 'template_detail_screen.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../../../../shared/widgets/catalog_favorite_widgets.dart';

String _storeRecommendedPhotoRange(PremiumTemplate template) {
  final count = publishedTemplatePhotoCount(template);
  if (count != null) return '$count장';
  final pages = template.pageCount <= 0 ? 24 : template.pageCount;
  final minPhotos = (pages * 1.6).round().clamp(18, 120);
  final maxPhotos = (pages * 2.15).round().clamp(minPhotos + 6, 160);
  return '$minPhotos~$maxPhotos장';
}

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
  bool _favoritesOnly = false;

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
  Widget build(BuildContext context) =>
      CatalogFavoritesBuilder(builder: _buildCatalog);

  Widget _buildCatalog(BuildContext context, CatalogFavorites favorites) {
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
            final filteredTemplates = favorites.arrange(
              _filterTemplates(templates),
              (t) => CatalogFavoriteKeys.template(t.id),
              onlyFavorites: _favoritesOnly,
            );
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
                        _StoreHero(
                          totalCount: templates.length,
                          categoryCount: categories.length > 1
                              ? categories.length - 1
                              : 0,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: CatalogFavoriteFilter(
                              selected: _favoritesOnly,
                              onChanged: (value) => setState(() {
                                _favoritesOnly = value;
                                _selectedCategory = '전체';
                                _searchController.clear();
                              }),
                            ),
                          ),
                        ),
                        if (!_favoritesOnly) ...[
                          const SizedBox(height: 22),
                          const _StoreSectionHeader(
                            title: '스냅핏 컬렉션',
                            subtitle: '표지와 내지 24쪽',
                          ),
                          const SizedBox(height: 12),
                          const PremiumTemplateList(maxItems: 3),
                          const SizedBox(height: 26),
                        ],
                        if (_favoritesOnly) const SizedBox(height: 18),
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
                          favoritesOnly: _favoritesOnly,
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
                        ? SliverToBoxAdapter(
                            child: _favoritesOnly
                                ? CatalogFavoritesEmpty(
                                    onShowAll: () => setState(() {
                                      _favoritesOnly = false;
                                      _selectedCategory = '전체';
                                      _searchController.clear();
                                    }),
                                  )
                                : const _EmptyState(),
                          )
                        : SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 280,
                                  mainAxisExtent: 320,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 14,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final template = filteredTemplates[index];
                              return CatalogFavoriteTile(
                                key: ValueKey('store-template-${template.id}'),
                                itemKey: CatalogFavoriteKeys.template(
                                  template.id,
                                ),
                                label: template.title,
                                child: _TemplateGridCard(
                                  template: template,
                                  onTap: () => _openDetail(template),
                                ),
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
    final values = orderedTemplateTopics(
      templates.map((template) => (template.category ?? '').trim()),
    );
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
  final int categoryCount;
  const _StoreHero({required this.totalCount, required this.categoryCount});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            '완성 템플릿',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
        ),
        Text(
          '$totalCount종',
          style: TextStyle(
            fontSize: 13,
            color: SnapFitColors.textMutedOf(context),
          ),
        ),
      ],
    ),
  );
}

class _StoreSectionHeader extends StatelessWidget {
  const _StoreSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '주제별 템플릿',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${categories.length - 1}가지 주제',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SnapFitColors.textMutedOf(context),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '주제, 분위기, 이름 검색',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '검색 지우기',
                          onPressed: searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: SnapFitColors.surfaceOf(
                    context,
                  ).withValues(alpha: 0.84),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: SnapFitColors.overlayLightOf(context),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: SnapFitColors.accent.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: SnapFitColors.overlayLightOf(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            key: const ValueKey('store-topic-filters'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                IntrinsicWidth(
                  child: _StoreCategoryPill(
                    label: category,
                    selected: category == selectedCategory,
                    onTap: () => onCategoryChanged(category),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreCategoryPill extends StatelessWidget {
  const _StoreCategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: SnapFitPressable(
        onTap: onTap,
        pressedScale: 0.97,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? SnapFitColors.accent.withValues(
                    alpha: SnapFitColors.isDark(context) ? 0.24 : 0.14,
                  )
                : SnapFitColors.surfaceOf(context).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? SnapFitColors.accent.withValues(alpha: 0.42)
                  : SnapFitColors.overlayLightOf(context),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: SnapFitColors.isDark(context) ? 0.22 : 0.08,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: selected
                  ? SnapFitColors.textPrimaryOf(context)
                  : SnapFitColors.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _AllTemplatesHeader extends StatelessWidget {
  final int visibleCount;
  final int totalCount;
  final String selectedCategory;
  final bool favoritesOnly;

  const _AllTemplatesHeader({
    required this.visibleCount,
    required this.totalCount,
    required this.selectedCategory,
    required this.favoritesOnly,
  });

  @override
  Widget build(BuildContext context) {
    final isAll = selectedCategory == '전체';
    final title = favoritesOnly
        ? '즐겨찾는 템플릿'
        : isAll
        ? '전체 템플릿'
        : '$selectedCategory 템플릿';
    final subtitle = favoritesOnly
        ? '저장한 컬렉션 $visibleCount개'
        : isAll
        ? '분위기별로 고른 $visibleCount개의 포토북 스타일'
        : '$selectedCategory 분위기에 어울리는 $visibleCount개';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
    final label = template.isBest
        ? 'BEST'
        : template.isNew
        ? 'NEW'
        : null;
    const labelColor = SnapFitColors.accent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${template.title} 룩북 보기 '
          '${template.category ?? '포토북'} · 내지 ${template.pageCount}쪽',
      onTap: onTap,
      child: SnapFitPressable(
        onTap: onTap,
        pressedScale: 0.98,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? SnapFitColors.surfaceOf(context)
                : const Color(0xFFFFFCF7),
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(11, 13, 11, 6),
                        child: _StoreTemplateSampleStack(template: template),
                      ),
                      if (!isPublishedCreationTemplate(template))
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.00),
                                Colors.black.withValues(alpha: 0.05),
                                Colors.black.withValues(alpha: 0.30),
                              ],
                              stops: const [0, 0.56, 1],
                            ),
                          ),
                        ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: PointShopProductBadge(
                          productKey: pointShopTemplateKey(template),
                        ),
                      ),
                      if (label != null)
                        Positioned(
                          top: 10,
                          right: 10,
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
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '룩북 보기',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: SnapFitColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: SnapFitColors.textPrimaryOf(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
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
                      if ((template.subTitle ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          template.subTitle!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: SnapFitColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${template.category ?? '포토북'} · ${template.pageCount}쪽 · 사진 ${_storeRecommendedPhotoRange(template)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: SnapFitColors.overlayLightOf(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: SnapFitColors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                color: SnapFitColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '템플릿 숍을 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '잠시 후 다시 시도하면 추천 템플릿을 이어서 볼 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: SnapFitColors.textMutedOf(context),
              ),
            ),
            const SizedBox(height: 18),
            SnapFitPressable(
              onTap: onRetry,
              pressedScale: 0.98,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: SnapFitColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '다시 불러오기',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context).withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: SnapFitColors.accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.collections_bookmark_outlined,
              color: SnapFitColors.accent,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '아직 이 무드의 템플릿이 없어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '곧 새로운 포토북 스타일을 채워둘게요. 전체 템플릿에서 먼저 둘러보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: SnapFitColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: SnapFitColors.accent.withValues(alpha: 0.20),
              ),
            ),
            child: const Text(
              '전체 템플릿 보기',
              style: TextStyle(
                color: SnapFitColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreTemplateSampleStack extends StatelessWidget {
  const _StoreTemplateSampleStack({required this.template});

  final PremiumTemplate template;

  @override
  Widget build(BuildContext context) {
    if (isPublishedCreationTemplate(template)) {
      return CreationCatalogCover(template: template);
    }
    final urls = <String>[
      _storeCoverPreviewUrl(template),
      ...template.previewImages.map((e) => e.trim()),
    ].where((e) => e.isNotEmpty).toSet().toList(growable: false);
    Widget page(
      int index, {
      required double scale,
      required Offset offset,
      required double opacity,
    }) {
      final hasUrl = index < urls.length;
      return Positioned.fill(
        child: FractionalTranslation(
          translation: Offset(offset.dx / 130, offset.dy / 180),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Opacity(
              opacity: opacity,
              child: TemplatePreviewFrame(
                borderRadius: 22,
                padding: EdgeInsets.all(4.w),
                showShadow: index == 0,
                child: hasUrl
                    ? _NetworkImage(
                        url: urls[index],
                        variant: ImageVariant.thumb,
                      )
                    : const TemplatePaperPlaceholder(compact: true),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        page(2, scale: 0.84, offset: const Offset(16, -10), opacity: 0.78),
        page(1, scale: 0.90, offset: const Offset(9, -4), opacity: 0.88),
        page(0, scale: 1.0, offset: Offset.zero, opacity: 1),
      ],
    );
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
        errorBuilder: (_, __, ___) => const TemplatePaperPlaceholder(),
      );
    }
    final transformed = imageUrlByVariant(url, variant: variant);
    if (transformed.startsWith('asset:')) {
      return Image.asset(
        transformed.substring('asset:'.length),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const TemplatePaperPlaceholder(),
      );
    }
    return Image.network(
      transformed,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const TemplatePaperPlaceholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const TemplatePaperPlaceholder();
      },
    );
  }
}

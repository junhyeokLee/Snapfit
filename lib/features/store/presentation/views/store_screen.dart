import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';
import '../widgets/premium_template_list.dart';
import '../widgets/template_preview_frame.dart';
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
                            'SNAPFIT TEMPLATE STORE',
                            style: TextStyle(
                              color: SnapFitColors.accent,
                              fontSize: 12,
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
                      '사진만 골라도\n앨범처럼 완성되게',
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
                      '가족, 여행, 웨딩, 아기 기록에 맞춘 감성 포토북 템플릿을 골라보세요.',
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
                              label: 'Family',
                              colors: [Color(0xFFFFE2C5), Color(0xFFFFF7ED)],
                              angle: -0.12,
                            ),
                          ),
                          Positioned(
                            left: 64,
                            top: 0,
                            child: _StoreHeroMiniCard(
                              width: 88,
                              label: 'Travel',
                              colors: [Color(0xFFE0F7FF), Color(0xFFFFFFFF)],
                              angle: 0.06,
                            ),
                          ),
                          Positioned(
                            left: 138,
                            top: 16,
                            child: _StoreHeroMiniCard(
                              width: 76,
                              label: 'Wedding',
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
    required this.label,
  });

  final double width;
  final List<Color> colors;
  final double angle;
  final String label;

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
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: SnapFitColors.deepCharcoal.withValues(alpha: 0.62),
              fontSize: 10,
              fontWeight: FontWeight.w900,
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
              hintText: '어떤 기록을 만들까요?',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: SnapFitColors.surfaceOf(
                context,
              ).withValues(alpha: 0.86),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: SnapFitColors.overlayLightOf(context),
                ),
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
                selectedColor: SnapFitColors.deepCharcoal,
                backgroundColor: SnapFitColors.surfaceOf(
                  context,
                ).withValues(alpha: 0.76),
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
    final label = template.isBest
        ? 'BEST'
        : template.isNew
        ? 'NEW'
        : template.isPremium
        ? 'PREMIUM'
        : '무료 사용';
    final labelColor = (template.isBest || template.isNew || template.isPremium)
        ? SnapFitColors.accent
        : SnapFitColors.textSecondaryOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SnapFitPressable(
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
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                      child: _StoreTemplateSampleStack(template: template),
                    ),
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
                      right: 12,
                      bottom: 12,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.90),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 15,
                          color: SnapFitColors.textPrimaryOf(context),
                        ),
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
                      '${template.category ?? '포토북'} · ${template.pageCount}페이지 구성',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
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

class _StoreTemplateSampleStack extends StatelessWidget {
  const _StoreTemplateSampleStack({required this.template});

  final PremiumTemplate template;

  @override
  Widget build(BuildContext context) {
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

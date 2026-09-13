import 'package:flutter/material.dart';
import '../../../../point_shop/domain/point_shop_template_key.dart';
import '../../../../point_shop/data/point_shop_provider.dart';
import '../../../../point_shop/presentation/point_shop_access.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../store/domain/entities/premium_template.dart';
import 'creation_catalog_cover.dart';
import '../../../../../shared/widgets/catalog_favorite_widgets.dart';

class AiAlbumStartStep extends ConsumerStatefulWidget {
  final VoidCallback onAiStart;
  final VoidCallback onManualStart;
  final int aiPointCost;
  final String? freeDraftLabel;
  final bool isFirstAiDraftFree;
  final AsyncValue<List<PremiumTemplate>> templates;
  final ValueChanged<PremiumTemplate>? onTemplateSelected;
  final VoidCallback? onRetry;

  const AiAlbumStartStep({
    super.key,
    required this.onAiStart,
    required this.onManualStart,
    this.aiPointCost = 300,
    this.freeDraftLabel,
    this.isFirstAiDraftFree = false,
    this.templates = const AsyncData([]),
    this.onTemplateSelected,
    this.onRetry,
  });

  @override
  ConsumerState<AiAlbumStartStep> createState() => _AiAlbumStartStepState();
}

class _AiAlbumStartStepState extends ConsumerState<AiAlbumStartStep> {
  String _filter = '전체';
  bool _favoritesOnly = false;
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CatalogFavoritesBuilder(builder: _buildCatalog);

  Widget _buildCatalog(BuildContext context, CatalogFavorites favorites) {
    final ink = SnapFitColors.textPrimaryOf(context);
    final muted = SnapFitColors.textSecondaryOf(context);
    final catalog = ref.watch(pointShopCatalogProvider);
    final products = {
      for (final product in catalog.asData?.value ?? const [])
        product.productKey: product,
    };
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 4 : 2;
          return CustomScrollView(
            key: const PageStorageKey('albumCreationHub'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '어떤 앨범을 만들까요?',
                        style: TextStyle(
                          fontSize: 25,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _StartAction(
                              title: '직접 만들기',
                              subtitle: '빈 앨범부터 자유롭게',
                              icon: Icons.add,
                              onTap: widget.onManualStart,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StartAction(
                              title: 'AI 템플릿으로 시작',
                              subtitle: '원하는 느낌으로 새롭게',
                              icon: Icons.auto_awesome_outlined,
                              ai: true,
                              onTap: widget.onAiStart,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        '템플릿에서 시작',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _search,
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        style: TextStyle(fontSize: 14, color: ink),
                        decoration: InputDecoration(
                          hintText: '여행, 웨딩, 일상 검색',
                          prefixIcon: const Icon(Icons.search, size: 21),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '검색 지우기',
                                  icon: const Icon(Icons.close, size: 19),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          filled: true,
                          fillColor: SnapFitColors.surfaceOf(context),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: ink.withValues(alpha: .12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          textStyle: const TextStyle(
                            fontFamily: SnapFitFonts.body,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedBackgroundColor: ink,
                          selectedForegroundColor: SnapFitColors.backgroundOf(
                            context,
                          ),
                          side: BorderSide(color: ink.withValues(alpha: .15)),
                        ),
                        segments: const [
                          ButtonSegment(value: '전체', label: Text('전체')),
                          ButtonSegment(value: '무료', label: Text('무료')),
                          ButtonSegment(value: '포인트', label: Text('포인트')),
                        ],
                        selected: {_filter},
                        onSelectionChanged: catalog.hasValue
                            ? (value) => setState(() => _filter = value.first)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      CatalogFavoriteFilter(
                        selected: _favoritesOnly,
                        onChanged: (value) =>
                            setState(() => _favoritesOnly = value),
                      ),
                    ],
                  ),
                ),
              ),
              widget.templates.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text('템플릿을 불러오지 못했어요', style: TextStyle(color: muted)),
                        TextButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 불러오기'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (templates) {
                  final visible = favorites.arrange(
                    templates.where((template) {
                      final product = products[pointShopTemplateKey(template)];
                      final isFree =
                          product == null ||
                          (product.isActive && product.pointPrice == 0);
                      if (_filter == '무료' && !isFree) return false;
                      if (_filter == '포인트' && isFree) return false;
                      return '${template.title} ${template.category ?? ''} ${(template.tags ?? []).join(' ')}'
                          .toLowerCase()
                          .contains(_query);
                    }),
                    (t) => CatalogFavoriteKeys.template(t.id),
                    onlyFavorites: _favoritesOnly,
                  );
                  if (visible.isEmpty && _favoritesOnly)
                    return SliverToBoxAdapter(
                      child: CatalogFavoritesEmpty(
                        onShowAll: () => setState(() {
                          _favoritesOnly = false;
                          _filter = '전체';
                          _query = '';
                          _search.clear();
                        }),
                      ),
                    );
                  if (visible.isEmpty)
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.collections_bookmark_outlined,
                              size: 32,
                              color: muted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty ? '등록된 템플릿이 없어요' : '검색 결과가 없어요',
                              style: TextStyle(color: muted),
                            ),
                          ],
                        ),
                      ),
                    );
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 24,
                        mainAxisExtent:
                            ((constraints.maxWidth - 48 - 16 * (columns - 1)) /
                                    columns) *
                                1.12 +
                            90,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final template = visible[index];
                        return CatalogFavoriteTile(
                          itemKey: CatalogFavoriteKeys.template(template.id),
                          label: template.title,
                          child: Semantics(
                            button: true,
                            label: template.title,
                            child: InkWell(
                              key: ValueKey('creation-template-${template.id}'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: widget.onTemplateSelected == null
                                  ? null
                                  : () => widget.onTemplateSelected!(template),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AspectRatio(
                                    aspectRatio: 1 / 1.12,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      color: SnapFitColors.isDark(context)
                                          ? const Color(0xFF242828)
                                          : const Color(0xFFEDF0EF),
                                      child: CreationCatalogCover(
                                        template: template,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    template.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  PointShopProductBadge(
                                    productKey: pointShopTemplateKey(template),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }, childCount: visible.length),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StartAction extends StatelessWidget {
  const _StartAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.ai = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool ai;

  @override
  Widget build(BuildContext context) {
    final dark = SnapFitColors.isDark(context);
    final ink = SnapFitColors.textPrimaryOf(context);
    return Material(
      color: ai
          ? (dark ? const Color(0xFF153D3D) : const Color(0xFFE5F1EF))
          : SnapFitColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: ink.withValues(alpha: .10)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 160),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: ai
                      ? (dark
                            ? const Color(0xFF96D9D2)
                            : const Color(0xFF22625D))
                      : ink,
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: SnapFitColors.textSecondaryOf(context),
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

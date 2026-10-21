import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../shared/web/web_design.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;

import '../../../../shared/widgets/catalog_filter_bar.dart';
import '../../../../shared/widgets/snapfit_shimmer.dart';
import '../../../../shared/widgets/experience_icon.dart';
import 'material_catalog_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../widgets/template_curation.dart';
import '../widgets/store_material_discovery.dart';
import '../widgets/template_editorial_list.dart';
import '../widgets/store_topic_shelf.dart';
import '../widgets/web/web_catalog_toolbar.dart';
import '../widgets/web/web_catalog_footer.dart';
import '../widgets/template_catalog_tile.dart';
import '../widgets/template_design_comparison.dart';
import '../widgets/public_template_information.dart';
import '../../data/store_curation_provider.dart';
import '../../../../core/templates/template_catalog_categories.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';
import 'template_detail_screen.dart';
import '../../../point_shop/data/point_shop_provider.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({
    super.key,
    this.ownedOnly = false,
    this.embedded = false,
    this.editorial = false,
    this.onBrowseMaterials,
    this.searchMode = false,
  });
  final bool ownedOnly;
  final bool embedded;
  final bool editorial;
  final bool searchMode;
  final VoidCallback? onBrowseMaterials;
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _filterAnchor = GlobalKey();
  bool? _pendingRevealAtTop;
  bool _revealScheduled = false;
  bool _revealing = false;
  String _lastSearchText = '';
  static const _pageSize = 12;
  int _visibleCount = _pageSize;
  int _resultCount = 0;
  bool _loadingMore = false;
  int _pageGeneration = 0;
  String _priceFilter = '전체';
  String _sort = '추천순';
  TemplateDesignComparisonSelection _comparison =
      const TemplateDesignComparisonSelection.empty();

  void _toggleComparison(PremiumTemplate template) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_comparison.contains(template.id)) {
      setState(() => _comparison = _comparison.remove(template.id));
    } else if (_comparison.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TemplateDesignComparisonSelection.limitMessage),
        ),
      );
    } else {
      setState(() => _comparison = _comparison.add(template.id));
    }
  }

  Widget _withComparison(List<PremiumTemplate> catalog, Widget content) {
    final selected = [
      for (final id in _comparison.ids)
        ...catalog.where((template) => template.id == id).take(1),
    ];
    void remove(PremiumTemplate template) =>
        setState(() => _comparison = _comparison.remove(template.id));
    void clear() => setState(() => _comparison = _comparison.clear());
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        children: [
          Expanded(child: content),
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: bounds.hasBoundedHeight
                    ? bounds.maxHeight * .4
                    : 240,
              ),
              child: TemplateDesignComparisonTray(
                designs: selected,
                onRemove: remove,
                onClear: clear,
                onCompare: () => showTemplateDesignComparison(
                  context,
                  designs: selected,
                  onRemove: remove,
                  onClear: clear,
                  onOpen: _openTemplate,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _resetPage() {
    _pageGeneration++;
    _loadingMore = false;
    _visibleCount = _pageSize;
  }

  void _resetFilteredPage() {
    _resetPage();
    _requestCatalogReveal(atTop: false);
  }

  void _requestCatalogReveal({required bool atTop}) {
    _pendingRevealAtTop = atTop;
    _scheduleCatalogReveal();
  }

  // Resolve after the new layout: changing a subject/price can remove a large
  // collection above the controls, so the old offset no longer identifies them.
  void _scheduleCatalogReveal() {
    if (_pendingRevealAtTop == null || _revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted || _pendingRevealAtTop == null) return;
      final positions = _scrollController.positions;
      if (positions.length != 1 ||
          !positions.single.hasContentDimensions ||
          positions.single.viewportDimension <= 0)
        return;
      final position = positions.single;
      var destination = 0.0;
      if (!_pendingRevealAtTop!) {
        final target = _filterAnchor.currentContext?.findRenderObject();
        if (target is! RenderBox || !target.attached || !target.hasSize) return;
        final viewport = RenderAbstractViewport.maybeOf(target);
        if (viewport == null) return;
        destination = viewport.getOffsetToReveal(target, 0).offset;
        if (!destination.isFinite) return;
      }
      _pendingRevealAtTop = null;
      _revealing = true;
      try {
        position.jumpTo(
          destination.clamp(position.minScrollExtent, position.maxScrollExtent),
        );
      } finally {
        _revealing = false;
      }
    });
  }

  void _onSearchChanged() {
    if (_searchController.text == _lastSearchText) return;
    _lastSearchText = _searchController.text;
    setState(_resetFilteredPage);
  }

  void _openTemplate(PremiumTemplate template) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: kIsWeb
            ? WebAppRouteSettings(
                WebAppLocation(WebAppPage.template, '${template.id}'),
              )
            : null,
        builder: (_) => TemplateDetailScreen(
          template: template,
          heroTag: (this, template.id),
        ),
      ),
    );
  }

  void _loadNearEnd() {
    if (!_revealing &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < 300 &&
        _visibleCount < _resultCount) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _visibleCount >= _resultCount) return;
    final generation = _pageGeneration;
    setState(() => _loadingMore = true);
    // Paint the progress state before mounting the next batch of native covers.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    if (!mounted || generation != _pageGeneration) return;
    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(0, _resultCount);
      _loadingMore = false;
    });
  }

  String _selectedCategory = '전체';
  bool _favoritesOnly = false;
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_loadNearEnd);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CatalogFavoritesBuilder(
    builder: (context, favorites) {
      final data = ref.watch(templateListProvider);
      final prices = {
        for (final product
            in ref.watch(pointShopCatalogProvider).asData?.value ?? [])
          product.productKey: product,
      };
      final owned = (widget.ownedOnly || kIsWeb)
          ? ref.watch(ownedPointShopKeysProvider)
          : null;
      return _catalogFrame(
        body: SafeArea(
          top: false,
          child: data.when(
            loading: () => const SingleChildScrollView(
              child: SnapFitShimmerTemplateTileGrid(rows: 4),
            ),
            error: (_, __) => Center(
              child: TextButton.icon(
                onPressed: () => ref.invalidate(templateListProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('다시 불러오기'),
              ),
            ),
            data: (templates) {
              if (widget.ownedOnly && owned!.isLoading) {
                return const SingleChildScrollView(
                  child: SnapFitShimmerTemplateTileGrid(rows: 4),
                );
              }
              if (widget.ownedOnly && owned!.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(ownedPointShopKeysProvider),
                    child: const Text('보관함 다시 불러오기'),
                  ),
                );
              }
              // A pending reveal may have waited while a refresh showed its
              // loading state. Data is mounted again at the end of this frame.
              _scheduleCatalogReveal();
              final categories = [
                '전체',
                ...orderedTemplateTopics(
                  templates.map((t) => t.category ?? ''),
                ),
              ];
              final query = _searchController.text.trim().toLowerCase();
              bool paid(PremiumTemplate template) {
                final product = prices[pointShopTemplateKey(template)];
                return product?.pointPrice != null
                    ? product!.pointPrice! > 0
                    : template.isPremium;
              }

              final free = templates.where((t) => !paid(t)).toList();
              final premium = templates.where(paid).toList();
              final ordered = <PremiumTemplate>[];
              // Two free editions and one premium edition per recommendation group.
              var f = 0;
              var p = 0;
              while (f < free.length || p < premium.length) {
                for (var n = 0; n < 2 && f < free.length; n++) {
                  ordered.add(free[f++]);
                }
                if (p < premium.length) ordered.add(premium[p++]);
              }
              final sorted = ordered;
              if (_sort == '이름순') {
                sorted.sort((a, b) => a.title.compareTo(b.title));
              }
              final filtered = favorites.arrange(
                sorted
                    .where(
                      (t) =>
                          (_priceFilter == '전체' ||
                              (_priceFilter == '보유'
                                  ? (owned?.asData?.value.contains(
                                          pointShopTemplateKey(t),
                                        ) ??
                                        false)
                                  : (_priceFilter == '유료') == paid(t))) &&
                          (!widget.ownedOnly ||
                              (owned?.asData?.value.contains(
                                    pointShopTemplateKey(t),
                                  ) ??
                                  false)) &&
                          (_selectedCategory == '전체' ||
                              t.category == _selectedCategory) &&
                          [
                            t.title,
                            t.subTitle ?? '',
                            t.description ?? '',
                            ...?t.tags,
                          ].any((v) => v.toLowerCase().contains(query)),
                    )
                    .toList(),
                (t) => CatalogFavoriteKeys.template(t.id),
                onlyFavorites: _favoritesOnly,
              );
              _resultCount = filtered.length;
              final spotlight =
                  !widget.ownedOnly &&
                      !widget.searchMode &&
                      filtered.isNotEmpty &&
                      query.isEmpty &&
                      _priceFilter == '전체' &&
                      !_favoritesOnly &&
                      _sort == '추천순'
                  ? filtered.where(paid).firstOrNull ?? filtered.first
                  : null;
              final curation = !widget.ownedOnly
                  ? ref.watch(storeCurationsProvider).asData?.value['templates']
                  : null;
              final showDiscoveryFeatures =
                  _selectedCategory == '전체' && spotlight != null;
              return _withComparison(
                templates,
                RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _resetPage();
                      _requestCatalogReveal(atTop: true);
                    });
                    ref.invalidate(templateListProvider);
                    ref.invalidate(storeCurationsProvider);
                    ref.invalidate(pointShopCatalogProvider);
                    ref.invalidate(publicPointShopCatalogProvider);
                    try {
                      await Future.wait([
                        ref.read(templateListProvider.future),
                        ref.read(storeCurationsProvider.future),
                        ref.read(pointShopCatalogProvider.future),
                      ]);
                    } catch (_) {
                      /* Catalog widgets retain scoped errors. */
                    }
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    // A bounded warm-up area avoids building covers at the visible edge.
                    cacheExtent: 280,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (!widget.embedded && !kIsWeb && !widget.searchMode)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                            child: Text(
                              widget.ownedOnly ? '내가 고른 디자인' : '앨범 템플릿',
                              style: ExperienceFormStyle.text(
                                context,
                                28,
                                weight: FontWeight.w700,
                              ).copyWith(height: 1.2, letterSpacing: -0.4),
                            ),
                          ),
                        ),
                      if (showDiscoveryFeatures && curation != null)
                        SliverToBoxAdapter(
                          key: const ValueKey('store-curation-sliver'),
                          child: SizedBox(
                            key: const ValueKey('store-collection-spotlight'),
                            child: TemplateCuration(
                              templates: filtered.where((t) {
                                final product = prices[pointShopTemplateKey(t)];
                                return product == null ||
                                    (product.isActive &&
                                        product.pointPrice != null);
                              }).toList(),
                              selection: curation,
                              onOpen: _openTemplate,
                            ),
                          ),
                        ),
                      if (widget.editorial &&
                          showDiscoveryFeatures &&
                          widget.onBrowseMaterials != null)
                        SliverToBoxAdapter(
                          child: StoreMaterialDiscovery(
                            onBrowse: widget.onBrowseMaterials!,
                          ),
                        ),
                      SliverPadding(
                        key: const ValueKey('store-filters-sliver'),
                        padding: EdgeInsets.fromLTRB(
                          kIsWeb ? 0 : 20,
                          0,
                          kIsWeb ? 0 : 20,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            key: _filterAnchor,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!widget.ownedOnly &&
                                  !kIsWeb &&
                                  !widget.editorial) ...[
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: ExperienceFormStyle.selectionInk(
                                          context,
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '주제별 템플릿',
                                      style: ExperienceFormStyle.text(
                                        context,
                                        17,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (kIsWeb)
                                WebCatalogToolbar(
                                  controller: _searchController,
                                  searchHint: '템플릿 이름, 주제, 키워드 검색',
                                  onSearchChanged: (_) {},
                                  categories: categories,
                                  category: _selectedCategory,
                                  onCategoryChanged: (value) => setState(() {
                                    _selectedCategory = value;
                                    _resetFilteredPage();
                                  }),
                                  price: _priceFilter,
                                  onPriceChanged: (value) => setState(() {
                                    _priceFilter = value;
                                    _resetFilteredPage();
                                  }),
                                  favoritesOnly: _favoritesOnly,
                                  onFavoritesChanged: () => setState(() {
                                    _favoritesOnly = !_favoritesOnly;
                                    _resetFilteredPage();
                                  }),
                                  resultLabel: '${filtered.length}개의 템플릿',
                                  sort: _sort,
                                  onSortChanged: (value) => setState(() {
                                    _sort = value;
                                    _resetFilteredPage();
                                  }),
                                  filtersActive:
                                      query.isNotEmpty ||
                                      _selectedCategory != '전체' ||
                                      _priceFilter != '전체' ||
                                      _favoritesOnly ||
                                      _sort != '추천순',
                                  onReset: _resetWebFilters,
                                )
                              else ...[
                                if (widget.searchMode) ...[
                                  TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: ExperienceFormStyle.text(
                                      context,
                                      14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '어떤 순간을 담고 싶나요?',
                                      hintStyle: ExperienceFormStyle.text(
                                        context,
                                        14,
                                        color: ExperienceFormStyle.muted(
                                          context,
                                        ),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 21,
                                      ),
                                      suffixIcon: query.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: '검색 지우기',
                                              onPressed:
                                                  _searchController.clear,
                                              icon: const Icon(
                                                Icons.close,
                                                size: 20,
                                              ),
                                            ),
                                      filled: true,
                                      fillColor: ExperienceFormStyle.surface(
                                        context,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          SnapFitRadius.md,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          SnapFitRadius.md,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ] else
                                  StoreTopicShelf(
                                    categories: categories,
                                    templates: templates,
                                    selected: _selectedCategory,
                                    onSelect: (value) => setState(() {
                                      _selectedCategory = value;
                                      _resetFilteredPage();
                                    }),
                                  ),
                                const SizedBox(height: 20),
                                Text(
                                  _selectedCategory == '전체'
                                      ? '모든 템플릿'
                                      : '$_selectedCategory 템플릿',
                                  style: ExperienceFormStyle.text(
                                    context,
                                    18,
                                    weight: FontWeight.w700,
                                  ).copyWith(letterSpacing: -0.2),
                                ),
                                const SizedBox(height: 8),
                                CatalogFilterBar(
                                  price: _priceFilter,
                                  onPriceChanged: (value) => setState(() {
                                    _priceFilter = value;
                                    _resetFilteredPage();
                                  }),
                                  favoritesOnly: _favoritesOnly,
                                  onFavoritesChanged: () => setState(() {
                                    _favoritesOnly = !_favoritesOnly;
                                    _resetFilteredPage();
                                  }),
                                  resultLabel: _selectedCategory == '전체'
                                      ? '${filtered.length}개의 디자인'
                                      : '$_selectedCategory · ${filtered.length}종',
                                  sort: _sort,
                                  onSortChanged: (value) => setState(() {
                                    _sort = value;
                                    _resetFilteredPage();
                                  }),
                                ),
                              ],
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: !kIsWeb
                              ? const Center(child: Text('조건에 맞는 디자인이 없어요'))
                              : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.search_off, size: 36),
                                      const SizedBox(height: 12),
                                      Text(
                                        kIsWeb &&
                                                _priceFilter == '보유' &&
                                                owned?.isLoading == true
                                            ? '보유한 디자인을 확인하고 있어요'
                                            : '조건에 맞는 디자인이 없어요',
                                      ),
                                      if (kIsWeb)
                                        TextButton(
                                          onPressed:
                                              _priceFilter == '보유' &&
                                                  owned?.hasError == true
                                              ? () => ref.invalidate(
                                                  ownedPointShopKeysProvider,
                                                )
                                              : _resetWebFilters,
                                          child: Text(
                                            _priceFilter == '보유' &&
                                                    owned?.hasError == true
                                                ? '보유 목록 다시 불러오기'
                                                : '검색·필터 초기화',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      SliverPadding(
                        key: const ValueKey('store-grid-sliver'),
                        padding: EdgeInsets.fromLTRB(
                          kIsWeb ? 0 : 16,
                          0,
                          kIsWeb ? 0 : 16,
                          32,
                        ),
                        sliver: widget.editorial && spotlight != null
                            ? TemplateEditorialList(
                                templates: filtered,
                                visibleCount: _visibleCount,
                                onOpen: _openTemplate,
                                onCompare: _toggleComparison,
                                comparisonIds: _comparison.ids,
                                heroTag: (t) => (this, t.id),
                                scrollController: _scrollController,
                              )
                            : SliverLayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = kIsWeb
                                      ? (constraints.crossAxisExtent >= 1080
                                            ? 4
                                            : constraints.crossAxisExtent >= 760
                                            ? 3
                                            : constraints.crossAxisExtent >= 430
                                            ? 2
                                            : 1)
                                      : constraints.crossAxisExtent > 650
                                      ? 3
                                      : 2;
                                  final gap = kIsWeb ? 16.0 : 14.0;
                                  final width =
                                      (constraints.crossAxisExtent -
                                          gap * (columns - 1)) /
                                      columns;
                                  final scaler = MediaQuery.textScalerOf(
                                    context,
                                  );
                                  final screen = MediaQuery.sizeOf(context);
                                  final previewRatio = kIsWeb
                                      ? 1.06
                                      : screen.width > screen.height
                                      ? 1.12
                                      : .92;
                                  return SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          crossAxisSpacing: gap,
                                          mainAxisSpacing: 18,
                                          mainAxisExtent:
                                              TemplateCatalogTile.extent(
                                                width,
                                                previewRatio,
                                                scaler,
                                              ),
                                        ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, i) {
                                        final template = filtered[i];
                                        return TemplateCatalogTile(
                                          template: template,
                                          onCompare: () =>
                                              _toggleComparison(template),
                                          comparisonSelected: _comparison
                                              .contains(template.id),
                                          onOpen: () => _openTemplate(template),
                                          heroTag: (this, template.id),
                                          scrollController: _scrollController,
                                          previewRatio: previewRatio,
                                        );
                                      },
                                      childCount: _visibleCount.clamp(
                                        0,
                                        filtered.length,
                                      ),
                                      addAutomaticKeepAlives: false,
                                    ),
                                  );
                                },
                              ),
                      ),
                      if (_visibleCount < filtered.length)
                        SliverToBoxAdapter(
                          child: kIsWeb
                              ? WebCatalogFooter(
                                  loading: _loadingMore,
                                  visible: _visibleCount,
                                  total: filtered.length,
                                  noun: '템플릿',
                                  onMore: _loadMore,
                                )
                              : SizedBox(
                                  height: 56,
                                  child: Center(
                                    child: _loadingMore
                                        ? const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                              SizedBox(width: 10),
                                              Text('템플릿을 더 불러오고 있어요'),
                                            ],
                                          )
                                        : OutlinedButton(
                                            onPressed: _loadMore,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  ExperienceFormStyle.selectionInk(
                                                    context,
                                                  ),
                                              side: BorderSide(
                                                color: ExperienceFormStyle.line(
                                                  context,
                                                ),
                                              ),
                                              minimumSize: const Size(140, 38),
                                              shape: const StadiumBorder(),
                                              textStyle:
                                                  ExperienceFormStyle.text(
                                                    context,
                                                    13,
                                                    weight: FontWeight.w600,
                                                  ),
                                            ),
                                            child: Text(
                                              '더 보기  $_visibleCount / ${filtered.length}',
                                            ),
                                          ),
                                  ),
                                ),
                        ),
                      if (filtered.isNotEmpty &&
                          _visibleCount >= filtered.length)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Center(
                              child: Text(
                                '${filtered.length}개 템플릿을 모두 확인했어요',
                                style: ExperienceFormStyle.text(
                                  context,
                                  12,
                                  color: ExperienceFormStyle.muted(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );

  void _resetWebFilters() => setState(() {
    _searchController.clear();
    _selectedCategory = '전체';
    _priceFilter = '전체';
    _favoritesOnly = false;
    _sort = '추천순';
    _resetFilteredPage();
  });

  void _openLibrary() {
    final scope = ExperienceNavigationScope.maybeOf(context);
    if (scope != null) {
      scope.onNavigate(6);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: kIsWeb
            ? const WebAppRouteSettings(WebAppLocation.library)
            : null,
        builder: (_) => const MaterialCatalogScreen(library: true),
      ),
    );
  }

  Widget _catalogFrame({required Widget body}) {
    if (kIsWeb) {
      if (widget.embedded) return body;
      return SnapFitWebShell(
        section: WebSection.designs,
        actions: [
          OutlinedButton.icon(
            onPressed: _openLibrary,
            icon: const Icon(Icons.bookmark_outline, size: 18),
            label: const Text('내 디자인 보관함'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WebPageHeading(title: widget.ownedOnly ? '내가 고른 템플릿' : '앨범 템플릿'),
            const SizedBox(height: 20),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: widget.embedded
          ? null
          : ExperienceHeader(
              title: widget.searchMode
                  ? '템플릿 검색'
                  : widget.ownedOnly
                  ? '내 보관함'
                  : '스토어',
              brand: !widget.ownedOnly && !widget.searchMode,
              back: widget.ownedOnly || widget.searchMode,
              showNotifications: !widget.searchMode,
              actions: [
                if (!widget.ownedOnly && !widget.searchMode)
                  IconButton(
                    tooltip: '내 보관함',
                    icon: const ExperienceIcon('Bookmark'),
                    onPressed: _openLibrary,
                  ),
              ],
            ),
      body: body,
    );
  }
}

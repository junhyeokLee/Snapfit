import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../shared/web/web_design.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/viewport_sliver_layout_builder.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;

import '../../../../shared/widgets/catalog_filter_bar.dart';
import '../../../../shared/widgets/catalog_active_filters.dart';
import '../../../../shared/widgets/catalog_empty_result.dart';
import '../../../../shared/widgets/snapfit_shimmer.dart';
import '../../../../shared/widgets/catalog_skeleton_shimmer.dart';
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
import '../widgets/template_catalog_tile.dart';
import '../widgets/template_design_comparison.dart';
import '../widgets/public_template_information.dart';
import '../../data/store_curation_provider.dart';
import '../../domain/store_template_recommendations.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/domain/point_shop_product.dart';
import '../../data/api/template_provider.dart';
import '../../../album/data/bundled_creation_templates.dart'
    show publishedCreationTemplates;
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
  int? _paginationFrame;
  String _lastSearchText = '';
  String _priceFilter = '전체';
  String _sort = '추천순';
  TemplateDesignComparisonSelection _comparison =
      const TemplateDesignComparisonSelection.empty();
  final _comparisonTemplates = <int, PremiumTemplate>{};
  Widget? _catalogContent;
  late final _categories = storeTemplateCategories(
    publishedCreationTemplates.map((t) => t.category ?? ''),
  ).where((t) => !widget.ownedOnly || t != storeRecommendedCategory).toList();
  bool get _isRecommended => _selectedCategory == storeRecommendedCategory;

  Widget _recommendationCaption(BuildContext context) => Text(
    _priceFilter == '전체' && !_favoritesOnly
        ? '여러 주제와 무료·유료 디자인을 골고루 모았어요.'
        : '선택한 조건에 맞춰 여러 주제의 디자인을 모았어요.',
    key: const ValueKey('store-recommendation-description'),
    style: ExperienceFormStyle.text(
      context,
      12,
      secondary: true,
    ).copyWith(height: 1.5),
  );

  void _toggleComparison(PremiumTemplate template) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_comparison.contains(template.id)) {
      setState(() {
        _comparison = _comparison.remove(template.id);
        _comparisonTemplates.remove(template.id);
      });
    } else if (_comparison.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TemplateDesignComparisonSelection.limitMessage),
        ),
      );
    } else {
      setState(() {
        _comparison = _comparison.add(template.id);
        _comparisonTemplates[template.id] = template;
      });
    }
  }

  Widget _withComparison(List<PremiumTemplate> catalog, Widget content) {
    // Selected products remain available across filters without starting a
    // second, full-catalog request just to display the comparison tray.
    final selected = <PremiumTemplate>[];
    for (final id in _comparison.ids) {
      final template =
          catalog.where((item) => item.id == id).firstOrNull ??
          _comparisonTemplates[id];
      if (template != null) {
        _comparisonTemplates[id] = template;
        selected.add(template);
      }
    }
    void remove(PremiumTemplate template) => setState(() {
      _comparison = _comparison.remove(template.id);
      _comparisonTemplates.remove(template.id);
    });
    void clear() => setState(() {
      _comparison = _comparison.clear();
      _comparisonTemplates.clear();
    });
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
    _cancelPagination();
    _filterVersion++; // data/filter changed — invalidate cache
    _visibleCount = _pageSize;
  }

  void _resetFilteredPage() {
    _resetPage();
    _requestCatalogReveal(atTop: false);
  }

  void _changeFilter(VoidCallback update) => setState(() {
    update();
    _resetFilteredPage();
  });

  void _selectCategory(String category) {
    if (_selectedCategory == category) return;
    _changeFilter(() => _selectedCategory = category);
    ref
        .read(storeTemplateFeedProvider.notifier)
        .setFilters(
          category: category == storeRecommendedCategory ? '전체' : category,
          query: '',
        );
  }

  void _clearSearchFilter() {
    // Avoid a second setState through the controller listener.
    _lastSearchText = '';
    _searchController.clear();
    setState(_resetFilteredPage);
  }

  List<CatalogActiveFilter> get _activeFilters => [
    if (_searchController.text.trim().isNotEmpty)
      CatalogActiveFilter(
        id: 'query',
        label: '검색 · ${_searchController.text.trim()}',
        onRemove: _clearSearchFilter,
      ),
    if (_selectedCategory != '전체')
      CatalogActiveFilter(
        id: 'category',
        label: _isRecommended ? '추천 모아보기' : '주제 · $_selectedCategory',
        onRemove: () => _selectCategory('전체'),
      ),
    if (_priceFilter != '전체')
      CatalogActiveFilter(
        id: 'price',
        label: '가격 · $_priceFilter',
        onRemove: () => _changeFilter(() => _priceFilter = '전체'),
      ),
    if (_favoritesOnly)
      CatalogActiveFilter(
        id: 'favorites',
        label: '즐겨찾기만',
        onRemove: () => _changeFilter(() => _favoritesOnly = false),
      ),
    if (_sort != '추천순')
      CatalogActiveFilter(
        id: 'sort',
        label: _sort,
        onRemove: () => _changeFilter(() => _sort = '추천순'),
      ),
  ];

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
      // Keep the pending reveal for the next visible build instead of moving
      // an offstage scroll position and mounting another page of products.
      if (!TickerMode.of(context)) return;
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
    setState(_resetPage);
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
    if (_paginationFrame != null || !_canLoadNearEnd) return;
    // Offset notifications can arrive many times before layout extends the
    // feed. Coalesce them so one gesture cannot mount several pages at once.
    _paginationFrame = WidgetsBinding.instance.scheduleFrameCallback((_) {
      _paginationFrame = null;
      if (!_canLoadNearEnd) return;
      if (_visibleCount < _cachedFiltered.length) {
        setState(() => _visibleCount += _pageSize);
        return;
      }
      if (_isRecommended && _cachedFiltered.length >= storeRecommendationLimit)
        return;
      final feed = ref.read(storeTemplateFeedProvider);
      if (feed.hasNext && !feed.isLoadingMore && !feed.isInitialLoading) {
        ref.read(storeTemplateFeedProvider.notifier).loadMore();
      }
    });
  }

  bool get _canLoadNearEnd =>
      mounted &&
      !_revealing &&
      _pendingRevealAtTop == null &&
      TickerMode.of(context) &&
      _scrollController.hasClients &&
      _scrollController.position.hasContentDimensions &&
      _scrollController.position.extentAfter < 300;

  void _cancelPagination() {
    if (_paginationFrame == null) return;
    WidgetsBinding.instance.cancelFrameCallbackWithId(_paginationFrame!);
    _paginationFrame = null;
  }

  String _selectedCategory = '전체';
  bool _restoredFeedCategory = false;
  bool _favoritesOnly = false;

  // ── Client-side pagination ───────────────────────────────────────────────
  static const _pageSize = 12;
  int _visibleCount = _pageSize;

  // ── Filter memoization ───────────────────────────────────────────────────
  // Avoids O(n) recomputation on every setState that only changes _visibleCount.
  // Re-runs only when data or filter params actually change.
  int _filterVersion = 0;
  int _cachedFilterVersion = -1;
  int _cachedFavoritesVersion = -1;
  Object? _cachedTemplateRef;
  Object? _cachedCatalogRef;
  Object? _cachedOwnedRef;
  Object? _cachedCurationRef;
  List<PremiumTemplate> _cachedFiltered = const [];
  TemplateCuration? _cachedCuration;
  PremiumTemplate? _cachedSpotlight;
  List<PointShopProduct>? _pricedCatalog;
  Map<String, PointShopProduct> _prices = const {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_loadNearEnd);
  }

  @override
  void dispose() {
    _cancelPagination();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CatalogFavoritesBuilder(
    builder: (context, favorites) {
      final feed = ref.watch(storeTemplateFeedProvider);
      // The route can be recreated while its shared feed still owns a subject
      // query. Adopt that selection once without refetching/resetting rows.
      // Later local modes (including Recommended) keep their own selection.
      if (!_restoredFeedCategory) {
        _restoredFeedCategory = true;
        if (_categories.contains(feed.filterCategory)) {
          _selectedCategory = feed.filterCategory;
        }
      }
      final catalog = ref.watch(pointShopCatalogProvider);
      final owned = (widget.ownedOnly || kIsWeb)
          ? ref.watch(ownedPointShopKeysProvider)
          : null;
      // Responses can arrive after a root/department switch. Keep listening
      // for current data, but do not sort or rebuild an offstage catalog.
      if (!TickerMode.of(context)) {
        return _catalogContent ?? const SizedBox.shrink();
      }
      // Pagination/comparison changes do not change product data. Keep only
      // the current provider snapshot; replace (or clear) it on catalog changes.
      final catalogRef = catalog.asData?.value;
      if (!identical(_pricedCatalog, catalogRef)) {
        _pricedCatalog = catalogRef;
        _prices = {
          for (final product in catalogRef ?? <PointShopProduct>[])
            product.productKey: product,
        };
      }
      final prices = _prices;
      return _catalogContent = _catalogFrame(
        body: SafeArea(
          top: false,
          child: (() {
            final templates = feed.items;
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
            if (!widget.ownedOnly &&
                templates.isEmpty &&
                feed.isInitialLoading) {
              return const SingleChildScrollView(
                child: SnapFitShimmerTemplateTileGrid(rows: 4),
              );
            }
            // A pending reveal may have waited while a refresh showed its
            // loading state. Data is mounted again at the end of this frame.
            _scheduleCatalogReveal();
            final categories = _categories;
            final curation = !widget.ownedOnly
                ? ref.watch(storeCurationsProvider).asData?.value['templates']
                : null;
            final query = _searchController.text.trim().toLowerCase();
            final activeFilters = _activeFilters;
            bool paid(PremiumTemplate template) {
              final product = prices[pointShopTemplateKey(template)];
              return product?.pointPrice != null
                  ? product!.pointPrice! > 0
                  : template.isPremium;
            }

            // ── Memoized filter ──────────────────────────────────────────
            // Only recompute when filter params or source data change.
            // loadMore/setState only changes _visibleCount — skipped here.
            final ownedRef = owned?.asData?.value;
            final dataChanged =
                !identical(_cachedTemplateRef, templates) ||
                !identical(_cachedCatalogRef, catalogRef) ||
                !identical(_cachedOwnedRef, ownedRef) ||
                !identical(_cachedCurationRef, curation) ||
                _cachedFavoritesVersion != favorites.version;
            if (dataChanged) _filterVersion++;
            if (_filterVersion != _cachedFilterVersion || dataChanged) {
              _cachedFilterVersion = _filterVersion;
              _cachedTemplateRef = templates;
              _cachedCatalogRef = catalogRef;
              _cachedOwnedRef = ownedRef;
              _cachedCurationRef = curation;
              _cachedFavoritesVersion = favorites.version;

              final free = templates.where((t) => !paid(t)).toList();
              final premium = templates.where(paid).toList();
              final ordered = <PremiumTemplate>[];
              var f = 0;
              var p = 0;
              while (f < free.length || p < premium.length) {
                for (var n = 0; n < 2 && f < free.length; n++) {
                  ordered.add(free[f++]);
                }
                if (p < premium.length) ordered.add(premium[p++]);
              }
              final eligible = ordered
                  .where(
                    (t) =>
                        (query.isEmpty ||
                            [
                              t.title,
                              t.subTitle ?? '',
                              t.description ?? '',
                              ...?t.tags,
                            ].any((v) => v.toLowerCase().contains(query))) &&
                        (_priceFilter == '전체' ||
                            (_priceFilter == '보유'
                                ? (ownedRef?.contains(
                                        pointShopTemplateKey(t),
                                      ) ??
                                      false)
                                : (_priceFilter == '유료') == paid(t))) &&
                        (!widget.ownedOnly ||
                            (ownedRef?.contains(pointShopTemplateKey(t)) ??
                                false)) &&
                        (!_favoritesOnly ||
                            favorites.contains(
                              CatalogFavoriteKeys.template(t.id),
                            )) &&
                        (!_isRecommended ||
                            (() {
                              final product = prices[pointShopTemplateKey(t)];
                              return product == null
                                  ? !t.isPremium
                                  : product.isActive &&
                                        product.pointPrice != null;
                            })()),
                  )
                  .toList();
              final sorted = _isRecommended
                  ? recommendStoreTemplates(
                      eligible,
                      isPaid: paid,
                      featuredIds:
                          (curation?.resolve(eligible, pointShopTemplateKey) ??
                                  <PremiumTemplate>[])
                              .map((t) => t.id)
                              .toSet(),
                      favoriteIds: eligible
                          .where(
                            (t) => favorites.contains(
                              CatalogFavoriteKeys.template(t.id),
                            ),
                          )
                          .map((t) => t.id)
                          .toSet(),
                    )
                  : eligible;
              if (_sort == '이름순') {
                sorted.sort((a, b) => a.title.compareTo(b.title));
              }
              _cachedFiltered = _isRecommended
                  ? sorted
                  : favorites.arrange(
                      sorted,
                      (t) => CatalogFavoriteKeys.template(t.id),
                      onlyFavorites: _favoritesOnly,
                    );
              _cachedSpotlight =
                  !widget.ownedOnly &&
                      !widget.searchMode &&
                      _cachedFiltered.isNotEmpty &&
                      query.isEmpty &&
                      _priceFilter == '전체' &&
                      !_favoritesOnly &&
                      _sort == '추천순'
                  ? _cachedFiltered.where(paid).firstOrNull ??
                        _cachedFiltered.first
                  : null;
              // Reuse the recommendation subtree on pagination/comparison
              // changes, so resolving its products/title layout stays off that
              // frame path. Real data/filter changes still update its state.
              _cachedCuration =
                  curation == null ||
                      _selectedCategory != '전체' ||
                      _cachedSpotlight == null
                  ? null
                  : TemplateCuration(
                      templates: _cachedFiltered.where((t) {
                        final product = prices[pointShopTemplateKey(t)];
                        return product == null ||
                            (product.isActive && product.pointPrice != null);
                      }).toList(),
                      selection: curation,
                      onOpen: _openTemplate,
                    );
            }
            final filtered = _cachedFiltered;
            final spotlight = _cachedSpotlight;
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
                  ref.invalidate(storeCurationsProvider);
                  ref.invalidate(pointShopCatalogProvider);
                  ref.invalidate(publicPointShopCatalogProvider);
                  try {
                    await Future.wait([
                      ref.read(storeTemplateFeedProvider.notifier).refresh(),
                      ref.read(storeCurationsProvider.future),
                      ref.read(pointShopCatalogProvider.future),
                    ]);
                  } catch (_) {
                    /* Catalog widgets retain scoped errors. */
                  }
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  // Pre-build off-screen tiles so artwork is ready before scrolling in.
                  // Bound offscreen mounting and image decoding to roughly one row.
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
                          child: _cachedCuration,
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
                                leading: _isRecommended
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '지금 둘러보기 좋은 디자인',
                                            style: ExperienceFormStyle.text(
                                              context,
                                              18,
                                              weight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          _recommendationCaption(context),
                                        ],
                                      )
                                    : null,
                                controller: _searchController,
                                searchHint: '템플릿 이름, 주제, 키워드 검색',
                                onSearchChanged: (_) {},
                                categories: categories,
                                category: _selectedCategory,
                                onCategoryChanged: _selectCategory,
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
                                onReset: _resetFilters,
                              )
                            else ...[
                              if (widget.searchMode) ...[
                                TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => FocusManager
                                      .instance
                                      .primaryFocus
                                      ?.unfocus(),
                                  style: ExperienceFormStyle.text(context, 14),
                                  decoration: InputDecoration(
                                    hintText: '템플릿 이름·키워드 검색',
                                    hintStyle: ExperienceFormStyle.text(
                                      context,
                                      14,
                                      color: ExperienceFormStyle.muted(context),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 21,
                                    ),
                                    suffixIcon: query.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: '검색 지우기',
                                            onPressed: _searchController.clear,
                                            icon: const Icon(
                                              Icons.close,
                                              size: 20,
                                            ),
                                          ),
                                    filled: true,
                                    fillColor: ExperienceFormStyle.surface(
                                      context,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
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
                                  onSelect: _selectCategory,
                                ),
                              const SizedBox(height: 16),
                              Semantics(
                                header: true,
                                child: Text(
                                  _selectedCategory == '전체'
                                      ? '모든 템플릿'
                                      : _isRecommended
                                      ? '지금 둘러보기 좋은 디자인'
                                      : '$_selectedCategory 템플릿',
                                  style: ExperienceFormStyle.text(
                                    context,
                                    18,
                                    weight: FontWeight.w700,
                                  ).copyWith(letterSpacing: -0.2),
                                ),
                              ),
                              if (_isRecommended) ...[
                                const SizedBox(height: 6),
                                _recommendationCaption(context),
                              ],
                              const SizedBox(height: 12),
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
                                resultLabel: '${filtered.length}개의 디자인',
                                sort: _sort,
                                onSortChanged: (value) => setState(() {
                                  _sort = value;
                                  _resetFilteredPage();
                                }),
                              ),
                              CatalogActiveFilters(
                                filters: activeFilters,
                                onReset: _resetFilters,
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: !kIsWeb
                            ? CatalogEmptyResult(
                                title: '조건에 맞는 디자인이 없어요',
                                query: _searchController.text.trim(),
                                icon: _favoritesOnly && query.isEmpty
                                    ? Icons.bookmark_border_rounded
                                    : Icons.search_off_rounded,
                                description: _favoritesOnly
                                    ? '다른 조건을 해제하거나 마음에 드는 디자인을 즐겨찾기에 담아 보세요.'
                                    : activeFilters.isNotEmpty
                                    ? '검색어를 짧게 바꾸거나 선택한 조건을 해제해 보세요.'
                                    : widget.ownedOnly
                                    ? '스토어에서 고른 템플릿이 여기에 모여요.'
                                    : '다른 주제를 둘러보거나 잠시 후 다시 확인해 주세요.',
                                onReset: activeFilters.isEmpty
                                    ? null
                                    : _resetFilters,
                              )
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
                                            : _resetFilters,
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
                              visibleCount: filtered.length,
                              onOpen: _openTemplate,
                              onCompare: _toggleComparison,
                              comparisonIds: _comparison.ids,
                              heroTag: (t) => (this, t.id),
                              scrollController: _scrollController,
                            )
                          : ViewportSliverLayoutBuilder(
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
                                final scaler = MediaQuery.textScalerOf(context);
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
                                      return RepaintBoundary(
                                        child: TemplateCatalogTile(
                                          template: template,
                                          onCompare: () =>
                                              _toggleComparison(template),
                                          comparisonSelected: _comparison
                                              .contains(template.id),
                                          onOpen: () => _openTemplate(template),
                                          heroTag: (this, template.id),
                                          scrollController: _scrollController,
                                          previewRatio: previewRatio,
                                        ),
                                      );
                                    },
                                    childCount: min(
                                      _visibleCount,
                                      filtered.length,
                                    ),
                                    addAutomaticKeepAlives: false,
                                    addRepaintBoundaries: false,
                                  ),
                                );
                              },
                            ),
                    ),
                    if (feed.isLoadingMore)
                      const SliverToBoxAdapter(
                        child: SizedBox(
                          height: 56,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('템플릿을 더 불러오고 있어요'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_isRecommended &&
                        filtered.isNotEmpty &&
                        _visibleCount >= filtered.length)
                      SliverToBoxAdapter(
                        child: Center(
                          child: TextButton(
                            onPressed: () => _selectCategory('전체'),
                            child: const Text('전체 템플릿 보기'),
                          ),
                        ),
                      ),
                    if (!_isRecommended && filtered.isNotEmpty && !feed.hasNext)
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
          }()),
        ),
      );
    },
  );

  void _resetFilters() {
    FocusManager.instance.primaryFocus?.unfocus();
    _lastSearchText = '';
    _searchController.clear();
    setState(() {
      _selectedCategory = '전체';
      _priceFilter = '전체';
      _favoritesOnly = false;
      _sort = '추천순';
      _resetFilteredPage();
    });
    // The visible controls and the paginated feed must return to the same
    // scope; changing just the label left the old subject's results in place.
    ref
        .read(storeTemplateFeedProvider.notifier)
        .setFilters(category: '전체', query: '');
  }

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
    body = CatalogSkeletonShimmer(child: body);
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

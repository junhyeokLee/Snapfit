import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../shared/web/web_design.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../core/constants/snapfit_colors.dart';

import '../../../../shared/widgets/catalog_search_disclosure.dart';
import '../../../../shared/widgets/catalog_filter_bar.dart';
import '../../../../shared/widgets/experience_icon.dart';
import 'material_catalog_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../widgets/template_curation.dart';
import '../widgets/template_catalog_tile.dart';
import '../../data/store_curation_provider.dart';
import '../../../../core/templates/template_catalog_categories.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';
import 'template_detail_screen.dart';
import '../../../point_shop/data/point_shop_provider.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key, this.ownedOnly = false, this.embedded = false});
  final bool ownedOnly;
  final bool embedded;
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  static const _pageSize = 12;
  int _visibleCount = _pageSize;
  int _resultCount = 0;
  bool _loadingMore = false;
  int _pageGeneration = 0;
  String _priceFilter = '전체';
  String _sort = '추천순';

  void _resetPage() {
    _pageGeneration++;
    _loadingMore = false;
    _visibleCount = _pageSize;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _openTemplate(PremiumTemplate template) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateDetailScreen(
          template: template,
          heroTag: (this, template.id),
        ),
      ),
    );
  }

  void _loadNearEnd() {
    if (_scrollController.hasClients &&
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
    _searchController.addListener(() => setState(_resetPage));
    _scrollController.addListener(_loadNearEnd);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _topicFilters(List<String> categories) => Container(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ExperienceFormStyle.line(context)),
      ),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        key: const ValueKey('store-topic-filters'),
        children: [
          for (final category in categories)
            Semantics(
              selected: _selectedCategory == category,
              child: InkWell(
                onTap: () => setState(() {
                  _selectedCategory = category;
                  _resetPage();
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 20),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: _selectedCategory == category
                            ? ExperienceFormStyle.ink(context)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    category,
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      weight: _selectedCategory == category
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _selectedCategory == category
                          ? ExperienceFormStyle.ink(context)
                          : ExperienceFormStyle.muted(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => CatalogFavoritesBuilder(
    builder: (context, favorites) {
      final data = ref.watch(templateListProvider);
      final prices = ref.watch(pointShopCatalogProvider).asData?.value;
      final owned = widget.ownedOnly
          ? ref.watch(ownedPointShopKeysProvider)
          : null;
      return _catalogFrame(
        body: SafeArea(
          top: false,
          child: data.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: TextButton.icon(
                onPressed: () => ref.invalidate(templateListProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('다시 불러오기'),
              ),
            ),
            data: (templates) {
              if (widget.ownedOnly && owned!.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (widget.ownedOnly && owned!.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(ownedPointShopKeysProvider),
                    child: const Text('보관함 다시 불러오기'),
                  ),
                );
              }
              final categories = [
                '전체',
                ...orderedTemplateTopics(
                  templates.map((t) => t.category ?? ''),
                ),
              ];
              final query = _searchController.text.trim().toLowerCase();
              bool paid(PremiumTemplate template) {
                final product = prices
                    ?.where(
                      (p) => p.productKey == pointShopTemplateKey(template),
                    )
                    .firstOrNull;
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
                              (_priceFilter == '유료') == paid(t)) &&
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
                      filtered.isNotEmpty &&
                      query.isEmpty &&
                      _selectedCategory == '전체' &&
                      _priceFilter == '전체' &&
                      !_favoritesOnly &&
                      _sort == '추천순'
                  ? filtered.where(paid).firstOrNull ?? filtered.first
                  : null;
              final curation = !widget.ownedOnly
                  ? ref.watch(storeCurationsProvider).asData?.value['templates']
                  : null;
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_resetPage);
                  ref.invalidate(templateListProvider);
                  ref.invalidate(storeCurationsProvider);
                  ref.invalidate(pointShopCatalogProvider);
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
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        widget.embedded ? 0 : 24,
                        20,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!widget.embedded && !kIsWeb) ...[
                              Text(
                                'SNAPFIT COLLECTION',
                                style: ExperienceFormStyle.text(
                                  context,
                                  11,
                                  weight: FontWeight.w600,
                                  color: ExperienceFormStyle.muted(context),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.ownedOnly ? '내가 고른 디자인' : '앨범 템플릿',
                                style: ExperienceFormStyle.text(
                                  context,
                                  27,
                                  weight: FontWeight.w600,
                                ).copyWith(height: 1.25),
                              ),
                              const SizedBox(height: 28),
                            ],
                            if (!kIsWeb &&
                                spotlight != null &&
                                curation != null) ...[
                              SizedBox(
                                key: const ValueKey(
                                  'store-collection-spotlight',
                                ),
                                child: TemplateCuration(
                                  templates: filtered.where((t) {
                                    final product = prices
                                        ?.where(
                                          (p) =>
                                              p.productKey ==
                                              pointShopTemplateKey(t),
                                        )
                                        .firstOrNull;
                                    return product == null ||
                                        (product.isActive &&
                                            product.pointPrice != null);
                                  }).toList(),
                                  selection: curation,
                                  onOpen: _openTemplate,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            CatalogSearchDisclosure(
                              key: const ValueKey('store-search-control'),
                              controller: _searchController,
                              leading: _topicFilters(categories),
                              child: TextField(
                                controller: _searchController,
                                style: ExperienceFormStyle.text(context, 14),
                                decoration: InputDecoration(
                                  hintText: widget.embedded
                                      ? '템플릿 이름이나 주제 검색'
                                      : '어떤 순간을 담고 싶나요?',
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
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            CatalogFilterBar(
                              price: _priceFilter,
                              onPriceChanged: (value) => setState(() {
                                _priceFilter = value;
                                _resetPage();
                              }),
                              favoritesOnly: _favoritesOnly,
                              onFavoritesChanged: () => setState(() {
                                _favoritesOnly = !_favoritesOnly;
                                _resetPage();
                              }),
                              resultLabel: _selectedCategory == '전체'
                                  ? '${filtered.length}개의 디자인'
                                  : '$_selectedCategory · ${filtered.length}종',
                              sort: _sort,
                              onSortChanged: (value) => setState(() {
                                _sort = value;
                                _resetPage();
                              }),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('조건에 맞는 디자인이 없어요')),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverLayoutBuilder(
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
                          final width =
                              (constraints.crossAxisExtent -
                                  16 * (columns - 1)) /
                              columns;
                          final scaler = MediaQuery.textScalerOf(context);
                          final screen = MediaQuery.sizeOf(context);
                          final previewRatio = kIsWeb
                              ? 1.06
                              : screen.width > screen.height
                              ? 1.12
                              : .88;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 25,
                                  mainAxisExtent: TemplateCatalogTile.extent(
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
                        child: SizedBox(
                          height: 56,
                          child: Center(
                            child: _loadingMore
                                ? const Row(
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
                                  )
                                : TextButton(
                                    onPressed: _loadMore,
                                    child: Text(
                                      '더 보기 · $_visibleCount / ${filtered.length}',
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    if (filtered.isNotEmpty && _visibleCount >= filtered.length)
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
              );
            },
          ),
        ),
      );
    },
  );

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
            WebPageHeading(
              eyebrow: 'DESIGN COLLECTION',
              title: widget.ownedOnly ? '내가 고른 템플릿' : '앨범 템플릿',
              description: '주제와 디자인을 살펴보고 나의 사진으로 완성하세요.',
            ),
            const SizedBox(height: 24),
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
              title: widget.ownedOnly ? '내 보관함' : '스토어',
              brand: !widget.ownedOnly,
              back: widget.ownedOnly,
              actions: [
                if (!widget.ownedOnly)
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

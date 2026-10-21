import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../shared/web/web_design.dart';
import '../../data/store_curation_provider.dart';
import '../widgets/material_curation.dart';
import '../widgets/material_catalog_tile.dart';
import '../widgets/library_design_tile.dart';
import '../widgets/web/web_catalog_toolbar.dart';
import '../widgets/web/web_catalog_footer.dart';

import '../../../../shared/widgets/catalog_artwork_hero.dart';
import '../../../../shared/widgets/album_stage_style.dart';

import '../../../../shared/widgets/catalog_search_disclosure.dart';
import '../../../../shared/widgets/catalog_filter_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../core/templates/studio_phrase_catalog.dart';
import '../../../../core/templates/studio_word_art_catalog.dart';
import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/studio_decoration.dart';
import '../../../../core/templates/frame_preview_photos.dart';
import '../../../../shared/widgets/studio_word_art_preview.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart'
    show imageFrameStyles, ImageFramePreview;
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';
import 'template_detail_screen.dart';
import 'material_detail_screen.dart';
import '../widgets/material_original_preview.dart';
import '../../../../core/templates/catalog_preview_assets.g.dart';

class _CatalogItem {
  const _CatalogItem(
    this.key,
    this.favoriteKey,
    this.title,
    this.type,
    this.preview, {
    this.template,
  });
  final String key, favoriteKey, title, type;
  final Widget Function(bool detail) preview;
  final PremiumTemplate? template;
}

enum _LibrarySort { favorites, name }

class MaterialCatalogScreen extends ConsumerStatefulWidget {
  const MaterialCatalogScreen({
    super.key,
    this.library = false,
    this.embedded = false,
    this.initialType = '전체',
    this.searchMode = false,
  });
  final bool library;
  final bool embedded;
  final String initialType;
  final bool searchMode;
  @override
  ConsumerState<MaterialCatalogScreen> createState() =>
      _MaterialCatalogScreenState();
}

class _MaterialCatalogScreenState extends ConsumerState<MaterialCatalogScreen> {
  String _type = '전체';
  final _librarySearchKey = GlobalKey();
  final _libraryContentKey = GlobalKey();
  bool _favoritesOnly = false;
  String _priceFilter = '전체';
  String _catalogSort = '추천순';
  _LibrarySort _librarySort = _LibrarySort.favorites;
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _query = '';
  static const _pageSize = 12;
  int _visible = _pageSize;
  int _total = 0;
  int _generation = 0;
  bool _loading = false;
  late final _materials = _buildMaterials();

  @override
  void initState() {
    super.initState();
    if (widget.library &&
        const [
          '전체',
          '템플릿',
          '스티커',
          '프레임',
          '문구',
          '종이',
        ].contains(widget.initialType)) {
      _type = widget.initialType;
    }
    _scroll.addListener(_nearEnd);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _resetPage() {
    _generation++;
    _visible = _pageSize;
    _loading = false;
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _resetWebFilters() => setState(() {
    _search.clear();
    _query = '';
    _type = '전체';
    _priceFilter = '전체';
    _favoritesOnly = false;
    _librarySort = _LibrarySort.favorites;
    _catalogSort = '추천순';
    _resetPage();
  });

  String get _sortLabel =>
      _librarySort == _LibrarySort.name ? '이름순' : '즐겨찾기 먼저';

  Widget _librarySortMenu() => PopupMenuButton<_LibrarySort>(
    key: const ValueKey('library-sort'),
    tooltip: '보관함 정렬',
    initialValue: _librarySort,
    color: ExperienceFormStyle.surface(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SnapFitRadius.md),
    ),
    onSelected: (sort) => setState(() {
      _librarySort = sort;
      _resetPage();
    }),
    itemBuilder: (context) => [
      for (final sort in _LibrarySort.values)
        CheckedPopupMenuItem<_LibrarySort>(
          key: ValueKey('library-sort-${sort.name}'),
          value: sort,
          checked: _librarySort == sort,
          child: Text(
            sort == _LibrarySort.name ? '이름순' : '즐겨찾기 먼저',
            style: ExperienceFormStyle.text(context, 13),
          ),
        ),
    ],
    child: SizedBox(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_sortLabel, style: ExperienceFormStyle.text(context, 12)),
          const SizedBox(width: 6),
          Icon(
            Icons.expand_more,
            size: 18,
            color: ExperienceFormStyle.muted(context),
          ),
        ],
      ),
    ),
  );

  Widget _librarySidebar(List<String> tabs) => SingleChildScrollView(
    key: const ValueKey('library-sidebar'),
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final type in tabs)
                SizedBox(
                  width: (box.maxWidth - 8) / 2,
                  child: Semantics(
                    button: true,
                    selected: _type == type,
                    child: InkWell(
                      key: ValueKey('library-type-$type'),
                      onTap: () => setState(() {
                        _type = type;
                        _resetPage();
                      }),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        constraints: const BoxConstraints(minHeight: 44),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _type == type
                                  ? ExperienceFormStyle.selectionInk(context)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          type,
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            weight: _type == type
                                ? FontWeight.w600
                                : FontWeight.w400,
                            secondary: _type != type,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _librarySearch(),
      ],
    ),
  );

  Widget _librarySearch({Widget? leading}) => CatalogSearchDisclosure(
    key: _librarySearchKey,
    compactAction: leading == null,
    leading: leading,
    controller: _search,
    onClear: () => setState(() {
      _query = '';
      _resetPage();
    }),
    child: TextField(
      controller: _search,
      onChanged: (value) => setState(() {
        _query = value.trim().toLowerCase();
        _resetPage();
      }),
      style: ExperienceFormStyle.text(context, 13),
      decoration: ExperienceFormStyle.input(context, hint: '보관함에서 검색'),
    ),
  );

  Widget _typeFilters(List<String> tabs) => Container(
    key: const ValueKey('material-topic-filters'),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ExperienceFormStyle.line(context)),
      ),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in tabs)
            Semantics(
              selected: _type == type,
              child: InkWell(
                key: ValueKey(
                  '${widget.library ? 'library' : 'material'}-type-$type',
                ),
                onTap: () => setState(() {
                  _type = type;
                  _resetPage();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  margin: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: _type == type
                            ? ExperienceFormStyle.ink(context)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    type,
                    style: ExperienceStyle.text(
                      14,
                      weight: _type == type ? FontWeight.w600 : FontWeight.w400,
                      color: _type == type
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

  void _nearEnd() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _visible >= _total) return;
    final generation = _generation;
    setState(() => _loading = true);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    if (!mounted || generation != _generation) return;
    setState(() {
      _visible = (_visible + _pageSize).clamp(0, _total);
      _loading = false;
    });
  }

  Future<void> _refreshCatalog() async {
    setState(_resetPage);
    ref.invalidate(pointShopCatalogProvider);
    if (!widget.library) ref.invalidate(storeCurationsProvider);
    if (widget.library) ref.invalidate(ownedPointShopKeysProvider);
    final needsTemplates = widget.library && (_type == '전체' || _type == '템플릿');
    if (needsTemplates) ref.invalidate(templateListProvider);
    // Async providers retain the error so the page can offer a scoped retry.
    try {
      await Future.wait<Object?>([
        ref.read(pointShopCatalogProvider.future),
        if (!widget.library) ref.read(storeCurationsProvider.future),
        if (widget.library) ref.read(ownedPointShopKeysProvider.future),
        if (needsTemplates) ref.read(templateListProvider.future),
      ]);
    } catch (_) {}
  }

  Widget _catalogState({
    required String title,
    required IconData icon,
    String? detail,
    String? action,
    VoidCallback? onAction,
    bool loading = false,
  }) => SliverFillRemaining(
    hasScrollBody: false,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: 28, color: ExperienceFormStyle.muted(context)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: ExperienceFormStyle.text(
                  context,
                  14,
                  weight: FontWeight.w600,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: ExperienceFormStyle.text(context, 13, secondary: true),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: onAction, child: Text(action)),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  List<_CatalogItem> _items(List<PremiumTemplate> templates) => [
    if (widget.library)
      for (final t in templates)
        _CatalogItem(
          pointShopTemplateKey(t),
          CatalogFavoriteKeys.template(t.id),
          t.title,
          '템플릿',
          (detail) => CreationCatalogCover(
            template: t,
            useThumbnail: !detail,
            showBookMaterial: true,
          ),
          template: t,
        ),
    ..._materials,
  ];

  List<_CatalogItem> _buildMaterials() => [
    for (final spec in studioDecorations)
      _CatalogItem(
        'sticker:${spec.id}',
        CatalogFavoriteKeys.decoration(spec.insertionValue),
        spec.label,
        spec.category == StudioDecorationCategory.paper ? '종이' : '스티커',
        (detail) =>
            StudioDecoration(spec: spec, imageDecodeWidth: detail ? 1024 : 384),
      ),
    for (final frame in imageFrameStyles.where((f) => f.key.isNotEmpty))
      _CatalogItem(
        'frame:${frame.key}',
        CatalogFavoriteKeys.frame(frame.key),
        frame.label,
        '프레임',
        (detail) => ImageFramePreview(
          style: frame,
          child: Image.asset(
            framePreviewPhotos[frame.key]!,
            fit: BoxFit.cover,
            cacheWidth: detail ? 1024 : 384,
          ),
        ),
      ),
    for (final phrase in studioPhrases)
      _CatalogItem(
        'phrase:${phrase.id}',
        CatalogFavoriteKeys.phrase(phrase.id),
        phrase.text.replaceAll('\n', ' '),
        '문구',
        (_) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            phrase.text,
            textAlign: phrase.alignment,
            style: phrase.lettering.style,
          ),
        ),
      ),
    for (final art in studioWordArts)
      _CatalogItem(
        art.productKey,
        art.favoriteKey,
        art.label,
        '문구',
        (_) => StudioWordArtPreview(art: art),
      ),
  ];

  Future<void> _open(_CatalogItem item) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (item.template != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TemplateDetailScreen(
            template: item.template!,
            heroTag: (this, item.key),
          ),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialDetailScreen(
          productKey: item.key,
          favoriteKey: item.favoriteKey,
          title: item.title,
          type: item.type,
          preview: (_) => item.preview(true),
          heroTag: (this, item.key),
        ),
      ),
    );
  }

  Widget _materialCollection(
    List<_CatalogItem> items,
    StoreCuration selection,
  ) => MaterialCuration(
    selection: selection,
    items: [
      for (final item in items)
        MaterialCurationItem(
          key: item.key,
          title: item.title,
          type: item.type,
          favoriteKey: item.favoriteKey,
          preview:
              !usesLiveCatalogArtwork(item.template) &&
                  catalogPreviewAssets.containsKey(item.key)
              ? Image.asset(
                  catalogPreviewAssets[item.key]!,
                  fit: BoxFit.contain,
                  cacheWidth: 320,
                )
              : item.preview(false),
          onOpen: () => _open(item),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => CatalogFavoritesBuilder(
    builder: (context, favorites) {
      final owned = ref.watch(ownedPointShopKeysProvider);
      final catalog = ref.watch(pointShopCatalogProvider);
      final prices = {
        for (final product in catalog.hasValue ? catalog.requireValue : [])
          product.productKey: product,
      };
      final ownedKeys = owned.hasValue ? owned.requireValue : const <String>{};
      bool matchesPrice(_CatalogItem item) {
        if (_priceFilter == '전체') return true;
        if (_priceFilter == '보유') return ownedKeys.contains(item.key);
        if (!catalog.hasValue) return false;
        final product = prices[item.key];
        // Missing catalog entries are legacy free materials, matching the price badge.
        if (product == null) return _priceFilter == '무료';
        if (!product.isActive || product.pointPrice == null) return false;
        return _priceFilter == '무료'
            ? product.pointPrice == 0
            : product.pointPrice! > 0;
      }

      final templates = widget.library && (_type == '전체' || _type == '템플릿')
          ? ref.watch(templateListProvider)
          : null;
      final items = favorites.arrange(
        _items(
              templates != null && templates.hasValue
                  ? templates.requireValue
                  : [],
            )
            .where(
              (item) =>
                  (_type == '전체' || item.type == _type) &&
                  (_query.isEmpty ||
                      item.title.toLowerCase().contains(_query) ||
                      item.type.contains(_query)) &&
                  matchesPrice(item) &&
                  (!widget.library ||
                      ownedKeys.contains(item.key) ||
                      favorites.contains(item.favoriteKey)),
            )
            .toList(),
        (item) => item.favoriteKey,
        onlyFavorites: widget.library ? false : _favoritesOnly,
      );
      if ((!widget.library && kIsWeb && _catalogSort == '이름순') ||
          (widget.library && _librarySort == _LibrarySort.name)) {
        items.sort((a, b) => a.title.compareTo(b.title));
      }
      _total = items.length;
      final curation = !widget.library
          ? ref.watch(storeCurationsProvider).asData?.value['materials']
          : null;
      final collection =
          !widget.library &&
              !widget.searchMode &&
              _query.isEmpty &&
              _type == '전체' &&
              _priceFilter == '전체' &&
              !_favoritesOnly &&
              curation != null
          ? curation.resolve(
              items.where(
                (item) =>
                    !prices.containsKey(item.key) ||
                    (prices[item.key]!.isActive &&
                        prices[item.key]!.pointPrice != null),
              ),
              (item) => item.key,
            )
          : const <_CatalogItem>[];
      final tabs = widget.library
          ? ['전체', '템플릿', '스티커', '프레임', '문구', '종이']
          : ['전체', '스티커', '프레임', '문구', '종이'];
      final loadingLibrary =
          widget.library &&
          ((owned.isLoading && !owned.hasValue) ||
              ((templates?.isLoading ?? false) &&
                  !(templates?.hasValue ?? false)));
      final failedLibrary =
          widget.library &&
          ((owned.hasError && !owned.hasValue) ||
              ((templates?.hasError ?? false) &&
                  !(templates?.hasValue ?? false)));
      final horizontalPadding = kIsWeb
          ? 0.0
          : ((MediaQuery.sizeOf(context).width - 1000) / 2).clamp(
              20.0,
              double.infinity,
            );
      final libraryWide =
          widget.library &&
          (kIsWeb
              ? MediaQuery.sizeOf(context).width >= 1000
              : MediaQuery.sizeOf(context).width -
                            MediaQuery.paddingOf(context).horizontal >=
                        560 &&
                    MediaQuery.orientationOf(context) == Orientation.landscape);
      final noResultsTitle = widget.library
          ? '조건에 맞는 항목이 없어요.'
          : '조건에 맞는 소재가 없어요.';
      final resultHeaderExtent =
          (MediaQuery.textScalerOf(context).scale(12) * 1.6 + 24).clamp(
            48.0,
            100.0,
          );
      final content = RefreshIndicator(
        key: widget.library ? _libraryContentKey : null,
        onRefresh: _refreshCatalog,
        child: CustomScrollView(
          key: const ValueKey('material-catalog-scroll'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          // Prepare roughly one row before it enters the viewport.
          cacheExtent: 240,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                widget.embedded
                    ? 0
                    : libraryWide
                    ? 8
                    : 24,
                horizontalPadding,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kIsWeb)
                      WebCatalogToolbar(
                        controller: _search,
                        searchHint: widget.library
                            ? '내 디자인 이름이나 소재 종류 검색'
                            : '스티커, 프레임, 문구, 종이 검색',
                        onSearchChanged: (value) => setState(() {
                          _query = value.trim().toLowerCase();
                          _resetPage();
                        }),
                        categories: tabs,
                        category: _type,
                        onCategoryChanged: (value) => setState(() {
                          _type = value;
                          _resetPage();
                        }),
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
                        resultLabel: loadingLibrary
                            ? '보관함을 확인하고 있어요'
                            : '${items.length}개의 디자인',
                        sort: widget.library
                            ? (_librarySort == _LibrarySort.name
                                  ? '이름순'
                                  : '추천순')
                            : _catalogSort,
                        onSortChanged: (value) => setState(() {
                          if (widget.library) {
                            _librarySort = value == '이름순'
                                ? _LibrarySort.name
                                : _LibrarySort.favorites;
                          } else {
                            _catalogSort = value;
                          }
                          _resetPage();
                        }),
                        filtersActive:
                            _query.isNotEmpty ||
                            _type != '전체' ||
                            _priceFilter != '전체' ||
                            _favoritesOnly ||
                            _catalogSort != '추천순' ||
                            _librarySort != _LibrarySort.favorites,
                        onReset: _resetWebFilters,
                        leading: null,
                      )
                    else ...[
                      if (widget.searchMode &&
                          !widget.library &&
                          !widget.embedded) ...[
                        TextField(
                          controller: _search,
                          decoration:
                              ExperienceFormStyle.input(
                                context,
                                hint: '프레임, 스티커, 문구 검색',
                              ).copyWith(
                                prefixIcon: const Icon(Icons.search, size: 20),
                              ),
                          onChanged: (value) => setState(() {
                            _query = value.trim().toLowerCase();
                            _resetPage();
                          }),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if ((widget.library ||
                              widget.embedded ||
                              widget.searchMode) &&
                          !libraryWide)
                        _typeFilters(tabs)
                      else if (!libraryWide && !kIsWeb && !widget.library) ...[
                        if (!widget.library) ...[
                          Text(
                            'SNAPFIT MATERIALS',
                            style: ExperienceStyle.text(
                              11,
                              weight: FontWeight.w600,
                              color: ExperienceFormStyle.muted(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.library ? '내 디자인' : '사진 곁에 놓는 작은 취향',
                                style: ExperienceStyle.text(
                                  27,
                                  weight: FontWeight.w700,
                                  color: ExperienceFormStyle.ink(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.library
                              ? '내가 고른 디자인과 구매한 소재.'
                              : '스티커, 종이, 프레임. 한 장을 더 나답게.',
                          style: ExperienceStyle.text(
                            14,
                            color: ExperienceFormStyle.muted(context),
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],
                      if (!widget.embedded &&
                          !widget.library &&
                          !widget.searchMode)
                        _typeFilters(tabs),
                      SizedBox(height: libraryWide ? 0 : 10),
                      if (!widget.library)
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
                        ),
                      SizedBox(height: libraryWide ? 8 : 16),
                    ],
                    if (kIsWeb) const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (widget.library && !kIsWeb)
              SliverPersistentHeader(
                pinned: true,
                delegate: _LibraryResultHeader(
                  extent: resultHeaderExtent,
                  child: ColoredBox(
                    color: SnapFitColors.backgroundOf(context),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              loadingLibrary
                                  ? '항목을 불러오는 중'
                                  : failedLibrary
                                  ? '목록을 확인해 주세요'
                                  : '${items.length}개 항목',
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                secondary: true,
                              ),
                            ),
                          ),
                          _librarySortMenu(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (collection.isNotEmpty && !kIsWeb)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                sliver: SliverToBoxAdapter(
                  key: const ValueKey('material-collection-spotlight'),
                  child: _materialCollection(collection, curation!),
                ),
              ),
            if (_priceFilter == '보유' && owned.isLoading && !owned.hasValue)
              _catalogState(
                title: '보유한 디자인을 확인하고 있어요',
                icon: Icons.inventory_2_outlined,
                loading: true,
              )
            else if (_priceFilter == '보유' && owned.hasError && !owned.hasValue)
              _catalogState(
                title: '보유한 디자인을 불러오지 못했어요',
                icon: Icons.cloud_off_outlined,
                action: '다시 불러오기',
                onAction: () => ref.invalidate(ownedPointShopKeysProvider),
              )
            else if (_priceFilter != '전체' &&
                _priceFilter != '보유' &&
                catalog.isLoading &&
                !catalog.hasValue)
              _catalogState(
                title: '가격을 확인하고 있어요',
                icon: Icons.toll_outlined,
                loading: true,
              )
            else if (_priceFilter != '전체' &&
                _priceFilter != '보유' &&
                catalog.hasError)
              _catalogState(
                title: '가격을 불러오지 못했어요',
                icon: Icons.cloud_off_outlined,
                action: '가격 다시 불러오기',
                onAction: () => ref.invalidate(pointShopCatalogProvider),
              )
            else if (failedLibrary)
              _catalogState(
                title: '보관함을 불러오지 못했어요',
                icon: Icons.cloud_off_outlined,
                detail: '연결을 확인한 뒤 다시 시도해 주세요.',
                action: '보관함 다시 불러오기',
                onAction: () {
                  ref.invalidate(ownedPointShopKeysProvider);
                  if (templates != null) ref.invalidate(templateListProvider);
                },
              )
            else if (loadingLibrary)
              _catalogState(
                title: '보관함을 불러오고 있어요',
                icon: Icons.inventory_2_outlined,
                loading: true,
              )
            else if (items.isEmpty)
              _catalogState(
                icon: _favoritesOnly
                    ? Icons.bookmark_border
                    : Icons.inventory_2_outlined,
                title: _query.isNotEmpty
                    ? noResultsTitle
                    : _favoritesOnly
                    ? '즐겨찾는 항목이 없어요.'
                    : _priceFilter != '전체' || _type != '전체' || !widget.library
                    ? noResultsTitle
                    : '아직 보관한 항목이 없어요.',
                detail: _query.isNotEmpty || _type != '전체'
                    ? '다른 검색어나 분류로 찾아보세요.'
                    : widget.library
                    ? '구매한 소재와 즐겨찾기가 여기에 모여요.'
                    : null,
                action:
                    _query.isNotEmpty ||
                        _type != '전체' ||
                        (kIsWeb && (_priceFilter != '전체' || _favoritesOnly))
                    ? '필터 초기화'
                    : null,
                onAction: () => setState(() {
                  _query = '';
                  _search.clear();
                  _type = '전체';
                  _priceFilter = '전체';
                  if (kIsWeb) {
                    _favoritesOnly = false;
                  }
                  _resetPage();
                }),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  32,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, box) {
                    final columns = kIsWeb
                        ? (box.crossAxisExtent >= 1000
                              ? 4
                              : box.crossAxisExtent >= 700
                              ? 3
                              : box.crossAxisExtent >= 420
                              ? 2
                              : 1)
                        : widget.library && _type == '템플릿'
                        ? (libraryWide && box.crossAxisExtent >= 680 ? 2 : 1)
                        : libraryWide
                        ? (_type == '템플릿'
                              ? (box.crossAxisExtent >= 760 ? 3 : 2)
                              : (box.crossAxisExtent >= 520 ? 3 : 2))
                        : _type == '템플릿'
                        ? (box.crossAxisExtent > 650 ? 3 : 2)
                        : (box.crossAxisExtent > 650 ? 4 : 2);
                    final width =
                        (box.crossAxisExtent - 12 * (columns - 1)) / columns;
                    final titleHeight = widget.library
                        ? MediaQuery.textScalerOf(context).scale(14) * 1.5 * 2
                        : 40.0;
                    final typeHeight = widget.library
                        ? MediaQuery.textScalerOf(context).scale(11) * 1.5 + 2
                        : 0.0;
                    final previewHeight = libraryWide
                        ? (box.viewportMainAxisExtent -
                                  resultHeaderExtent -
                                  LibraryDesignTile.extent(
                                    0,
                                    MediaQuery.textScalerOf(context),
                                  ) -
                                  8)
                              .clamp(64.0, width)
                        : widget.library
                        ? _type == '템플릿'
                              ? (width * .52).clamp(176.0, 260.0)
                              : width * 1.14
                        : width;
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 20,
                        mainAxisExtent: widget.library && !kIsWeb
                            ? LibraryDesignTile.extent(
                                previewHeight,
                                MediaQuery.textScalerOf(context),
                              )
                            : widget.library
                            ? previewHeight + titleHeight + typeHeight + 9 + 48
                            : MaterialCatalogTile.extent(
                                width,
                                MediaQuery.textScalerOf(context),
                              ),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final item = items[i];
                          final thumbnail =
                              usesLiveCatalogArtwork(item.template)
                              ? null
                              : catalogPreviewAssets[item.key];
                          if (!widget.library) {
                            return MaterialCatalogTile(
                              key: ValueKey('material-item-${item.key}'),
                              productKey: item.key,
                              title: item.title,
                              type: item.type,
                              favoriteKey: item.favoriteKey,
                              onOpen: () => _open(item),
                              preview: CatalogArtworkHero(
                                tag: (this, item.key),
                                child: thumbnail != null
                                    ? Image.asset(
                                        thumbnail,
                                        fit: BoxFit.contain,
                                        cacheWidth: 384,
                                        errorBuilder: (_, _, _) =>
                                            MaterialOriginalPreview(
                                              productKey: item.key,
                                              child: item.preview(false),
                                            ),
                                      )
                                    : MaterialOriginalPreview(
                                        productKey: item.key,
                                        child: item.preview(false),
                                      ),
                              ),
                            );
                          }
                          if (!kIsWeb) {
                            return LibraryDesignTile(
                              key: ValueKey('material-item-${item.key}'),
                              productKey: item.key,
                              title: item.title,
                              type: item.type,
                              template: item.template,
                              owned: ownedKeys.contains(item.key),
                              favoriteKey: item.favoriteKey,
                              heroTag: (this, item.key),
                              previewHeight: previewHeight,
                              onOpen: () => _open(item),
                              preview: item.template != null
                                  ? item.preview(false)
                                  : thumbnail != null
                                  ? Image.asset(
                                      thumbnail,
                                      fit: BoxFit.contain,
                                      cacheWidth: 384,
                                      errorBuilder: (_, __, ___) =>
                                          MaterialOriginalPreview(
                                            productKey: item.key,
                                            child: item.preview(false),
                                          ),
                                    )
                                  : MaterialOriginalPreview(
                                      productKey: item.key,
                                      child: item.preview(false),
                                    ),
                            );
                          }
                          return InkWell(
                            key: ValueKey('material-item-${item.key}'),
                            onTap: () => _open(item),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: previewHeight,
                                  width: double.infinity,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: item.template != null
                                              ? AlbumStageStyle.gradient(
                                                  context,
                                                )
                                              : null,
                                          color: item.template == null
                                              ? MaterialOriginalPreview.backgroundFor(
                                                  item.key,
                                                )
                                              : null,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(13),
                                          child: RepaintBoundary(
                                            child: CatalogArtworkHero(
                                              tag: (this, item.key),
                                              child: item.template != null
                                                  ? item.preview(false)
                                                  : thumbnail != null
                                                  ? Image.asset(
                                                      thumbnail,
                                                      fit: BoxFit.contain,
                                                      cacheWidth: 384,
                                                      errorBuilder: (_, __, ___) =>
                                                          MaterialOriginalPreview(
                                                            productKey:
                                                                item.key,
                                                            child: item.preview(
                                                              false,
                                                            ),
                                                          ),
                                                    )
                                                  : MaterialOriginalPreview(
                                                      productKey: item.key,
                                                      child: item.preview(
                                                        false,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 9),
                                SizedBox(
                                  height: titleHeight,
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: ExperienceStyle.text(
                                      widget.library ? 14 : 13,
                                      weight: widget.library
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: ExperienceFormStyle.ink(context),
                                    ),
                                  ),
                                ),
                                if (widget.library)
                                  SizedBox(
                                    height: typeHeight,
                                    child: Text(
                                      item.template != null
                                          ? '템플릿 · 내지 ${item.template!.pageCount}쪽'
                                          : item.type,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ExperienceFormStyle.text(
                                        context,
                                        11,
                                        secondary: true,
                                      ),
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: PointShopProductBadge(
                                          productKey: item.key,
                                          unlistedLabel:
                                              item.template?.isPremium == true
                                              ? '판매 준비 중'
                                              : null,
                                        ),
                                      ),
                                    ),
                                    CatalogFavoriteButton(
                                      bookmark: true,
                                      unframed: true,
                                      itemKey: item.favoriteKey,
                                      label: item.title,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: _visible.clamp(0, items.length),
                        addAutomaticKeepAlives: false,
                      ),
                    );
                  },
                ),
              ),
            if (items.isNotEmpty &&
                (!widget.library || (!loadingLibrary && !failedLibrary)))
              SliverToBoxAdapter(
                child: kIsWeb
                    ? WebCatalogFooter(
                        loading: _loading,
                        visible: _visible,
                        total: items.length,
                        onMore: _loadMore,
                      )
                    : SizedBox(
                        height: 56,
                        child: Center(
                          child: _loading
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
                                    Text('목록을 더 불러오고 있어요'),
                                  ],
                                )
                              : _visible < items.length
                              ? TextButton(
                                  onPressed: _loadMore,
                                  child: Text(
                                    '더 보기 · $_visible / ${items.length}',
                                  ),
                                )
                              : Text(
                                  '${items.length}개 항목을 모두 확인했어요',
                                  style: ExperienceStyle.text(
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
      if (kIsWeb) {
        final body = content;
        if (widget.embedded) return body;
        return SnapFitWebShell(
          section: WebSection.designs,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebPageHeading(title: widget.library ? '내 디자인 보관함' : '꾸밈 소재'),
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
                    ? '소재 검색'
                    : widget.library
                    ? '내 디자인'
                    : '꾸밈 소재',
                themeAware: true,
                showDivider: !widget.library,
                showNotifications: !widget.searchMode,
                back: Navigator.of(context).canPop(),
              ),
        body: SafeArea(
          top: false,
          child: libraryWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width:
                          ((MediaQuery.sizeOf(context).width -
                                      MediaQuery.paddingOf(
                                        context,
                                      ).horizontal) *
                                  .2)
                              .clamp(136.0, 172.0),
                      child: _librarySidebar(tabs),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: ExperienceFormStyle.line(context),
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
        ),
      );
    },
  );
}

class _LibraryResultHeader extends SliverPersistentHeaderDelegate {
  _LibraryResultHeader({required this.extent, required this.child});
  final double extent;
  final Widget child;
  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(_LibraryResultHeader oldDelegate) =>
      extent != oldDelegate.extent || child != oldDelegate.child;
}

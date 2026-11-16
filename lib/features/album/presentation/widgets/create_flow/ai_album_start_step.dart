import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../point_shop/data/point_shop_provider.dart';
import '../../../../point_shop/domain/point_shop_product.dart';
import '../../../../point_shop/domain/point_shop_template_key.dart';
import '../../../../store/data/store_curation_provider.dart';
import '../../../../store/data/store_discovery_provider.dart';
import '../../../../store/domain/entities/premium_template.dart';
import '../../../../store/domain/store_product_discovery.dart';
import '../../../../store/domain/template_design_profile.dart';
import '../../../../store/domain/store_template_recommendations.dart';
import '../../../../store/presentation/widgets/library_design_tile.dart';
import '../../../../store/presentation/widgets/template_design_profile_summary.dart';
import '../../../domain/creation_catalog_selection.dart';
import 'creation_catalog_cover.dart';
import 'creation_category_rail.dart';
import 'creation_collection_showcase.dart';
import 'creation_workspace.dart';
import '../../../../../shared/widgets/experience_icon.dart';

class AiAlbumStartStep extends ConsumerStatefulWidget {
  const AiAlbumStartStep({
    super.key,
    required this.onManualStart,
    this.templates = const AsyncData([]),
    this.onTemplateSelected,
    this.onRetry,
    this.browsing,
    this.onBrowsingChanged,
  });
  final VoidCallback onManualStart;
  final AsyncValue<List<PremiumTemplate>> templates;
  final ValueChanged<PremiumTemplate>? onTemplateSelected;
  final VoidCallback? onRetry;
  // The creation shell owns header back navigation; standalone pickers own it locally.
  final bool? browsing;
  final ValueChanged<bool>? onBrowsingChanged;
  @override
  ConsumerState<AiAlbumStartStep> createState() => _AiAlbumStartStepState();
}

class _AiAlbumStartStepState extends ConsumerState<AiAlbumStartStep> {
  final _search = TextEditingController();
  final _catalogScroll = ScrollController();
  String _category = '전체', _price = '전체', _query = '';
  bool _favoritesOnly = false, _localBrowsing = false;
  int? _inspectedTemplateId;
  List<PremiumTemplate> get _templates =>
      widget.templates.hasValue ? widget.templates.requireValue : const [];
  bool get _browsing => widget.browsing ?? _localBrowsing;
  void _openTemplate(PremiumTemplate template) {
    setState(() => _inspectedTemplateId = template.id);
    widget.onTemplateSelected?.call(template);
  }

  void _setBrowsing(bool value) {
    setState(() => _localBrowsing = value);
    widget.onBrowsingChanged?.call(value);
  }

  void _clearFilters() => setState(() {
    _category = '전체';
    _price = '전체';
    _query = '';
    _favoritesOnly = false;
    _search.clear();
  });
  @override
  void dispose() {
    _search.dispose();
    _catalogScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _browsing ? CatalogFavoritesBuilder(builder: _catalog) : _entry(context);

  Widget _entry(BuildContext context) => SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          key: const PageStorageKey('creation-method-entry'),
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
          child: LayoutBuilder(
            builder: (context, box) {
              final titleStyle = ExperienceFormStyle.text(
                context,
                20,
                weight: FontWeight.w600,
              );
              final detailStyle = ExperienceFormStyle.text(
                context,
                14,
                secondary: true,
              ).copyWith(height: 1.5);
              const direct = '빈 앨범에서 사진과 글을 자유롭게';
              const design = '준비된 표지와 내지에 사진을 담아요';
              double textHeight(String text, TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: math.max(40, box.maxWidth - 110));
                final height = painter.height;
                painter.dispose();
                return height;
              }

              final actionHeight = math.max(
                92.0,
                math.max(
                      textHeight('직접 만들기', titleStyle) +
                          textHeight(direct, detailStyle),
                      textHeight('디자인으로 시작', titleStyle) +
                          textHeight(design, detailStyle),
                    ) +
                    34,
              );
              final featured = _templates.firstOrNull;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '어떻게 시작할까요?',
                    style: ExperienceFormStyle.text(
                      context,
                      26,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '나에게 맞는 방법으로 시작해요.',
                    style: ExperienceFormStyle.text(
                      context,
                      15,
                      secondary: true,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _routeAction(
                    context,
                    key: const ValueKey('creation-manual-start'),
                    title: '직접 만들기',
                    detail: direct,
                    icon: Icons.menu_book_outlined,
                    height: actionHeight,
                    onTap: widget.onManualStart,
                  ),
                  const SizedBox(height: 12),
                  _routeAction(
                    context,
                    key: const ValueKey('creation-open-catalog'),
                    title: '디자인으로 시작',
                    detail: design,
                    icon: Icons.photo_library_outlined,
                    height: actionHeight,
                    onTap: () => _setBrowsing(true),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    '완성 예시',
                    textAlign: TextAlign.center,
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: (box.maxWidth * .64).clamp(180.0, 280.0),
                    child: featured == null
                        ? const CreationBlankBook(cover: defaultCoverSize)
                        : CreationCollectionShowcase(
                            template: featured,
                            editorial: true,
                            showDetails: false,
                            onOpen: null,
                          ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '사진과 글은 편집하면서 바꿀 수 있어요.',
                    textAlign: TextAlign.center,
                    style: ExperienceFormStyle.text(
                      context,
                      13,
                      secondary: true,
                    ).copyWith(height: 1.5),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _routeAction(
    BuildContext context, {
    required Key key,
    required String title,
    required String detail,
    required IconData icon,
    required double height,
    required VoidCallback onTap,
  }) => SizedBox(
    key: key,
    height: height,
    child: Material(
      color: ExperienceFormStyle.selection(context).withValues(alpha: .5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ExperienceFormStyle.selectionInk(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 36,
                color: ExperienceFormStyle.selectionInk(context),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ExperienceFormStyle.text(
                        context,
                        20,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        secondary: true,
                      ).copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ExperienceIcon(
                'ChevronRight',
                color: ExperienceFormStyle.selectionInk(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _catalog(BuildContext context, CatalogFavorites favorites) {
    final prices = ref.watch(pointShopCatalogProvider);
    final ownership = ref.watch(ownedPointShopKeysProvider);
    // Ownership reloads across accounts must not reveal the previous owner's keys.
    final owned = ownership.asData?.value ?? <String>{};
    final discovery = ref.watch(storeDiscoveryProvider);
    final clock = ref.watch(storeDiscoveryClockProvider);
    final curations = ref.watch(storeCurationsProvider);
    final templates = _templates;
    // A refresh error can retain confirmed data without being AsyncData.
    final products = <String, PointShopProduct>{
      for (final product
          in prices.hasValue ? prices.requireValue : const <PointShopProduct>[])
        product.productKey: product,
    };
    final favoriteIds = templates
        .where((t) => favorites.contains(CatalogFavoriteKeys.template(t.id)))
        .map((t) => t.id)
        .toSet();
    final metadata = discovery.hasValue
        ? discovery.requireValue
        : const <String, StoreProductDiscovery>{};
    final curation = curations.hasValue
        ? curations.requireValue['templates']
        : null;
    final visible = _price != '전체' && !prices.hasValue
        ? <PremiumTemplate>[]
        : selectCreationCatalog(
            templates: templates,
            category: _category,
            price: _price,
            query: _query,
            favoritesOnly: _favoritesOnly,
            favoriteIds: favoriteIds,
            products: products,
            discovery: metadata,
            now: clock,
            featuredIds:
                (curation?.resolve(templates, pointShopTemplateKey) ??
                        <PremiumTemplate>[])
                    .map((t) => t.id)
                    .toSet(),
          );
    final preferredBottom = ['일상', '여행', '동아리'];
    final topics = {
      ...storeTemplateTopicOrder,
      ...templates
          .map((t) => t.category?.trim() ?? '')
          .where((t) => t.isNotEmpty && !['전체', '추천', '인기'].contains(t)),
    };
    final rest = topics.where((t) => !preferredBottom.contains(t)).toList();
    final top = [
      '전체',
      '추천',
      '인기',
      for (var i = 0; i < rest.length; i += 2) rest[i],
    ];
    final bottom = [
      ...preferredBottom,
      for (var i = 1; i < rest.length; i += 2) rest[i],
    ];
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 1100
                  ? 5
                  : box.maxWidth >= 760
                  ? 4
                  : box.maxWidth >= 540
                  ? 3
                  : 2;
              final previewHeight =
                  ((box.maxWidth - 40 - 16 * (columns - 1)) / columns).clamp(
                    110.0,
                    280.0,
                  );
              return CustomScrollView(
                key: const PageStorageKey('albumCreationHub'),
                controller: _catalogScroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.browsing == null) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: const ValueKey('creation-catalog-back'),
                                onPressed: () => _setBrowsing(false),
                                icon: const ExperienceIcon(
                                  'ArrowLeft',
                                  size: 18,
                                ),
                                label: const Text('만들기 방법'),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          TextField(
                            key: const ValueKey('creation-search'),
                            controller: _search,
                            onChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase(),
                            ),
                            style: ExperienceFormStyle.text(context, 14),
                            decoration:
                                ExperienceFormStyle.input(
                                  context,
                                  hint: '디자인 이름, 주제 검색',
                                ).copyWith(
                                  prefixIcon: const ExperienceIcon(
                                    'Search',
                                    size: 22,
                                  ),
                                  suffixIcon: _query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: '검색어 지우기',
                                          onPressed: () => setState(() {
                                            _query = '';
                                            _search.clear();
                                          }),
                                          icon: const ExperienceIcon(
                                            'X',
                                            size: 18,
                                          ),
                                        ),
                                ),
                          ),
                          const SizedBox(height: 18),
                          CreationCategoryRail(
                            topCategories: top,
                            bottomCategories: bottom,
                            selected: _category,
                            onSelected: (value) =>
                                setState(() => _category = value),
                          ),
                          const SizedBox(height: 16),
                          _priceFilters(
                            context,
                            enabled: prices.hasValue && !prices.isLoading,
                          ),
                          if (prices.isLoading && !prices.hasValue) ...[
                            const SizedBox(height: 8),
                            Text(
                              '가격을 확인하고 있어요.',
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                secondary: true,
                              ),
                            ),
                          ],
                          if (prices.hasError) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                Text(
                                  '가격을 확인하지 못했어요.',
                                  style: ExperienceFormStyle.text(
                                    context,
                                    13,
                                    secondary: true,
                                  ),
                                ),
                                TextButton(
                                  key: const ValueKey('creation-retry-prices'),
                                  onPressed: () =>
                                      ref.invalidate(pointShopCatalogProvider),
                                  child: const Text('다시 확인'),
                                ),
                              ],
                            ),
                          ],
                          if (_category == '인기') ...[
                            const SizedBox(height: 10),
                            Text(
                              discovery.isLoading
                                  ? '인기 순위를 확인하고 있어요.'
                                  : visible.any(
                                      (t) =>
                                          metadata[pointShopTemplateKey(t)]
                                              ?.isBest ==
                                          true,
                                    )
                                  ? '인기 디자인을 먼저, 나머지는 최신순으로 보여드려요.'
                                  : '인기 순위가 확인되지 않아 최신순으로 보여드려요.',
                              key: const ValueKey('creation-popularity-status'),
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                secondary: true,
                              ).copyWith(height: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (visible
                          .where((t) => t.id == _inspectedTemplateId)
                          .firstOrNull
                      case final inspected?)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: TemplateDesignProfileSummary(
                          key: const ValueKey('creation-inspected-profile'),
                          heading: '최근 살펴본 디자인 · ${inspected.title}',
                          profile: TemplateDesignProfile.of(inspected),
                        ),
                      ),
                    ),
                  if (widget.templates.isLoading && !widget.templates.hasValue)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (widget.templates.hasError &&
                      !widget.templates.hasValue)
                    SliverToBoxAdapter(
                      child: _notice(
                        context,
                        '디자인을 불러오지 못했어요.',
                        action: '다시 불러오기',
                        onTap: widget.onRetry,
                      ),
                    )
                  else if (visible.isEmpty)
                    SliverToBoxAdapter(
                      child: _notice(
                        context,
                        _price != '전체' && !prices.hasValue
                            ? '가격을 확인한 뒤 디자인을 보여드릴게요.'
                            : _favoritesOnly
                            ? favoriteIds.isEmpty
                                  ? '즐겨찾기한 디자인이 아직 없어요.'
                                  : '현재 조건에 맞는 즐겨찾기가 없어요.'
                            : templates.isEmpty
                            ? '사용할 수 있는 디자인이 아직 없어요.'
                            : '검색 결과가 없어요',
                        action: templates.isEmpty ? null : '조건 초기화',
                        onTap: _clearFilters,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 20,
                          mainAxisExtent: LibraryDesignTile.extent(
                            previewHeight,
                            MediaQuery.textScalerOf(context),
                            coverOnly: true,
                          ),
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final template = visible[index];
                          final productKey = pointShopTemplateKey(template);
                          return LibraryDesignTile(
                            key: ValueKey('creation-template-${template.id}'),
                            productKey: productKey,
                            title: template.title,
                            type: '템플릿',
                            previewHeight: previewHeight,
                            owned: owned.contains(productKey),
                            template: template,
                            coverOnly: true,
                            favoriteKey: CatalogFavoriteKeys.template(
                              template.id,
                            ),
                            onOpen: () => _openTemplate(template),
                            preview: CreationCatalogCover(
                              template: template,
                              useThumbnail: true,
                              showBookMaterial: true,
                            ),
                          );
                        }, childCount: visible.length),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        '디자인을 누르면 표지와 내지를 미리 볼 수 있어요.',
                        textAlign: TextAlign.center,
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ).copyWith(height: 1.5),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _priceFilters(BuildContext context, {required bool enabled}) =>
      LayoutBuilder(
        builder: (context, box) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
          final choices = Row(
            children: [
              for (final value in ['전체', '무료', '유료'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: TextButton(
                      key: ValueKey('creation-price-$value'),
                      onPressed: enabled
                          ? () => setState(() => _price = value)
                          : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 10,
                        ),
                        backgroundColor: _price == value
                            ? ExperienceFormStyle.selection(context)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: ExperienceFormStyle.ink(context),
                      ),
                      child: Semantics(
                        selected: _price == value,
                        child: Text(
                          value,
                          style: ExperienceFormStyle.text(
                            context,
                            14,
                            weight: _price == value
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
          final favorites = IconButton(
            key: const ValueKey('creation-favorites-only'),
            tooltip: _favoritesOnly ? '전체 디자인 보기' : '즐겨찾기만 보기',
            isSelected: _favoritesOnly,
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
            icon: const ExperienceIcon('Bookmark'),
            selectedIcon: const ExperienceIcon('Bookmark'),
            color: _favoritesOnly
                ? ExperienceFormStyle.selectionInk(context)
                : ExperienceFormStyle.muted(context),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(height: 1, color: ExperienceFormStyle.line(context)),
              const SizedBox(height: 8),
              if (largeText || box.maxWidth < 300) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '가격',
                        style: ExperienceFormStyle.text(
                          context,
                          14,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    favorites,
                  ],
                ),
                choices,
              ] else
                Row(
                  children: [
                    Text(
                      '가격',
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: choices),
                    const SizedBox(width: 12),
                    favorites,
                  ],
                ),
              const SizedBox(height: 8),
              Divider(height: 1, color: ExperienceFormStyle.line(context)),
            ],
          );
        },
      );

  Widget _notice(
    BuildContext context,
    String text, {
    String? action,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: ExperienceFormStyle.text(
            context,
            14,
            secondary: true,
          ).copyWith(height: 1.5),
        ),
        if (action != null)
          TextButton(
            key: const ValueKey('creation-clear-filters'),
            onPressed: onTap,
            child: Text(action),
          ),
      ],
    ),
  );
}

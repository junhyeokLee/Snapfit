import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../../../core/templates/template_catalog_categories.dart';
import '../../../../point_shop/domain/point_shop_template_key.dart';
import '../../../../point_shop/data/point_shop_provider.dart';
import '../../../../point_shop/presentation/point_shop_access.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../store/domain/entities/premium_template.dart';
import 'creation_catalog_cover.dart';
import '../../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../../shared/widgets/catalog_filter_bar.dart';
import '../../../../../shared/widgets/catalog_search_disclosure.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../core/constants/cover_size.dart';
import 'creation_collection_showcase.dart';
import 'creation_workspace.dart';

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
  String? _topic;
  bool _favoritesOnly = false;
  String _query = '';
  final _search = TextEditingController();

  void _clearFilters() => setState(() {
    _favoritesOnly = false;
    _filter = '전체';
    _topic = null;
    _query = '';
    _search.clear();
  });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CatalogFavoritesBuilder(builder: _buildCatalog);

  Widget _buildCatalog(BuildContext context, CatalogFavorites favorites) {
    final ink = ExperienceFormStyle.ink(context);
    final muted = ExperienceFormStyle.muted(context);
    final catalog = ref.watch(pointShopCatalogProvider);
    final products = {
      for (final product in catalog.asData?.value ?? const [])
        product.productKey: product,
    };
    final topics = orderedTemplateTopics(
      (widget.templates.asData?.value ?? const <PremiumTemplate>[]).map(
        (template) => template.category?.trim() ?? '',
      ),
    );
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = kIsWeb
              ? constraints.maxWidth >= 1100 ? 5 : constraints.maxWidth >= 760 ? 4 : constraints.maxWidth >= 540 ? 3 : 2
              : constraints.maxWidth >= 720 ? 4 : 2;
          final titleHeight = (MediaQuery.textScalerOf(context).scale(14) * 2.5)
              .clamp(36.0, double.infinity)
              .toDouble();
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
                        kIsWeb ? '어떻게 시작할까요?' : '디자인 선택',
                        style: ExperienceFormStyle.text(
                          context,
                          22,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, area) {
                          final wide =
                              area.maxWidth >= 520 &&
                              MediaQuery.orientationOf(context) ==
                                  Orientation.landscape;
                          final featured =
                              widget.templates.asData?.value.firstOrNull;
                          final showArtwork =
                              _query.isEmpty &&
                              _filter == '전체' &&
                              _topic == null &&
                              !_favoritesOnly;
                          final artwork = featured == null
                              ? CreationBlankBook(cover: defaultCoverSize)
                              : CreationCollectionShowcase(
                                  template: featured,
                                  onOpen: widget.onTemplateSelected == null
                                      ? null
                                      : () => widget.onTemplateSelected!(
                                          featured,
                                        ),
                                );
                          final manual = _StartAction(
                            title: '직접 만들기',
                            icon: Icons.add,
                            onTap: widget.onManualStart,
                          );
                          final ai = _StartAction(
                            title: 'AI 템플릿',
                            icon: Icons.auto_awesome_outlined,
                            ai: true,
                            onTap: widget.onAiStart,
                          );
                          return Column(
                            children: [
                              if (kIsWeb || !showArtwork)
                                Row(
                                  children: [
                                    Expanded(child: manual),
                                    const SizedBox(width: 12),
                                    Expanded(child: ai),
                                  ],
                                )
                              else if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: SizedBox(
                                        height: 170,
                                        child: artwork,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        children: [
                                          manual,
                                          const SizedBox(height: 12),
                                          ai,
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                SizedBox(height: 235, child: artwork),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(child: manual),
                                    const SizedBox(width: 12),
                                    Expanded(child: ai),
                                  ],
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      CatalogSearchDisclosure(
                        controller: _search,
                        onClear: () => setState(() => _query = ''),
                        leading: Text(
                          '템플릿',
                          style: ExperienceFormStyle.text(
                            context,
                            16,
                            weight: FontWeight.w600,
                          ),
                        ),
                        child: TextField(
                          controller: _search,
                          onChanged: (value) => setState(
                            () => _query = value.trim().toLowerCase(),
                          ),
                          style: ExperienceFormStyle.text(context, 14),
                          decoration: ExperienceFormStyle.input(
                            context,
                            hint: '여행, 웨딩, 일상 검색',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (topics.isNotEmpty) ...[
                        SingleChildScrollView(
                          key: const ValueKey('creation-topic-filters'),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final topic in [null, ...topics])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    key: ValueKey(
                                      'creation-topic-${topic ?? 'all'}',
                                    ),
                                    label: Text(topic ?? '모든 주제'),
                                    selected: _topic == topic,
                                    onSelected: (_) =>
                                        setState(() => _topic = topic),
                                    showCheckmark: false,
                                    selectedColor:
                                        ExperienceFormStyle.selection(context),
                                    backgroundColor:
                                        ExperienceFormStyle.surface(context),
                                    side: BorderSide.none,
                                    labelStyle:
                                        ExperienceFormStyle.text(
                                          context,
                                          12,
                                        ).copyWith(
                                          color: _topic == topic
                                              ? ExperienceFormStyle.selectionInk(
                                                  context,
                                                )
                                              : muted,
                                        ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      CatalogFilterBar(
                        price: _filter,
                        enabled: catalog.hasValue,
                        onPriceChanged: (value) =>
                            setState(() => _filter = value),
                        favoritesOnly: _favoritesOnly,
                        onFavoritesChanged: () =>
                            setState(() => _favoritesOnly = !_favoritesOnly),
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
                      if (_topic != null &&
                          template.category?.trim() != _topic) {
                        return false;
                      }
                      final product = products[pointShopTemplateKey(template)];
                      final isFree =
                          product == null ||
                          (product.isActive && product.pointPrice == 0);
                      if (_filter == '무료' && !isFree) return false;
                      if (_filter == '유료' && isFree) return false;
                      return '${template.title} ${template.category ?? ''} ${(template.tags ?? []).join(' ')}'
                          .toLowerCase()
                          .contains(_query);
                    }),
                    (t) => CatalogFavoriteKeys.template(t.id),
                    onlyFavorites: _favoritesOnly,
                  );
                  if (visible.isEmpty && _favoritesOnly)
                    return SliverToBoxAdapter(
                      child: CatalogFavoritesEmpty(onShowAll: _clearFilters),
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
                              templates.isEmpty ? '등록된 템플릿이 없어요' : '검색 결과가 없어요',
                              style: TextStyle(color: muted),
                            ),
                            if (templates.isNotEmpty)
                              TextButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('전체 템플릿 보기'),
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
                            titleHeight +
                            60,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final template = visible[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              button: true,
                              label: template.title,
                              child: InkWell(
                                key: ValueKey(
                                  'creation-template-${template.id}',
                                ),
                                borderRadius: BorderRadius.circular(6),
                                onTap: widget.onTemplateSelected == null
                                    ? null
                                    : () =>
                                          widget.onTemplateSelected!(template),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AspectRatio(
                                      aspectRatio: 1 / 1.12,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        color: ExperienceFormStyle.surface(
                                          context,
                                        ),
                                        child: RepaintBoundary(
                                          child: CreationCatalogCover(
                                            template: template,
                                            useThumbnail: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: titleHeight,
                                      child: Text(
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
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: PointShopProductBadge(
                                      productKey: pointShopTemplateKey(
                                        template,
                                      ),
                                    ),
                                  ),
                                ),
                                CatalogFavoriteButton(
                                  itemKey: CatalogFavoriteKeys.template(
                                    template.id,
                                  ),
                                  label: template.title,
                                  bookmark: true,
                                  unframed: true,
                                ),
                              ],
                            ),
                          ],
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
    required this.icon,
    required this.onTap,
    this.ai = false,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool ai;

  @override
  Widget build(BuildContext context) => kIsWeb ? Material(
    color: WebPalette.of(context).surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: WebPalette.of(context).line)),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 26, color: WebPalette.of(context).brandInk),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: WebPalette.of(context).ink))),
            Icon(Icons.arrow_forward, size: 19, color: WebPalette.of(context).brandInk),
          ]),
          const SizedBox(height: 8),
          Text(ai ? '사진과 원하는 분위기로 디자인을 준비합니다.' : '빈 앨범에서 사진과 글을 직접 배치합니다.', style: TextStyle(fontSize: 13, height: 1.6, color: WebPalette.of(context).muted)),
        ]),
      ),
    ),
  ) : Material(
    color: ai
        ? ExperienceFormStyle.selection(context)
        : ExperienceFormStyle.surface(context),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              if (ai)
                Icon(
                  icon,
                  size: 22,
                  color: ExperienceFormStyle.selectionInk(context),
                )
              else
                ExperienceIcon(
                  'BookOpen',
                  size: 22,
                  color: ExperienceFormStyle.ink(context),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: ExperienceFormStyle.text(
                    context,
                    14,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

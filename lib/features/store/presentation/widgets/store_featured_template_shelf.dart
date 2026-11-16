import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/data/catalog_preview.dart';
import '../../../../core/templates/catalog_preview_assets.g.dart';
import '../../../../core/templates/catalog_editorial_assets.g.dart';
import '../../../../core/utils/korean_text_preview.dart';
import '../../../../shared/widgets/catalog_artwork_visibility.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../album/presentation/widgets/create_flow/creation_template_image.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../../data/store_curation_provider.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/store_product_discovery.dart';
import 'store_product_badge.dart';
import 'catalog_edition_artwork.dart' show CatalogEditionPalette;
import '../../../../shared/widgets/experience_icon.dart';

class StoreFeaturedTemplateGroups {
  const StoreFeaturedTemplateGroups({
    required this.best,
    required this.curated,
    this.isTopicRecommendation = false,
  });
  final List<PremiumTemplate> best, curated;
  final bool isTopicRecommendation;
}

/// Inputs have already passed public sale eligibility. Only verified discovery
/// ranks can enter BEST. The default storefront never invents operator picks;
/// a concrete topic may offer separately labelled catalog suggestions.
StoreFeaturedTemplateGroups selectStoreFeaturedTemplates({
  required List<PremiumTemplate> templates,
  required StoreCuration? selection,
  required Map<String, StoreProductDiscovery> discovery,
  String? topic,
}) {
  final byId = <int, PremiumTemplate>{};
  for (final template in templates) {
    if (topic != null && template.category != topic) continue;
    byId.putIfAbsent(template.id, () => template);
  }
  final unique = byId.values.toList(growable: false);
  final best = unique
      .where(
        (template) => discovery[pointShopTemplateKey(template)]?.isBest == true,
      )
      .toList();
  best.sort((a, b) {
    final left = pointShopTemplateKey(a), right = pointShopTemplateKey(b);
    final rank = discovery[left]!.bestRank!.compareTo(
      discovery[right]!.bestRank!,
    );
    return rank != 0 ? rank : left.compareTo(right);
  });
  final seen = <int>{};
  var curated =
      selection
          ?.resolve(unique, pointShopTemplateKey)
          .where((template) => seen.add(template.id))
          .take(6)
          .toList(growable: false) ??
      const <PremiumTemplate>[];
  // A concrete topic is an explicit browsing request. When neither measured
  // BEST nor an operator pick covers it, offer that topic's eligible designs
  // in catalog order, clearly labelled as a topic suggestion. The default
  // storefront and an explicitly disabled placement never invent a fallback.
  final topicRecommendation =
      topic != null &&
      selection?.enabled != false &&
      best.isEmpty &&
      curated.isEmpty &&
      unique.isNotEmpty;
  if (topicRecommendation) {
    curated = unique.take(6).toList(growable: false);
  }
  return StoreFeaturedTemplateGroups(
    best: List<PremiumTemplate>.unmodifiable(best.take(5)),
    curated: List<PremiumTemplate>.unmodifiable(curated),
    isTopicRecommendation: topicRecommendation,
  );
}

enum _FeaturedMode { best, curated }

/// A small storefront shelf. Its static cover images never acquire a template
/// preview worker, a full document, or document fonts.
class StoreFeaturedTemplateShelf extends StatefulWidget {
  const StoreFeaturedTemplateShelf({
    super.key,
    required this.templates,
    required this.selection,
    required this.discovery,
    required this.onOpen,
    this.topic,
  });

  final List<PremiumTemplate> templates;
  final StoreCuration? selection;
  final Map<String, StoreProductDiscovery> discovery;
  final ValueChanged<PremiumTemplate> onOpen;
  final String? topic;

  @override
  State<StoreFeaturedTemplateShelf> createState() =>
      _StoreFeaturedTemplateShelfState();
}

class _StoreFeaturedTemplateShelfState
    extends State<StoreFeaturedTemplateShelf> {
  late StoreFeaturedTemplateGroups _groups;
  _FeaturedMode _mode = _FeaturedMode.best;
  bool _userChoseMode = false;
  final _selectedIds = <_FeaturedMode, int>{};
  final _assets = <int, String?>{};
  final _spreads = <int, String?>{};
  double _dragDistance = 0;

  List<PremiumTemplate> _items(_FeaturedMode mode) =>
      mode == _FeaturedMode.best ? _groups.best : _groups.curated;

  int get _index => _items(
    _mode,
  ).indexWhere((template) => template.id == _selectedIds[_mode]);

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    _groups = selectStoreFeaturedTemplates(
      templates: widget.templates,
      selection: widget.selection,
      discovery: widget.discovery,
      topic: widget.topic,
    );
    final unavailable = _mode == _FeaturedMode.best
        ? _groups.best.isEmpty
        : _groups.curated.isEmpty;
    if (!_userChoseMode || unavailable) {
      _userChoseMode = false;
      _mode = _groups.best.isNotEmpty
          ? _FeaturedMode.best
          : _FeaturedMode.curated;
    }
    for (final mode in _FeaturedMode.values) {
      final items = _items(mode);
      if (items.isEmpty) {
        _selectedIds.remove(mode);
      } else if (!items.any((item) => item.id == _selectedIds[mode])) {
        _selectedIds[mode] = items.first.id;
      }
    }
    _assets.clear();
    _spreads.clear();
    for (final template in [..._groups.best, ..._groups.curated]) {
      final id = canonicalCatalogPreviewId(template);
      _assets[template.id] = id == null
          ? null
          : catalogPreviewAssets['template:$id'];
      _spreads[template.id] = id == null ? null : catalogEditorialAssets[id];
    }
  }

  @override
  void didUpdateWidget(StoreFeaturedTemplateShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.templates, widget.templates) ||
        !identical(oldWidget.selection, widget.selection) ||
        !identical(oldWidget.discovery, widget.discovery) ||
        oldWidget.topic != widget.topic) {
      _prepare();
    }
  }

  void _select(_FeaturedMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _userChoseMode = true;
    });
  }

  void _move(int direction) {
    final items = _items(_mode);
    if (items.isEmpty) return;
    final next = (_index + direction).clamp(0, items.length - 1);
    if (next == _index) return;
    setState(() {
      _userChoseMode = true;
      _selectedIds[_mode] = items[next].id;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_groups.best.isEmpty && _groups.curated.isEmpty)
      return const SizedBox.shrink();
    final popular = _mode == _FeaturedMode.best;
    final templates = _items(_mode);
    final index = _index;
    final selected = templates[index];
    final topicRecommendation = !popular && _groups.isTopicRecommendation;
    final title = popular
        ? '요즘 많이 소장한 디자인'
        : topicRecommendation
        ? '${widget.topic} 추천 디자인'
        : widget.selection!.title;
    final subtitle = popular
        ? '최근 30일 포인트 소장 기준'
        : topicRecommendation
        ? '선택한 주제의 디자인을 모았어요.'
        : widget.selection!.subtitle.trim();
    final canSwitch = _groups.best.isNotEmpty && _groups.curated.isNotEmpty;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          key: const ValueKey('store-featured-templates'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          popular
                              ? '많은 선택이 모인 한 권'
                              : topicRecommendation
                              ? '주제에서 골라보기'
                              : '스냅핏 셀렉션',
                          style: ExperienceFormStyle.text(
                            context,
                            10,
                            color: ExperienceFormStyle.selectionInk(context),
                            weight: FontWeight.w600,
                          ).copyWith(letterSpacing: .8),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          keepShortKoreanWords(title),
                          semanticsLabel: title,
                          key: const ValueKey('store-featured-title'),
                          style: ExperienceFormStyle.text(
                            context,
                            19,
                            weight: FontWeight.w700,
                          ).copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
                if (canSwitch) ...[
                  const SizedBox(width: 6),
                  for (final (mode, label) in [
                    (_FeaturedMode.best, '인기'),
                    (_FeaturedMode.curated, '추천'),
                  ])
                    Semantics(
                      selected: _mode == mode,
                      child: TextButton(
                        key: ValueKey('store-featured-mode-${mode.name}'),
                        onPressed: () => _select(mode),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          foregroundColor: _mode == mode
                              ? ExperienceFormStyle.selectionInk(context)
                              : ExperienceFormStyle.muted(context),
                          textStyle: ExperienceFormStyle.text(
                            context,
                            11,
                            weight: _mode == mode
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        child: Text(label),
                      ),
                    ),
                ],
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ExperienceFormStyle.text(
                  context,
                  11,
                  secondary: true,
                ).copyWith(height: 1.5),
              ),
            ],
            const SizedBox(height: 14),
            GestureDetector(
              onHorizontalDragStart: (_) => _dragDistance = 0,
              onHorizontalDragUpdate: (details) =>
                  _dragDistance += details.primaryDelta ?? 0,
              onHorizontalDragCancel: () => _dragDistance = 0,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (_dragDistance.abs() > 35 || velocity.abs() > 120) {
                  final direction = _dragDistance.abs() > 35
                      ? _dragDistance
                      : velocity;
                  _move(direction < 0 ? 1 : -1);
                }
                _dragDistance = 0;
              },
              child: _FeaturedTemplateTile(
                template: selected,
                asset: _assets[selected.id],
                spread: _spreads[selected.id],
                onOpen: () => widget.onOpen(selected),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Semantics(
                  liveRegion: true,
                  label:
                      '${index + 1} / ${templates.length}, ${selected.title}',
                  excludeSemantics: true,
                  child: Text(
                    '${(index + 1).toString().padLeft(2, '0')} / '
                    '${templates.length.toString().padLeft(2, '0')}',
                    key: const ValueKey('store-featured-position'),
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey('store-featured-previous'),
                  tooltip: '이전 추천 디자인',
                  onPressed: index > 0 ? () => _move(-1) : null,
                  icon: const ExperienceIcon('ArrowLeft', size: 20),
                ),
                const SizedBox(width: 6),
                IconButton(
                  key: const ValueKey('store-featured-next'),
                  tooltip: '다음 추천 디자인',
                  onPressed: index < templates.length - 1
                      ? () => _move(1)
                      : null,
                  icon: const ExperienceIcon('ArrowRight', size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedTemplateTile extends StatelessWidget {
  const _FeaturedTemplateTile({
    required this.template,
    required this.asset,
    required this.spread,
    required this.onOpen,
  });
  final PremiumTemplate template;
  final String? asset, spread;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final productKey = pointShopTemplateKey(template);
    final palette = CatalogEditionPalette.of(template.category);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = dark
        ? Color.lerp(palette.ink, const Color(0xFF181E1B), .88)!
        : Color.lerp(palette.paper, const Color(0xFFFAF1DE), .74)!;
    final description = template.subTitle?.trim() ?? '';
    return Semantics(
      button: true,
      label: '${template.title} 상세 보기',
      child: Material(
        color: paper,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('store-featured-template-${template.id}'),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final stacked =
                    bounds.maxWidth < 260 ||
                    (bounds.maxWidth < 520 &&
                        MediaQuery.textScalerOf(context).scale(14) > 21);
                final artwork = _FeaturedBookArtwork(
                  template: template,
                  asset: asset,
                  spread: spread,
                );
                final copy = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${template.category ?? '앨범'} · ${template.pageCount}쪽',
                      style: ExperienceFormStyle.text(
                        context,
                        11,
                        secondary: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      keepShortKoreanWords(_editorialTitle(template.title)),
                      semanticsLabel: template.title,
                      key: ValueKey(
                        'store-featured-template-title-${template.id}',
                      ),
                      maxLines: stacked ? null : 3,
                      overflow: stacked
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: ExperienceFormStyle.text(
                        context,
                        23,
                        weight: FontWeight.w700,
                      ).copyWith(height: 1.25),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        keepShortKoreanWords(description),
                        semanticsLabel: description,
                        maxLines: stacked ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceFormStyle.text(
                          context,
                          11,
                          secondary: true,
                        ).copyWith(height: 1.45),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      key: ValueKey(
                        'store-featured-template-price-${template.id}',
                      ),
                      alignment: AlignmentDirectional.centerStart,
                      child: PointShopProductBadge(
                        productKey: productKey,
                        compact: false,
                        fontSize: 13,
                        unlistedLabel: template.isPremium ? '가격 확인 중' : '무료',
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      key: ValueKey('store-featured-open-${template.id}'),
                      onPressed: onOpen,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                        foregroundColor: ExperienceFormStyle.selectionInk(
                          context,
                        ),
                        textStyle: ExperienceFormStyle.text(
                          context,
                          12,
                          weight: FontWeight.w600,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text('디자인 보기')),
                          SizedBox(width: 7),
                          ExperienceIcon('ChevronRight', size: 16),
                        ],
                      ),
                    ),
                  ],
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 210, child: artwork),
                      const SizedBox(height: 20),
                      copy,
                    ],
                  );
                }
                final artWidth = (bounds.maxWidth * .49).clamp(140.0, 300.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 8),
                    SizedBox(width: artWidth, height: 210, child: artwork),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

String _editorialTitle(String title) {
  final firstSpace = title.trim().indexOf(' ');
  if (firstSpace < 0) return title;
  final clean = title.trim();
  return '${clean.substring(0, firstSpace)}\n'
      '${clean.substring(firstSpace + 1)}';
}

class _FeaturedBookArtwork extends StatelessWidget {
  const _FeaturedBookArtwork({required this.template, this.asset, this.spread});
  final PremiumTemplate template;
  final String? asset, spread;

  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: ExperienceIcon('BookOpen', color: ExperienceFormStyle.muted(context),
        size: 40,
      ),
    );
    return ExcludeSemantics(
      child: CatalogArtworkVisibility(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final coverWidth = (bounds.maxWidth * .85).clamp(120.0, 190.0);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (spread != null)
                  Positioned(
                    left: -8,
                    right: 0,
                    top: 18,
                    child: Transform.rotate(
                      angle: .055,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .09),
                              blurRadius: 14,
                              offset: const Offset(3, 7),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          spread!,
                          fit: BoxFit.contain,
                          cacheWidth: 640,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  width: coverWidth,
                  left: (bounds.maxWidth - coverWidth) / 2,
                  bottom: spread == null ? 22 : 8,
                  child: Transform.rotate(
                    angle: spread == null ? -.035 : -.065,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .17),
                            blurRadius: 20,
                            offset: const Offset(4, 13),
                          ),
                        ],
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: asset == null
                            ? CreationTemplateImage(
                                url: template.coverImageUrl,
                                decodeWidth: 512,
                              )
                            : Image.asset(
                                asset!,
                                fit: BoxFit.contain,
                                cacheWidth: 512,
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) => placeholder,
                              ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: StoreProductBadge(
                    productKey: pointShopTemplateKey(template),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

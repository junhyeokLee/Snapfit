import 'store_product_badge.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;
import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/viewport_sliver_layout_builder.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../../domain/entities/premium_template.dart';
import 'catalog_edition_artwork.dart';
import 'catalog_item_title.dart';
import 'template_catalog_tile.dart';

/// Five products form one full-width editorial and bounded comparison rows.
List<List<int>> storeEditorialRows(
  int count, {
  int columns = 2,
  bool compactStart = false,
}) {
  assert(columns > 0);
  final rows = <List<int>>[];
  final firstGroup = compactStart ? math.min(columns * 3, count) : 0;
  for (var i = 0; i < firstGroup; i += columns) {
    rows.add([for (var j = i; j < math.min(i + columns, firstGroup); j++) j]);
  }
  for (var i = firstGroup; i < count;) {
    if ((i - firstGroup) % 5 == 0) {
      rows.add([i++]);
    } else {
      final row = [i++];
      while (row.length < columns && i < count && (i - firstGroup) % 5 != 0) {
        row.add(i++);
      }
      rows.add(row);
    }
  }
  return rows;
}

class TemplateEditorialList extends StatelessWidget {
  const TemplateEditorialList({
    super.key,
    required this.templates,
    required this.visibleCount,
    required this.onOpen,
    required this.heroTag,
    required this.scrollController,
    this.onCompare,
    this.comparisonIds = const [],
    this.compactStart = false,
    this.interlude,
  });
  final List<PremiumTemplate> templates;
  final int visibleCount;
  final ValueChanged<PremiumTemplate> onOpen;
  final Object Function(PremiumTemplate) heroTag;
  final ScrollController scrollController;
  final ValueChanged<PremiumTemplate>? onCompare;
  final List<int> comparisonIds;
  final bool compactStart;
  final Widget? interlude;
  @override
  Widget build(BuildContext context) => ViewportSliverLayoutBuilder(
    builder: (context, bounds) {
      final columns = bounds.crossAxisExtent >= 1000 ? 4 : 2;
      final rows = storeEditorialRows(
        math.min(visibleCount, templates.length),
        columns: columns,
        compactStart: compactStart,
      );
      final firstGroup = compactStart
          ? math.min(columns * 3, math.min(visibleCount, templates.length))
          : 0;
      final insertion = compactStart
          ? (firstGroup / columns).ceil()
          : math.min(3, rows.length);
      final wide = bounds.crossAxisExtent >= 700;
      final ratio = wide ? 1.15 : .98;
      final tileWidth = (bounds.crossAxisExtent - 16 * (columns - 1)) / columns;
      final height = TemplateCatalogTile.extent(
        tileWidth,
        ratio,
        MediaQuery.textScalerOf(context),
      );
      Widget tile(int i) => TemplateCatalogTile(
        template: templates[i],
        onOpen: () => onOpen(templates[i]),
        heroTag: heroTag(templates[i]),
        scrollController: scrollController,
        previewRatio: ratio,
        onCompare: onCompare == null ? null : () => onCompare!(templates[i]),
        comparisonSelected: comparisonIds.contains(templates[i].id),
      );
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (interlude != null && index == insertion) {
              return Padding(
                key: const ValueKey('store-editorial-interlude'),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: interlude,
              );
            }
            final rowIndex = interlude != null && index > insertion
                ? index - 1
                : index;
            final row = rows[rowIndex];
            final featured =
                row.length == 1 &&
                row.first >= firstGroup &&
                (row.first - firstGroup) % 5 == 0;
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: featured
                    ? _EditorialEdition(
                        template: templates[row.first],
                        onOpen: () => onOpen(templates[row.first]),
                        onCompare: onCompare == null
                            ? null
                            : () => onCompare!(templates[row.first]),
                        comparisonSelected: comparisonIds.contains(
                          templates[row.first].id,
                        ),
                      )
                    : SizedBox(
                        height: height,
                        child: Row(
                          children: [
                            for (var slot = 0; slot < columns; slot++) ...[
                              if (slot > 0) const SizedBox(width: 16),
                              Expanded(
                                child: slot < row.length
                                    ? tile(row[slot])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            );
          },
          childCount: rows.length + (interlude == null ? 0 : 1),
          addAutomaticKeepAlives: false,
        ),
      );
    },
  );
}

class _EditorialEdition extends StatelessWidget {
  const _EditorialEdition({
    required this.template,
    required this.onOpen,
    this.onCompare,
    this.comparisonSelected = false,
  });
  final PremiumTemplate template;
  final VoidCallback onOpen;
  final VoidCallback? onCompare;
  final bool comparisonSelected;
  @override
  Widget build(BuildContext context) {
    final palette = CatalogEditionPalette.of(template.category);
    final hasSpread = catalogEditorialSpread(template) != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('editorial-edition-${template.id}'),
        onTap: onOpen,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, box) => SizedBox(
                    height: (box.maxWidth * .76).clamp(228.0, 340.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(SnapFitRadius.lg),
                      child: ColoredBox(
                        color: dark
                            ? Color.lerp(
                                palette.ink,
                                const Color(0xFF202321),
                                .7,
                              )!
                            : Color.lerp(palette.paper, Colors.white, .4)!,
                        child: LayoutBuilder(
                          builder: (context, stage) => Stack(
                            children: [
                              if (hasSpread)
                                Positioned(
                                  right: stage.maxWidth * .04,
                                  top: stage.maxHeight * .2,
                                  width: stage.maxWidth * .67,
                                  height: stage.maxHeight * .56,
                                  child: Transform.rotate(
                                    angle: .035,
                                    child: CatalogSpreadPreview(
                                      template: template,
                                      decodeWidth: 640,
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: stage.maxWidth * (hasSpread ? .045 : .1),
                                top: stage.maxHeight * .075,
                                width: stage.maxWidth * (hasSpread ? .58 : .8),
                                height: stage.maxHeight * .85,
                                child: RepaintBoundary(
                                  child: CreationCatalogCover(
                                    template: template,
                                    useThumbnail: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CatalogItemTitle(
                            template.title,
                            style: ExperienceFormStyle.text(
                              context,
                              20,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${template.category ?? '앨범'} · 내지 ${template.pageCount}쪽',
                            style: ExperienceFormStyle.text(
                              context,
                              12,
                              secondary: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (onCompare != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      toggled: comparisonSelected,
                      label: '${template.title} 비교',
                      child: OutlinedButton.icon(
                        key: ValueKey('compare-template-${template.id}'),
                        onPressed: onCompare,
                        icon: Icon(
                          comparisonSelected
                              ? Icons.check
                              : Icons.compare_arrows,
                          size: 16,
                        ),
                        label: const Text('비교'),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                StoreProductBadge(productKey: pointShopTemplateKey(template)),
                const SizedBox(height: 8),
                PointShopProductBadge(
                  productKey: pointShopTemplateKey(template),
                  compact: false,
                  fontSize: 14,
                  unlistedLabel: template.isPremium ? '판매 준비 중' : '무료',
                ),
              ],
            ),
            Positioned(
              top: 4,
              right: 4,
              child: CatalogFavoriteButton(
                itemKey: CatalogFavoriteKeys.template(template.id),
                label: template.title,
                bookmark: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/theme/snapfit_design_tokens.dart'
    show SnapFitRadius, SnapFitShadow;

import '../../../../shared/widgets/catalog_artwork_hero.dart';
import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/template_design_profile.dart';
import 'catalog_edition_artwork.dart';
import 'catalog_item_title.dart';
import 'store_floating_cover.dart';

class TemplateCatalogTile extends StatefulWidget {
  const TemplateCatalogTile({
    super.key,
    required this.template,
    required this.onOpen,
    required this.heroTag,
    required this.scrollController,
    required this.previewRatio,
    this.onCompare,
    this.comparisonSelected = false,
  });
  final PremiumTemplate template;
  final VoidCallback onOpen;
  final Object heroTag;
  final ScrollController scrollController;
  final double previewRatio;
  final VoidCallback? onCompare;
  final bool comparisonSelected;
  static double comparisonExtent(TextScaler scaler) =>
      math.max(48, (scaler.scale(11) * 3.1 + 6).ceilToDouble());
  static double extent(double width, double ratio, TextScaler scaler) =>
      width / ratio +
      scaler.scale(15) * 2.8 +
      comparisonExtent(scaler) +
      math.max(34, scaler.scale(14) * 1.5) +
      40;

  @override
  State<TemplateCatalogTile> createState() => _TemplateCatalogTileState();
}

class _TemplateCatalogTileState extends State<TemplateCatalogTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = CatalogEditionPalette.of(widget.template.category);
    final cover = CreationCatalogCover(
      template: widget.template,
      useThumbnail: true,
      // Current catalog layers stay bounded; book surfaces belong in detail.
      showBookMaterial: false,
    );
    final hasSpread = catalogEditorialSpread(widget.template) != null;
    final elevated = _hovered || _pressed;
    return Semantics(
      key: ValueKey('store-template-${widget.template.id}'),
      button: true,
      label: '${widget.template.title} 상세 보기',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpen,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SnapFitRadius.lg),
                    boxShadow: elevated ? SnapFitShadow.artwork(dark) : [],
                  ),
                  child: AspectRatio(
                    aspectRatio: widget.previewRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(SnapFitRadius.lg),
                      child: ColoredBox(
                        key: ValueKey(
                          'template-cover-stage-${widget.template.id}',
                        ),
                        color: dark
                            ? Color.lerp(
                                palette.ink,
                                const Color(0xFF202321),
                                .65,
                              )!
                            : Color.lerp(palette.paper, Colors.white, .35)!,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  16,
                                  10,
                                  10,
                                ),
                                child: CatalogArtworkHero(
                                  tag: widget.heroTag,
                                  child: kIsWeb
                                      ? cover
                                      : StoreFloatingCover(
                                          scrollController:
                                              widget.scrollController,
                                          seed: widget.template.id,
                                          child: cover,
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 5,
                              right: 5,
                              child: CatalogFavoriteButton(
                                bookmark: true,
                                itemKey: CatalogFavoriteKeys.template(
                                  widget.template.id,
                                ),
                                label: widget.template.title,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
                  child: SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(15) * 2.8,
                    child: CatalogItemTitle(
                      widget.template.title,
                      style: ExperienceFormStyle.text(
                        context,
                        15,
                        weight: FontWeight.w600,
                      ).copyWith(height: 1.4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
                  child: SizedBox(
                    height: TemplateCatalogTile.comparisonExtent(
                      MediaQuery.textScalerOf(context),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.template.category ?? '포토북'} · ${widget.template.pageCount}쪽',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ExperienceFormStyle.text(
                                  context,
                                  11,
                                  secondary: true,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                TemplateDesignProfile.of(
                                  widget.template,
                                ).compositionLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ExperienceFormStyle.text(
                                  context,
                                  11,
                                  secondary: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onCompare != null)
                          Semantics(
                            toggled: widget.comparisonSelected,
                            label: '${widget.template.title} 비교',
                            child: TextButton(
                              key: ValueKey(
                                'compare-template-${widget.template.id}',
                              ),
                              onPressed: widget.onCompare,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                textStyle: ExperienceFormStyle.text(
                                  context,
                                  13,
                                ).copyWith(height: 1.4),
                              ),
                              child: widget.comparisonSelected
                                  ? const Icon(Icons.check, size: 20)
                                  : const Text('비교'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
                  child: SizedBox(
                    height: math.max(
                      34,
                      MediaQuery.textScalerOf(context).scale(14) * 1.5,
                    ),
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final showSpread =
                            hasSpread &&
                            bounds.maxWidth >= 152 &&
                            MediaQuery.textScalerOf(context).scale(14) <= 17;
                        return Row(
                          children: [
                            Expanded(
                              child: PointShopProductBadge(
                                productKey: pointShopTemplateKey(
                                  widget.template,
                                ),
                                unlistedLabel: widget.template.isPremium
                                    ? '판매 준비 중'
                                    : '무료',
                                compact: false,
                                fontSize: 14,
                              ),
                            ),
                            if (showSpread) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 58,
                                height: 32,
                                child: CatalogSpreadPreview(
                                  template: widget.template,
                                  decodeWidth: 192,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
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
}

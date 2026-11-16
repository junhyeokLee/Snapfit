import 'store_product_badge.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/templates/free_template_material_policy.dart';
import '../../../../core/theme/snapfit_design_tokens.dart'
    show SnapFitRadius, SnapFitShadow;
import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../shared/widgets/catalog_artwork_visibility.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/web/web_design.dart' show WebPalette;
import '../../../point_shop/presentation/point_shop_access.dart';
import 'catalog_item_title.dart';
import 'material_original_preview.dart';

class MaterialCatalogTile extends StatefulWidget {
  const MaterialCatalogTile({
    super.key,
    required this.productKey,
    required this.title,
    required this.type,
    required this.preview,
    required this.onOpen,
    this.favoriteKey,
    this.compact = false,
    this.showCommerce = true,
    this.isNew = false,
    this.isBest = false,
  });
  final String productKey, title, type;
  final Widget preview;
  final VoidCallback onOpen;
  final String? favoriteKey;
  final bool compact;
  final bool showCommerce;
  final bool isNew, isBest;

  static double extent(
    double width,
    TextScaler scaler, {
    bool showCommerce = true,
  }) =>
      width +
      scaler.scale(14) * 2.9 +
      (showCommerce ? scaler.scale(14) * 1.5 + 32 : 24);

  @override
  State<MaterialCatalogTile> createState() => _MaterialCatalogTileState();
}

class _MaterialCatalogTileState extends State<MaterialCatalogTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const previewInk = MaterialArtworkStage.ink;
    final artworkTheme = Theme.of(context).copyWith(
      brightness: Brightness.light,
      extensions: [
        ...Theme.of(
          context,
        ).extensions.values.where((extension) => extension is! WebPalette),
        WebPalette.light,
      ],
      colorScheme: Theme.of(context).colorScheme.copyWith(
        brightness: Brightness.light,
        onSurface: MaterialArtworkStage.ink,
        onSurfaceVariant: MaterialArtworkStage.ink,
        onPrimaryContainer: SnapFitColors.accentInk,
      ),
    );
    final elevated = _hovered || _pressed;
    return Semantics(
      button: true,
      label: '${widget.title} ${widget.type}',
      onTap: widget.onOpen,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: widget.onOpen,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SnapFitRadius.lg),
                      boxShadow: elevated ? SnapFitShadow.artwork(dark) : [],
                    ),
                    child: MaterialArtworkStage(
                      productKey: widget.productKey,
                      padding: EdgeInsets.zero,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Padding(
                            padding: MaterialArtworkStage.artworkInsets(
                              context,
                              productKey: widget.productKey,
                              type: widget.type,
                              compact: widget.compact,
                            ),
                            child: CatalogArtworkVisibility(
                              child: RepaintBoundary(child: widget.preview),
                            ),
                          ),
                          Positioned(
                            left: 9,
                            top: 9,
                            child: Text(
                              widget.type,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: previewInk,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 9,
                            bottom: 9,
                            child: StoreProductBadge(
                              productKey: widget.productKey,
                            ),
                          ),
                          if (widget.showCommerce && widget.favoriteKey != null)
                            Positioned(
                              right: 3,
                              top: 3,
                              child: Theme(
                                data: artworkTheme,
                                child: CatalogFavoriteButton(
                                  itemKey: widget.favoriteKey!,
                                  label: widget.title,
                                  bookmark: true,
                                  unframed: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    2,
                    12,
                    2,
                    widget.showCommerce ? 0 : 12,
                  ),
                  child: SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(14) * 2.9,
                    child: CatalogItemTitle(
                      widget.title,
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        weight: FontWeight.w600,
                      ).copyWith(height: 1.45),
                    ),
                  ),
                ),
                if (widget.showCommerce)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 5, 2, 12),
                    child: PointShopProductBadge(
                      productKey: widget.productKey,
                      compact: false,
                      fontSize: 14,
                      unlistedLabel:
                          freeTemplateMaterialProductKeys.contains(
                            widget.productKey,
                          )
                          ? '무료'
                          : '판매 준비 중',
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

/// A quiet support for the original artwork, shared by the grid and discovery
/// shelf. Translucent papers retain the contrast chosen for their detail view.
/// This widget never constructs photos, documents or fonts for scrolling.
class MaterialArtworkStage extends StatelessWidget {
  const MaterialArtworkStage({
    super.key,
    required this.productKey,
    required this.child,
    this.padding = const EdgeInsets.all(8),
  });

  final String productKey;
  final Widget child;
  final EdgeInsetsGeometry padding;
  static const ink = Color(0xFF455953);

  static EdgeInsets artworkInsets(
    BuildContext context, {
    required String productKey,
    required String type,
    bool compact = false,
  }) {
    final horizontal =
        productKey.startsWith('frame:') || productKey.startsWith('phrase:')
        ? 6.0
        : 8.0;
    final labelHeight = MediaQuery.textScalerOf(context).scale(10) * 1.2;
    return EdgeInsets.fromLTRB(
      horizontal,
      labelHeight + (compact ? 10 : 12),
      horizontal,
      type == '종이' ? 8 : 7,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = MaterialOriginalPreview.backgroundFor(productKey);
    // The original contains translucent paper and dark printed linework. Keep
    // its artboard light in both themes instead of recoloring the artwork.
    final background = Color.lerp(base, const Color(0xFFF7F8F6), .28)!;
    final radius = BorderRadius.circular(SnapFitRadius.lg);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        key: ValueKey('material-artwork-stage-$productKey'),
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(
            color: const Color(0xFF788B86).withValues(alpha: dark ? .20 : .14),
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

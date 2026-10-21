import 'package:flutter/material.dart';

import '../../../../core/templates/free_template_material_policy.dart';
import '../../../../core/theme/snapfit_design_tokens.dart'
    show SnapFitRadius, SnapFitShadow;
import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import 'catalog_item_title.dart';

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
  });
  final String productKey, title, type;
  final Widget preview;
  final VoidCallback onOpen;
  final String? favoriteKey;
  final bool compact;
  final bool showCommerce;

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
    final (paper, ink) = switch (widget.type) {
      '프레임' => (const Color(0xFFE5ECE2), const Color(0xFF3D6148)),
      '종이' => (const Color(0xFFC6D8DF), const Color(0xFF405C69)),
      '문구' => (const Color(0xFFF3E2E8), const Color(0xFF7D4157)),
      _ => (const Color(0xFFE6E9F1), const Color(0xFF45516B)),
    };
    final dark = Theme.of(context).brightness == Brightness.dark;
    final previewPaper = dark
        ? Color.lerp(paper, const Color(0xFF1B2324), .86)!
        : paper;
    final previewInk = dark ? Color.lerp(ink, Colors.white, .72)! : ink;
    final elevated = _hovered || _pressed;
    return MouseRegion(
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
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SnapFitRadius.lg),
                  boxShadow: elevated ? SnapFitShadow.artwork(dark) : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SnapFitRadius.lg),
                child: ColoredBox(
                  color: previewPaper,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          widget.compact ? 28 : 30,
                          12,
                          10,
                        ),
                        child: RepaintBoundary(child: widget.preview),
                      ),
                      Positioned(
                        left: 9,
                        top: 9,
                        child: Text(
                          widget.type,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: previewInk,
                          ),
                        ),
                      ),
                      if (widget.showCommerce && widget.favoriteKey != null)
                        Positioned(
                          right: 3,
                          top: 3,
                          child: CatalogFavoriteButton(
                            itemKey: widget.favoriteKey!,
                            label: widget.title,
                            bookmark: true,
                            unframed: true,
                          ),
                        ),
                    ],
                  ),
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
                  unlistedLabel: freeTemplateMaterialProductKeys.contains(
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
  );
  }

}

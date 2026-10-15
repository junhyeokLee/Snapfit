import 'package:flutter/material.dart';

import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import 'catalog_item_title.dart';

class MaterialCatalogTile extends StatelessWidget {
  const MaterialCatalogTile({
    super.key,
    required this.productKey,
    required this.title,
    required this.type,
    required this.preview,
    required this.onOpen,
    this.favoriteKey,
    this.compact = false,
  });
  final String productKey, title, type;
  final Widget preview;
  final VoidCallback onOpen;
  final String? favoriteKey;
  final bool compact;

  static double extent(double width, TextScaler scaler) =>
      width + scaler.scale(13) * 2.9 + 46;
  @override
  Widget build(BuildContext context) {
    final (paper, ink) = switch (type) {
      '프레임' => (const Color(0xFFE5ECE2), const Color(0xFF3D6148)),
      '종이' => (const Color(0xFFEEE5DC), const Color(0xFF78534A)),
      '문구' => (const Color(0xFFE9E3EB), const Color(0xFF614869)),
      _ => (const Color(0xFFE2E9ED), const Color(0xFF365A6A)),
    };
    return Material(
      color: ExperienceFormStyle.surface(context),
      borderRadius: BorderRadius.circular(7),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: paper,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        13,
                        compact ? 23 : 32,
                        13,
                        12,
                      ),
                      child: RepaintBoundary(child: preview),
                    ),
                    Positioned(
                      left: 9,
                      top: 9,
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                    if (favoriteKey != null)
                      Positioned(
                        right: 3,
                        top: 3,
                        child: CatalogFavoriteButton(
                          itemKey: favoriteKey!,
                          label: title,
                          bookmark: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: SizedBox(
                height: MediaQuery.textScalerOf(context).scale(13) * 2.9,
                child: CatalogItemTitle(
                  title,
                  style: ExperienceFormStyle.text(
                    context,
                    13,
                    weight: FontWeight.w600,
                  ).copyWith(height: 1.45),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 11),
              child: PointShopProductBadge(
                productKey: productKey,
                compact: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

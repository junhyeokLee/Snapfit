import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/templates/catalog_preview_assets.g.dart';
import '../../../../core/templates/free_template_material_policy.dart';
import '../../../../core/templates/catalog_favorite_keys.dart';
import '../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../core/templates/studio_word_art_catalog.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/domain/point_shop_known_products.dart';
import '../../../point_shop/presentation/point_shop_artwork.dart';
import '../../data/store_curation_provider.dart';
import '../views/material_detail_screen.dart';

class StoreMaterialDiscovery extends ConsumerWidget {
  const StoreMaterialDiscovery({super.key, required this.onBrowse});
  final VoidCallback onBrowse;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref
        .watch(storeCurationsProvider)
        .asData
        ?.value['materials'];
    if (selection == null) return const SizedBox.shrink();
    final prices = {
      for (final p in ref.watch(pointShopCatalogProvider).asData?.value ?? [])
        p.productKey: p,
    };
    final items = selection
        .resolve(
          pointShopKnownProducts.where((p) {
            if (p.kind == 'template') return false;
            final price = prices[p.productKey];
            return price == null
                ? freeTemplateMaterialProductKeys.contains(p.productKey)
                : price.isActive && price.pointPrice != null;
          }),
          (p) => p.productKey,
        )
        .take(4)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      key: const ValueKey('store-material-discovery'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ColoredBox(
        color: ExperienceFormStyle.surface(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selection.title,
                      style: ExperienceFormStyle.text(
                        context,
                        21,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '꾸밈소재 모두 보기',
                    onPressed: onBrowse,
                    icon: const ExperienceIcon('ArrowRight', size: 21),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 154 + scaler.scale(12) * 2.9 + scaler.scale(10) * 1.5,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final decoration = item.kind == 'sticker'
                        ? studioDecorationById(item.assetId)
                        : null;
                    final wordArt = studioWordArts
                        .where((art) => art.productKey == item.productKey)
                        .firstOrNull;
                    final favoriteKey = decoration != null
                        ? CatalogFavoriteKeys.decoration(
                            decoration.insertionValue,
                          )
                        : wordArt?.favoriteKey ?? item.productKey;
                    final type = item.kind == 'frame'
                        ? '프레임'
                        : item.kind == 'phrase'
                        ? '문구'
                        : decoration?.category == StudioDecorationCategory.paper
                        ? '종이'
                        : '스티커';
                    final asset = catalogPreviewAssets[item.productKey];
                    return SizedBox(
                      width: 148,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey(
                            'discovery-material-${item.productKey}',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MaterialDetailScreen(
                                productKey: item.productKey,
                                favoriteKey: favoriteKey,
                                title: item.title,
                                type: type,
                                preview: (_) => PointShopArtwork(
                                  productKey: item.productKey,
                                ),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 138,
                                width: 148,
                                child: RepaintBoundary(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: asset == null
                                        ? PointShopArtwork(
                                            productKey: item.productKey,
                                          )
                                        : Image.asset(
                                            asset,
                                            fit: BoxFit.contain,
                                            cacheWidth: 320,
                                            errorBuilder: (_, _, _) =>
                                                PointShopArtwork(
                                                  productKey: item.productKey,
                                                ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ExperienceFormStyle.text(
                                  context,
                                  12,
                                  weight: FontWeight.w500,
                                ).copyWith(height: 1.4),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type,
                                style: ExperienceFormStyle.text(
                                  context,
                                  10,
                                  secondary: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

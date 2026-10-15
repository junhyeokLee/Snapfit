import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../shared/widgets/catalog_artwork_hero.dart';
import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../../domain/entities/premium_template.dart';
import 'catalog_edition_artwork.dart';
import 'catalog_item_title.dart';
import 'store_floating_cover.dart';

class TemplateCatalogTile extends StatelessWidget {
  const TemplateCatalogTile({
    super.key,
    required this.template,
    required this.onOpen,
    required this.heroTag,
    required this.scrollController,
    required this.previewRatio,
  });
  final PremiumTemplate template;
  final VoidCallback onOpen;
  final Object heroTag;
  final ScrollController scrollController;
  final double previewRatio;
  static double extent(double width, double ratio, TextScaler scaler) =>
      width / ratio + scaler.scale(14) * 2.9 + scaler.scale(11) * 1.5 + 58;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = CatalogEditionPalette.of(template.category);
    final cover = CreationCatalogCover(
      template: template,
      useThumbnail: true,
      showBookMaterial: !kIsWeb,
    );
    final hasSpread = catalogEditorialSpread(template) != null;
    return Semantics(
      key: ValueKey('store-template-${template.id}'),
      button: true,
      label: '${template.title} 상세 보기',
      child: Material(
        color: ExperienceFormStyle.surface(context),
        borderRadius: BorderRadius.circular(7),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: previewRatio,
                child: ColoredBox(
                  key: ValueKey('template-cover-stage-${template.id}'),
                  color: dark
                      ? Color.lerp(palette.ink, const Color(0xFF202321), .65)!
                      : palette.paper,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        bottom: hasSpread ? 42 : 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 20, 12, 4),
                          child: CatalogArtworkHero(
                            tag: heroTag,
                            child: kIsWeb
                                ? cover
                                : StoreFloatingCover(
                                    scrollController: scrollController,
                                    seed: template.id,
                                    child: cover,
                                  ),
                          ),
                        ),
                      ),
                      if (hasSpread)
                        Positioned(
                          left: 15,
                          right: 15,
                          bottom: 9,
                          height: 37,
                          child: CatalogSpreadPreview(
                            template: template,
                            decodeWidth: 384,
                          ),
                        ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: CatalogFavoriteButton(
                          bookmark: true,
                          itemKey: CatalogFavoriteKeys.template(template.id),
                          label: template.title,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 12, 11, 0),
                child: SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(14) * 2.9,
                  child: CatalogItemTitle(
                    template.title,
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      weight: FontWeight.w600,
                    ).copyWith(height: 1.45),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 2, 11, 0),
                child: Text(
                  '${template.category ?? '포토북'} · ${template.pageCount}쪽',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExperienceFormStyle.text(context, 11, secondary: true),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
                child: PointShopProductBadge(
                  productKey: pointShopTemplateKey(template),
                  unlistedLabel: template.isPremium ? '판매 준비 중' : '무료',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

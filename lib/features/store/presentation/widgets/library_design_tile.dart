import 'package:flutter/material.dart';

import '../../../../core/templates/free_template_material_policy.dart';
import '../../../../shared/widgets/catalog_artwork_hero.dart';
import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/album_stage_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../../domain/entities/premium_template.dart';
import 'catalog_edition_artwork.dart';
import 'catalog_item_title.dart';
import 'material_original_preview.dart';

//앨범 편집할때 템플릿 적용할때 한페이지만 적용하게되는데 유료 템틀릿은 전체를 사는 비용인데 한페이지밖에 적용이안되니 유저가 햇갈릴수있을거같아 이부분 어떻게 진행하는게 좋을까?

class LibraryDesignTile extends StatelessWidget {
  const LibraryDesignTile({
    super.key,
    required this.productKey,
    required this.title,
    required this.type,
    required this.preview,
    required this.previewHeight,
    required this.onOpen,
    required this.owned,
    this.template,
    this.favoriteKey,
    this.heroTag,
    this.coverOnly = false,
    this.undoOnRemove = false,
  });

  final String productKey, title, type;
  final Widget preview;
  final double previewHeight;
  final VoidCallback onOpen;
  final bool owned;
  final PremiumTemplate? template;
  final String? favoriteKey;
  final Object? heroTag;

  /// Creation browsing needs a large jacket; other shelves keep their spread.
  final bool coverOnly;
  final bool undoOnRemove;

  static double extent(
    double previewHeight,
    TextScaler scaler, {
    bool coverOnly = false,
  }) => coverOnly
      ? previewHeight + scaler.scale(15) * 2.9 + scaler.scale(12) * 1.8 + 18
      : previewHeight +
            scaler.scale(13) * 2.9 +
            scaler.scale(11) * 1.5 +
            (scaler.scale(12) * 1.5).clamp(32, double.infinity) +
            25;

  @override
  Widget build(BuildContext context) {
    final edition = template;
    final hasSpread =
        !coverOnly &&
        edition != null &&
        catalogEditorialSpread(edition) != null;
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      button: true,
      label: '$title, $type${owned ? ', 구매 완료' : ''}, 상세 보기',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: previewHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: edition == null
                        ? MaterialOriginalPreview.backgroundFor(productKey)
                        : null,
                    gradient: edition != null
                        ? AlbumStageStyle.gradient(context)
                        : null,
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasSpread)
                          Positioned(
                            right: 12,
                            top: box.maxHeight * .16,
                            width:
                                box.maxWidth *
                                (box.maxWidth >= 260 ? .59 : .66),
                            height: box.maxHeight * .66,
                            child: CatalogSpreadPreview(
                              template: edition,
                              decodeWidth: box.maxWidth > 240 ? 768 : 384,
                            ),
                          ),
                        Positioned(
                          left: hasSpread ? 12 : 0,
                          right: hasSpread
                              ? box.maxWidth * (box.maxWidth >= 260 ? .61 : .39)
                              : 0,
                          top: hasSpread ? box.maxHeight * .12 : 0,
                          bottom: hasSpread ? box.maxHeight * .08 : 0,
                          child: Padding(
                            padding: EdgeInsets.all(
                              coverOnly ? 4 : (hasSpread ? 0 : 16),
                            ),
                            child: RepaintBoundary(
                              child: CatalogArtworkHero(
                                tag: heroTag,
                                child: preview,
                              ),
                            ),
                          ),
                        ),
                        if (favoriteKey != null)
                          Positioned(
                            right: 3,
                            top: 3,
                            child: CatalogFavoriteButton(
                              bookmark: true,
                              undoOnRemove: undoOnRemove,
                              itemKey: favoriteKey!,
                              label: title,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: scaler.scale(coverOnly ? 15 : 13) * 2.9,
                child: CatalogItemTitle(
                  title,
                  style: ExperienceFormStyle.text(
                    context,
                    coverOnly ? 15 : 13,
                    weight: FontWeight.w600,
                  ).copyWith(height: 1.45),
                ),
              ),
              if (!coverOnly) ...[
                const SizedBox(height: 3),
                Text(
                  edition == null ? type : '템플릿 · 내지 ${edition.pageCount}쪽',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExperienceFormStyle.text(
                    context,
                    11,
                    secondary: true,
                  ).copyWith(height: 1.5),
                ),
                const Spacer(),
              ],
              SizedBox(
                height: coverOnly
                    ? scaler.scale(12) * 1.8
                    : (scaler.scale(12) * 1.5).clamp(32, double.infinity),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: owned
                      ? Row(
                          children: [
                            ExperienceIcon(
                              'Check',
                              size: 15,
                              color: ExperienceFormStyle.selectionInk(context),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '구매 완료',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ExperienceFormStyle.text(
                                  context,
                                  12,
                                  secondary: true,
                                ),
                              ),
                            ),
                            ExperienceIcon(
                              'ArrowRight',
                              size: 17,
                              color: ExperienceFormStyle.muted(context),
                            ),
                          ],
                        )
                      : coverOnly
                      ? LayoutBuilder(
                          builder: (context, box) {
                            // Prioritize the amount/status on narrow or enlarged UI.
                            if (box.maxWidth < 140 || scaler.scale(12) > 18) {
                              return _priceBadge();
                            }
                            return Row(
                              children: [
                                _priceBadge(),
                                if (edition?.category case final category?) ...[
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      '· $category',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ExperienceFormStyle.text(
                                        context,
                                        12,
                                        secondary: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        )
                      : _priceBadge(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Price and unlisted status keep using the existing server-backed badge.
  Widget _priceBadge() => PointShopProductBadge(
    productKey: productKey,
    compact: false,
    fontSize: 12,
    unlistedLabel:
        freeTemplateMaterialProductKeys.contains(productKey) ||
            template?.isPremium == false
        ? '무료'
        : '판매 준비 중',
  );
}

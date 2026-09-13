import 'package:flutter/material.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart';
import '../../../domain/entities/layer.dart';
import 'creation_document_preview.dart';
import '../../../../../shared/widgets/catalog_favorite_widgets.dart';

class CreationTemplatePreview extends StatelessWidget {
  const CreationTemplatePreview({
    super.key,
    required this.title,
    required this.isPremium,
    required this.pages,
    required this.canvas,
    required this.onUse,
    required this.onRetry,
    this.isUsing = false,
    this.preserveTypography = false,
    this.favoriteKey,
    this.accessBadge,
  });
  final String title;
  final bool isPremium;
  final List<List<LayerModel>> pages;
  final Size canvas;
  final VoidCallback onUse;
  final VoidCallback onRetry;
  final bool isUsing;
  final bool preserveTypography;
  final String? favoriteKey;
  final Widget? accessBadge;

  Widget _use(BuildContext context) => FilledButton(
    onPressed: isUsing || pages.isEmpty ? null : onUse,
    style: FilledButton.styleFrom(
      backgroundColor: SnapFitColors.textPrimaryOf(context),
      foregroundColor: SnapFitColors.backgroundOf(context),
      minimumSize: const Size(144, 48),
      textStyle: const TextStyle(
        fontFamily: SnapFitFonts.body,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: isUsing
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('이 디자인 선택'),
  );

  @override
  Widget build(BuildContext context) {
    final ink = SnapFitColors.textPrimaryOf(context);
    final wide =
        MediaQuery.sizeOf(context).width >= 640 &&
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        actions: [
          if (favoriteKey != null)
            CatalogFavoriteButton(itemKey: favoriteKey!, label: title),
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _use(context),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: pages.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('디자인을 불러오지 못했어요'),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('다시 불러오기'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : CreationDocumentPreview(
                      pages: pages,
                      canvas: canvas,
                      preserveTypography: preserveTypography,
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, wide ? 8 : 12),
              child: Row(
                children: [
                  accessBadge ??
                      Text(
                        '템플릿',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                  const SizedBox(width: 16),
                  if (!wide) Expanded(child: _use(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

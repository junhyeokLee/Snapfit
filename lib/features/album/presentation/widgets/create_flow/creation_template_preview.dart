import 'package:flutter/material.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import 'creation_workspace.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
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
    this.profileSummary,
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
  final Widget? profileSummary;

  Widget _use(BuildContext context) => FilledButton(
    onPressed: isUsing || pages.isEmpty ? null : onUse,
    style: CreationStyle.primary(
      context,
    ).copyWith(minimumSize: const WidgetStatePropertyAll(Size(144, 48))),
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
        toolbarHeight: wide
            ? (MediaQuery.textScalerOf(context).scale(14) * 1.6 + 24).clamp(
                56.0,
                96.0,
              )
            : 56,
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
          if (wide && accessBadge != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: accessBadge),
            ),
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _use(context),
            ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: SnapFitColors.backgroundOf(context),
                border: Border(
                  top: BorderSide(color: ExperienceFormStyle.line(context)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, wide ? 8 : 12),
                  child: Row(
                    children: [
                      Flexible(
                        child:
                            accessBadge ??
                            Text(
                              '템플릿',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                      ),
                      const SizedBox(width: 16),
                      if (!wide) Expanded(flex: 3, child: _use(context)),
                    ],
                  ),
                ),
              ),
            ),
      body: SafeArea(
        top: false,
        bottom: wide,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final summary = profileSummary;
            final summaryExtent = summary != null && !wide
                ? (bounds.maxHeight * .28).clamp(0.0, 180.0)
                : 0.0;
            // Short displays keep the book and page controls ahead of the rail.
            final showThumbnails =
                summary == null ||
                bounds.maxHeight - summaryExtent >=
                    240 + MediaQuery.textScalerOf(context).scale(16);
            final document = pages.isEmpty
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
                    showBookMaterial: true,
                    spreadInLandscape: true,
                    showThumbnails: showThumbnails,
                  );
            if (summary == null) return document;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: document),
                  SizedBox(
                    width: (bounds.maxWidth * .3).clamp(200.0, 280.0),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: summary,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: summaryExtent),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: summary,
                  ),
                ),
                Expanded(child: document),
              ],
            );
          },
        ),
      ),
    );
  }
}

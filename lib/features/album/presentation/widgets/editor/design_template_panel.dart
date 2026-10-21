import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../../point_shop/presentation/point_shop_access.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/design_templates.dart';
import '../../../../../core/templates/template_catalog_categories.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../providers/design_template_catalog_provider.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../cover/cover.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
import '../../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../domain/entities/layer.dart';
import 'template_apply_preview.dart';

class DesignTemplatePanel extends ConsumerStatefulWidget {
  const DesignTemplatePanel({
    super.key,
    this.closeOnApply = true,
    this.showHeader = true,
  });

  final bool closeOnApply;
  final bool showHeader;

  @override
  ConsumerState<DesignTemplatePanel> createState() =>
      _DesignTemplatePanelState();
}

class _DesignTemplatePanelState extends ConsumerState<DesignTemplatePanel> {
  String? _selectedId;
  bool _isApplying = false;
  String _selectedCategory = '전체';
  bool _favoritesOnly = false;
  final Set<String> _warmedThumbs = <String>{};

  Size _effectiveLogicalCanvasSize({
    required AlbumEditorViewModel vm,
    required AlbumEditorState? stateVal,
  }) {
    final double aspect = vm.selectedCover.ratio > 0
        ? vm.selectedCover.ratio
        : (3 / 4);
    final double baseW = kCoverReferenceWidth;
    return Size(baseW, baseW / aspect);
  }

  @override
  Widget build(BuildContext context) =>
      CatalogFavoritesBuilder(builder: _buildCatalog);

  Widget _buildCatalog(BuildContext context, CatalogFavorites favorites) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final stateVal = ref.watch(albumEditorViewModelProvider).value;
    final Size canvasSize = _effectiveLogicalCanvasSize(
      vm: vm,
      stateVal: stateVal,
    );
    final templateSourceSize = Size(
      kCoverReferenceWidth,
      kCoverReferenceWidth /
          ((vm.selectedCover.ratio > 0) ? vm.selectedCover.ratio : (3 / 4)),
    );

    final catalogAsync = ref.watch(designTemplateCatalogProvider);
    final hasCatalogData = catalogAsync.hasValue && catalogAsync.value != null;
    // 기존 값이 있더라도 로딩 중에는 리스트를 숨겨 "보였다가 바뀌는" 느낌을 제거
    final isCatalogLoading = catalogAsync.isLoading;
    final allTemplates = hasCatalogData
        ? catalogAsync.value!
        : publishedDesignTemplates;

    final categories = <String>[
      '전체',
      ...orderedTemplateTopics(allTemplates.map((t) => t.category)),
    ];

    int _countByCategory(String category) {
      if (category == '전체') {
        return allTemplates.length;
      }
      return allTemplates.where((t) => t.category == category).length;
    }

    final orderedTemplates =
        allTemplates
            // 커버/페이지 모두 동일 템플릿 목록을 노출한다.
            .where((_) => true)
            .where(
              (t) =>
                  _selectedCategory == '전체' || t.category == _selectedCategory,
            )
            // 커버/페이지에서 동일한 템플릿 셋을 노출한다.
            // 기존 cover_* 전용 항목은 중복 노출을 막기 위해 패널에서는 제외한다.
            .where((t) => !t.id.startsWith('cover_'))
            .toList()
          ..sort((a, b) {
            if (a.isFeatured != b.isFeatured) {
              return a.isFeatured ? -1 : 1;
            }
            final byPriority = b.priority.compareTo(a.priority);
            if (byPriority != 0) return byPriority;
            final aRef = a.id.startsWith('data_ref_');
            final bRef = b.id.startsWith('data_ref_');
            if (aRef != bRef) return aRef ? -1 : 1;
            final byCategory = a.category.compareTo(b.category);
            if (byCategory != 0) return byCategory;
            return a.name.compareTo(b.name);
          });

    final templates = favorites.arrange(
      orderedTemplates,
      (t) => CatalogFavoriteKeys.design(t.id),
      onlyFavorites: _favoritesOnly,
    );
    _warmUpPreviewThumbs(templates);

    return Container(
      height: kIsWeb
          ? double.infinity
          : MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: kIsWeb
            ? WebPalette.of(context).surface
            : SnapFitColors.surfaceOf(context),
        borderRadius: kIsWeb
            ? BorderRadius.circular(12)
            : BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!kIsWeb) ...[
              SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SnapFitColors.textPrimaryOf(
                      context,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
            if (widget.showHeader && (!kIsWeb || widget.closeOnApply))
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '앨범 분위기 고르기',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: kIsWeb
                              ? FontWeight.w700
                              : FontWeight.w900,
                          color: SnapFitColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    if (kIsWeb)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        tooltip: '템플릿 닫기',
                        icon: const Icon(Icons.close, size: 20),
                      ),
                  ],
                ),
              ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '사진에 맞는 무드를 골라보세요',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CatalogFavoriteFilter(
                        selected: _favoritesOnly,
                        onChanged: (value) => setState(() {
                          _favoritesOnly = value;
                          _selectedCategory = '전체';
                        }),
                      ),
                    ),
                    for (final c in categories)
                      Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: _FilterPill(
                          label: c,
                          count: _countByCategory(c),
                          selected: _selectedCategory == c,
                          onTap: () {
                            setState(() {
                              _selectedCategory = c;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: isCatalogLoading
                    ? Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                '어울리는 템플릿을 고르는 중이에요…',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: SnapFitColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : templates.isEmpty
                    ? CatalogFavoritesEmpty(
                        onShowAll: () => setState(() {
                          _favoritesOnly = false;
                          _selectedCategory = '전체';
                        }),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent:
                              176 + MediaQuery.textScalerOf(context).scale(32),
                        ),
                        itemCount: templates.length,
                        itemBuilder: (context, index) {
                          final template = templates[index];
                          final isSelected = _selectedId == template.id;
                          return CatalogFavoriteTile(
                            key: ValueKey(template.id),
                            itemKey: CatalogFavoriteKeys.design(template.id),
                            label: template.name,
                            child: _buildTemplateCard(
                              context,
                              template: template,
                              isSelected: isSelected,
                              logicalCanvasSize: canvasSize,
                              templateSourceSize: templateSourceSize,
                              ref: ref,
                              onTap: () async {
                                if (_isApplying) return;
                                _isApplying = true;
                                final pageId = vm.currentPage?.id;
                                try {
                                  final approved =
                                      await showTemplateApplyPreview(
                                        context,
                                        title: template.name,
                                        replacesContent:
                                            vm.currentPage?.layers.isNotEmpty ??
                                            false,
                                        preview: _DesignTemplatePreview(
                                          template: template,
                                          ref: ref,
                                          logicalCanvasSize: canvasSize,
                                          sourceCanvasSize: templateSourceSize,
                                        ),
                                      );
                                  if (!mounted ||
                                      !approved ||
                                      vm.currentPage?.id != pageId)
                                    return;
                                  if (!await ensurePointShopAccess(
                                    context,
                                    ref,
                                    productKey: 'template:${template.id}',
                                    title: template.name,
                                  ))
                                    return;
                                  if (!mounted || vm.currentPage?.id != pageId)
                                    return;
                                  setState(() => _selectedId = template.id);
                                  vm.applyDesignTemplateToCurrentPage(
                                    template,
                                    canvasSize,
                                  );
                                  if (widget.closeOnApply && context.mounted)
                                    Navigator.of(context).pop();
                                } finally {
                                  _isApplying = false;
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _warmUpPreviewThumbs(List<DesignTemplate> templates) {
    if (templates.isEmpty) return;
    final top = templates.take(8);
    for (final t in top) {
      final urls = templatePreviewImagesFor(t);
      if (urls.isEmpty) continue;
      final url = urls.first;
      if (url.isEmpty || _warmedThumbs.contains(url)) continue;
      _warmedThumbs.add(url);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        precacheImage(NetworkImage(url), context, onError: (_, __) {});
      });
    }
  }

  Widget _buildTemplateCard(
    BuildContext context, {
    required DesignTemplate template,
    required bool isSelected,
    required Size logicalCanvasSize,
    required Size templateSourceSize,
    required WidgetRef ref,
    required VoidCallback onTap,
  }) {
    return SnapFitPressable(
      onTap: onTap,
      semanticLabel: '${template.name} 템플릿 미리보기',
      selected: isSelected,
      pressedScale: 0.98,
      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: SnapFitMotion.settle,
        decoration: BoxDecoration(
          color: kIsWeb
              ? WebPalette.of(context).surface
              : SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(kIsWeb ? 12 : 8),
          border: Border.all(
            color: isSelected
                ? kIsWeb
                      ? WebPalette.of(context).brandInk
                      : SnapFitColors.accent
                : kIsWeb
                ? WebPalette.of(context).line
                : SnapFitColors.overlayLightOf(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: kIsWeb
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      SnapFitColors.isDark(context) ? 0.24 : 0.07,
                    ),
                    blurRadius: isSelected ? 22 : 14,
                    offset: const Offset(0, 9),
                  ),
                ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, 11),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio:
                              logicalCanvasSize.width /
                              logicalCanvasSize.height,
                          child: Container(
                            decoration: BoxDecoration(
                              color: SnapFitColors.backgroundOf(context),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _DesignTemplatePreview(
                                template: template,
                                ref: ref,
                                logicalCanvasSize: logicalCanvasSize,
                                sourceCanvasSize: templateSourceSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.38),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          template.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: SnapFitColors.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: kIsWeb
                                    ? WebPalette.of(context).onBrand
                                    : Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                '선택',
                                style: TextStyle(
                                  color: kIsWeb
                                      ? WebPalette.of(context).onBrand
                                      : Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 9),
              Text(
                template.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                  color: isSelected
                      ? SnapFitColors.accent
                      : SnapFitColors.textPrimaryOf(context),
                  height: 1.05,
                  letterSpacing: -0.05,
                ),
              ),
              SizedBox(height: 3),
              PointShopProductBadge(productKey: 'template:${template.id}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = kIsWeb
        ? selected
              ? WebPalette.of(context).softBrand
              : WebPalette.of(context).surface
        : selected
        ? const Color(0xFF132331)
        : SnapFitColors.surfaceOf(context);
    final fg = kIsWeb
        ? selected
              ? WebPalette.of(context).brandInk
              : WebPalette.of(context).muted
        : selected
        ? Colors.white
        : SnapFitColors.textSecondaryOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected && !kIsWeb
                ? [
                    BoxShadow(
                      color: const Color(0xFF132331).withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
            border: Border.all(
              color: kIsWeb
                  ? selected
                        ? WebPalette.of(context).brandInk
                        : WebPalette.of(context).line
                  : selected
                  ? const Color(0xFF20384D)
                  : SnapFitColors.overlayMediumOf(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: fg,
                  height: 1.0,
                ),
              ),
              if (count != null) ...[
                SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kIsWeb
                        ? WebPalette.of(context).surface
                        : selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : SnapFitColors.overlayLightOf(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: kIsWeb
                          ? WebPalette.of(context).brandInk
                          : selected
                          ? Colors.white
                          : SnapFitColors.textSecondaryOf(context),
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DesignTemplatePreview extends StatelessWidget {
  final DesignTemplate template;
  final WidgetRef ref;
  final Size logicalCanvasSize;
  final Size sourceCanvasSize;

  const _DesignTemplatePreview({
    required this.template,
    required this.ref,
    required this.logicalCanvasSize,
    required this.sourceCanvasSize,
  });

  @override
  Widget build(BuildContext context) {
    final previewInteraction = LayerInteractionManager.preview(
      ref,
      () => logicalCanvasSize,
    );
    final layerBuilder = LayerBuilder(
      previewInteraction,
      () => logicalCanvasSize,
    );

    final rawLayers = template.buildLayers(sourceCanvasSize);
    final layers = _scaleTemplateLayersForPreview(
      rawLayers,
      from: sourceCanvasSize,
      to: logicalCanvasSize,
    );
    final previewReady = injectTemplatePreviewImages(template, layers);

    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      child: SizedBox(
        width: logicalCanvasSize.width,
        height: logicalCanvasSize.height,
        child: CoverLayout(
          aspect: logicalCanvasSize.width / logicalCanvasSize.height,
          layers: previewReady,
          isInteracting: false,
          leftSpine: 0,
          backgroundColor: template.backgroundColor,
          onCoverSizeChanged: (_) {},
          buildImage: (layer) => layerBuilder.buildImage(layer, isCover: true),
          buildText: (layer) => layerBuilder.buildText(layer, isCover: true),
          sortedByZ: previewInteraction.sortByZ,
          theme: CoverTheme.classic,
        ),
      ),
    );
  }
}

List<LayerModel> _scaleTemplateLayersForPreview(
  List<LayerModel> layers, {
  required Size from,
  required Size to,
}) {
  if (layers.isEmpty || from.width <= 0 || from.height <= 0) return layers;
  final sx = to.width / from.width;
  final sy = to.height / from.height;
  final sText = sx < sy ? sx : sy;

  return layers.map((l) {
    final style = l.textStyle;
    final scaledStyle = style?.copyWith(
      fontSize: style.fontSize == null ? null : style.fontSize! * sText,
      letterSpacing: style.letterSpacing == null
          ? null
          : style.letterSpacing! * sText,
    );
    return l.copyWith(
      position: Offset(l.position.dx * sx, l.position.dy * sy),
      width: l.width * sx,
      height: l.height * sy,
      textStyle: scaledStyle,
    );
  }).toList();
}

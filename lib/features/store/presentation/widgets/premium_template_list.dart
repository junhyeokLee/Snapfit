import 'store_product_badge.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/image_url_policy.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../../../album/data/bundled_creation_templates.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../domain/entities/premium_template.dart';
import '../views/template_detail_screen.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import 'template_page_renderer.dart';
import 'template_preview_frame.dart';
import '../../data/api/template_provider.dart';
import '../../../../shared/widgets/experience_icon.dart';

class PremiumTemplateList extends ConsumerStatefulWidget {
  final int? maxItems;

  const PremiumTemplateList({super.key, this.maxItems});

  @override
  ConsumerState<PremiumTemplateList> createState() =>
      _PremiumTemplateListState();
}

class _PremiumTemplateListState extends ConsumerState<PremiumTemplateList> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  String _recommendedPhotoRange(PremiumTemplate template) {
    final count = publishedTemplatePhotoCount(template);
    if (count != null) return '$count장';
    final pages = template.pageCount <= 0 ? 24 : template.pageCount;
    final minPhotos = (pages * 1.6).round().clamp(18, 120);
    final maxPhotos = (pages * 2.15).round().clamp(minPhotos + 6, 160);
    return '$minPhotos~$maxPhotos장';
  }

  String _coverPreviewUrl(PremiumTemplate template) {
    final cover = template.coverImageUrl.trim();
    if (cover.isNotEmpty) return cover;
    final previews = template.previewImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (previews.isNotEmpty) return previews.first;
    return '';
  }

  Widget _buildCoverImage(BuildContext context, String rawUrl) {
    if (rawUrl.trim().isEmpty) {
      return const TemplatePaperPlaceholder();
    }
    final bundledAsset = bundledTemplateAssetPath(rawUrl);
    if (bundledAsset != null) {
      return Image.asset(
        bundledAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const TemplatePaperPlaceholder(),
      );
    }
    final transformed = imageUrlByVariant(rawUrl, variant: ImageVariant.thumb);
    if (transformed.startsWith('asset:')) {
      return Image.asset(
        transformed.substring('asset:'.length),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const TemplatePaperPlaceholder(),
      );
    }
    return Image.network(
      transformed,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const TemplatePaperPlaceholder();
      },
      errorBuilder: (_, __, ___) => const TemplatePaperPlaceholder(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CatalogFavoritesBuilder(builder: _buildCatalog);

  Widget _buildCatalog(BuildContext context, CatalogFavorites favorites) {
    final templatesAsync = ref.watch(templateListProvider);

    return templatesAsync.when(
      data: (templates) {
        if (templates.isEmpty) return const SizedBox.shrink();
        final ordered = favorites.arrange(
          templates,
          (t) => CatalogFavoriteKeys.template(t.id),
        );
        final visibleTemplates = widget.maxItems == null
            ? ordered
            : ordered.take(widget.maxItems!).toList();
        if (visibleTemplates.isEmpty) return const SizedBox.shrink();

        if (visibleTemplates.every(isPublishedCreationTemplate)) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 40).clamp(240.0, 420.0);
              final coverHeight = width.clamp(240.0, 330.0);
              return Center(
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      SizedBox(
                        height: coverHeight + 90,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: visibleTemplates.length,
                          onPageChanged: (index) =>
                              setState(() => _currentIndex = index),
                          itemBuilder: (context, index) {
                            final template = visibleTemplates[index];
                            return CatalogFavoriteTile(
                              key: ValueKey(template.id),
                              itemKey: CatalogFavoriteKeys.template(
                                template.id,
                              ),
                              label: template.title,
                              child: SnapFitPressable(
                                onTap: () => Navigator.push(
                                  context,
                                  snapFitRoute(page: TemplateDetailScreen(
                                      template: template,
                                    )),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: coverHeight,
                                      width: width,
                                      child: ExcludeSemantics(
                                        child: CreationCatalogCover(
                                          template: template,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            template.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0,
                                            ),
                                          ),
                                        ),
                                        PointShopProductBadge(
                                          productKey: pointShopTemplateKey(
                                            template,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const ExperienceIcon('ChevronRight', size: 20),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${template.category} · 표지 + 내지 ${template.pageCount}쪽 · 사진 ${_recommendedPhotoRange(template)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (visibleTemplates.length > 5)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: '이전 컬렉션',
                              onPressed: _currentIndex == 0
                                  ? null
                                  : () => _pageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    ),
                              icon: const ExperienceIcon('ChevronLeft'),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                '${_currentIndex + 1} / ${visibleTemplates.length}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              tooltip: '다음 컬렉션',
                              onPressed:
                                  _currentIndex == visibleTemplates.length - 1
                                  ? null
                                  : () => _pageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    ),
                              icon: const ExperienceIcon('ChevronRight'),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (
                              var index = 0;
                              index < visibleTemplates.length;
                              index++
                            )
                              Semantics(
                                button: true,
                                selected: _currentIndex == index,
                                label: visibleTemplates[index].title,
                                child: Tooltip(
                                  message: visibleTemplates[index].title,
                                  child: InkResponse(
                                    onTap: () => _pageController.animateToPage(
                                      index,
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    ),
                                    child: SizedBox(
                                      width: 44,
                                      height: 32,
                                      child: Center(
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          width: _currentIndex == index
                                              ? 18
                                              : 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(
                                                  alpha: _currentIndex == index
                                                      ? 0.85
                                                      : 0.2,
                                                ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            // Compact panels keep actions in reach, with room for larger text.
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final cardHeight =
                (constraints.maxWidth * 368 / 390).clamp(300.0, 368.0) *
                (textScale < 1 ? 1 : textScale);
            return SnapFitFadeIn(
              delay: const Duration(milliseconds: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Static Card Frame (Layout does not move)
                  Container(
                    height: cardHeight,
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.grey[200],
                      boxShadow: [
                        // Softer, more diffused shadow
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Stack(
                        children: [
                          // Swipeable Content (Image changes)
                          PageView.builder(
                            controller: _pageController,
                            itemCount: visibleTemplates.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final template = visibleTemplates[index];
                              final previewUrl = _coverPreviewUrl(template);
                              final parsed =
                                  isPublishedCreationTemplate(template)
                                  ? null
                                  : _parseFirstPage(template);
                              return SnapFitPressable(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    snapFitRoute(page: TemplateDetailScreen(
                                        template: template,
                                      )),
                                  );
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (isPublishedCreationTemplate(template))
                                      CreationCatalogCover(template: template)
                                    else if (previewUrl.isNotEmpty)
                                      _buildCoverImage(context, previewUrl)
                                    else if (parsed != null)
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final aspect = parsed.$2;
                                          final maxHeight =
                                              constraints.maxHeight;
                                          final drawWidth = maxHeight * aspect;
                                          return Center(
                                            child: SizedBox(
                                              width: drawWidth,
                                              height: maxHeight,
                                              child: TemplatePageRenderer(
                                                layers: parsed.$1,
                                                width: drawWidth,
                                                height: maxHeight,
                                                designCanvasSize: parsed.$3,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      const TemplatePaperPlaceholder(),
                                    _ShowcaseMiniPeek(template: template),
                                    // Premium Gradient Overlay (Deep and smooth)
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                            Colors.black.withValues(
                                              alpha: 0.30,
                                            ),
                                            Colors.black.withValues(
                                              alpha: 0.76,
                                            ),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          stops: const [0.0, 0.48, 1.0],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 16,
                                      top: 16,
                                      child: PointShopProductBadge(
                                        productKey: pointShopTemplateKey(
                                          template,
                                        ),
                                      ),
                                    ),
                                    // Content Text
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 24,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          StoreProductBadge(
                                            productKey: pointShopTemplateKey(
                                              template,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            template.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 25,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              height: 1.15,
                                              letterSpacing: -0.5,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.38),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          if (template.subTitle != null)
                                            Text(
                                              template.subTitle!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white.withValues(
                                                  alpha: 0.88,
                                                ),
                                                fontWeight: FontWeight.w500,
                                                height: 1.35,
                                                letterSpacing: 0,
                                              ),
                                            ),
                                          SizedBox(height: 14),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Wrap(
                                                  spacing: 7,
                                                  runSpacing: 6,
                                                  children: [
                                                    _ShowcaseMetaPill(
                                                      label:
                                                          template.category ??
                                                          '포토북',
                                                    ),
                                                    _ShowcaseMetaPill(
                                                      label:
                                                          '${template.pageCount}쪽',
                                                    ),
                                                    _ShowcaseMetaPill(
                                                      label:
                                                          '사진 ${_recommendedPhotoRange(template)}',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              const _ShowcaseCtaPill(),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          // Dots Indicator (Top Center)
                          Positioned(
                            top: 18,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    visibleTemplates.length,
                                    (index) => AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      margin: EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      width: _currentIndex == index ? 18 : 5,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _currentIndex == index
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => Container(
        height: 400,
        margin: EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
      error: (err, stack) => SizedBox(
        height: 100,
        child: Center(child: Text('템플릿을 불러올 수 없습니다.')), // Simple error message
      ),
    );
  }
}

class _ShowcaseMiniPeek extends StatelessWidget {
  const _ShowcaseMiniPeek({required this.template});

  final PremiumTemplate template;

  @override
  Widget build(BuildContext context) {
    final urls = template.previewImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .skip(1)
        .take(2)
        .toList(growable: false);
    if (urls.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 74,
      right: 20,
      child: SizedBox(
        width: 112,
        height: 128,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < urls.length; i++)
              Positioned(
                right: (i * 38).toDouble(),
                top: (i * 12).toDouble(),
                child: Transform.rotate(
                  angle: i == 0 ? 0.06 : -0.08,
                  child: SizedBox(
                    width: 58,
                    height: 82,
                    child: TemplatePreviewFrame(
                      borderRadius: 16,
                      padding: EdgeInsets.all(3),
                      showShadow: true,
                      child: _ShowcaseMiniImage(url: urls[i]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShowcaseMiniImage extends StatelessWidget {
  const _ShowcaseMiniImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final bundledAsset = bundledTemplateAssetPath(url);
    if (bundledAsset != null) {
      return Image.asset(bundledAsset, fit: BoxFit.cover);
    }
    final transformed = imageUrlByVariant(url, variant: ImageVariant.thumb);
    if (transformed.startsWith('asset:')) {
      return Image.asset(
        transformed.substring('asset:'.length),
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      transformed,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const TemplatePaperPlaceholder(compact: true),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const TemplatePaperPlaceholder(compact: true),
    );
  }
}

class _ShowcaseCtaPill extends StatelessWidget {
  const _ShowcaseCtaPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '룩북 보기',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: 3),
          const ExperienceIcon('ChevronRight', size: 15, color: Color(0xFF1F2937),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseMetaPill extends StatelessWidget {
  final String label;

  const _ShowcaseMetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

(List<LayerModel>, double, Size)? _parseFirstPage(PremiumTemplate template) {
  final raw = template.templateJson;
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final metadata =
        (data['metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pages = data['pages'];
    if (pages is! List || pages.isEmpty) return null;
    final page = pages.first;
    if (page is! Map<String, dynamic>) return null;
    final layersJson = page['layers'];
    if (layersJson is! List || layersJson.isEmpty) return null;

    final designWidth =
        (data['designWidth'] as num?)?.toDouble() ??
        (metadata['designWidth'] as num?)?.toDouble() ??
        1080.0;
    final designHeight =
        (data['designHeight'] as num?)?.toDouble() ??
        (metadata['designHeight'] as num?)?.toDouble() ??
        1440.0;
    final canvasSize = Size(designWidth, designHeight);
    final layers = layersJson
        .whereType<Map<String, dynamic>>()
        .map(
          (layer) => LayerExportMapper.fromJson(layer, canvasSize: canvasSize),
        )
        .toList(growable: false);
    if (layers.isEmpty) return null;
    final aspect = (designWidth / designHeight).clamp(0.6, 1.8);
    return (layers, aspect, canvasSize);
  } catch (_) {
    return null;
  }
}

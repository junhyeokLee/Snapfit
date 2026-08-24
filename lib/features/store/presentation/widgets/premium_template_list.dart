import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../../domain/entities/premium_template.dart';
import '../views/template_detail_screen.dart';
import 'template_page_renderer.dart';
import 'template_preview_frame.dart';
import '../../data/api/template_provider.dart';

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
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templateListProvider);

    return templatesAsync.when(
      data: (templates) {
        if (templates.isEmpty) return const SizedBox.shrink();
        final visibleTemplates = widget.maxItems == null
            ? templates
            : templates.take(widget.maxItems!).toList();
        if (visibleTemplates.isEmpty) return const SizedBox.shrink();

        return SnapFitFadeIn(
          delay: const Duration(milliseconds: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Static Card Frame (Layout does not move)
              Container(
                height: 376.h,
                margin: EdgeInsets.symmetric(horizontal: 20.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30.r),
                  color: Colors.grey[200],
                  boxShadow: [
                    // Softer, more diffused shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32.r),
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
                          final parsed = _parseFirstPage(template);
                          return SnapFitPressable(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TemplateDetailScreen(template: template),
                                ),
                              );
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (previewUrl.isNotEmpty)
                                  _buildCoverImage(context, previewUrl)
                                else if (parsed != null)
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final aspect = parsed.$2;
                                      final maxHeight = constraints.maxHeight;
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
                                        Colors.black.withOpacity(0.0),
                                        Colors.black.withOpacity(0.06),
                                        Colors.black.withOpacity(0.62),
                                      ],
                                      begin: Alignment.center,
                                      end: Alignment.bottomCenter,
                                      stops: const [0.0, 0.62, 1.0],
                                    ),
                                  ),
                                ),
                                // Content Text
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24.w,
                                    vertical: 24.h,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (template.isBest)
                                        Container(
                                          margin: EdgeInsets.only(bottom: 12.h),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 14.w,
                                            vertical: 6.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF22D3EE,
                                            ), // Cyan-400 equivalent
                                            borderRadius: BorderRadius.circular(
                                              100.r,
                                            ),
                                          ),
                                          child: Text(
                                            '이달의 추천',
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        template.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 27.sp,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 1.15,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      if (template.subTitle != null)
                                        Text(
                                          template.subTitle!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            color: Colors.white.withOpacity(
                                              0.78,
                                            ),
                                            fontWeight: FontWeight.w500,
                                            height: 1.35,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                      SizedBox(height: 14.h),
                                      Wrap(
                                        spacing: 7.w,
                                        runSpacing: 6.h,
                                        children: [
                                          _ShowcaseMetaPill(
                                            label: template.category ?? '포토북',
                                          ),
                                          _ShowcaseMetaPill(
                                            label: '${template.pageCount}페이지',
                                          ),
                                          if (template.isPremium)
                                            const _ShowcaseMetaPill(
                                              label: 'Premium',
                                            ),
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
                        top: 24.h,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            visibleTemplates.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.symmetric(horizontal: 4.w),
                              width: _currentIndex == index ? 24.w : 6.w,
                              height: 6.h,
                              decoration: BoxDecoration(
                                color: _currentIndex == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(3.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
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
      loading: () => Container(
        height: 400.h,
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
      error: (err, stack) => SizedBox(
        height: 100.h,
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
      top: 74.h,
      right: 20.w,
      child: SizedBox(
        width: 112.w,
        height: 128.h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < urls.length; i++)
              Positioned(
                right: (i * 38).w,
                top: (i * 12).h,
                child: Transform.rotate(
                  angle: i == 0 ? 0.06 : -0.08,
                  child: SizedBox(
                    width: 58.w,
                    height: 82.h,
                    child: TemplatePreviewFrame(
                      borderRadius: 16,
                      padding: EdgeInsets.all(3.w),
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

class _ShowcaseMetaPill extends StatelessWidget {
  final String label;

  const _ShowcaseMetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.88),
          fontSize: 11.sp,
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

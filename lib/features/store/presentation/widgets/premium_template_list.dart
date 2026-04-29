import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../../domain/entities/premium_template.dart';
import '../views/template_detail_screen.dart';
import 'template_page_renderer.dart';
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
      return _fallbackCover();
    }
    final bundledAsset = bundledTemplateAssetPath(rawUrl);
    if (bundledAsset != null) {
      return Image.asset(
        bundledAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackCover(),
      );
    }
    final transformed = imageUrlByVariant(rawUrl, variant: ImageVariant.thumb);
    if (transformed.startsWith('asset:')) {
      return Image.asset(
        transformed.substring('asset:'.length),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackCover(),
      );
    }
    return Image.network(
      transformed,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.white,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _fallbackCover(),
    );
  }

  Widget _fallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7EDF4), Color(0xFFD8E3F0)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.photo_outlined, color: Color(0xFF7A8AA0)),
      ),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Static Card Frame (Layout does not move)
            Container(
              height: 400.h, // Adjusted height for better balance (was 480.h)
              margin: EdgeInsets.symmetric(horizontal: 20.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  32.r,
                ), // More rounded corners
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
                        return GestureDetector(
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
                                _fallbackCover(),
                              // Premium Gradient Overlay (Deep and smooth)
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.0),
                                      Colors.black.withOpacity(0.2),
                                      Colors.black.withOpacity(0.8),
                                    ],
                                    begin: Alignment
                                        .center, // Start slightly lower
                                    end: Alignment.bottomCenter,
                                    stops: const [0.0, 0.4, 1.0],
                                  ),
                                ),
                              ),
                              // Content Text
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24.w,
                                  vertical: 32.h,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                          'MONTHLY BEST',
                                          style: TextStyle(
                                            fontSize: 10.sp,
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
                                        fontSize: 34.sp, // Large, clean font
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1.15,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    if (template.subTitle != null)
                                      Text(
                                        template.subTitle!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.white.withOpacity(0.7),
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0,
                                        ),
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
                            duration: const Duration(milliseconds: 300),
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

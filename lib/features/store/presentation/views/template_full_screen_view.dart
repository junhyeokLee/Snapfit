import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../album/domain/entities/layer.dart';
import '../widgets/template_page_renderer.dart';

class TemplateFullScreenView extends StatefulWidget {
  final List<List<LayerModel>> parsedPages;
  final List<String> previewImages; // Fallback
  final int initialIndex;
  final Size designCanvasSize;

  const TemplateFullScreenView({
    super.key,
    required this.parsedPages,
    required this.previewImages,
    this.initialIndex = 0,
    this.designCanvasSize = const Size(3, 4),
  });

  @override
  State<TemplateFullScreenView> createState() => _TemplateFullScreenViewState();
}

class _TemplateFullScreenViewState extends State<TemplateFullScreenView> {
  late PageController _pageController;
  late int _currentIndex;

  Color? _parseHexColor(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    var hex = value.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  Color _inferredTemplateSurfaceColor(List<LayerModel>? layers) {
    if (layers == null || layers.isEmpty) {
      return Colors.white;
    }

    final canvasW = widget.designCanvasSize.width <= 0
        ? 1.0
        : widget.designCanvasSize.width;
    final canvasH = widget.designCanvasSize.height <= 0
        ? 1.0
        : widget.designCanvasSize.height;

    LayerModel? best;
    double bestScore = -1;

    for (final layer in layers) {
      if (layer.type != LayerType.decoration) continue;
      final fill = _parseHexColor(layer.decorationFillColor);
      if (fill == null || fill.opacity <= 0.02) continue;

      final areaScore = (layer.width * layer.height) / (canvasW * canvasH);
      if (areaScore < 0.82) continue;
      final zBonus = (1000 - layer.zIndex).clamp(0, 1000) / 1000.0;
      final score = areaScore * 10 + zBonus;
      if (score > bestScore) {
        best = layer;
        bestScore = score;
      }
    }

    return _parseHexColor(best?.decorationFillColor) ?? Colors.white;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Total pages is max of parsed or preview
    final totalCount = widget.parsedPages.isNotEmpty
        ? widget.parsedPages.length
        : widget.previewImages.length;

    final safeAspect = widget.designCanvasSize.height > 0
        ? (widget.designCanvasSize.width / widget.designCanvasSize.height)
              .clamp(0.6, 1.8)
        : 0.75;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: totalCount,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return Center(
                child: AspectRatio(
                  aspectRatio: safeAspect,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Render Parsed Page
                        if (index < widget.parsedPages.length) {
                          return ColoredBox(
                            color: _inferredTemplateSurfaceColor(
                              widget.parsedPages[index],
                            ),
                            child: TemplatePageRenderer(
                              layers: widget.parsedPages[index],
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              designCanvasSize: widget.designCanvasSize,
                            ),
                          );
                        }
                        // Fallback Image
                        if (index < widget.previewImages.length) {
                          return Image.network(
                            imageUrlByVariant(
                              widget.previewImages[index],
                              variant: ImageVariant.detail,
                            ),
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: SnapFitColors.deepCharcoal,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.photo_outlined,
                                color: SnapFitStylePalette.charcoal,
                                size: 36,
                              ),
                            ),
                          );
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // Close Button
          Positioned(
            top: 60.h,
            right: 20.w,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),

          // Page Indicator
          Positioned(
            bottom: 40.h,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '${_currentIndex + 1} / $totalCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

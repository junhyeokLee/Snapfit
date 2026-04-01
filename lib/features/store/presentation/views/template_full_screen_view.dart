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

  const TemplateFullScreenView({
    super.key,
    required this.parsedPages,
    required this.previewImages,
    this.initialIndex = 0,
  });

  @override
  State<TemplateFullScreenView> createState() => _TemplateFullScreenViewState();
}

class _TemplateFullScreenViewState extends State<TemplateFullScreenView> {
  late PageController _pageController;
  late int _currentIndex;

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
                  aspectRatio: 1.0, // Assuming 1:1 or dynamic?
                  // Let's use fitting box
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Render Parsed Page
                        if (index < widget.parsedPages.length) {
                          return TemplatePageRenderer(
                            layers: widget.parsedPages[index],
                            width: constraints.maxWidth,
                            height: constraints
                                .maxWidth, // 1:1 ratio forced for now
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

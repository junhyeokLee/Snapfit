import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/premium_template.dart';
import '../views/template_detail_screen.dart';
import '../../data/api/template_provider.dart';

class PremiumTemplateList extends ConsumerStatefulWidget {
  const PremiumTemplateList({super.key});

  @override
  ConsumerState<PremiumTemplateList> createState() =>
      _PremiumTemplateListState();
}

class _PremiumTemplateListState extends ConsumerState<PremiumTemplateList> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

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
                      itemCount: templates.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final template = templates[index];
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
                              // Background Image
                              Image.network(
                                template.coverImageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey[300],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.error),
                                  );
                                },
                              ),
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
                          templates.length,
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

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../album/presentation/widgets/home/section_header.dart';
import '../../domain/entities/premium_template.dart';
import '../views/template_detail_screen.dart';

class PremiumTemplateList extends StatefulWidget {
  const PremiumTemplateList({super.key});

  @override
  State<PremiumTemplateList> createState() => _PremiumTemplateListState();
}

class _PremiumTemplateListState extends State<PremiumTemplateList> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // Dummy Data
  final List<PremiumTemplate> templates = [
    const PremiumTemplate(
      id: '1',
      title: '우리들의\n여름 제주',
      subTitle: '푸른 바다와 돌담길, 우리의 소중한 기록을 감성적인 레이아웃에 담아보세요.',
      dateRange: '2024.07.12 — 2024.07.15',
      coverImageUrl: 'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?ixlib=rb-4.0.3&auto=format&fit=crop&w=1740&q=80',
      previewImages: [],
      pageCount: 24,
      userCount: 1248,
      description: '제주 여행의 감성을 담은 프리미엄 템플릿입니다.',
      isBest: true,
    ),
    const PremiumTemplate(
      id: '2',
      title: '성수동\n카페 투어',
      subTitle: '힙한 성수동의 모든 것',
      dateRange: '2024.09.21 — 2024.09.22',
      coverImageUrl: 'https://images.unsplash.com/photo-1521017432531-fbd92d768814?ixlib=rb-4.0.3&auto=format&fit=crop&w=1740&q=80',
      previewImages: [],
      pageCount: 12,
      userCount: 856,
      description: '감각적인 카페 사진을 위한 레이아웃.',
      isBest: false,
    ),
    const PremiumTemplate(
      id: '3',
      title: '우리의\n결혼 1주년',
      subTitle: '가장 행복했던 순간들을 영원히',
      dateRange: '2023.10.25',
      coverImageUrl: 'https://images.unsplash.com/photo-1515934751635-c81c6bc9a2d8?ixlib=rb-4.0.3&auto=format&fit=crop&w=1740&q=80',
      previewImages: [],
      pageCount: 36,
      userCount: 210,
      description: '로맨틱한 분위기의 웨딩 앨범 템플릿.',
      isBest: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Static Card Frame (Layout does not move)
        Container(
          height: 400.h, // Adjusted height for better balance (was 480.h)
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32.r), // More rounded corners
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
                            builder: (_) => TemplateDetailScreen(template: template),
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
                                begin: Alignment.center, // Start slightly lower
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.4, 1.0], 
                              ),
                            ),
                          ),
                          // Content Text
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (template.isBest)
                                  Container(
                                    margin: EdgeInsets.only(bottom: 12.h),
                                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22D3EE), // Cyan-400 equivalent
                                      borderRadius: BorderRadius.circular(100.r),
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
                                Text(
                                  template.dateRange,
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
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Assuming svg is used or remove if not available
import '../../../../core/constants/snapfit_colors.dart';
import '../../domain/entities/premium_template.dart';

class TemplateDetailScreen extends StatelessWidget {
  final PremiumTemplate template;

  const TemplateDetailScreen({
    super.key,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Custom App Bar using SliverAppBar or just a SliverToBoxAdapter for content
              // Using SliverList for scrolling content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 60.h), // Top padding
                    // Header
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back_ios_new, size: 20),
                            ),
                          ),
                          Text(
                            '템플릿 상세',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.share_outlined, size: 20),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30.h),
                    
                    // Main Hero Image (Card UI reused larged)
                    _buildHeroImage(),
                    
                    SizedBox(height: 40.h),
                    
                    // "Start with this template" Section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        children: [
                          Text(
                            '이 템플릿으로 시작하기',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            template.subTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: const Color(0xFF666666),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 40.h),
                    
                    // Feature Cards
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        children: [
                          Expanded(child: _buildFeatureCard(Icons.photo_library_outlined, '제주 전용 레이아웃', '여행지 감성에 맞춘 스티커와 프레임이 포함되어 있습니다.')),
                          SizedBox(width: 16.w),
                          Expanded(child: _buildFeatureCard(Icons.people_outline, '5인 협업 최적화', '가족, 친구들과 함께 각자의 페이지를 동시에 편집하세요.')),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 50.h),
                    
                    // Page Previews
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '페이지 미리보기',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '총 ${template.pageCount}페이지',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: SnapFitColors.accent, // Using primary color for link-like look
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    SizedBox(
                      height: 240.h,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        scrollDirection: Axis.horizontal,
                        itemCount: 3, // Mock count
                        separatorBuilder: (_, __) => SizedBox(width: 16.w),
                        itemBuilder: (context, index) => _buildPagePreviewPlaceholder(index),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12.h),
                        child: Text(
                          '표지 및 프롤로그',
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 40.h),
                    
                    // User Count Badge
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 20.w),
                      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF8F9),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Row(
                        children: [
                          // Mock Avatar Group
                          SizedBox(
                            width: 60.w,
                            height: 30.w,
                            child: Stack(
                              children: [
                                _avatar(0, Colors.grey[300]!),
                                _avatar(18.w, Colors.grey[400]!),
                                _avatar(36.w, Colors.grey[500]!),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: const Color(0xFF555555),
                              ),
                              children: [
                                const TextSpan(text: '현재 '),
                                TextSpan(
                                  text: '${template.userCount}명',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: SnapFitColors.accent,
                                  ),
                                ),
                                const TextSpan(text: '이 이 템플릿으로 제작 중입니다.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 120.h), // Bottom padding for fixed button
                  ],
                ),
              ),
            ],
          ),
          
          // Fixed Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20.w, 
                right: 20.w, 
                top: 20.h, 
                bottom: MediaQuery.of(context).padding.bottom + 20.h
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_border, color: Colors.grey),
                      SizedBox(height: 4.h),
                      Text('241', style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                    ],
                  ),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SnapFitColors.accent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '이 템플릿 사용하기',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          const Icon(Icons.arrow_forward, size: 20),
                        ],
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
  }

  Widget _buildHeroImage() {
    return Center(
      child: Container(
        width: 320.w,
        height: 380.h, // Larger hero
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: const Color(0xFFE5DCD0), // Fallback
          image: DecorationImage(
            image: NetworkImage(template.coverImageUrl),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
           children: [
             if (template.isBest || template.isPremium)
              Positioned(
                top: 24.h,
                left: 24.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C7D8),
                    borderRadius: BorderRadius.circular(100.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'PREMIUM',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
             Positioned(
               bottom: 24.h,
               left: 24.w,
               right: 24.w,
               child: Text(
                template.title.replaceAll(' ', ' '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Assuming dark image or overlay
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
               ),
             ),
           ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc) {
    return Container(
      padding: EdgeInsets.all(24.w),
      height: 180.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
             padding: EdgeInsets.all(10.w),
             decoration: BoxDecoration(
               color: const Color(0xFFEBF8F9), // Light Cyan
               shape: BoxShape.circle,
             ),
             child: Icon(icon, color: SnapFitColors.accent, size: 24.sp),
           ),
           SizedBox(height: 16.h),
           Text(
             title,
             style: TextStyle(
               fontSize: 15.sp,
               fontWeight: FontWeight.bold,
               color: const Color(0xFF1A1A1A),
             ),
           ),
           SizedBox(height: 8.h),
           Text(
             desc,
             style: TextStyle(
               fontSize: 12.sp,
               color: const Color(0xFF888888),
               height: 1.4,
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildPagePreviewPlaceholder(int index) {
    return Container(
      width: 180.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Center(
        child: Container(
          width: 140.w,
          height: 200.h,
          decoration: BoxDecoration(
            border: Border.all(color: SnapFitColors.accent.withOpacity(0.3), width: 1.5),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: index == 0 ? Center(
              child: Icon(Icons.add_a_photo_outlined, color: SnapFitColors.accent.withOpacity(0.5))
          ) : null, // Placeholder dashed look simulated
        ),
      ),
    );
  }

  Widget _avatar(double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 30.w,
        height: 30.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(Icons.person, color: Colors.white, size: 16.sp),
      ),
    );
  }
}

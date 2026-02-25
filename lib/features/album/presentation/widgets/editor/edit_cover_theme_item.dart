import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../shared/widgets/spine_painter.dart';
import '../../../../../core/constants/cover_theme.dart';

class EditCoverThemeItem extends StatelessWidget {
  final CoverTheme theme;
  final bool isSelected;
  final double width;
  final double height;
  final VoidCallback onTap;

  const EditCoverThemeItem({
    super.key,
    required this.theme,
    required this.isSelected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double miniLeftSpine = 8.0;
    const double miniRightRadius = 4.0;
    const double miniBottomRadius = 4.0;

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: isSelected ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            transform: isSelected
                ? (Matrix4.identity()..translate(0.0, -6.h))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12.r),
                bottomRight: Radius.circular(12.r),
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4.r,
                  offset: Offset(5.w, 20.h),
                ),
              ]
                  : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4.r,
                  offset: Offset(4.w, 8.h),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(miniRightRadius.r),
                bottomRight: Radius.circular(miniBottomRadius.r),
              ),
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 커버 이미지 or 그라데이션
                    Container(
                      decoration: BoxDecoration(
                        image: theme.imageAsset != null
                            ? DecorationImage(
                          image: AssetImage(theme.imageAsset!),
                          fit: BoxFit.cover,
                        )
                            : null,
                        gradient: theme.imageAsset == null ? theme.gradient : null,
                      ),
                    ),
                    // 왼쪽 봉제선
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CustomPaint(
                        painter: SpinePainter(
                          baseStart: Colors.white.withValues(alpha: 0.05),
                          baseEnd: Colors.white.withValues(alpha: 0.05),
                        ),
                        size: Size(miniLeftSpine.w, double.infinity),
                      ),
                    ),
                    // 라벨
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 6.h),
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          theme.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

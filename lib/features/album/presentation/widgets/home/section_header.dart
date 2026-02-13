import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    color: SnapFitColors.textPrimaryOf(context),
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 6.h),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: SnapFitColors.textSecondaryOf(context).withOpacity(0.6),
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onViewAll != null)
            Padding(
              padding: EdgeInsets.only(bottom: 4.h), // Align slightly with title baseline
              child: GestureDetector(
                onTap: onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '전체보기',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFF00C2E0), // Accent color from mockup
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 10.sp,
                      color: const Color(0xFF00C2E0),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

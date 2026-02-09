import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// 바텀 네비게이션 플레이스홀더
class HomeBottomNavPlaceholder extends StatelessWidget {
  final String label;

  const HomeBottomNavPlaceholder({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SnapFitColors.backgroundOf(context),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 40.sp,
                color: SnapFitColors.textMutedOf(context),
              ),
              SizedBox(height: 12.h),
              Text(
                "$label 준비중이에요",
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: SnapFitColors.textPrimaryOf(context).withOpacity(0.85),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                "조금만 기다려 주세요",
                style: TextStyle(
                  fontSize: 12.sp,
                  color: SnapFitColors.textMutedOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

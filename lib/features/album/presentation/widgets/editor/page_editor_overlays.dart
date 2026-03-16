import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// 앨범 저장 중 진행률 오버레이
class PageEditorSaveOverlay extends StatelessWidget {
  final double progress;

  const PageEditorSaveOverlay({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SnapFitColors.overlayStrongOf(context),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              color: SnapFitColors.accent,
              backgroundColor: Colors.white24,
            ),
            SizedBox(height: 20.h),
            Text(
              '저장 중... ${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 앨범 준비 중(백그라운드 생성) 오버레이
class PageEditorPreparingOverlay extends StatelessWidget {
  const PageEditorPreparingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SnapFitColors.backgroundOf(context),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              color: SnapFitColors.accent,
            ),
            SizedBox(height: 24.h),
            Text(
              '앨범을 준비하고 있습니다...',
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '잠시만 기다려주세요.',
              style: TextStyle(
                color: SnapFitColors.textSecondaryOf(context),
                fontSize: 14.sp,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';

/// 앨범 저장 중 진행률 오버레이
class PageEditorSaveOverlay extends StatelessWidget {
  final double progress;

  const PageEditorSaveOverlay({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SnapFitFadeIn(
      duration: const Duration(milliseconds: 220),
      child: Container(
        color: Colors.black.withOpacity(0.42),
        child: Center(
          child: _EditorProgressCard(
            title: '포토북을 저장하고 있어요',
            subcopy: '사진과 페이지를 안전하게 정리 중입니다.',
            progress: progress,
            showPercent: true,
          ),
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
    return SnapFitFadeIn(
      duration: const Duration(milliseconds: 220),
      child: Container(
        color: SnapFitColors.backgroundOf(context).withOpacity(0.96),
        child: const Center(
          child: _EditorProgressCard(
            title: '앨범을 펼치는 중이에요',
            subcopy: '선택한 템플릿을 페이지에 맞추고 있어요.',
            progress: null,
            showPercent: false,
          ),
        ),
      ),
    );
  }
}

class _EditorProgressCard extends StatelessWidget {
  const _EditorProgressCard({
    required this.title,
    required this.subcopy,
    required this.progress,
    required this.showPercent,
  });

  final String title;
  final String subcopy;
  final double? progress;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final percent = ((progress ?? 0) * 100).round().clamp(0, 100);
    return Container(
      width: 246.w,
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 22.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              SnapFitColors.isDark(context) ? 0.34 : 0.16,
            ),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48.w,
            height: 48.w,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              color: SnapFitColors.accent,
              backgroundColor: SnapFitColors.accent.withOpacity(0.14),
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
              decoration: TextDecoration.none,
            ),
          ),
          if (showPercent) ...[
            SizedBox(height: 8.h),
            Text(
              '$percent%',
              style: TextStyle(
                color: SnapFitColors.accent,
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          SizedBox(height: 8.h),
          Text(
            subcopy,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SnapFitColors.textSecondaryOf(context),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              height: 1.45,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

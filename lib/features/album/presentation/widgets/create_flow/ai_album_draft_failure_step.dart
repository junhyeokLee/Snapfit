import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';

class AiAlbumDraftFailureStep extends StatelessWidget {
  const AiAlbumDraftFailureStep({
    super.key,
    this.title = '초안을 만들지 못했어요',
    required this.message,
    this.primaryActionLabel = '사진 범위 다시 고르기',
    required this.onRetryRange,
    required this.onManualStart,
  });

  final String title;
  final String message;
  final String primaryActionLabel;
  final VoidCallback onRetryRange;
  final VoidCallback onManualStart;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final background = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFFAF8F3);

    return ColoredBox(
      color: background,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 20.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1A17) : Colors.white,
                  borderRadius: BorderRadius.circular(26.r),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.10)
                        : const Color(0xFFE7E1D8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NoChargeBadge(isDark: isDark),
                    SizedBox(height: 16.h),
                    Text(
                      title,
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 22.sp,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    SizedBox(height: 9.h),
                    Text(
                      message,
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: 13.5.sp,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      '기기 안에서만 확인해요. 사진은 업로드하지 않았어요.',
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: 12.5.sp,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '포인트는 차감되지 않았어요.',
                      style: TextStyle(
                        color: const Color(0xFF4C6A55),
                        fontSize: 13.sp,
                        height: 1.35,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: onRetryRange,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: isDark
                        ? const Color(0xFFF4F1EA)
                        : const Color(0xFF1F1F1D),
                    foregroundColor: isDark
                        ? const Color(0xFF111111)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17.r),
                    ),
                  ),
                  child: Text(
                    primaryActionLabel,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: OutlinedButton(
                  onPressed: onManualStart,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SnapFitColors.textPrimaryOf(context),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.16)
                          : const Color(0xFFE0D7CA),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    '직접 구성하기',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoChargeBadge extends StatelessWidget {
  const _NoChargeBadge({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F4EC),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        '차감 없음',
        style: TextStyle(
          color: const Color(0xFF4C6A55),
          fontSize: 11.5.sp,
          height: 1.1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

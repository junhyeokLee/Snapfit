import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/snapfit_colors.dart';
import 'snapfit_primary_gradient_background.dart';

/// 스냅핏 디자인 시스템 기준 Primary Action 버튼
///
/// - Primary Gradient 배경 (Cyan → Violet)
/// - 둥근 모서리 14
/// - 다크/라이트 공통 사용
class SnapFitPrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const SnapFitPrimaryActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;
    final effectiveOnPressed = enabled ? onPressed : null;

    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            gradient: enabled
                ? const LinearGradient(
                    colors: SnapFitColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      SnapFitColors.overlayMediumOf(context),
                      SnapFitColors.overlayLightOf(context),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        SnapFitColors.pureWhite,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ] else if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20.sp,
                    color: enabled
                        ? SnapFitColors.pureWhite
                        : SnapFitColors.textSecondaryOf(context),
                  ),
                  SizedBox(width: 8.w),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? SnapFitColors.pureWhite
                        : SnapFitColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


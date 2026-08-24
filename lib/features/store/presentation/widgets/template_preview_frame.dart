import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';

class TemplatePreviewFrame extends StatelessWidget {
  const TemplatePreviewFrame({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.showShadow = true,
    this.showPageEdge = true,
  });

  final Widget child;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool showShadow;
  final bool showPageEdge;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final radius = BorderRadius.circular((borderRadius ?? 24).r);
    return Container(
      padding: padding ?? EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFFFFDF8),
        borderRadius: radius,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.36 : 0.10),
                  blurRadius: isDark ? 34 : 28,
                  offset: Offset(0, isDark ? 16 : 12),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          ((borderRadius ?? 24) - 5).clamp(8, 26).r,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(isDark ? 0.06 : 0.28),
                      Colors.transparent,
                      Colors.black.withOpacity(isDark ? 0.08 : 0.03),
                    ],
                    stops: const [0.0, 0.34, 1.0],
                  ),
                ),
              ),
            ),
            if (showPageEdge)
              Positioned(
                top: 8.h,
                right: 4.w,
                bottom: 8.h,
                child: Container(
                  width: 2.w,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TemplatePaperPlaceholder extends StatelessWidget {
  const TemplatePaperPlaceholder({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF5E8), Color(0xFFEAFBFD), Color(0xFFFFFDF8)],
        ),
      ),
      child: Center(
        child: Container(
          width: compact ? 42.w : 74.w,
          height: compact ? 52.h : 92.h,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.44),
            borderRadius: BorderRadius.circular(compact ? 12.r : 18.r),
            border: Border.all(
              color: SnapFitColors.deepCharcoal.withOpacity(0.10),
            ),
          ),
          child: Icon(
            Icons.photo_size_select_actual_outlined,
            size: compact ? 16.sp : 24.sp,
            color: SnapFitColors.deepCharcoal.withOpacity(0.34),
          ),
        ),
      ),
    );
  }
}

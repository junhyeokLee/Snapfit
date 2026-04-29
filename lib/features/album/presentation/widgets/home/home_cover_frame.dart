import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const _coverRadius = BorderRadius.only(
  topRight: Radius.circular(12),
  bottomRight: Radius.circular(12),
  bottomLeft: Radius.zero,
);

/// 커버 프레임
class HomeCoverFrame extends StatelessWidget {
  final double width;
  final double height;
  final double shadowScale;
  final bool showShadow;
  final Widget child;

  const HomeCoverFrame({
    super.key,
    required this.width,
    required this.height,
    required this.shadowScale,
    required this.showShadow,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final clampedShadowScale = shadowScale.clamp(0.35, 10.0);

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: _coverRadius,
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 20,
                    spreadRadius: clampedShadowScale,
                    offset: Offset(
                      6 * clampedShadowScale,
                      14 * clampedShadowScale,
                    ),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(borderRadius: _coverRadius, child: child),
      ),
    );
  }
}

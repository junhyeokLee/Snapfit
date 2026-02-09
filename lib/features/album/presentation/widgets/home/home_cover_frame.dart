import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'home_focus_wrap.dart';

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
              ? HomeFocusWrap.coverStyleShadowForScale(shadowScale, 0.5)
              : null,
        ),
        child: ClipRRect(
          borderRadius: _coverRadius,
          child: child,
        ),
      ),
    );
  }
}

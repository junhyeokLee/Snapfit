import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// 아바타 점
class HomeAvatarDot extends StatelessWidget {
  const HomeAvatarDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        color: SnapFitColors.overlayLightOf(context),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'A',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ),
    );
  }
}

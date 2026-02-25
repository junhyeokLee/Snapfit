import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

class DecorateFrameTab extends StatelessWidget {
  final Color surfaceColor;

  const DecorateFrameTab({super.key, required this.surfaceColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "프레임 스타일 준비 중",
        style: TextStyle(color: SnapFitColors.textSecondaryOf(context), fontSize: 14.sp),
      ),
    );
  }
}

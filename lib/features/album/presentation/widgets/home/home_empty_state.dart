import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// 홈 화면 빈 상태
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '앨범이 비어있습니다.',
        style: TextStyle(
          fontSize: 18.sp,
          color: SnapFitColors.textPrimaryOf(context).withOpacity(0.9),
        ),
      ),
    );
  }
}

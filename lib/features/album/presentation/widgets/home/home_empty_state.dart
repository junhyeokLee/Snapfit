import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';

/// 홈 화면 빈 상태
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeEmptyState', '홈 빈 상태 · 앨범 없음');
    }
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

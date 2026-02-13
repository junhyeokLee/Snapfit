import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';

/// 홈 화면 빈 상태
class HomeEmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const HomeEmptyState({
    super.key,
    required this.onCreate,
  });

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeEmptyState', '홈 빈 상태 · 프리미엄 디자인');
    }

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        height: 600.w, // Sufficient height for centering
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium Illustration
            Image.asset(
              'assets/empty_state.png',
              width: 320.w,
              height: 320.w,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 12.w),
            // Title
            Text(
              '함께 만드는 우리만의 앨범',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textPrimaryOf(context),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 12.w),
            // Description
            Text(
              '아직 참여 중인 앨범이 없습니다.\n지금 바로 첫 번째 앨범을 만들어보세요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                color: SnapFitColors.textSecondaryOf(context),
                height: 1.5,
              ),
            ),
            SizedBox(height: 48.w),
            // CTA Button
            SizedBox(
              width: double.infinity,
              height: 56.w,
              child: ElevatedButton(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SnapFitColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 24.w),
                    SizedBox(width: 8.w),
                    Text(
                      '첫 앨범 만들기',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

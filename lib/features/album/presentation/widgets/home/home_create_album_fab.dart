import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';

/// 홈 화면 우측 하단 새 앨범 버튼
class HomeCreateAlbumFab extends StatelessWidget {
  final VoidCallback onPressed;

  const HomeCreateAlbumFab({super.key, required this.onPressed});

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeCreateAlbumFab', '앨범 만들기 FAB');
    }
    return SizedBox(
      width: 58.w,
      height: 58.w,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SnapFitColors.accent,
          border: Border.all(
            color: SnapFitColors.pureWhite.withOpacity(0.28),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(
              child: Icon(
                Icons.add_rounded,
                color: SnapFitColors.pureWhite,
                size: 30.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

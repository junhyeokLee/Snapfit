import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import 'home_icon_buttons.dart';
import 'home_avatar_dot.dart';

/// 홈 화면 상단 헤더 (제목 + 아이콘)
class HomeHeader extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onNotification;

  const HomeHeader({
    super.key,
    required this.onSearch,
    required this.onNotification,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: [
            Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: SnapFitColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.photo_album_outlined,
                size: 18.sp,
                color: SnapFitColors.accentLight,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              'SnapFit',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
        const Spacer(),
        HomeRoundIconButton(icon: Icons.search, onTap: onSearch),
        SizedBox(width: 10.w),
        HomeRoundIconButton(icon: Icons.notifications_none, onTap: onNotification),
        SizedBox(width: 10.w),
        const HomeAvatarDot(),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';

/// 홈 화면 하단 네비게이션 바
class HomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hasUnreadNotification;

  const HomeBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.hasUnreadNotification = false,
  });

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeBottomNavigationBar', '홈 하단 네비 · 홈/앨범/스토어/알림/설정');
    }
    final isDark = SnapFitColors.isDark(context);
    final barColor = isDark ? const Color(0xF21C1F22) : SnapFitColors.pureWhite;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFECEFF3);

    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: Container(
        height: 58.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: barColor,
          border: Border(top: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.045),
              blurRadius: 14.r,
              spreadRadius: -8.r,
              offset: Offset(0, -4.h),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _BottomNavItem(
                icon: Icons.home_rounded,
                label: '홈',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon: Icons.photo_library_rounded,
                label: '앨범',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon: Icons.explore_rounded,
                label: '스토어',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon: Icons.notifications_rounded,
                label: '알림',
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
                showBadge: hasUnreadNotification,
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon: Icons.person_rounded,
                label: '설정',
                isSelected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 바텀 네비게이션 아이템
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showBadge;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final selectedColor = SnapFitColors.accent;
    final unselectedColor = isDark
        ? Colors.white.withOpacity(0.56)
        : SnapFitColors.deepCharcoal.withOpacity(0.58);
    final color = isSelected ? selectedColor : unselectedColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        scale: isSelected ? 1.06 : 1.0,
                        child: Icon(
                          icon,
                          size: isSelected ? 20.sp : 19.sp,
                          color: color,
                        ),
                      ),
                      if (showBadge)
                        Positioned(
                          right: -2.w,
                          top: -2.h,
                          child: Container(
                            width: 7.w,
                            height: 7.w,
                            decoration: const BoxDecoration(
                              color: SnapFitColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style:
                        (Theme.of(context).textTheme.bodySmall ??
                                const TextStyle())
                            .copyWith(
                              fontSize: 9.5.sp,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              height: 1.0,
                              color: color,
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

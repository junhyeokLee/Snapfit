import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';

/// 홈 화면 하단 네비게이션 바
class HomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const HomeBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeBottomNavigationBar', '홈 하단 네비 · 홈/앨범/스토어/설정');
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
                icon: Icons.person_rounded,
                label: '설정',
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
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

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
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
          height: 48.h,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
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
              SizedBox(height: 2.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style:
                    (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
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
    );
  }
}

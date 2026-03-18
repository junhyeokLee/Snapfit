import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';

/// 홈 화면 하단 네비게이션 바
class HomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreate;

  const HomeBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCreate,
  });

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeBottomNavigationBar', '홈 하단 네비 · 홈/앨범만들기');
    }
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(10.w, 0, 10.w, 6.h),
        padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 6.h),
        decoration: BoxDecoration(
          color: SnapFitColors.isDark(context)
              ? SnapFitColors.surfaceOf(context)
              : SnapFitColors.pureWhite,
          borderRadius: BorderRadius.circular(16.r),
          border: Border(
            top: BorderSide(
              color: SnapFitColors.isDark(context)
                  ? SnapFitColors.overlayLightOf(context)
                  : SnapFitColors.overlayStrongOf(context),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                SnapFitColors.isDark(context) ? 0.12 : 0.045,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                icon: Icons.photo_album_rounded,
                label: '앨범',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
            ),
            SizedBox(width: 4.w),
            _CreateNavButton(onTap: onCreate),
            SizedBox(width: 4.w),
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

/// 바텀 네비게이션 중앙 액션 버튼
class _CreateNavButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateNavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final buttonColor = isDark
        ? const Color(0xFF1987AB)
        : const Color(0xFF10A4D1);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: buttonColor.withOpacity(isDark ? 0.18 : 0.16),
                blurRadius: 7.r,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: buttonColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(isDark ? 0.08 : 0.5),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: 20.sp,
                  color: SnapFitColors.pureWhite,
                ),
              ),
            ),
          ),
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
    final color = isSelected
        ? (isDark ? SnapFitColors.accent : SnapFitColors.accent)
        : (isDark
              ? SnapFitColors.textMutedOf(context)
              : SnapFitColors.deepCharcoal.withOpacity(0.7));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SnapFitColors.accent.withOpacity(isDark ? 0.14 : 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Icon(icon, size: 17.sp, color: color),
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                style:
                    (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
                        .copyWith(
                          fontSize: 9.sp,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
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

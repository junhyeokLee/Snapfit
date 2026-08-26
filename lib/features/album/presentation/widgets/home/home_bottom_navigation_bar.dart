import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
      ScreenLogger.widget(
        'HomeBottomNavigationBar',
        '홈 하단 네비 · 홈/앨범/스토어/알림/설정',
      );
    }
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8EFE2), Color(0xFFEFE2D0)],
          ),
        ),
        child: SizedBox(
          height: 88.h,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 62.h,
              margin: EdgeInsets.fromLTRB(20.w, 13.h, 20.w, 0),
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(999.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 24.r,
                    offset: Offset(0, 10.h),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _BottomNavItem(
                      label: '홈',
                      isSelected: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      label: '앨범',
                      isSelected: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      label: '스토어',
                      isSelected: currentIndex == 2,
                      onTap: () => onTap(2),
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      label: '알림',
                      isSelected: currentIndex == 3,
                      onTap: () => onTap(3),
                      showBadge: hasUnreadNotification,
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      label: '마이',
                      isSelected: currentIndex == 4,
                      onTap: () => onTap(4),
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

/// 바텀 네비게이션 아이템
class _BottomNavItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showBadge;

  const _BottomNavItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF08B8D0);
    final unselectedColor = Colors.white.withOpacity(0.46);
    final color = isSelected ? selectedColor : unselectedColor;
    final labelText = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      style: TextStyle(
        fontSize: isSelected ? 13.sp : 12.sp,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0,
        color: color,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              labelText,
              if (showBadge)
                Positioned(
                  right: -7.w,
                  top: -7.h,
                  child: Container(
                    width: 7.w,
                    height: 7.w,
                    decoration: const BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

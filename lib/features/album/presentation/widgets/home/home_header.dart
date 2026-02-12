import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import 'home_icon_buttons.dart';
import 'home_avatar_dot.dart';

/// 홈 화면 상단 헤더 (제목 + 아이콘)
class HomeHeader extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onNotification;
  final bool isEditMode;
  final VoidCallback onEditToggle;
  final bool hasAlbums;
  final bool isSearching;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClose;

  const HomeHeader({
    super.key,
    required this.onSearch,
    required this.onNotification,
    required this.isEditMode,
    required this.onEditToggle,
    required this.hasAlbums,
    this.isSearching = false,
    this.searchQuery = '',
    this.onSearchChanged,
    this.onSearchClose,
  });

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeHeader', '홈 상단 헤더 · 로고/검색/알림/편집');
    }

    // 검색 모드일 때
    if (isSearching) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              autofocus: true,
              onChanged: onSearchChanged,
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 16.sp,
              ),
              decoration: InputDecoration(
                hintText: '앨범 검색...',
                hintStyle: TextStyle(
                  color: SnapFitColors.textMutedOf(context),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          HomeRoundIconButton(
            icon: Icons.close,
            onTap: onSearchClose ?? () {},
          ),
        ],
      );
    }

    // 일반 모드
    return Row(
      children: [
        Row(
          children: [
            // 앱 로고
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.asset(
                'assets/snapfit_logo.png',
                width: 28.w,
                height: 28.w,
                fit: BoxFit.cover,
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
        // 편집 모드 토글 버튼 (앨범이 있을 때만 표시)
        if (hasAlbums)
          HomeRoundIconButton(
              icon: isEditMode ? Icons.check : Icons.edit_outlined,
              onTap: onEditToggle,
              isActive: isEditMode),
        SizedBox(width: 10.w),
        HomeRoundIconButton(icon: Icons.search, onTap: onSearch),
        SizedBox(width: 10.w),
        HomeRoundIconButton(
            icon: Icons.notifications_none, onTap: onNotification),
      ],
    );
  }
}

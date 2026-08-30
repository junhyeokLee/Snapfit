import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../ai_album/domain/ai_album_models.dart';

class AiAlbumThemeStep extends StatelessWidget {
  const AiAlbumThemeStep({
    super.key,
    required this.onThemeSelected,
    required this.onBack,
  });

  final ValueChanged<AlbumTheme> onThemeSelected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final background = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFFAF8F3);
    return ColoredBox(
      color: background,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackTextButton(onPressed: onBack),
              SizedBox(height: 18.h),
              Text(
                'AI 초안',
                style: TextStyle(
                  color: SnapFitColors.textMutedOf(context),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '분위기',
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 24.sp,
                  height: 1.16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 18.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 10.h,
                children: [
                  _ThemeCard(
                    theme: AlbumTheme.travel,
                    title: '여행',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.family,
                    title: '가족',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.baby,
                    title: '성장',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.couple,
                    title: '커플',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.birthday,
                    title: '기념일',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.daily,
                    title: '일상',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.custom,
                    title: '직접 입력',
                    onTap: onThemeSelected,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.title,
    required this.onTap,
  });

  final AlbumTheme theme;
  final String title;
  final ValueChanged<AlbumTheme> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('ai_theme_${theme.name}'),
        borderRadius: BorderRadius.circular(20.r),
        onTap: () => onTap(theme),
        child: Ink(
          width: 104.w,
          height: 82.h,
          padding: EdgeInsets.all(13.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1B20) : const Color(0xFFF7F7FF),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xFFE0E2EF),
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              title,
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 15.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackTextButton extends StatelessWidget {
  const _BackTextButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size(0, 34.h),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        '이전',
        style: TextStyle(
          color: SnapFitColors.textSecondaryOf(context),
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

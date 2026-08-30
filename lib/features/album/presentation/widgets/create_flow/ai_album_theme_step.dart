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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BackTextButton(onPressed: onBack),
                    SizedBox(height: 14.h),
                    const _MoodPreviewBoard(),
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
                          colors: const [Color(0xFF93B7D8), Color(0xFFFFC985)],
                          onTap: onThemeSelected,
                        ),
                        _ThemeCard(
                          theme: AlbumTheme.family,
                          title: '가족',
                          colors: const [Color(0xFFF1C8A6), Color(0xFFB9CFA4)],
                          onTap: onThemeSelected,
                        ),
                        _ThemeCard(
                          theme: AlbumTheme.baby,
                          title: '성장',
                          colors: const [Color(0xFFF6C6D8), Color(0xFFEAE2B7)],
                          onTap: onThemeSelected,
                        ),
                        _ThemeCard(
                          theme: AlbumTheme.couple,
                          title: '커플',
                          colors: const [Color(0xFFECA2A2), Color(0xFFB8A5DF)],
                          onTap: onThemeSelected,
                        ),
                        _ThemeCard(
                          theme: AlbumTheme.birthday,
                          title: '기념일',
                          colors: const [Color(0xFFFFD166), Color(0xFFEF8E72)],
                          onTap: onThemeSelected,
                        ),
                        _ThemeCard(
                          theme: AlbumTheme.daily,
                          title: '일상',
                          colors: const [Color(0xFFC9D8C5), Color(0xFFF2E8D8)],
                          onTap: onThemeSelected,
                        ),
                        _ThemeCard(
                          theme: AlbumTheme.custom,
                          title: '직접 입력',
                          colors: const [Color(0xFFDDD7F3), Color(0xFFE8E8E8)],
                          onTap: onThemeSelected,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodPreviewBoard extends StatelessWidget {
  const _MoodPreviewBoard();

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      width: double.infinity,
      height: 132.h,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B20) : Colors.white,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE6DED3),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFFB8A889).withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _PreviewPhoto(
                    colors: const [Color(0xFF9DB6C8), Color(0xFFE7D2B8)],
                    radius: 22.r,
                  ),
                ),
                Positioned(
                  right: 12.w,
                  bottom: 12.h,
                  child: const _PreviewChip(text: 'mood'),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          SizedBox(
            width: 108.w,
            child: Column(
              children: [
                Expanded(
                  child: _PreviewPhoto(
                    colors: const [Color(0xFFECA2A2), Color(0xFFF4E8BE)],
                  ),
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: _PreviewPhoto(
                    colors: const [Color(0xFFADC9A9), Color(0xFFD9C6F1)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.title,
    required this.colors,
    required this.onTap,
  });

  final AlbumTheme theme;
  final String title;
  final List<Color> colors;
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
          height: 92.h,
          padding: EdgeInsets.all(11.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1B20) : Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xFFE0E2EF),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: _PreviewPhoto(colors: colors, radius: 14.r),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.38)
                        : Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SnapFitColors.textPrimaryOf(context),
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
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

class _PreviewPhoto extends StatelessWidget {
  const _PreviewPhoto({required this.colors, this.radius});

  final List<Color> colors;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(radius ?? 16.r),
      ),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Container(
          width: 28.w,
          height: 28.w,
          margin: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.36),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.44),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
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

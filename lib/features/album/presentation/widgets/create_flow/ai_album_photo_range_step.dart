import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../ai_album/domain/ai_album_models.dart';

class AiAlbumPhotoRangeStep extends StatelessWidget {
  const AiAlbumPhotoRangeStep({
    super.key,
    required this.theme,
    required this.onRangeSelected,
    required this.onBack,
  });

  final AlbumTheme theme;
  final ValueChanged<AiPhotoRange> onRangeSelected;
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
                    _RangePreview(theme: theme),
                    SizedBox(height: 18.h),
                    Text(
                      'AI 초안',
                      style: TextStyle(
                        color: SnapFitColors.textMutedOf(context),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '사진 범위',
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 24.sp,
                        height: 1.16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    _RangeCard(
                      title: '최근 30일',
                      subtitle: '가장 자연스러운 기본값',
                      icon: Icons.auto_awesome_rounded,
                      emphasized: true,
                      onTap: () => onRangeSelected(AiPhotoRange.recent30Days),
                    ),
                    _RangeCard(
                      title: '날짜 선택',
                      subtitle: '여행·기념일만 정확히',
                      icon: Icons.calendar_month_rounded,
                      onTap: () => onRangeSelected(AiPhotoRange.dateRange),
                    ),
                    _RangeCard(
                      title: '앨범 선택',
                      subtitle: '휴대폰 앨범 단위로',
                      icon: Icons.photo_album_rounded,
                      onTap: () => onRangeSelected(AiPhotoRange.album),
                    ),
                    _RangeCard(
                      title: '직접 고르기',
                      subtitle: '넣을 사진만 직접 픽',
                      icon: Icons.touch_app_rounded,
                      onTap: () =>
                          onRangeSelected(AiPhotoRange.manualSelection),
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

class _RangePreview extends StatelessWidget {
  const _RangePreview({required this.theme});
  final AlbumTheme theme;

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
      ),
      child: Row(
        children: [
          Expanded(child: _MosaicTile(color: _accent(theme), big: true)),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _MosaicTile(color: const Color(0xFFECC7A1))),
                SizedBox(height: 8.h),
                Expanded(child: _MosaicTile(color: const Color(0xFFB9C8A9))),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _MosaicTile(color: const Color(0xFFD8CAE8), big: true),
          ),
        ],
      ),
    );
  }

  Color _accent(AlbumTheme theme) => switch (theme) {
    AlbumTheme.travel => const Color(0xFF95B8D1),
    AlbumTheme.family => const Color(0xFFCDAF8D),
    AlbumTheme.baby => const Color(0xFFF0B8C9),
    AlbumTheme.couple => const Color(0xFFE8A0A0),
    AlbumTheme.birthday => const Color(0xFFF6C15E),
    AlbumTheme.daily => const Color(0xFFAFC5A5),
    AlbumTheme.friends => const Color(0xFFB7B0E5),
    AlbumTheme.custom => const Color(0xFFC9C1E6),
  };
}

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({required this.color, this.big = false});
  final Color color;
  final bool big;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(big ? 20.r : 16.r),
      ),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Container(
          width: big ? 34.w : 24.w,
          height: big ? 34.w : 24.w,
          margin: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.32),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: onTap,
          child: Ink(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14.w, 13.h, 14.w, 13.h),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1B20)
                  : (emphasized ? const Color(0xFFF7F7FF) : Colors.white),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : (emphasized
                          ? const Color(0xFFBFC7DC)
                          : const Color(0xFFE7E1D8)),
                width: emphasized ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: emphasized
                        ? const Color(0xFF9DB6C8)
                        : const Color(0xFFEDE7DD),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Center(
                    child: Container(
                      width: 14.w,
                      height: 14.w,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: emphasized
                              ? Colors.white
                              : const Color(0xFF6E6558),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: SnapFitColors.textPrimaryOf(context),
                          fontSize: 15.5.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SnapFitColors.textMutedOf(context),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '›',
                  style: TextStyle(
                    color: SnapFitColors.textMutedOf(context),
                    fontSize: 27.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
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

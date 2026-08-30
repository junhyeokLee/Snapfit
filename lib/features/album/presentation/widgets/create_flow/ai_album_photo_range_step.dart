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
                meta: '새 사진 중심',
                emphasized: true,
                onTap: () => onRangeSelected(AiPhotoRange.recent30Days),
              ),
              _RangeCard(
                title: '날짜 선택',
                meta: '기간 기준',
                onTap: () => onRangeSelected(AiPhotoRange.dateRange),
              ),
              _RangeCard(
                title: '앨범 선택',
                meta: '폴더 기준',
                onTap: () => onRangeSelected(AiPhotoRange.album),
              ),
              _RangeCard(
                title: '직접 고르기',
                meta: '선택 사진만',
                onTap: () => onRangeSelected(AiPhotoRange.manualSelection),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({
    required this.title,
    required this.meta,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String meta;
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
                      SizedBox(height: 4.h),
                      Text(
                        meta,
                        style: TextStyle(
                          color: SnapFitColors.textSecondaryOf(context),
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: SnapFitColors.textMutedOf(context),
                  size: 22.sp,
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

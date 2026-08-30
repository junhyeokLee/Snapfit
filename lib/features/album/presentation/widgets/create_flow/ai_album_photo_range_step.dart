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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BackTextButton(onPressed: onBack),
                    SizedBox(height: 14.h),
                    Text(
                      '사진 범위를 정해주세요',
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 23.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '허용한 사진 안에서만 앨범 초안을 준비해요.',
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: 14.5.sp,
                        height: 1.42,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _PrivacyMemo(theme: theme),
                    SizedBox(height: 18.h),
                    _RangeCard(
                      title: '최근 30일',
                      description: '가장 빠르게 ${_themeLabel(theme)} 앨범 초안을 만들어요.',
                      onTap: () => onRangeSelected(AiPhotoRange.recent30Days),
                      emphasized: true,
                    ),
                    _RangeCard(
                      title: '날짜 선택',
                      description: '여행이나 기념일처럼 기간이 분명할 때 좋아요.',
                      onTap: () => onRangeSelected(AiPhotoRange.dateRange),
                    ),
                    _RangeCard(
                      title: '앨범 선택',
                      description: '기기 사진첩의 특정 앨범 안에서만 추천해요.',
                      onTap: () => onRangeSelected(AiPhotoRange.album),
                    ),
                    _RangeCard(
                      title: '직접 고르기',
                      description: '가장 안전하게, 선택한 사진만 Snapfit이 정리해요.',
                      onTap: () =>
                          onRangeSelected(AiPhotoRange.manualSelection),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      '전체 사진첩이 부담스럽다면 일부 사진만 선택할 수 있어요.',
                      style: TextStyle(
                        color: SnapFitColors.textMutedOf(context),
                        fontSize: 12.5.sp,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.couple => '커플',
      AlbumTheme.travel => '여행',
      AlbumTheme.family => '가족',
      AlbumTheme.baby => '아기/성장',
      AlbumTheme.birthday => '생일',
      AlbumTheme.friends => '친구',
      AlbumTheme.daily => '일상',
      AlbumTheme.custom => '직접 입력',
    };
  }
}

class _PrivacyMemo extends StatelessWidget {
  const _PrivacyMemo({required this.theme});

  final AlbumTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(17.w),
      decoration: BoxDecoration(
        color: SnapFitColors.isDark(context)
            ? const Color(0xFF1D1C1A)
            : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: SnapFitColors.isDark(context)
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE7E1D8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사진 접근 전 안내',
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            'Snapfit은 사용자가 허용한 사진 안에서만 날짜별 흐름과 대표 장면을 골라요. 추천 결과를 확인하기 전에는 앨범이 만들어지지 않아요.',
            style: TextStyle(
              color: SnapFitColors.textSecondaryOf(context),
              fontSize: 13.sp,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({
    required this.title,
    required this.description,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String description;
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
            padding: EdgeInsets.fromLTRB(16.w, 15.h, 16.w, 15.h),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1D1C1A)
                  : emphasized
                  ? const Color(0xFFFFFCF5)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : emphasized
                    ? const Color(0xFFD8C8AF)
                    : const Color(0xFFE7E1D8),
              ),
            ),
            child: Row(
              children: [
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
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        description,
                        style: TextStyle(
                          color: SnapFitColors.textSecondaryOf(context),
                          fontSize: 12.5.sp,
                          height: 1.35,
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
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size(0, 34.h),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 14.sp,
        color: SnapFitColors.textSecondaryOf(context),
      ),
      label: Text(
        '주제 다시 고르기',
        style: TextStyle(
          color: SnapFitColors.textSecondaryOf(context),
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

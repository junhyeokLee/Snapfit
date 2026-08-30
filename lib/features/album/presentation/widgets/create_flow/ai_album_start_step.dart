import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../ai_album/domain/ai_album_models.dart';

class AiAlbumStartStep extends StatelessWidget {
  const AiAlbumStartStep({
    super.key,
    required this.onThemeSelected,
    required this.onManualStart,
  });

  final ValueChanged<AlbumTheme> onThemeSelected;
  final VoidCallback onManualStart;

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
              Text(
                '새 앨범 만들기',
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '어떻게 시작할까요?',
                style: TextStyle(
                  color: SnapFitColors.textSecondaryOf(context),
                  fontSize: 15.sp,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 18.h),
              _StartOptionCard(
                title: 'AI가 먼저 골라주는 앨범',
                description: '주제만 고르면, 어울리는 사진과 흐름을 먼저 정리해드려요.',
                footnote: '추천안은 만들기 전에 직접 확인하고 고칠 수 있어요.',
                cta: 'AI로 시작하기',
                highlighted: true,
                onTap: () => onThemeSelected(AlbumTheme.travel),
              ),
              SizedBox(height: 12.h),
              _StartOptionCard(
                title: '직접 구성하기',
                description: '제목, 비율, 사진을 하나씩 정하며 시작해요.',
                cta: '직접 만들기',
                highlighted: false,
                onTap: onManualStart,
              ),
              SizedBox(height: 26.h),
              Text(
                '어떤 앨범을 만들까요?',
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '사진은 아직 고르지 않아도 괜찮아요. 주제에 맞는 장면을 먼저 찾아볼게요.',
                style: TextStyle(
                  color: SnapFitColors.textSecondaryOf(context),
                  fontSize: 13.5.sp,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 14.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 10.h,
                children: const [
                  _ThemeChip(
                    theme: AlbumTheme.couple,
                    title: '커플',
                    caption: '둘의 시간',
                  ),
                  _ThemeChip(
                    theme: AlbumTheme.travel,
                    title: '여행',
                    caption: '날짜 흐름',
                  ),
                  _ThemeChip(
                    theme: AlbumTheme.family,
                    title: '가족',
                    caption: '함께한 장면',
                  ),
                  _ThemeChip(
                    theme: AlbumTheme.baby,
                    title: '아기',
                    caption: '성장 기록',
                  ),
                  _ThemeChip(
                    theme: AlbumTheme.birthday,
                    title: '생일',
                    caption: '축하 순간',
                  ),
                  _ThemeChip(
                    theme: AlbumTheme.daily,
                    title: '일상',
                    caption: '남기고 싶은 하루',
                  ),
                  _ThemeChip(
                    theme: AlbumTheme.custom,
                    title: '직접입력',
                    caption: '원하는 주제',
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              Text(
                '언제든 에디터에서 사진과 문구를 다시 바꿀 수 있어요.',
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
    );
  }
}

class _StartOptionCard extends StatelessWidget {
  const _StartOptionCard({
    required this.title,
    required this.description,
    required this.cta,
    required this.highlighted,
    required this.onTap,
    this.footnote,
  });

  final String title;
  final String description;
  final String? footnote;
  final String cta;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final cardColor = isDark
        ? const Color(0xFF1C1A17)
        : highlighted
        ? const Color(0xFFFFFCF5)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.10)
        : highlighted
        ? const Color(0xFFD8C8AF)
        : const Color(0xFFE7E1D8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24.r),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: borderColor),
            boxShadow: highlighted && !isDark
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B6F47).withOpacity(0.08),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (highlighted) ...[
                _SmallLabel(text: '추천'),
                SizedBox(height: 10.h),
              ],
              Text(
                title,
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 17.sp,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.25,
                ),
              ),
              SizedBox(height: 7.h),
              Text(
                description,
                style: TextStyle(
                  color: SnapFitColors.textSecondaryOf(context),
                  fontSize: 13.5.sp,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (footnote != null) ...[
                SizedBox(height: 7.h),
                Text(
                  footnote!,
                  style: TextStyle(
                    color: SnapFitColors.textMutedOf(context),
                    fontSize: 12.sp,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: 14.h),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  cta,
                  style: TextStyle(
                    color: highlighted
                        ? SnapFitColors.textPrimaryOf(context)
                        : SnapFitColors.textSecondaryOf(context),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
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

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.theme,
    required this.title,
    required this.caption,
  });

  final AlbumTheme theme;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final parent = context.findAncestorWidgetOfExactType<AiAlbumStartStep>();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () => parent?.onThemeSelected(theme),
        child: Ink(
          width: 104.w,
          padding: EdgeInsets.fromLTRB(12.w, 11.h, 12.w, 12.h),
          decoration: BoxDecoration(
            color: SnapFitColors.isDark(context)
                ? const Color(0xFF1D1C1A)
                : Colors.white,
            borderRadius: BorderRadius.circular(18.r),
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
                title,
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: SnapFitColors.textMutedOf(context),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F4EC),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF4C6A55),
          fontSize: 11.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

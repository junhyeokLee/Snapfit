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
    final background = SnapFitColors.isDark(context)
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
              TextButton.icon(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14.sp,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
                label: Text(
                  '시작 방식 다시 고르기',
                  style: TextStyle(
                    color: SnapFitColors.textSecondaryOf(context),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              _SmallLabel(text: 'AI 초안'),
              SizedBox(height: 14.h),
              Text(
                '어떤 앨범으로 정리해볼까요?',
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 23.sp,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '선택한 주제는 AI가 사진 흐름과 제목을 제안할 때만 참고해요.',
                style: TextStyle(
                  color: SnapFitColors.textSecondaryOf(context),
                  fontSize: 14.sp,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
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
                    caption: '날짜와 장소 흐름',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.family,
                    title: '가족',
                    caption: '함께한 장면 중심',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.baby,
                    title: '아기·성장',
                    caption: '변화와 표정 기록',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.couple,
                    title: '커플',
                    caption: '둘의 시간',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.birthday,
                    title: '생일·기념일',
                    caption: '축하와 하이라이트',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.daily,
                    title: '일상',
                    caption: '남기고 싶은 하루',
                    onTap: onThemeSelected,
                  ),
                  _ThemeCard(
                    theme: AlbumTheme.custom,
                    title: '직접 입력',
                    caption: '원하는 주제로',
                    onTap: onThemeSelected,
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              Text(
                '정답을 고르는 단계가 아니에요. 나중에 제목, 사진, 페이지는 모두 바꿀 수 있어요.',
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

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final AlbumTheme theme;
  final String title;
  final String caption;
  final ValueChanged<AlbumTheme> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('ai_theme_${theme.name}'),
        borderRadius: BorderRadius.circular(18.r),
        onTap: () => onTap(theme),
        child: Ink(
          width: 108.w,
          height: 76.h,
          padding: EdgeInsets.all(13.w),
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
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: SnapFitColors.textMutedOf(context),
                  fontSize: 10.5.sp,
                  height: 1.2,
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
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F4EC),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF4C6A55),
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

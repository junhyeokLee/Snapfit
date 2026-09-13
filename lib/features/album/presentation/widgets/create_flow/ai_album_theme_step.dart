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

  static const _styles = <_TemplateStyle>[
    _TemplateStyle(
      theme: AlbumTheme.travel,
      themeLabel: '여행',
      title: '여행 매거진',
      subtitle: '장소감이 큰 사진과 여백 중심의 기록형 레이아웃',
      density: '여백 넓게',
      rhythm: '장면 흐름',
      colors: [Color(0xFF6F91A8), Color(0xFFF2C37D), Color(0xFFF7EFE3)],
    ),
    _TemplateStyle(
      theme: AlbumTheme.family,
      themeLabel: '가족',
      title: '패밀리 아카이브',
      subtitle: '함께 찍은 컷과 작은 디테일을 따뜻하게 묶는 구성',
      density: '사진 균형',
      rhythm: '부드럽게',
      colors: [Color(0xFFEABF9B), Color(0xFF8EA47F), Color(0xFFFFF7EC)],
    ),
    _TemplateStyle(
      theme: AlbumTheme.baby,
      themeLabel: '성장',
      title: '성장 스토리',
      subtitle: '한 장면을 크게 남기고 월령/메모가 잘 보이는 템플릿',
      density: '문구 포함',
      rhythm: '차분하게',
      colors: [Color(0xFFEFB7CB), Color(0xFFE8DA9D), Color(0xFFFFF5F8)],
    ),
    _TemplateStyle(
      theme: AlbumTheme.couple,
      themeLabel: '커플',
      title: '커플 시네마',
      subtitle: '두 사람의 장면을 영화 스틸처럼 이어 붙이는 무드',
      density: '대표 컷',
      rhythm: '드라마틱',
      colors: [Color(0xFFB76E78), Color(0xFF242125), Color(0xFFF5E6E1)],
    ),
    _TemplateStyle(
      theme: AlbumTheme.birthday,
      themeLabel: '기념일',
      title: '기념일 포스터북',
      subtitle: '표지 임팩트와 이벤트 장면이 살아나는 선명한 구성',
      density: '강조 크게',
      rhythm: '경쾌하게',
      colors: [Color(0xFFE4A73A), Color(0xFFE77665), Color(0xFFFFF0CF)],
    ),
    _TemplateStyle(
      theme: AlbumTheme.daily,
      themeLabel: '일상',
      title: '데일리 미니멀',
      subtitle: '작은 순간을 정갈한 여백과 짧은 문장으로 보관',
      density: '미니멀',
      rhythm: '잔잔하게',
      colors: [Color(0xFFAFC2A7), Color(0xFFD9C7A8), Color(0xFFF8F4EC)],
    ),
    _TemplateStyle(
      theme: AlbumTheme.custom,
      themeLabel: '직접 입력',
      title: '커스텀 브리프',
      subtitle: '원하는 느낌을 다음 단계에서 사진 범위와 함께 맞춰볼게요',
      density: '자유 구성',
      rhythm: '맞춤형',
      colors: [Color(0xFFB8AEDF), Color(0xFF9FB7C9), Color(0xFFF0EEF8)],
    ),
  ];

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
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isLandscape ? 28 : 20.w,
                    isLandscape ? 10 : 12.h,
                    isLandscape ? 28 : 20.w,
                    isLandscape ? 22 : 28.h,
                  ),
                  child: isLandscape
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 300,
                              child: _HeaderColumn(onBack: onBack),
                            ),
                            const SizedBox(width: 22),
                            Expanded(
                              child: _StyleGrid(
                                styles: _styles,
                                onThemeSelected: onThemeSelected,
                                isLandscape: true,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeaderColumn(onBack: onBack),
                            SizedBox(height: 18.h),
                            _StyleGrid(
                              styles: _styles,
                              onThemeSelected: onThemeSelected,
                              isLandscape: false,
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderColumn extends StatelessWidget {
  const _HeaderColumn({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackTextButton(onPressed: onBack),
        SizedBox(height: 14.h),
        const _MoodPreviewBoard(),
        SizedBox(height: 18.h),
        Text(
          'AI 템플릿',
          style: TextStyle(
            color: SnapFitColors.textMutedOf(context),
            fontSize: 12.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.1,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          '원하는 앨범 무드를 골라주세요',
          style: TextStyle(
            color: SnapFitColors.textPrimaryOf(context),
            fontSize: 24.sp,
            height: 1.16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          '사진을 자동으로 끼워 넣기보다, 먼저 편집 가능한 템플릿의 구조와 분위기를 잡아요.',
          style: TextStyle(
            color: SnapFitColors.textSecondaryOf(context),
            fontSize: 13.2.sp,
            height: 1.45,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.12,
          ),
        ),
      ],
    );
  }
}

class _StyleGrid extends StatelessWidget {
  const _StyleGrid({
    required this.styles,
    required this.onThemeSelected,
    required this.isLandscape,
  });

  final List<_TemplateStyle> styles;
  final ValueChanged<AlbumTheme> onThemeSelected;
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    if (isLandscape) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: styles
            .map(
              (style) => SizedBox(
                width: 230,
                child: _TemplateStyleCard(
                  style: style,
                  onTap: onThemeSelected,
                  compact: true,
                ),
              ),
            )
            .toList(growable: false),
      );
    }

    return Column(
      children: styles
          .map(
            (style) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _TemplateStyleCard(style: style, onTap: onThemeSelected),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _TemplateStyleCard extends StatelessWidget {
  const _TemplateStyleCard({
    required this.style,
    required this.onTap,
    this.compact = false,
  });

  final _TemplateStyle style;
  final ValueChanged<AlbumTheme> onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('ai_theme_${style.theme.name}'),
        borderRadius: BorderRadius.circular(24.r),
        onTap: () => onTap(style.theme),
        child: Ink(
          padding: EdgeInsets.all(compact ? 10 : 12.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1B20) : Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xFFE2D7C9),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF5B4A34).withOpacity(0.08),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: compact ? 70 : 88.w,
                height: compact ? 88 : 102.h,
                child: _TemplateThumbnail(colors: style.colors),
              ),
              SizedBox(width: compact ? 11 : 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: _ThemePill(text: style.themeLabel)),
                        SizedBox(width: 6.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: compact ? 16 : 17.sp,
                          color: SnapFitColors.textMutedOf(context),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 8 : 9.h),
                    Text(
                      style.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: compact ? 15 : 16.sp,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    ),
                    SizedBox(height: compact ? 5 : 6.h),
                    Text(
                      style.subtitle,
                      maxLines: compact ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: compact ? 11.5 : 12.3.sp,
                        height: 1.36,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: compact ? 9 : 10.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _SpecChip(text: style.density),
                        _SpecChip(text: style.rhythm),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
      height: 148.h,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B20) : Colors.white,
        borderRadius: BorderRadius.circular(28.r),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _PreviewSpread(
              colors: const [Color(0xFF8AA4B8), Color(0xFFE7D2B8)],
              label: 'cover',
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _PreviewSpread(
              colors: const [Color(0xFFE99A8F), Color(0xFFF0D58C)],
              label: 'story',
              reversed: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSpread extends StatelessWidget {
  const _PreviewSpread({
    required this.colors,
    required this.label,
    this.reversed = false,
  });

  final List<Color> colors;
  final String label;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1E8),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Stack(
          children: [
            Positioned(
              left: reversed ? null : 0,
              right: reversed ? 0 : null,
              top: 0,
              bottom: 22.h,
              width: 48.w,
              child: _PreviewPhoto(colors: colors, radius: 13.r),
            ),
            Positioned(
              left: reversed ? 0 : 56.w,
              right: reversed ? 56.w : 0,
              top: 8.h,
              child: _MiniTextBar(
                width: 42.w,
                color: const Color(0xFF2B2520).withOpacity(0.38),
              ),
            ),
            Positioned(
              left: reversed ? 0 : 56.w,
              right: reversed ? 56.w : 0,
              top: 22.h,
              child: _MiniTextBar(
                width: 30.w,
                color: const Color(0xFF2B2520).withOpacity(0.18),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PreviewChip(text: label),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateThumbnail extends StatelessWidget {
  const _TemplateThumbnail({required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(7.w),
      decoration: BoxDecoration(
        color: colors.last.withOpacity(0.74),
        borderRadius: BorderRadius.circular(17.r),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: 30.h,
            child: _PreviewPhoto(
              colors: [colors.first, colors[1]],
              radius: 12.r,
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            width: 34.w,
            height: 42.h,
            child: _PreviewPhoto(
              colors: [colors[1], colors.first.withOpacity(0.72)],
              radius: 12.r,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 6.h,
            width: 30.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniTextBar(width: 30.w, color: const Color(0xFF2B2520)),
                SizedBox(height: 5.h),
                _MiniTextBar(
                  width: 20.w,
                  color: const Color(0xFF2B2520).withOpacity(0.32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  const _ThemePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: SnapFitColors.isDark(context)
            ? Colors.white.withOpacity(0.08)
            : const Color(0xFFF2E8DA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: SnapFitColors.textSecondaryOf(context),
          fontSize: 10.8.sp,
          height: 1.0,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.05,
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: SnapFitColors.textMutedOf(context),
        fontSize: 11.2.sp,
        height: 1.0,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.05,
      ),
    );
  }
}

class _MiniTextBar extends StatelessWidget {
  const _MiniTextBar({required this.width, required this.color});
  final double width;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 5.h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
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
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.44),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
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

class _TemplateStyle {
  const _TemplateStyle({
    required this.theme,
    required this.themeLabel,
    required this.title,
    required this.subtitle,
    required this.density,
    required this.rhythm,
    required this.colors,
  });

  final AlbumTheme theme;
  final String themeLabel;
  final String title;
  final String subtitle;
  final String density;
  final String rhythm;
  final List<Color> colors;
}

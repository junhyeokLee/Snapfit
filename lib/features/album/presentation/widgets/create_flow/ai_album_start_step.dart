import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';

class AiAlbumStartStep extends StatelessWidget {
  const AiAlbumStartStep({
    super.key,
    required this.onAiStart,
    required this.onManualStart,
    this.aiPointCost = 300,
    this.freeDraftLabel,
  });

  final VoidCallback onAiStart;
  final VoidCallback onManualStart;
  final int aiPointCost;
  final String? freeDraftLabel;

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
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AlbumHeroBoard(),
              SizedBox(height: 20.h),
              Text(
                '시작 방식',
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 25.sp,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.55,
                ),
              ),
              SizedBox(height: 18.h),
              _ManualStartCard(onTap: onManualStart),
              SizedBox(height: 14.h),
              _AiStartRow(onTap: onAiStart),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumHeroBoard extends StatelessWidget {
  const _AlbumHeroBoard();

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      width: double.infinity,
      height: 176.h,
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 16.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B20) : Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE4DBCE),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFFB8A889).withOpacity(0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Transform.rotate(
              angle: -0.12,
              child: _PreviewPage(
                width: 116.w,
                height: 132.h,
                color: const Color(0xFFF0E4D2),
                accent: const Color(0xFFD8A06D),
              ),
            ),
          ),
          Positioned(
            left: 86.w,
            top: 0,
            child: Transform.rotate(
              angle: 0.07,
              child: _PreviewPage(
                width: 122.w,
                height: 140.h,
                color: const Color(0xFFE9F4F6),
                accent: const Color(0xFF8FB9C8),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 6.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _HeroChip(text: 'manual'),
                SizedBox(height: 8.h),
                _HeroChip(text: 'ai draft', dark: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({
    required this.width,
    required this.height,
    required this.color,
    required this.accent,
  });

  final double width;
  final double height;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(11.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: Colors.white.withOpacity(0.72), width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: height * 0.42,
            child: Container(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 15.h,
            child: Container(
              width: width * 0.46,
              height: 7.h,
              color: accent.withOpacity(0.56),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 3.h,
            child: Container(
              width: width * 0.34,
              height: 7.h,
              color: accent.withOpacity(0.32),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.text, this.dark = false});
  final String text;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F1F1D) : const Color(0xFFEDE6DA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: dark ? Colors.white : const Color(0xFF4A4035),
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ManualStartCard extends StatelessWidget {
  const _ManualStartCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26.r),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D1C1A) : Colors.white,
            borderRadius: BorderRadius.circular(26.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : const Color(0xFF1F1F1D),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _BookMark(isDark: isDark),
              SizedBox(width: 18.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '직접 구성',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 21.sp,
                        height: 1.16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 21.sp,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiStartRow extends StatelessWidget {
  const _AiStartRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22.r),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 17.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1B20) : const Color(0xFFF7F7FF),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xFFE0E2EF),
            ),
          ),
          child: Row(
            children: [
              _PhotoCluster(isDark: isDark),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 초안',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22.sp,
                color: SnapFitColors.textMutedOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookMark extends StatelessWidget {
  const _BookMark({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58.w,
      height: 78.h,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2621) : const Color(0xFFF0E4D2),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFD9CBB8),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 1.5.w,
          height: 54.h,
          color: isDark
              ? Colors.white.withOpacity(0.18)
              : const Color(0xFFD6C7B2),
        ),
      ),
    );
  }
}

class _PhotoCluster extends StatelessWidget {
  const _PhotoCluster({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50.w,
      height: 44.h,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 8.h,
            child: _MiniPhoto(color: const Color(0xFF9BB4C5), isDark: isDark),
          ),
          Positioned(
            left: 18.w,
            top: 0,
            child: _MiniPhoto(color: const Color(0xFFB8C59D), isDark: isDark),
          ),
          Positioned(
            left: 24.w,
            top: 18.h,
            child: _MiniPhoto(color: const Color(0xFFD9BEB2), isDark: isDark),
          ),
        ],
      ),
    );
  }
}

class _MiniPhoto extends StatelessWidget {
  const _MiniPhoto({required this.color, required this.isDark});

  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25.w,
      height: 25.w,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          width: 1.5,
        ),
      ),
    );
  }
}

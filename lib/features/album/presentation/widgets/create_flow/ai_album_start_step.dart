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
    this.isFirstAiDraftFree = true,
  });

  final VoidCallback onAiStart;
  final VoidCallback onManualStart;
  final int aiPointCost;
  final String? freeDraftLabel;
  final bool isFirstAiDraftFree;

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
                    _AiStartRow(
                      onTap: onAiStart,
                      isFirstAiDraftFree: isFirstAiDraftFree,
                      freeDraftLabel: freeDraftLabel,
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

class _AlbumHeroBoard extends StatelessWidget {
  const _AlbumHeroBoard();

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      width: double.infinity,
      height: 238.h,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B20) : Colors.white,
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF5B4A34).withOpacity(0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 2.w,
            top: 10.h,
            child: Transform.rotate(
              angle: -0.06,
              child: _PhotoBookCover(
                width: 148.w,
                height: 184.h,
                title: '제주 여행',
                paper: const Color(0xFFF6E7D2),
                photo: const Color(0xFF86B7CA),
                accent: const Color(0xFFE7A36D),
              ),
            ),
          ),
          Positioned(
            left: 126.w,
            top: 18.h,
            child: Transform.rotate(
              angle: 0.045,
              child: _PhotoBookCover(
                width: 132.w,
                height: 166.h,
                title: '우리집',
                paper: const Color(0xFFF8F2E7),
                photo: const Color(0xFFD6B199),
                accent: const Color(0xFF9CB88D),
                compact: true,
              ),
            ),
          ),
          Positioned(
            right: 4.w,
            top: 4.h,
            child: _FreeDraftPill(isDark: isDark),
          ),
          Positioned(
            right: 4.w,
            bottom: 12.h,
            child: _FinishedBookBadge(isDark: isDark),
          ),
        ],
      ),
    );
  }
}

class _PhotoBookCover extends StatelessWidget {
  const _PhotoBookCover({
    required this.width,
    required this.height,
    required this.title,
    required this.paper,
    required this.photo,
    required this.accent,
    this.compact = false,
  });

  final double width;
  final double height;
  final String title;
  final Color paper;
  final Color photo;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(11.w),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: Colors.white.withOpacity(0.78), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: height * (compact ? 0.48 : 0.55),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [photo, accent.withOpacity(0.76)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12.w,
                    bottom: 10.h,
                    child: Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.30),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 2.w,
            bottom: compact ? 20.h : 26.h,
            child: Text(
              title,
              style: TextStyle(
                color: const Color(0xFF29231D),
                fontSize: compact ? 13.sp : 16.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
              ),
            ),
          ),
          Positioned(
            left: 2.w,
            bottom: 8.h,
            child: Row(
              children: [
                _TinyLine(width: compact ? 25.w : 36.w, color: accent),
                SizedBox(width: 5.w),
                _TinyLine(
                  width: compact ? 16.w : 24.w,
                  color: accent.withOpacity(0.48),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeDraftPill extends StatelessWidget {
  const _FreeDraftPill({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFFF4F1EA) : const Color(0xFF1F1F1D),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        '첫 AI 생성 무료',
        style: TextStyle(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          fontSize: 11.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _FinishedBookBadge extends StatelessWidget {
  const _FinishedBookBadge({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78.w,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24252B) : const Color(0xFFF3EBDD),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TinyLine(width: 36.w, height: 6.h, color: const Color(0xFF8FAF9A)),
          SizedBox(height: 8.h),
          _TinyLine(width: 52.w, height: 6.h, color: const Color(0xFFCDAA82)),
          SizedBox(height: 8.h),
          _TinyLine(width: 28.w, height: 6.h, color: const Color(0xFFD7C5EF)),
        ],
      ),
    );
  }
}

class _TinyLine extends StatelessWidget {
  const _TinyLine({required this.width, required this.color, this.height});
  final double width;
  final double? height;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 7.h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
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
              Text(
                '→',
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiStartRow extends StatelessWidget {
  const _AiStartRow({
    required this.onTap,
    required this.isFirstAiDraftFree,
    this.freeDraftLabel,
  });

  final VoidCallback onTap;
  final bool isFirstAiDraftFree;
  final String? freeDraftLabel;

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
                    if (isFirstAiDraftFree || freeDraftLabel != null) ...[
                      SizedBox(height: 3.h),
                      Text(
                        freeDraftLabel ?? '첫 생성은 무료예요',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SnapFitColors.textMutedOf(context),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '›',
                style: TextStyle(
                  color: SnapFitColors.textMutedOf(context),
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w900,
                ),
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

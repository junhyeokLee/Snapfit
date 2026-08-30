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
              SizedBox(height: 28.h),
              _RecentTemplateStrip(isDark: isDark),
            ],
          ),
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
                    SizedBox(height: 8.h),
                    Text(
                      '제목 · 비율 · 분량',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: 13.sp,
                        height: 1.28,
                        fontWeight: FontWeight.w600,
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
                    SizedBox(height: 5.h),
                    Text(
                      '사진 흐름 추천',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _RecentTemplateStrip extends StatelessWidget {
  const _RecentTemplateStrip({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final items = [
      (label: '필름', color: const Color(0xFFA3B0BC)),
      (label: '베이직', color: const Color(0xFFD9C7B0)),
      (label: '클래식', color: const Color(0xFFBBC5A8)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 템플릿',
          style: TextStyle(
            color: SnapFitColors.textPrimaryOf(context),
            fontSize: 15.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == items.length - 1 ? 0 : 10.w,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 128.h,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
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

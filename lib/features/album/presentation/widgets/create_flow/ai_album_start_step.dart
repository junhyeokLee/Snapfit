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
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '작은 책으로 남길 순간을 골라볼까요?',
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 24.sp,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '직접 차근차근 만들거나, Snapfit이 먼저 초안을 정리해드릴 수 있어요.',
                style: TextStyle(
                  color: SnapFitColors.textSecondaryOf(context),
                  fontSize: 14.sp,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 18.h),
              _StartOptionCard(
                title: '직접 구성하기',
                description: '제목, 책 비율, 분량을 직접 정하고 빈 앨범에서 시작해요.',
                bullets: const [
                  '사진과 문구를 원하는 순서대로 배치',
                  '기존 에디터 기능 그대로 사용',
                  'AI 포인트 사용 없음',
                ],
                cta: '직접 만들기',
                highlighted: false,
                onTap: onManualStart,
              ),
              SizedBox(height: 12.h),
              _StartOptionCard(
                title: 'AI 초안으로 시작하기',
                description: '앨범 주제와 사진 범위를 알려주면, 어울리는 사진과 흐름을 먼저 정리해드려요.',
                badge: 'AI 도움',
                pointHint:
                    freeDraftLabel ?? 'AI 초안 만들기 ${_formatPoint(aiPointCost)}P',
                cta: 'AI 초안 만들기',
                highlighted: true,
                onTap: onAiStart,
              ),
              SizedBox(height: 20.h),
              Text(
                '어떤 방식으로 시작해도, 마지막에는 에디터에서 직접 고칠 수 있어요.',
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

  String _formatPoint(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final left = text.length - i;
      buffer.write(text[i]);
      if (left > 1 && left % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}

class _StartOptionCard extends StatelessWidget {
  const _StartOptionCard({
    required this.title,
    required this.description,
    required this.cta,
    required this.highlighted,
    required this.onTap,
    this.badge,
    this.pointHint,
    this.bullets = const [],
  });

  final String title;
  final String description;
  final String cta;
  final bool highlighted;
  final VoidCallback onTap;
  final String? badge;
  final String? pointHint;
  final List<String> bullets;

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
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badge != null) ...[
                _SmallLabel(text: badge!),
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
              if (bullets.isNotEmpty) ...[
                SizedBox(height: 10.h),
                ...bullets.map(
                  (bullet) => Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text(
                      '• $bullet',
                      style: TextStyle(
                        color: SnapFitColors.textMutedOf(context),
                        fontSize: 12.5.sp,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              if (pointHint != null) ...[
                SizedBox(height: 10.h),
                Text(
                  pointHint!,
                  style: TextStyle(
                    color: const Color(0xFF6C5E4B),
                    fontSize: 12.5.sp,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
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

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// 협업자 요약 표시
class HomeCollaboratorSummary extends StatelessWidget {
  final int count;
  final Color textColor;

  const HomeCollaboratorSummary({
    super.key,
    required this.count,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HomeAvatarStack(
          borderColor: SnapFitColors.backgroundOf(context),
          count: count,
        ),
        SizedBox(width: 8.w),
        Text(
          '공동작업자 $count명',
          style: TextStyle(
            fontSize: 11.sp,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 협업자 아바타 스택
class HomeAvatarStack extends StatelessWidget {
  final Color borderColor;
  final int count;

  const HomeAvatarStack({
    super.key,
    required this.borderColor,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    if (count == 1) {
      return SizedBox(
        width: 20.w,
        height: 20.w,
        child: HomeCollaboratorDot(
          color: SnapFitColors.accent.withOpacity(0.8),
          borderColor: borderColor,
          size: 18.w,
        ),
      );
    }

    if (count == 2) {
      return SizedBox(
        width: 32.w,
        height: 20.w,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              child: HomeCollaboratorDot(
                color: SnapFitColors.accent.withOpacity(0.8),
                borderColor: borderColor,
                size: 18.w,
              ),
            ),
            Positioned(
              left: 12.w,
              child: HomeCollaboratorDot(
                color: SnapFitColors.accentLight.withOpacity(0.8),
                borderColor: borderColor,
                size: 18.w,
              ),
            ),
          ],
        ),
      );
    }

    // 3명 이상: 2개의 점 + "+N"
    final extra = count - 2;
    return SizedBox(
      width: 46.w,
      height: 20.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            child: HomeCollaboratorDot(
              color: SnapFitColors.accent.withOpacity(0.6),
              borderColor: borderColor,
              size: 18.w,
            ),
          ),
          Positioned(
            left: 12.w,
            child: HomeCollaboratorDot(
              color: SnapFitColors.accentLight.withOpacity(0.6),
              borderColor: borderColor,
              size: 18.w,
            ),
          ),
          Positioned(
            left: 24.w,
            child: HomePlusDot(
              label: '+$extra',
              borderColor: borderColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 협업자 표시 점(디자인용 자리)
class HomeCollaboratorDots extends StatelessWidget {
  const HomeCollaboratorDots({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HomeCollaboratorDot(
          color: SnapFitColors.textMuted.withOpacity(0.7),
          borderColor: SnapFitColors.backgroundOf(context),
          size: 14.w,
        ),
        SizedBox(width: 6.w),
        HomeCollaboratorDot(
          color: SnapFitColors.textMuted.withOpacity(0.7),
          borderColor: SnapFitColors.backgroundOf(context),
          size: 14.w,
        ),
        SizedBox(width: 6.w),
        HomeCollaboratorDot(
          color: SnapFitColors.textMuted.withOpacity(0.7),
          borderColor: SnapFitColors.backgroundOf(context),
          size: 14.w,
        ),
        SizedBox(width: 8.w),
        HomePlusDot(
          label: '+3',
          borderColor: SnapFitColors.backgroundOf(context),
        ),
      ],
    );
  }
}

/// 협업자 점
class HomeCollaboratorDot extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final double size;

  const HomeCollaboratorDot({
    super.key,
    required this.color,
    required this.borderColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.w),
      ),
    );
  }
}

/// 플러스 점
class HomePlusDot extends StatelessWidget {
  final String label;
  final Color borderColor;

  const HomePlusDot({
    super.key,
    required this.label,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24.w,
      height: 24.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SnapFitColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.w),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: SnapFitColors.textPrimary,
        ),
      ),
    );
  }
}

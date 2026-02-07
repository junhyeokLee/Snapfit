import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 원형 액션 버튼. 홈 화면, 부채꼴 뷰 등에서 공통 사용.
///
/// [variant]에 따라 스타일이 다름:
/// - [CircleButtonVariant.transparent]: 반투명 흰 배경 + 흰색 아이콘 (홈 화면용)
/// - [CircleButtonVariant.white]: 흰색 배경 + 진한 회색 아이콘 (부채꼴 뷰용)
enum CircleButtonVariant {
  /// 반투명 흰 배경 + 흰색 아이콘
  transparent,

  /// 흰색 배경 + 진한 회색 아이콘
  white,
}

/// 커버 아래 중앙/우하단 등에 쓰는 원형 액션 버튼.
class CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final CircleButtonVariant variant;
  final double size;

  const CircleActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = CircleButtonVariant.transparent,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, iconColor) = switch (variant) {
      CircleButtonVariant.transparent => (
          Colors.white.withOpacity(0.25),
          Colors.white,
        ),
      CircleButtonVariant.white => (
          Colors.white,
          Colors.grey[800]!,
        ),
    };

    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size.w,
          height: size.w,
          child: Icon(icon, color: iconColor, size: 24.sp),
        ),
      ),
    );
  }
}

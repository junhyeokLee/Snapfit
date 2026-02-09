import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const _coverRadius = BorderRadius.only(
  topRight: Radius.circular(12),
  bottomRight: Radius.circular(12),
  bottomLeft: Radius.zero,
);

/// 포커스 시 앨범 생성 페이지(cover.dart)와 동일한 그림자 + 살짝 들리는 애니메이션
/// - 그림자: cover.dart _AnimatedCoverContainer와 동일 (focus 0 → 기본, focus 1 → 선택 시)
/// - 들림: scale 1.03 + 위로 살짝 이동
/// [applyShadow] false면 그림자 없음 (레이어 커버는 CoverLayout 자체 그림자 사용)
class HomeFocusWrap extends StatelessWidget {
  final double focus;
  final bool applyShadow;
  final Widget child;

  const HomeFocusWrap({
    super.key,
    required this.focus,
    required this.child,
    this.applyShadow = true,
  });

  /// 앨범 생성 페이지 cover.dart 오른쪽·아래쪽 그림자와 동일한 비율로 맞춤
  /// [scale] = 메인 커버 너비 / 앨범생성 커버 기준 너비(280)
  /// [focus] 0→1 일 때 기본 그림자에서 들어올린(animate) 그림자로 보간 → 커질 때 그림자도 함께 강해짐
  static List<BoxShadow> coverStyleShadowForScale(double scale, [double focus = 0]) {
    final baseOffset1 = const Offset(14, 12);
    final liftedOffset1 = const Offset(14, 44);
    final baseOffset2 = const Offset(24, 12);
    final liftedOffset2 = const Offset(28, 44);
    final blur1 = 1 + 10 * focus;   // 10 → 20
    final blur2 = 1 + 8 * focus;    // 10 → 18
    return [
      BoxShadow(
        color: Color.lerp(
          Colors.black.withOpacity(0.12),
          Colors.black.withOpacity(0.18),
          focus,
        )!,
        blurRadius: blur1 * scale,
        offset: Offset.lerp(baseOffset1, liftedOffset1, focus)! * scale,
      ),
      BoxShadow(
        color: Color.lerp(
          const Color(0xFF5c5d8d).withOpacity(0.12),
          const Color(0xFF5c5d8d).withOpacity(0.18),
          focus,
        )!,
        blurRadius: blur2 * scale,
        offset: Offset.lerp(baseOffset2, liftedOffset2, focus)! * scale,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scale = 0.98 + 0.15 * focus;
    // 포커스일수록 살짝 위로 들림 (픽셀)
    final translateY = -18.0 * focus;

    final content = Transform.translate(
      offset: Offset(0, translateY),
      child: Transform.scale(
        scale: scale,
        child: applyShadow
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: _coverRadius,
                  boxShadow: coverStyleShadowForScale(1.0),
                ),
                child: child,
              )
            : child,
      ),
    );
    return content;
  }
}

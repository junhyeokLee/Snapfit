import 'package:flutter/material.dart';

/// 앨범 커버 카드의 공통 border radius (오른쪽 상·하 라운드, 왼쪽 하단 직각)
const coverRadius = BorderRadius.only(
  topRight: Radius.circular(12),
  bottomRight: Radius.circular(12),
  bottomLeft: Radius.zero,
);

/// 포커스 시 앨범 생성 페이지(cover.dart)와 동일한 그림자 + 살짝 들리는 애니메이션
///
/// - 그림자: cover.dart _AnimatedCoverContainer와 동일 (focus 0 → 기본, focus 1 → 선택 시)
/// - 들림: scale 1.03 + 위로 살짝 이동
/// [applyShadow] false면 그림자 없음 (레이어 커버는 CoverLayout 자체 그림자 사용)
class FocusWrap extends StatelessWidget {
  final double focus;
  final bool applyShadow;
  final Widget child;

  const FocusWrap({
    super.key,
    required this.focus,
    required this.child,
    this.applyShadow = true,
  });

  /// 앨범 생성 페이지 cover.dart 오른쪽·아래쪽 그림자와 동일한 비율로 맞춤
  ///
  /// [scale] = 메인 커버 너비 / 앨범생성 커버 기준 너비(280)
  /// [focus] 0→1 일 때 기본 그림자에서 들어올린(animate) 그림자로 보간
  static List<BoxShadow> coverStyleShadowForScale(double scale, [double focus = 0]) {
    const baseOffset1 = Offset(14, 12);
    const liftedOffset1 = Offset(14, 44);
    const baseOffset2 = Offset(24, 12);
    const liftedOffset2 = Offset(28, 44);
    final blur1 = 1 + 10 * focus;
    final blur2 = 1 + 8 * focus;
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
    final translateY = -18.0 * focus;

    final content = Transform.translate(
      offset: Offset(0, translateY),
      child: Transform.scale(
        scale: scale,
        child: applyShadow
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: coverRadius,
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

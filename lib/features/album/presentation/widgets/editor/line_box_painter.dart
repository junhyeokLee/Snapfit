import 'package:flutter/material.dart';

/// 인스타그램 스타일: 줄마다 다른 너비의 라운드 박스를 만들고
/// 서로 자연스럽게 이어 보이도록 Path.union 으로 합치는 페인터.
class LineBoxPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final Color? boxColor;        // null이면 박스 미표시
  final double padding;         // 텍스트 안쪽 패딩 (좌/우/상/하 동일)
  final TextAlign align;        // 텍스트 정렬 (TextPainter와 동일하게 적용)

  LineBoxPainter({
    required this.text,
    required this.style,
    required this.boxColor,
    this.padding = 12.0,
    this.align = TextAlign.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (boxColor == null || text.isEmpty) return;
    const double lineVerticalGap = 6.0; // <- 여기를 늘리면 줄 간격 넓어짐

    // TextPainter로 실제 줄 나눔과 각 줄 fragment box 추출
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: null,
    )..layout(maxWidth: size.width - padding * 2);

    final boxes = tp.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    if (boxes.isEmpty) return;

    // 줄별로 묶기 (y-좌표 대략 동일한 것들끼리 그룹)
    const double eps = 0.75; // 라인 그룹핑 허용 오차(px)
    final List<List<TextBox>> lineGroups = <List<TextBox>>[];
    for (final b in boxes) {
      bool placed = false;
      for (final g in lineGroups) {
        final ref = g.first;
        if ((b.top - ref.top).abs() < eps && (b.bottom - ref.bottom).abs() < eps) {
          g.add(b);
          placed = true;
          break;
        }
      }
      if (!placed) lineGroups.add([b]);
    }

    // 각 줄을 감싸는 RRect 계산
    // 인스타처럼 연결된 느낌을 주기 위해 줄 박스 사이를 약간 겹치게(overlap) 만든다.
    const double radius = 12.0;     // 모서리 라운드
    const double overlap = 4.0;     // 줄 사이 수직 겹침(px). 값이 클수록 더 붙어 보임

    Path? merged; // 누적 union 경로
    for (final line in lineGroups) {
      // 한 줄 안에서 좌우 최솟값/최댓값을 찾는다.
      double left = line.first.left;
      double right = line.first.right;
      double top = line.first.top;
      double bottom = line.first.bottom;
      for (final b in line) {
        if (b.left < left) left = b.left;
        if (b.right > right) right = b.right;
        // top/bottom은 거의 동일
      }

      // TextPainter는 (0,0)을 기준으로 레이아웃 됨. 페인터 캔버스 좌표로 패딩 보정.
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left + padding,                 // 좌측
          top + padding - overlap,        // 위쪽은 조금 올려서 다음 줄과 겹치게
          (right - left),
          (bottom - top) + overlap * 2,   // 높이도 겹침만큼 키움
        ).inflate(padding),               // 내부 패딩 부여 (좌우/상하 동일)
        const Radius.circular(radius),
      );

      final p = Path()..addRRect(rect);
      merged = (merged == null)
          ? p
          : Path.combine(PathOperation.union, merged, p);
    }

    final paint = Paint()..color = boxColor!;
    if (merged != null) {
      canvas.drawPath(merged, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LineBoxPainter oldDelegate) {
    return text != oldDelegate.text ||
        boxColor != oldDelegate.boxColor ||
        style != oldDelegate.style ||
        align != oldDelegate.align ||
        padding != oldDelegate.padding;
  }
}
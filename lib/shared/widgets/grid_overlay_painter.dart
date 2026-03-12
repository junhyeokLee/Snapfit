import 'package:flutter/material.dart';

// 이미지 레이아웃 터치시 그리드 선 추가
class GridOverlayPainter extends CustomPainter {
  final double leftSpine;
  GridOverlayPainter({required this.leftSpine});

  @override
  void paint(Canvas canvas, Size size) {
    final startX = leftSpine;
    
    // [Center Guide] 중앙 보조선만 유지 (3x3 격자 제거)

    // [Center Guide] 중앙 보조선 추가 (스냅 라인과 시각적 조화)
    final centerPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeWidth = 1.3;
    
    final centerX = startX + (size.width - startX) / 2;
    final centerY = size.height / 2;
    
    // 세로 중앙선
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), centerPaint);
    // 가로 중앙선
    canvas.drawLine(Offset(startX, centerY), Offset(size.width, centerY), centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
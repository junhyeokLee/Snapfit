import 'package:flutter/material.dart';

// 사진첩 접근시 그리드 형태 나열
class GridGuidelinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.2;
    final double thirdW = size.width / 3;
    final double thirdH = size.height / 3;
    // Vertical lines
    for (int i = 1; i < 3; i++) {
      final x = thirdW * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (int i = 1; i < 3; i++) {
      final y = thirdH * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
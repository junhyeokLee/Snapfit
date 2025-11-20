import 'package:flutter/material.dart';

// 이미지 레이아웃 터치시 그리드 선 추가
class GridOverlayPainter extends CustomPainter {
  final double leftSpine;
  GridOverlayPainter({required this.leftSpine});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..strokeWidth = 1;
    final startX = leftSpine;
    final stepX = (size.width - startX) / 3;
    final stepY = size.height / 3;
    for (double x = startX; x <= size.width; x += stepX) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += stepY) {
      canvas.drawLine(Offset(startX, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
part of 'layer_builder.dart';

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    this.dashWidth = 4,
    this.dashSpace = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final segment = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 티켓 스텁 – 왼쪽 톱니(원형 터치선) 연출
class _TicketNotchPainter extends CustomPainter {
  final Color color;

  _TicketNotchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const cx = 6.0;
    const r = 2.5;
    final step = size.height / 5;
    for (var i = 1; i <= 4; i++) {
      final y = step * i;
      canvas.drawCircle(Offset(cx, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 리본 – 양끝 비스듬히 잘린 배너 클리퍼
class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const cut = 14.0;
    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 격자 노트 – 가로·세로 그리드 라인 (step 지정 가능)
class _GridLinePainter extends CustomPainter {
  final Color color;
  final double step;

  _GridLinePainter({required this.color, this.step = 12.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HorizontalRulePainter extends CustomPainter {
  final Color color;
  final double gap;
  final double stroke;

  const _HorizontalRulePainter({
    required this.color,
    this.gap = 18,
    this.stroke = 0.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    double y = gap * 0.5;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += gap;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalRulePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.gap != gap ||
        oldDelegate.stroke != stroke;
  }
}

/// 찢어진 메모지 전용 – 아래쪽만 톱니 찢김 (종이 뜯은 느낌)
class _TornNoteEdgeClipper extends CustomClipper<Path> {
  final double step;
  final double amp;

  _TornNoteEdgeClipper({this.step = 8.0, this.amp = 2.5});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    for (var x = size.width - step; x > 0; x -= step) {
      path.lineTo(x + step / 2, size.height - amp);
      path.lineTo(x, size.height);
    }
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) =>
      oldDelegate is _TornNoteEdgeClipper &&
      (oldDelegate.step != step || oldDelegate.amp != amp);
}

/// 찢어진 테이프 전용 – 오른쪽만 톱니 찢김 (메모지 아래 톱니와 다른 느낌)
class _TapeTornEdgeClipper extends CustomClipper<Path> {
  final double step;
  final double amp;

  _TapeTornEdgeClipper({this.step = 8.0, this.amp = 2.5});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    for (var y = step; y < size.height; y += step) {
      path.lineTo(size.width - amp, y - step / 2);
      path.lineTo(size.width, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) =>
      oldDelegate is _TapeTornEdgeClipper &&
      (oldDelegate.step != step || oldDelegate.amp != amp);
}

/// 도트 테이프 – 작은 원 패턴
class _TapeDotsPainter extends CustomPainter {
  final Color baseColor;
  final Color dotColor;

  _TapeDotsPainter({required this.baseColor, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = baseColor,
    );
    final paint = Paint()..color = dotColor;
    const spacing = 8.0;
    const r = 2.0;
    // 여백 일정: 네 면 모두 spacing 이상 비워 두고 그 안쪽에만 도트 그리기 (끝 잘림 방지)
    for (var x = spacing; x <= size.width - spacing; x += spacing) {
      for (var y = spacing; y <= size.height - spacing; y += spacing) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 이중 스트라이프 테이프 (넓은 대각 줄무늬)
class _TapeDoubleStripePainter extends CustomPainter {
  final Color baseColor;
  final Color stripeColor;

  _TapeDoubleStripePainter({
    required this.baseColor,
    required this.stripeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = baseColor,
    );
    const stripeWidth = 12.0;
    var x = -size.height * 2;
    var index = 0;
    while (x < size.width + size.height * 2) {
      final paint = Paint()
        ..color = index.isEven ? stripeColor : baseColor
        ..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(x, 0);
      path.lineTo(x + stripeWidth, 0);
      path.lineTo(x + stripeWidth + size.height, size.height);
      path.lineTo(x + size.height, size.height);
      path.close();
      canvas.drawPath(path, paint);
      x += stripeWidth;
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 마스킹 테이프 적용 시 대각 스트라이프 (라벨/노트와 구분)
class _TapeStripePainter extends CustomPainter {
  final Color baseColor;
  final Color stripeColor;

  _TapeStripePainter({required this.baseColor, required this.stripeColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = baseColor,
    );
    const stripeWidth = 6.0;
    var x = -size.height * 2;
    var index = 0;
    while (x < size.width + size.height * 2) {
      final paint = Paint()
        ..color = index.isEven ? stripeColor : baseColor
        ..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(x, 0);
      path.lineTo(x + stripeWidth, 0);
      path.lineTo(x + stripeWidth + size.height, size.height);
      path.lineTo(x + size.height, size.height);
      path.close();
      canvas.drawPath(path, paint);
      x += stripeWidth;
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 말풍선 스타일: 라운드(꼬리 0.2/0.5/0.8) / 사각형(꼬리 0/0.5/1)
class _BubbleBackgroundPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double tailPosition; // 라운드: 0.2 왼 0.5 가운데 0.8 오른 / 사각: 0 왼 0.5 가운데 1 오른
  final bool shapeSquare;

  _BubbleBackgroundPainter({
    required this.fillColor,
    required this.borderColor,
    this.tailPosition = 0.2,
    this.shapeSquare = false,
  });

  static const double _tailWidth = 18.0;
  static const double _tailHeight = 10.0;
  static const double _radius = 16.0;

  /// 꼬리가 가장자리에 붙지 않도록 여백 (자연스러운 느낌)
  static const double _tailMargin = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    // 꼬리가 잘리지 않도록 본체 높이 = 전체 - 꼬리 높이 (그리기는 size 안에 완전히 포함)
    final h = size.height - _tailHeight;

    if (shapeSquare) {
      final tailCenterX = tailPosition <= 0.25
          ? _tailMargin + _tailWidth / 2
          : tailPosition >= 0.75
          ? w - _tailMargin - _tailWidth / 2
          : w / 2;
      final tailLeft = tailCenterX - _tailWidth / 2;
      final tailRight = tailCenterX + _tailWidth / 2;
      _drawSquareBubblePath(path, w, h, tailLeft, tailRight, tailCenterX);
    } else {
      final r = _radius;
      final minX = r + _tailMargin + _tailWidth / 2;
      final maxX = w - r - _tailMargin - _tailWidth / 2;
      // 라운드: 왼쪽(0.28) / 가운데(0.5) / 오른쪽(0.72) — 비율이 아닌 구간으로 명시 적용
      final bool isLeft = tailPosition < 0.4;
      final bool isRight = tailPosition > 0.6;
      final tailCenterX = minX <= maxX
          ? (isLeft
                ? minX
                : isRight
                ? maxX
                : w / 2)
          : (isLeft
                ? (r + _tailWidth / 2)
                : isRight
                ? (w - r - _tailWidth / 2)
                : w / 2);
      final tailLeft = tailCenterX - _tailWidth / 2;
      final tailRight = tailCenterX + _tailWidth / 2;
      _drawRoundBubblePath(path, w, h, tailLeft, tailRight, tailCenterX);
    }

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  /// 라운드 말풍선: 둥근 사각형 본체 + 하단 평평한 구간에 꼬리 연결 (한 경로, 여백 없음)
  void _drawRoundBubblePath(
    Path path,
    double w,
    double h,
    double tailLeft,
    double tailRight,
    double tailCenterX,
  ) {
    final r = _radius;
    path.moveTo(tailLeft, h);
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));
    path.lineTo(tailRight, h);
    path.lineTo(tailCenterX, h + _tailHeight);
    path.lineTo(tailLeft, h);
    path.close();
  }

  /// 사각형 말풍선: 직사각형 본체 + 꼬리 왼/가운데/오른쪽 (한 경로, 여백 없음)
  void _drawSquareBubblePath(
    Path path,
    double w,
    double h,
    double tailLeft,
    double tailRight,
    double tailCenterX,
  ) {
    path.moveTo(tailLeft, h);
    path.lineTo(0, h);
    path.lineTo(0, 0);
    path.lineTo(w, 0);
    path.lineTo(w, h);
    path.lineTo(tailRight, h);
    path.lineTo(tailCenterX, h + _tailHeight);
    path.lineTo(tailLeft, h);
    path.close();
  }

  @override
  bool shouldRepaint(covariant _BubbleBackgroundPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.tailPosition != tailPosition ||
        oldDelegate.shapeSquare != shapeSquare;
  }
}

// 노트 스타일: 아래 찢어진 종이 효과
class _TornPaperClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - 4);

    // 아랫부분 찢어진 효과
    const step = 8.0;
    double x = size.width;
    bool up = true;
    while (x > 0) {
      x -= step;
      final y = size.height - (up ? 0 : 4);
      path.lineTo(x.clamp(0, size.width), y);
      up = !up;
    }

    path.lineTo(0, size.height - 4);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RoughEdgePaperClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, 0);
    const topStep = 12.0;
    const sideStep = 10.0;
    const bottomStep = 8.0;

    double x = 0;
    bool topDown = false;
    while (x < size.width) {
      x += topStep;
      path.lineTo(x.clamp(0, size.width).toDouble(), topDown ? 1.2 : 0.0);
      topDown = !topDown;
    }

    double y = 0;
    bool rightIn = false;
    while (y < size.height) {
      y += sideStep;
      path.lineTo(
        rightIn ? size.width - 1.4 : size.width,
        y.clamp(0, size.height).toDouble(),
      );
      rightIn = !rightIn;
    }

    x = size.width;
    bool up = true;
    while (x > 0) {
      x -= bottomStep;
      path.lineTo(
        x.clamp(0, size.width).toDouble(),
        size.height - (up ? 0.0 : 5.0),
      );
      up = !up;
    }

    y = size.height;
    bool leftIn = true;
    while (y > 0) {
      y -= sideStep;
      path.lineTo(leftIn ? 1.4 : 0.0, y.clamp(0, size.height).toDouble());
      leftIn = !leftIn;
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// (중앙 찢김 스크래치용 CustomPainter들은 찢김 스티커 제거에 따라 삭제되었습니다)
// Film strip painter: 양쪽에 4개씩 연한 타공(perforation) — 레퍼런스 빈티지 필름 스트립
class _FilmHolePainterV2 extends CustomPainter {
  static const int holesPerSide = 4;
  static const double holeW = 5.0;
  static const double holeH = 5.0;
  static const Color holeColor = Color(0xFF3D4556);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = holeColor
      ..style = PaintingStyle.fill;
    final leftX = 2.0;
    final rightX = size.width - 2.0 - holeW;
    final totalGap = size.height - (holesPerSide * holeH);
    final gap = holesPerSide > 1 ? totalGap / (holesPerSide + 1) : totalGap / 2;

    for (int i = 0; i < holesPerSide; i++) {
      final y = gap + i * (holeH + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(leftX, y, holeW, holeH),
        const Radius.circular(1),
      );
      canvas.drawRRect(rect, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rightX, y, holeW, holeH),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Sketch frame painter for _frameSketch
class _SketchFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(4, 8);
    path.lineTo(size.width - 4, 4);
    path.lineTo(size.width - 6, size.height - 6);
    path.lineTo(6, size.height - 4);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// VHS 스캔라인
class _VhsScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 네온 코너 L자
class _NeonCornerLPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const r = 6.0;
    canvas.drawPath(
      Path()
        ..moveTo(0, r)
        ..lineTo(0, 0)
        ..lineTo(r, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BlobClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.10, h * 0.30);
    path.cubicTo(w * 0.02, h * 0.12, w * 0.18, h * 0.02, w * 0.36, h * 0.08);
    path.cubicTo(w * 0.54, h * 0.14, w * 0.66, h * 0.03, w * 0.82, h * 0.10);
    path.cubicTo(w * 0.95, h * 0.16, w * 0.99, h * 0.32, w * 0.90, h * 0.45);
    path.cubicTo(w * 0.84, h * 0.54, w * 0.84, h * 0.66, w * 0.88, h * 0.78);
    path.cubicTo(w * 0.92, h * 0.91, w * 0.74, h * 0.98, w * 0.58, h * 0.93);
    path.cubicTo(w * 0.42, h * 0.89, w * 0.30, h * 0.99, w * 0.18, h * 0.90);
    path.cubicTo(w * 0.06, h * 0.82, w * 0.02, h * 0.62, w * 0.08, h * 0.50);
    path.cubicTo(w * 0.13, h * 0.41, w * 0.15, h * 0.36, w * 0.10, h * 0.30);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.5, h * 0.97);
    path.cubicTo(w * 0.16, h * 0.78, w * 0.03, h * 0.50, w * 0.05, h * 0.28);
    path.cubicTo(w * 0.07, h * 0.10, w * 0.20, h * 0.02, w * 0.33, h * 0.02);
    path.cubicTo(w * 0.42, h * 0.02, w * 0.49, h * 0.10, w * 0.50, h * 0.20);
    path.cubicTo(w * 0.51, h * 0.10, w * 0.58, h * 0.02, w * 0.67, h * 0.02);
    path.cubicTo(w * 0.80, h * 0.02, w * 0.93, h * 0.10, w * 0.95, h * 0.28);
    path.cubicTo(w * 0.97, h * 0.50, w * 0.84, h * 0.78, w * 0.50, h * 0.97);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HeartFramePainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final double shadowBlur;

  _HeartFramePainter({
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.shadowBlur,
  });

  Path _heartPath(Size size) => _HeartClipper().getClip(size);

  @override
  void paint(Canvas canvas, Size size) {
    final path = _heartPath(size);
    canvas.drawShadow(path, const Color(0x22000000), shadowBlur, false);
    final fill = Paint()..color = fillColor;
    final stroke =
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _HeartFramePainter oldDelegate) {
    return fillColor != oldDelegate.fillColor ||
        strokeColor != oldDelegate.strokeColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        shadowBlur != oldDelegate.shadowBlur;
  }
}

class _PaperNoisePainter extends CustomPainter {
  final double opacity;

  const _PaperNoisePainter({this.opacity = 0.08});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final int seed =
        (size.width.floor() * 31) ^ (size.height.floor() * 17) ^ 0x5f3759df;
    final rnd = math.Random(seed);
    final count = (size.width * size.height / 240).clamp(80, 420).toInt();
    for (int i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = 0.35 + (rnd.nextDouble() * 0.85);
      final alpha = (0.05 + rnd.nextDouble() * opacity)
          .clamp(0.03, 0.18)
          .toDouble();
      paint.color =
          (i.isEven ? const Color(0xFFB79D80) : const Color(0xFFE7D7C0))
              .withOpacity(alpha);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperNoisePainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

class _TornBottomEdgeShadowPainter extends CustomPainter {
  final Color color;

  const _TornBottomEdgeShadowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color.withOpacity(0.26);
    final path = Path();
    final y = size.height - 6;
    path.moveTo(0, y);
    const step = 8.0;
    double x = 0;
    bool up = true;
    while (x < size.width) {
      x += step;
      path.lineTo(x.clamp(0, size.width).toDouble(), y - (up ? 1.2 : -0.8));
      up = !up;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TornBottomEdgeShadowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TinyHandwritingPainter extends CustomPainter {
  final Color color;

  const _TinyHandwritingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final gap = (size.height / 5).clamp(7.0, 10.0);
    for (int i = 0; i < 4; i++) {
      final y = 2 + (i * gap);
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * 0.18, y - 1.6, size.width * 0.34, y)
        ..quadraticBezierTo(size.width * 0.52, y + 1.5, size.width * 0.68, y)
        ..quadraticBezierTo(size.width * 0.84, y - 1.2, size.width, y + 0.8);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TinyHandwritingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _StarStickerPainter extends CustomPainter {
  final Color fillColor;
  final int points;
  final double innerFactor;

  const _StarStickerPainter({
    required this.fillColor,
    this.points = 7,
    this.innerFactor = 0.44,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.shortestSide * 0.48;
    final inner = outer * innerFactor;
    final path = Path();
    final step = 3.141592653589793 / points;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -3.141592653589793 / 2 + (step * i);
      final p = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fillColor);
  }

  @override
  bool shouldRepaint(covariant _StarStickerPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.points != points ||
        oldDelegate.innerFactor != innerFactor;
  }
}

class _PaperClipPainter extends CustomPainter {
  final Color color;

  const _PaperClipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1;
    final inner = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final p1 = Path()
      ..moveTo(size.width * 0.72, size.height * 0.08)
      ..quadraticBezierTo(
        size.width * 0.92,
        size.height * 0.12,
        size.width * 0.86,
        size.height * 0.34,
      )
      ..lineTo(size.width * 0.62, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.56,
        size.height * 0.94,
        size.width * 0.44,
        size.height * 0.90,
      )
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.84,
        size.width * 0.40,
        size.height * 0.66,
      )
      ..lineTo(size.width * 0.62, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.18,
        size.width * 0.58,
        size.height * 0.16,
      )
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.12,
        size.width * 0.42,
        size.height * 0.22,
      );
    final p2 = Path()
      ..moveTo(size.width * 0.56, size.height * 0.30)
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.20,
        size.width * 0.54,
        size.height * 0.20,
      )
      ..quadraticBezierTo(
        size.width * 0.46,
        size.height * 0.20,
        size.width * 0.42,
        size.height * 0.29,
      )
      ..lineTo(size.width * 0.22, size.height * 0.66)
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.84,
        size.width * 0.28,
        size.height * 0.94,
      );
    canvas.drawPath(p1, outer);
    canvas.drawPath(p2, inner);
  }

  @override
  bool shouldRepaint(covariant _PaperClipPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RibbonStickerPainter extends CustomPainter {
  final Color color;
  final Color shadeColor;

  const _RibbonStickerPainter({required this.color, required this.shadeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final knot = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.36),
      width: size.width * 0.32,
      height: size.height * 0.28,
    );
    final leftLoop = Path()
      ..moveTo(size.width * 0.18, size.height * 0.34)
      ..quadraticBezierTo(
        size.width * 0.02,
        size.height * 0.20,
        size.width * 0.26,
        size.height * 0.10,
      )
      ..quadraticBezierTo(
        size.width * 0.44,
        size.height * 0.18,
        size.width * 0.40,
        size.height * 0.34,
      )
      ..close();
    final rightLoop = Path()
      ..moveTo(size.width * 0.82, size.height * 0.34)
      ..quadraticBezierTo(
        size.width * 0.98,
        size.height * 0.20,
        size.width * 0.74,
        size.height * 0.10,
      )
      ..quadraticBezierTo(
        size.width * 0.56,
        size.height * 0.18,
        size.width * 0.60,
        size.height * 0.34,
      )
      ..close();
    final leftTail = Path()
      ..moveTo(size.width * 0.44, size.height * 0.46)
      ..lineTo(size.width * 0.34, size.height * 0.98)
      ..lineTo(size.width * 0.54, size.height * 0.75)
      ..close();
    final rightTail = Path()
      ..moveTo(size.width * 0.56, size.height * 0.46)
      ..lineTo(size.width * 0.66, size.height * 0.98)
      ..lineTo(size.width * 0.46, size.height * 0.75)
      ..close();

    canvas.drawPath(leftLoop, Paint()..color = color);
    canvas.drawPath(rightLoop, Paint()..color = color);
    canvas.drawRect(knot, Paint()..color = shadeColor);
    canvas.drawPath(leftTail, Paint()..color = shadeColor);
    canvas.drawPath(rightTail, Paint()..color = shadeColor);
  }

  @override
  bool shouldRepaint(covariant _RibbonStickerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.shadeColor != shadeColor;
  }
}

class _FlowerStickerPainter extends CustomPainter {
  final Color petalColor;
  final Color centerColor;
  final int petalCount;

  const _FlowerStickerPainter({
    required this.petalColor,
    required this.centerColor,
    this.petalCount = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final petalR = size.shortestSide * 0.24;
    final orbit = size.shortestSide * 0.22;
    for (int i = 0; i < petalCount; i++) {
      final a = (i / petalCount) * 3.141592653589793 * 2;
      final p = Offset(
        center.dx + orbit * math.cos(a),
        center.dy + orbit * math.sin(a),
      );
      canvas.drawCircle(p, petalR, Paint()..color = petalColor);
    }
    canvas.drawCircle(
      center,
      size.shortestSide * 0.17,
      Paint()..color = centerColor,
    );
    canvas.drawCircle(
      center,
      size.shortestSide * 0.17,
      Paint()
        ..color = Colors.black.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _FlowerStickerPainter oldDelegate) {
    return oldDelegate.petalColor != petalColor ||
        oldDelegate.centerColor != centerColor ||
        oldDelegate.petalCount != petalCount;
  }
}

class _CatDoodlePainter extends CustomPainter {
  final Color color;

  const _CatDoodlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final fill = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.28,
        size.width * 0.56,
        size.height * 0.5,
      ),
      Radius.circular(size.width * 0.2),
    );
    final earL = Path()
      ..moveTo(size.width * 0.36, size.height * 0.31)
      ..lineTo(size.width * 0.28, size.height * 0.12)
      ..lineTo(size.width * 0.46, size.height * 0.26)
      ..close();
    final earR = Path()
      ..moveTo(size.width * 0.64, size.height * 0.31)
      ..lineTo(size.width * 0.72, size.height * 0.12)
      ..lineTo(size.width * 0.54, size.height * 0.26)
      ..close();

    canvas.drawPath(earL, fill);
    canvas.drawPath(earR, fill);
    canvas.drawRRect(body, fill);
    canvas.drawPath(earL, stroke);
    canvas.drawPath(earR, stroke);
    canvas.drawRRect(body, stroke);
    canvas.drawCircle(
      Offset(size.width * 0.43, size.height * 0.49),
      2.0,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(size.width * 0.57, size.height * 0.49),
      2.0,
      Paint()..color = color,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.5, size.height * 0.57),
        radius: size.width * 0.06,
      ),
      0.15,
      2.8,
      false,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _CatDoodlePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ScribbleStickerPainter extends CustomPainter {
  final Color color;

  const _ScribbleStickerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.18,
        size.width * 0.34,
        size.height * 0.56,
      )
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.92,
        size.width * 0.64,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.79,
        size.height * 0.02,
        size.width * 0.92,
        size.height * 0.38,
      );
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _ScribbleStickerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _BrushStrokeStickerPainter extends CustomPainter {
  final Color color;

  const _BrushStrokeStickerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color.withOpacity(0.9);
    final path = Path()
      ..moveTo(size.width * 0.02, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.16,
        size.width * 0.42,
        size.height * 0.35,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.58,
        size.width * 0.98,
        size.height * 0.33,
      )
      ..lineTo(size.width * 0.95, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.9,
        size.width * 0.45,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.56,
        size.width * 0.04,
        size.height * 0.84,
      )
      ..close();
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant _BrushStrokeStickerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _BlobStickerPainter extends CustomPainter {
  final Color color;

  const _BlobStickerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color.withOpacity(0.95);
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * -0.05,
        size.width * 0.76,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 1.02,
        size.height * 0.4,
        size.width * 0.84,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.64,
        size.height * 0.98,
        size.width * 0.35,
        size.height * 0.88,
      )
      ..quadraticBezierTo(
        size.width * 0.04,
        size.height * 0.76,
        size.width * 0.12,
        size.height * 0.48,
      )
      ..close();
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant _BlobStickerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ArrowDoodlePainter extends CustomPainter {
  final Color color;

  const _ArrowDoodlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final line = Path()
      ..moveTo(size.width * 0.08, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.28,
        size.width * 0.9,
        size.height * 0.56,
      );
    canvas.drawPath(line, p);
    final head = Path()
      ..moveTo(size.width * 0.72, size.height * 0.41)
      ..lineTo(size.width * 0.9, size.height * 0.56)
      ..lineTo(size.width * 0.76, size.height * 0.74);
    canvas.drawPath(head, p);
  }

  @override
  bool shouldRepaint(covariant _ArrowDoodlePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _LeafCornerPainter extends CustomPainter {
  final Color color;
  final bool mirror;

  const _LeafCornerPainter({required this.color, required this.mirror});

  @override
  void paint(Canvas canvas, Size size) {
    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final branch = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.04
      ..strokeCap = StrokeCap.round;
    final leafPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final branchPath = Path()
      ..moveTo(size.width * 0.02, size.height * 0.98)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.72,
        size.width * 0.32,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.18,
        size.width * 0.84,
        size.height * 0.04,
      );
    canvas.drawPath(branchPath, branch);

    void drawLeaf(double x, double y, double w, double h, double tilt) {
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.rotate(tilt);
      final leaf = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * w,
          height: size.height * h,
        ),
        Radius.circular(size.shortestSide * 0.2),
      );
      canvas.drawRRect(leaf, leafPaint);
      canvas.restore();
    }

    drawLeaf(0.22, 0.69, 0.12, 0.18, -0.8);
    drawLeaf(0.32, 0.55, 0.11, 0.17, -0.55);
    drawLeaf(0.45, 0.42, 0.105, 0.16, -0.35);
    drawLeaf(0.59, 0.28, 0.1, 0.15, -0.25);
    drawLeaf(0.72, 0.16, 0.09, 0.14, -0.1);
  }

  @override
  bool shouldRepaint(covariant _LeafCornerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.mirror != mirror;
  }
}

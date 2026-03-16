import 'dart:async';
import 'package:flutter/material.dart';

/// 🔺 인스타그램 스타일 커스텀 세로 슬라이더 (트라이앵글 UI)
/// - Drag 전: 기본 디자인 (예: 얇은 세로 바 + 원형 thumb)
/// - Drag 중: 삼각형 형태 표시 + thumb 따라다님
/// - 드러그 시 value 변환 가능 (0.8 ~ 2.5 등)
class TriangleSlider extends StatefulWidget {
  final double min;
  final double max;
  final double value;
  final double height;
  final ValueChanged<double> onChanged;

  /// 슬라이더 감도(곡선 지수). 1.0=선형, 값이 커질수록 초반 미세/후반 급격.
  final double responseExponent;

  final Color? trackColor;
  final Color? triangleColor;
  final Color? thumbColor;

  const TriangleSlider({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.height = 150,
    this.trackColor,
    this.triangleColor,
    this.thumbColor,
    this.responseExponent = 1.6,
  });

  @override
  State<TriangleSlider> createState() => _TriangleSliderState();
}

class _TriangleSliderState extends State<TriangleSlider>
    with SingleTickerProviderStateMixin {
  double? _thumbY;
  bool _isDragging = false;

  late AnimationController _controller;
  late Animation<double> _triangleOpacity;

  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    _thumbY = _valueToOffset(widget.value);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _triangleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _controller.forward();
    _fadeTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted && !_isDragging) {
        _controller.reverse();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TriangleSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_isDragging) {
      _thumbY = _valueToOffset(widget.value);
    }
    _thumbY ??= _valueToOffset(widget.value);
  }

  double _valueToOffset(double value) {
    const thumbMargin = 12.0;
    final range = (widget.max - widget.min).clamp(1e-6, double.infinity);
    final t = ((value - widget.min) / range).clamp(
      0.0,
      1.0,
    ); // 0 at min, 1 at max
    final usableHeight = widget.height - (thumbMargin * 2);
    // Invert: min -> bottom, max -> top
    return (1.0 - t) * usableHeight + thumbMargin;
  }

  double _offsetToValue(double dy) {
    const thumbMargin = 12.0;
    final usableHeight = widget.height - (thumbMargin * 2);
    final clamped =
        dy.clamp(thumbMargin, widget.height - thumbMargin) - thumbMargin;
    final p = (clamped / usableHeight).clamp(0.0, 1.0); // 0 at top, 1 at bottom
    final t = 1.0 - p; // invert back so top=1 (max), bottom=0 (min)
    return widget.min + t * (widget.max - widget.min);
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTrack = isDark
        ? const Color(0x66FFFFFF)
        : const Color(0x66121212);
    final defaultTriangle = isDark
        ? const Color(0x22FFFFFF)
        : const Color(0x22121212);
    final defaultThumb = isDark ? Colors.white : const Color(0xFF121212);
    return SizedBox(
      height: widget.height,
      width: 80, // original hit area
      child: GestureDetector(
        behavior:
            HitTestBehavior.opaque, // Capture touches in transparent areas
        onVerticalDragStart: (d) {
          _fadeTimer?.cancel();
          setState(() => _isDragging = true);
          _controller.duration = const Duration(milliseconds: 160);
          _controller.forward();
        },
        onVerticalDragUpdate: (d) {
          final box = context.findRenderObject() as RenderBox;
          final local = box.globalToLocal(d.globalPosition);
          final newValue = _offsetToValue(
            local.dy,
          ).clamp(widget.min, widget.max);
          final clampedY = local.dy.clamp(12.0, widget.height - 12.0);
          setState(() => _thumbY = clampedY);
          widget.onChanged(newValue);
        },
        onVerticalDragEnd: (_) {
          setState(() => _isDragging = false);
          _controller.duration = const Duration(
            milliseconds: 180,
          ); // Faster reverse animation
          _fadeTimer = Timer(const Duration(milliseconds: 180), () {
            if (mounted && !_isDragging) {
              _controller.reverse();
            }
          });
        },
        child: AnimatedBuilder(
          animation: _triangleOpacity,
          builder: (context, child) {
            return CustomPaint(
              painter: _TriangleSliderPainter(
                height: widget.height,
                thumbY: _thumbY ?? _valueToOffset(widget.value),
                isDragging: _isDragging,
                triangleOpacity: _triangleOpacity.value,
                trackColor: widget.trackColor ?? defaultTrack,
                triangleColor: widget.triangleColor ?? defaultTriangle,
                thumbColor: widget.thumbColor ?? defaultThumb,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TriangleSliderPainter extends CustomPainter {
  final double height;
  final double thumbY;
  final bool isDragging;

  final double triangleOpacity;

  final Color trackColor;
  final Color triangleColor;
  final Color thumbColor;

  _TriangleSliderPainter({
    required this.height,
    required this.thumbY,
    required this.isDragging,
    required this.triangleOpacity,
    required this.trackColor,
    required this.triangleColor,
    required this.thumbColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double easedOpacity = Curves.easeOut.transform(triangleOpacity);
    final double dragOffset = 16.0 * easedOpacity;
    final centerX = size.width / 2 + dragOffset;

    // 기본 트랙
    final trackPaint = Paint()
      ..color = triangleColor.withOpacity(0.5)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, height), trackPaint);

    // 삼각형 (항상 그리되, opacity로 제어)
    if (triangleOpacity > 0.1) {
      final Rect triRect = Rect.fromLTWH(centerX - 12, 0, 24, height);
      final double triangleWidthFactor = easedOpacity;
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          triangleColor.withOpacity(0.5),
          triangleColor.withOpacity(0.5),
        ],
      ).createShader(triRect);
      final trianglePaint = Paint()..shader = gradient;
      final double halfWidth = 12 * triangleWidthFactor;
      final triangle = Path()
        ..moveTo(centerX, height) // pointed bottom
        ..lineTo(centerX + halfWidth, 0) // top right wide
        ..lineTo(centerX - halfWidth, 0) // top left wide
        ..close();
      canvas.drawPath(triangle, trianglePaint);
    }

    // Thumb
    canvas.drawCircle(Offset(centerX, thumbY), 8, Paint()..color = thumbColor);
  }

  @override
  bool shouldRepaint(covariant _TriangleSliderPainter oldDelegate) =>
      oldDelegate.thumbY != thumbY ||
      oldDelegate.isDragging != isDragging ||
      oldDelegate.triangleOpacity != triangleOpacity;
}

import 'dart:typed_data';
import 'dart:ui' as ui;

// JavaScript에서 수집한 Canvas 2D 명령만 재생한다. 곡면·투영 계산은 하지 않는다.
void paintApprovedCanvasReference(
  ui.Canvas canvas,
  List<dynamic> ops,
  List<ui.Image> images,
) {
  var path = ui.Path();
  Object? style = '#000000';
  final styles = <Object?>[];
  for (final raw in ops) {
    final op = raw as Map;
    final args = (op['args'] as List?) ?? const [];
    double number(int index) => (args[index] as num).toDouble();
    switch (op['op']) {
      case 'save':
        canvas.save();
        styles.add(style);
        break;
      case 'restore':
        canvas.restore();
        style = styles.removeLast();
        break;
      case 'beginPath':
        path = ui.Path();
        break;
      case 'moveTo':
        path.moveTo(number(0), number(1));
        break;
      case 'lineTo':
        path.lineTo(number(0), number(1));
        break;
      case 'closePath':
        path.close();
        break;
      case 'clip':
        canvas.clipPath(path, doAntiAlias: true);
        break;
      case 'transform':
        canvas.transform(
          Float64List.fromList([
            number(0),
            number(1),
            0,
            0,
            number(2),
            number(3),
            0,
            0,
            0,
            0,
            1,
            0,
            number(4),
            number(5),
            0,
            1,
          ]),
        );
        break;
      case 'fillStyle':
        style = op['value'];
        break;
      case 'fill':
        canvas.drawPath(path, _approvedPaint(style));
        break;
      case 'fillRect':
        canvas.drawRect(
          ui.Rect.fromLTWH(number(0), number(1), number(2), number(3)),
          _approvedPaint(style),
        );
        break;
      case 'drawImage':
        final image = images[(args[0] as num).toInt()];
        final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
        if (args.length == 3) {
          canvas.drawImage(image, ui.Offset(number(1), number(2)), paint);
        } else if (args.length == 5 || args.length == 9) {
          final source = args.length == 5
              ? ui.Rect.fromLTWH(
                  0,
                  0,
                  image.width.toDouble(),
                  image.height.toDouble(),
                )
              : ui.Rect.fromLTWH(number(1), number(2), number(3), number(4));
          final offset = args.length == 5 ? 1 : 5;
          canvas.drawImageRect(
            image,
            source,
            ui.Rect.fromLTWH(
              number(offset),
              number(offset + 1),
              number(offset + 2),
              number(offset + 3),
            ),
            paint,
          );
        } else {
          throw ArgumentError(
            'Unsupported drawImage argument count: ${args.length}',
          );
        }
        break;
      default:
        throw ArgumentError(
          'Unsupported approved Canvas operation: ${op['op']}',
        );
    }
  }
}

ui.Paint _approvedPaint(Object? style) {
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
  if (style is String) return paint..color = _approvedCssColor(style);
  final gradient = (style as Map)['gradient'] as Map;
  final stops = gradient['stops'] as List;
  return paint
    ..shader = ui.Gradient.linear(
      ui.Offset(
        (gradient['x0'] as num).toDouble(),
        (gradient['y0'] as num).toDouble(),
      ),
      ui.Offset(
        (gradient['x1'] as num).toDouble(),
        (gradient['y1'] as num).toDouble(),
      ),
      [
        for (final stop in stops)
          _approvedCssColor((stop as List)[1] as String),
      ],
      [for (final stop in stops) ((stop as List)[0] as num).toDouble()],
    );
}

ui.Color _approvedCssColor(String source) {
  final value = source.trim();
  if (value == 'transparent') return const ui.Color(0x00000000);
  if (value.startsWith('#')) {
    var hex = value.substring(1);
    if (hex.length == 3 || hex.length == 4) {
      hex = hex.split('').map((digit) => '$digit$digit').join();
    }
    if (hex.length == 6)
      return ui.Color(0xFF000000 | int.parse(hex, radix: 16));
    if (hex.length == 8) {
      return ui.Color.fromARGB(
        int.parse(hex.substring(6, 8), radix: 16),
        int.parse(hex.substring(0, 2), radix: 16),
        int.parse(hex.substring(2, 4), radix: 16),
        int.parse(hex.substring(4, 6), radix: 16),
      );
    }
  }
  if (value.startsWith('rgb')) {
    final parts = value
        .substring(value.indexOf('(') + 1, value.lastIndexOf(')'))
        .split(',')
        .map((part) => part.trim())
        .toList();
    return ui.Color.fromRGBO(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      parts.length == 4 ? double.parse(parts[3]) : 1.0,
    );
  }
  throw ArgumentError('Unsupported approved Canvas color: $source');
}

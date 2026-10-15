import 'package:flutter/material.dart';

/// Keep short Korean names from leaving a single syllable on the second line.
class CatalogItemTitle extends StatelessWidget {
  const CatalogItemTitle(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      double width(String value) {
        final painter = TextPainter(
          text: TextSpan(text: value, style: style),
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        final result = painter.width;
        painter.dispose();
        return result;
      }

      var display = text;
      final words = text.split(' ');
      if (words.length > 1 &&
          words.length <= 12 &&
          width(text) > box.maxWidth) {
        var best = double.infinity;
        for (var i = 1; i < words.length; i++) {
          final left = words.take(i).join(' '), right = words.skip(i).join(' ');
          final a = width(left), b = width(right);
          if (a <= box.maxWidth && b <= box.maxWidth && (a - b).abs() < best) {
            best = (a - b).abs();
            display = '$left\n$right';
          }
        }
      }
      return Text(
        display,
        semanticsLabel: text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    },
  );
}

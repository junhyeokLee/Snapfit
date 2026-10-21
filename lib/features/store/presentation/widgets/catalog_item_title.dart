import 'package:flutter/material.dart';

/// Keep short Korean names from leaving a single syllable on the second line.
class CatalogItemTitle extends StatefulWidget {
  const CatalogItemTitle(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<CatalogItemTitle> createState() => _CatalogItemTitleState();
}

class _CatalogItemTitleState extends State<CatalogItemTitle> {
  Object? _layoutKey;
  String _display = '';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final text = widget.text;
      final style = widget.style;
      final key = (text, style, box.maxWidth, scaler, direction);
      if (_layoutKey == key) {
        return Text(
          _display,
          semanticsLabel: text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      }
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
      _layoutKey = key;
      _display = display;
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

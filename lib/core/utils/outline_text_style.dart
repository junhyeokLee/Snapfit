import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Derived at render time so saved text remains editable and resolution independent.
TextStyle outlineTextStyle(TextStyle style) => style.copyWith(
  foreground: Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = (style.fontSize ?? 14) * .018
    ..color = style.color ?? Colors.black,
);

/// A fine paper edge without the historical sticker's red offset ink.
TextStyle paperCutTextStyle(TextStyle style) {
  final u = style.fontSize ?? 14;
  return style.copyWith(
    shadows: [
      Shadow(
        color: const Color(0x30202020),
        offset: Offset(u * .012, u * .025),
        blurRadius: u * .022,
      ),
      for (var i = 0; i < 20; i++)
        Shadow(
          color: const Color(0xFFFEFEFA),
          offset:
              Offset(math.cos(i * math.pi / 10), math.sin(i * math.pi / 10)) *
              u *
              .025,
        ),
    ],
  );
}

/// A die-cut white edge and a hard offset print, without duplicating text layers.
TextStyle stickerTextStyle(TextStyle style) {
  final u = style.fontSize ?? 14;
  return style.copyWith(
    shadows: [
      Shadow(
        color: const Color(0xFF92293E),
        offset: Offset(u * .075, u * .075),
      ),
      for (var i = 0; i < 20; i++)
        Shadow(
          color: const Color(0xFFFFFEFA),
          offset:
              Offset(math.cos(i * math.pi / 10), math.sin(i * math.pi / 10)) *
              u *
              .034,
        ),
    ],
  );
}

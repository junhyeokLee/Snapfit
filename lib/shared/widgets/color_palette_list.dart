import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../web/web_design.dart';

import '../../core/constants/snapfit_colors.dart';
import 'no_glow.dart';

/// 색상 팔레트 리스트 (옵션 영역)
class ColorPaletteList extends StatelessWidget {
  final List<Color> colors;
  final Color current;
  final ValueChanged<Color> onPick;
  final ScrollController? controller;
  const ColorPaletteList({
    super.key,
    required this.colors,
    required this.current,
    required this.onPick,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Wrap(spacing: 4, runSpacing: 4, children: [
        for (final color in colors) _colorDot(context, color, current, onPick),
      ]);
    }
    return SizedBox(
      height: 56,
      child: ScrollConfiguration(
        behavior: const NoGlow(),
        child: ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemBuilder: (context, i) =>
              _colorDot(context, colors[i], current, onPick),
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemCount: colors.length,
        ),
      ),
    );
  }

  Widget _colorDot(
    BuildContext context,
    Color color,
    Color current,
    ValueChanged<Color> onTap,
  ) {
    final selected = color == current;
    final label =
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onTap(color),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: kIsWeb ? WebPalette.of(context).ink.withValues(alpha: .6) : SnapFitColors.textPrimaryOf(
                        context,
                      ).withValues(alpha: .6),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: color.computeLuminance() > .5
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

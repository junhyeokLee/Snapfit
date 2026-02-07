import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'no_glow.dart';


/// 색상 팔레트 리스트 (옵션 영역)
class ColorPaletteList extends StatelessWidget {
  final List<Color> colors;
  final Color current;
  final ValueChanged<Color> onPick;
  final ScrollController? controller;
  const ColorPaletteList({super.key,
    required this.colors,
    required this.current,
    required this.onPick,
    this.controller
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48.h,
      child: ScrollConfiguration(
        behavior: const NoGlow(),
        child: ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          itemBuilder: (_, i) => _colorDot(colors[i], current, onPick),
          separatorBuilder: (_, __) => SizedBox(width: 12.w),
          itemCount: colors.length,
        ),
      ),
    );
  }

  Widget _colorDot(Color color, Color current, ValueChanged<Color> onTap) {
    return GestureDetector(
      onTap: () => onTap(color),
      child: Container(
        width: 28.w,
        height: 28.w,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: Colors.white, width: 1),
        ),
      ),
    );
  }
}

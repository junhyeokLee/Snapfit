import 'package:flutter/material.dart';

import '../../core/constants/snapfit_colors.dart';

/// SnapFit 공통 그라데이션 배경
class SnapFitGradientBackground extends StatelessWidget {
  final Widget child;

  const SnapFitGradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      decoration: isDark
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: SnapFitColors.editorGradientOf(context),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            )
          : BoxDecoration(
              color: SnapFitColors.backgroundOf(context),
            ),
      child: child,
    );
  }
}

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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: SnapFitColors.editorGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}

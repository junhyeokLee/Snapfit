import 'package:flutter/material.dart';

import '../../core/constants/snapfit_colors.dart';

/// 중요 버튼용 Primary Gradient 배경
class SnapFitPrimaryGradientBackground extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;

  const SnapFitPrimaryGradientBackground({
    super.key,
    required this.child,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: SnapFitColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

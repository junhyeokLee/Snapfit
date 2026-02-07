import 'package:flutter/material.dart';

/// SnapFit 앱 공통 그라데이션 배경 (보라-회색 계열)
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
          colors: [Color(0xFF7d7a97), Color(0xFF9893a9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}

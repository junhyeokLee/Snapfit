import 'package:flutter/material.dart';
import '../../core/theme/snapfit_design_tokens.dart';

/// Animated shimmer placeholder for loading states.
/// Wrap one or more [SnapFitShimmerBox] widgets to build skeleton layouts.
///
/// Example:
/// ```dart
/// SnapFitShimmer(child: SnapFitShimmerTemplateTile(ratio: .98))
/// ```
class SnapFitShimmer extends StatefulWidget {
  const SnapFitShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<SnapFitShimmer> createState() => _SnapFitShimmerState();
}

class _SnapFitShimmerState extends State<SnapFitShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SnapFitMotion.reduced(context)) return widget.child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2C3533) : const Color(0xFFECEDE8);
    final highlight = dark ? const Color(0xFF3E4846) : const Color(0xFFF6F6F2);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final pos = _anim.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: const Alignment(-1.8, 0),
            end: const Alignment(1.8, 0),
            colors: [base, highlight, base],
            stops: [
              (pos - 0.32).clamp(0.0, 1.0),
              pos.clamp(0.0, 1.0),
              (pos + 0.32).clamp(0.0, 1.0),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
      child: ColoredBox(color: base, child: widget.child),
    );
  }
}

/// A single rectangular placeholder block.
class SnapFitShimmerBox extends StatelessWidget {
  const SnapFitShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius,
  });
  final double? width;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius ?? SnapFitRadius.sm),
    child: SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: const ColoredBox(color: Colors.white),
    ),
  );
}

/// Skeleton that matches a [TemplateCatalogTile] layout.
class SnapFitShimmerTemplateTile extends StatelessWidget {
  const SnapFitShimmerTemplateTile({super.key, this.ratio = 0.98});
  final double ratio;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AspectRatio(
        aspectRatio: ratio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SnapFitRadius.lg),
          child: const ColoredBox(color: Colors.white),
        ),
      ),
      const SizedBox(height: 12),
      const SnapFitShimmerBox(height: 14),
      const SizedBox(height: 6),
      const SnapFitShimmerBox(width: 70, height: 11),
      const SizedBox(height: 4),
      const SnapFitShimmerBox(width: 48, height: 11),
    ],
  );
}

/// A full-width row of skeleton template tiles (for store loading state).
class SnapFitShimmerTemplateTileGrid extends StatelessWidget {
  const SnapFitShimmerTemplateTileGrid({
    super.key,
    this.columns = 2,
    this.rows = 3,
    this.ratio = 0.98,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });
  final int columns;
  final int rows;
  final double ratio;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SnapFitShimmer(
    child: Padding(
      padding: padding,
      child: Column(
        children: [
          for (var r = 0; r < rows; r++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: 16),
                  Expanded(
                    child: SnapFitShimmerTemplateTile(ratio: ratio),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    ),
  );
}

/// Single-line text placeholder (width as fraction of available space).
class SnapFitShimmerLine extends StatelessWidget {
  const SnapFitShimmerLine({
    super.key,
    this.widthFactor = 1.0,
    this.height = 14,
  });
  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: SnapFitShimmerBox(height: height),
  );
}

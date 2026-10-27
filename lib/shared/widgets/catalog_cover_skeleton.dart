import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'catalog_skeleton_shimmer.dart';

/// A paper/photo placeholder. Store scopes share one paint-only sheen clock;
/// other screens stay static. No per-cover ticker, shader mask or bitmap.
class CatalogCoverSkeleton extends StatelessWidget {
  const CatalogCoverSkeleton({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = bounds.hasBoundedWidth ? bounds.maxWidth : 160.0;
      final height = bounds.hasBoundedHeight ? bounds.maxHeight : width;
      final side = math.min(width, height).clamp(0.0, 300.0);
      final colors = Theme.of(context).colorScheme;
      final block = colors.onSurface.withValues(alpha: .09);
      return ExcludeSemantics(
        child: Center(
          child: SizedBox.square(
            dimension: side * .88,
            child: CatalogSkeletonSheen(
              shapes: (size) {
                final inset = side * .085;
                final innerWidth = size.width - inset * 2;
                final photoHeight = size.height - inset * 2 - side * .162;
                final titleY = inset + photoHeight + side * .07;
                return Path()
                  ..addRRect(
                    RRect.fromRectAndRadius(
                      Rect.fromLTWH(inset, inset, innerWidth, photoHeight),
                      const Radius.circular(3),
                    ),
                  )
                  ..addRect(
                    Rect.fromLTWH(inset, titleY, innerWidth * .65, side * .032),
                  )
                  ..addRect(
                    Rect.fromLTWH(
                      inset,
                      titleY + side * .067,
                      innerWidth * .4,
                      side * .025,
                    ),
                  );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Padding(
                  padding: EdgeInsets.all(side * .085),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: block,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      SizedBox(height: side * .07),
                      FractionallySizedBox(
                        widthFactor: .65,
                        child: ColoredBox(
                          color: block,
                          child: SizedBox(height: side * .032),
                        ),
                      ),
                      SizedBox(height: side * .035),
                      FractionallySizedBox(
                        widthFactor: .4,
                        child: ColoredBox(
                          color: block,
                          child: SizedBox(height: side * .025),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

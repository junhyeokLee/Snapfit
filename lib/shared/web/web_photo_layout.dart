import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// A small photograph grid keeps source proportions and reading order while
/// making use of a desktop's width. It is intentionally limited to two columns
/// so that album pages remain large enough to read.
class WebPhotoColumns extends StatelessWidget {
  const WebPhotoColumns({super.key, required this.children, this.gap = 28});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns =
          bounds.maxWidth >= 760 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.4
          ? 2
          : 1;
      final width = (bounds.maxWidth - gap * (columns - 1)) / columns;
      return Semantics(
        container: true,
        explicitChildNodes: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var column = 0; column < columns; column++) ...[
              if (column > 0) SizedBox(width: gap),
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var index = column;
                      index < children.length;
                      index += columns
                    ) ...[
                      if (index != column) SizedBox(height: gap),
                      Semantics(
                        sortKey: OrdinalSortKey(index.toDouble()),
                        child: children[index],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

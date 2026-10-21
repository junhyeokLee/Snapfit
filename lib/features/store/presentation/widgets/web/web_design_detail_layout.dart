import 'package:flutter/material.dart';

import '../../../../../shared/web/web_design.dart';

/// Keeps the artwork large while the use action stays ahead of long details.
class WebDesignDetailLayout extends StatelessWidget {
  const WebDesignDetailLayout({
    super.key,
    required this.preview,
    required this.action,
    required this.information,
    this.stackedPreviewHeightForWidth,
    this.stackedAction,
    this.bottomAction,
  });
  final Widget preview, action, information;

  /// Resolves the artwork stage from the actual available content width.
  /// Two-column details keep their existing, independently sized artwork.
  final double Function(double availableWidth)? stackedPreviewHeightForWidth;

  /// Optional in-flow information for stacked layouts when the primary action
  /// is supplied separately in [bottomAction].
  final Widget? stackedAction;

  /// Remains visible below the stacked detail's scrollable content. It is
  /// hidden while the keyboard is open and is not used in a two-column layout.
  final Widget? bottomAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      Widget detail(Widget currentAction) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebSurface(
            key: const ValueKey('web-design-detail-action'),
            child: currentAction,
          ),
          const SizedBox(height: 16),
          WebSurface(child: information),
        ],
      );
      if (bounds.maxWidth >= 940 && bounds.maxHeight >= 480) {
        return Row(
          key: const ValueKey('web-design-detail-columns'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: preview),
            const SizedBox(width: 24),
            SizedBox(
              width: bounds.maxWidth >= 1160 ? 380 : 340,
              child: SingleChildScrollView(
                key: const ValueKey('web-design-detail-information-scroll'),
                child: detail(action),
              ),
            ),
          ],
        );
      }
      final requestedHeight = stackedPreviewHeightForWidth?.call(
        bounds.maxWidth,
      );
      final previewHeight =
          requestedHeight != null &&
              requestedHeight.isFinite &&
              requestedHeight > 0
          ? requestedHeight
          : (bounds.maxHeight * .82).clamp(360.0, 720.0);
      final stacked = ListView(
        key: const ValueKey('web-design-detail-stacked'),
        padding: bottomAction == null
            ? null
            : const EdgeInsets.only(bottom: 16),
        children: [
          SizedBox(
            key: const ValueKey('web-design-detail-preview'),
            height: previewHeight,
            child: preview,
          ),
          const SizedBox(height: 16),
          detail(stackedAction ?? action),
        ],
      );
      if (bottomAction == null) return stacked;
      return Column(
        key: const ValueKey('web-design-detail-stacked-layout'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: stacked),
          // A resizing Scaffold removes the consumed bottom view inset from
          // its body's MediaQuery. Consult the view as well so the footer
          // cannot reappear inside that shortened body while typing.
          if (MediaQuery.viewInsetsOf(context).bottom == 0 &&
              View.of(context).viewInsets.bottom == 0)
            Material(
              key: const ValueKey('web-design-detail-bottom-action'),
              color: Theme.of(context).colorScheme.surface,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: ConstrainedBox(
                  // The footer shares its parent's remaining height rather
                  // than the full display: nested, short windows stay usable.
                  constraints: BoxConstraints(maxHeight: bounds.maxHeight * .4),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      key: const ValueKey(
                        'web-design-detail-bottom-action-scroll',
                      ),
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                      child: bottomAction!,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/album_stage_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../../shared/widgets/experience_icon.dart';

abstract final class StoreGalleryStyle {
  static ButtonStyle primary(BuildContext context) =>
      ExperienceFormStyle.primary(context).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? ExperienceFormStyle.surface(context)
              : SnapFitColors.actionAccent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? ExperienceFormStyle.muted(context)
              : SnapFitColors.onAccent,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

/// Two views of one product. Only the selected artwork is mounted by callers.
class StoreGalleryTabs extends StatelessWidget {
  const StoreGalleryTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.secondaryEnabled = true,
  }) : assert(labels.length == 2),
       assert(selected >= 0 && selected < 2);
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool secondaryEnabled;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ExperienceFormStyle.surface(context),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var index = 0; index < 2; index++)
            Expanded(
              child: MergeSemantics(
                key: ValueKey('store-gallery-choice-$index'),
                child: Semantics(
                  selected: selected == index,
                  enabled: index == 0 || secondaryEnabled,
                  inMutuallyExclusiveGroup: true,
                  child: TextButton(
                    key: ValueKey('store-gallery-view-$index'),
                    onPressed: index == 1 && !secondaryEnabled
                        ? null
                        : () {
                            if (selected == index) return;
                            HapticFeedback.selectionClick();
                            onChanged(index);
                          },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.padded,
                      animationDuration: SnapFitMotion.duration(
                        context,
                        SnapFitMotion.fast,
                      ),
                      foregroundColor: selected == index
                          ? ExperienceFormStyle.selectionInk(context)
                          : ExperienceFormStyle.muted(context),
                      backgroundColor: selected == index
                          ? ExperienceFormStyle.selection(context)
                          : Colors.transparent,
                      textStyle: ExperienceFormStyle.text(
                        context,
                        13,
                        weight: selected == index
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (selected == index) ...[
                          const ExperienceIcon('Check', size: 16),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            labels[index],
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// A static, clipped gallery canvas; no blur, extra previews or idle ticker.
class StoreGallerySurface extends StatelessWidget {
  const StoreGallerySurface({
    super.key,
    required this.child,
    required this.onExpand,
    required this.expandTooltip,
    this.color,
  });
  final Widget child;
  final VoidCallback onExpand;
  final String expandTooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: ColoredBox(
      color: color ?? AlbumStageStyle.controlFill(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: child),
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              tooltip: expandTooltip,
              onPressed: onExpand,
              style: IconButton.styleFrom(
                backgroundColor: ExperienceFormStyle.surface(context),
                minimumSize: const Size(48, 48),
                visualDensity: VisualDensity.standard,
              ),
              icon: ExperienceIcon(
                'Maximize2',
                size: 18,
                color: ExperienceFormStyle.ink(context),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class StoreDetailSection extends StatelessWidget {
  const StoreDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.summary,
  });
  final String title;
  final Widget child;
  final String? summary;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 18),
      shape: Border(top: BorderSide(color: ExperienceFormStyle.line(context))),
      collapsedShape: Border(
        top: BorderSide(color: ExperienceFormStyle.line(context)),
      ),
      expansionAnimationStyle: AnimationStyle(
        duration: SnapFitMotion.duration(context, SnapFitMotion.fast),
        reverseDuration: SnapFitMotion.duration(context, SnapFitMotion.fast),
        curve: Curves.easeOutCubic,
      ),
      title: Text(
        title,
        style: ExperienceFormStyle.text(context, 14, weight: FontWeight.w500),
      ),
      subtitle: summary == null
          ? null
          : Text(
              summary!,
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
      children: [child],
    ),
  );
}

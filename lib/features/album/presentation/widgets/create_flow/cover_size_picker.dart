import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart'
    show SnapFitMotion, SnapFitRadius;
import '../../../../../shared/widgets/experience_form_style.dart';

/// 새 앨범에서 선택할 수 있는 다섯 가지 실물 책 규격.
class CoverSizePicker extends StatelessWidget {
  const CoverSizePicker({
    super.key,
    required this.selectedCover,
    required this.onSelected,
    this.availableCovers,
  });

  final CoverSize? selectedCover;
  final List<CoverSize>? availableCovers;
  final ValueChanged<CoverSize> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minimum = math.max(
        152.0,
        MediaQuery.textScalerOf(context).scale(12) * 6 + 64,
      );
      final columns = (constraints.maxWidth / minimum).floor().clamp(1, 3);
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final cover in coverSizes)
            SizedBox(width: width, child: _option(context, cover)),
        ],
      );
    },
  );

  Widget _option(BuildContext context, CoverSize cover) {
    final selected = selectedCover?.sizeProductId == cover.sizeProductId;
    final enabled =
        availableCovers == null ||
        availableCovers!.any(
          (size) => size.sizeProductId == cover.sizeProductId,
        );
    final ink = ExperienceFormStyle.ink(context);
    final color = enabled ? ink : ink.withValues(alpha: .28);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      label: cover.displayName,
      child: Material(
        animationDuration: SnapFitMotion.duration(context, SnapFitMotion.fast),
        color: selected
            ? ExperienceFormStyle.selection(context)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SnapFitRadius.md),
          side: BorderSide(
            color: selected
                ? ExperienceFormStyle.selectionInk(context)
                : ExperienceFormStyle.line(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey('print-size-${cover.productId}'),
          onTap: enabled
              ? () => onSelected(
                  cover.withCoverType(
                    selectedCover?.coverType ?? PrintCoverType.soft,
                  ),
                )
              : null,
          borderRadius: BorderRadius.circular(SnapFitRadius.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: kIsWeb ? 18 : 14,
              horizontal: kIsWeb ? 14 : 10,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 40,
                  child: Center(
                    child: Container(
                      width: cover.realSize.width,
                      height: cover.realSize.height,
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 1.2),
                        color: selected
                            ? color.withValues(alpha: .05)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cover.name,
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          weight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cover.realSize.width.toInt()} × ${cover.realSize.height.toInt()}cm',
                        style: ExperienceFormStyle.text(
                          context,
                          11,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                ExcludeSemantics(
                  child: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    key: selected
                        ? ValueKey('print-size-selected-${cover.productId}')
                        : null,
                    size: 18,
                    color: selected
                        ? ExperienceFormStyle.selectionInk(context)
                        : color.withValues(alpha: enabled ? .45 : .28),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

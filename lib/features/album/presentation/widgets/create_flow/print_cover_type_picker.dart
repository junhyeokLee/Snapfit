import 'package:flutter/material.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart'
    show SnapFitMotion, SnapFitRadius;
import '../../../../../shared/widgets/experience_form_style.dart';

class PrintCoverTypePicker extends StatelessWidget {
  const PrintCoverTypePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PrintCoverType selected;
  final ValueChanged<PrintCoverType> onSelected;

  @override
  Widget build(BuildContext context) {
    final ink = ExperienceFormStyle.ink(context);
    return LayoutBuilder(
      builder: (context, box) {
        final vertical =
            MediaQuery.textScalerOf(context).scale(14) > 21 &&
            box.maxWidth < 480;
        final width = vertical ? box.maxWidth : (box.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in PrintCoverType.values)
              SizedBox(
                width: width,
                child: Semantics(
                  button: true,
                  selected: selected == type,
                  inMutuallyExclusiveGroup: true,
                  label: type.label,
                  child: Material(
                    animationDuration: SnapFitMotion.duration(
                      context,
                      SnapFitMotion.fast,
                    ),
                    color: selected == type
                        ? ExperienceFormStyle.selection(context)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SnapFitRadius.md),
                      side: BorderSide(
                        color: selected == type
                            ? ExperienceFormStyle.selectionInk(context)
                            : ExperienceFormStyle.line(context),
                        width: selected == type ? 1.5 : 1,
                      ),
                    ),
                    child: InkWell(
                      key: ValueKey('print-cover-${type.name}'),
                      onTap: () => onSelected(type),
                      borderRadius: BorderRadius.circular(SnapFitRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    type.label,
                                    textAlign: TextAlign.center,
                                    style: ExperienceFormStyle.text(
                                      context,
                                      14,
                                      weight: FontWeight.w600,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ExcludeSemantics(
                                  child: Icon(
                                    selected == type
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    key: selected == type
                                        ? ValueKey(
                                            'print-cover-selected-${type.name}',
                                          )
                                        : null,
                                    size: 18,
                                    color: selected == type
                                        ? ExperienceFormStyle.selectionInk(
                                            context,
                                          )
                                        : ink.withValues(alpha: .45),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              type == PrintCoverType.soft
                                  ? '유연한 종이 표지'
                                  : '단단한 사진 표지',
                              textAlign: TextAlign.center,
                              style: ExperienceFormStyle.text(
                                context,
                                11,
                                secondary: true,
                              ),
                            ),
                          ],
                        ),
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
}

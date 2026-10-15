import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/cover_size.dart';
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final type in PrintCoverType.values) ...[
          if (type == PrintCoverType.hard) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == type,
              label: type.label,
              child: Material(
                color: selected == type
                    ? ExperienceFormStyle.selection(context)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 8),
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
                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type == PrintCoverType.soft
                              ? '유연한 종이 표지'
                              : '사진 이미지랩 · 단단한 표지',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: ExperienceFormStyle.muted(context),
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
      ],
    );
  }
}

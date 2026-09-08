import 'package:flutter/material.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';

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
    final ink = SnapFitColors.textPrimaryOf(context);
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
                    ? (SnapFitColors.isDark(context)
                          ? const Color(0xFF153D3D)
                          : const Color(0xFFE5F1EF))
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: selected == type
                        ? const Color(0xFF43877E)
                        : ink.withValues(alpha: .13),
                    width: selected == type ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  key: ValueKey('print-cover-${type.name}'),
                  onTap: () => onSelected(type),
                  borderRadius: BorderRadius.circular(8),
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
                            color: SnapFitColors.textSecondaryOf(context),
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

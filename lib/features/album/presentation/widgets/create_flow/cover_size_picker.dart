import 'package:flutter/material.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';

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
      final columns = constraints.maxWidth >= 480 ? 3 : 2;
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
    final ink = SnapFitColors.textPrimaryOf(context);
    final color = enabled ? ink : ink.withValues(alpha: .28);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: cover.displayName,
      child: Material(
        color: selected
            ? (SnapFitColors.isDark(context)
                  ? const Color(0xFF153D3D)
                  : const Color(0xFFE5F1EF))
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected
                ? const Color(0xFF43877E)
                : ink.withValues(alpha: .13),
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
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: Center(
                    child: Container(
                      width: cover.realSize.width * 4 / 3,
                      height: cover.realSize.height * 4 / 3,
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 1.2),
                        color: selected
                            ? color.withValues(alpha: .05)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cover.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cover.realSize.width.toInt()} × ${cover.realSize.height.toInt()}cm',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

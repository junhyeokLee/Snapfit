import 'package:flutter/material.dart';

import 'experience_icon.dart';
import 'experience_style.dart';
import 'experience_form_style.dart';

class CatalogFilterBar extends StatelessWidget {
  const CatalogFilterBar({
    super.key,
    required this.price,
    required this.onPriceChanged,
    required this.favoritesOnly,
    required this.onFavoritesChanged,
    this.resultLabel,
    this.sort,
    this.onSortChanged,
    this.enabled = true,
    this.showOwned = false,
    this.trailing,
  });

  final String price;
  final ValueChanged<String> onPriceChanged;
  final bool favoritesOnly;
  final VoidCallback onFavoritesChanged;
  final String? resultLabel, sort;
  final ValueChanged<String>? onSortChanged;
  final bool enabled;
  final bool showOwned;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;
      final details = [
        Expanded(
          child: Text(
            resultLabel ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
        ),
        if (sort != null)
          DropdownButton<String>(
            value: sort,
            isDense: true,
            underline: const SizedBox.shrink(),
            dropdownColor: ExperienceFormStyle.surface(context),
            style: ExperienceFormStyle.text(context, 12),
            items: const [
              DropdownMenuItem(value: '추천순', child: Text('추천순')),
              DropdownMenuItem(value: '이름순', child: Text('이름순')),
            ],
            onChanged: (value) {
              if (value != null) onSortChanged?.call(value);
            },
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child:
                      showOwned &&
                          (constraints.maxWidth < 260 ||
                              (MediaQuery.textScalerOf(context).scale(12) >
                                      17 &&
                                  constraints.maxWidth < 400))
                      ? DropdownButton<String>(
                          isExpanded: true,
                          value: price,
                          underline: const SizedBox.shrink(),
                          dropdownColor: ExperienceFormStyle.surface(context),
                          style: ExperienceFormStyle.text(context, 13),
                          items: [
                            for (final value in ['전체', '무료', '유료', '보유'])
                              DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: enabled
                              ? (value) {
                                  if (value != null) onPriceChanged(value);
                                }
                              : null,
                        )
                      : SegmentedButton<String>(
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            padding: showOwned
                                ? const EdgeInsets.symmetric(vertical: 8)
                                : null,
                            minimumSize: showOwned ? const Size(44, 44) : null,
                            side: BorderSide.none,
                            backgroundColor: ExperienceFormStyle.surface(
                              context,
                            ),
                            foregroundColor: ExperienceFormStyle.ink(context),
                            selectedBackgroundColor:
                                ExperienceFormStyle.selection(context),
                            selectedForegroundColor:
                                ExperienceFormStyle.selectionInk(context),
                            visualDensity: VisualDensity.compact,
                            textStyle: ExperienceStyle.text(12),
                          ),
                          segments: [
                            const ButtonSegment(value: '전체', label: Text('전체')),
                            const ButtonSegment(value: '무료', label: Text('무료')),
                            const ButtonSegment(value: '유료', label: Text('유료')),
                            if (showOwned)
                              const ButtonSegment(
                                value: '보유',
                                label: Text('보유'),
                              ),
                          ],
                          selected: {price},
                          onSelectionChanged: enabled
                              ? (value) => onPriceChanged(value.single)
                              : null,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              if (trailing != null) trailing!,
              IconButton(
                tooltip: '즐겨찾기만 보기',
                isSelected: favoritesOnly,
                onPressed: onFavoritesChanged,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: favoritesOnly
                      ? ExperienceFormStyle.selection(context)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: ExperienceIcon(
                  'Bookmark',
                  color: favoritesOnly
                      ? ExperienceFormStyle.selectionInk(context)
                      : ExperienceFormStyle.muted(context),
                ),
              ),
              if (wide && (resultLabel != null || sort != null)) ...[
                const SizedBox(width: 24),
                ...details,
              ],
            ],
          ),
          if (!wide && (resultLabel != null || sort != null))
            Row(children: details),
        ],
      );
    },
  );
}

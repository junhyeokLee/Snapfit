import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'experience_icon.dart';
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
      final textSize = MediaQuery.textScalerOf(context).scale(12);
      final priceItemHeight = math.max(
        kMinInteractiveDimension,
        MediaQuery.textScalerOf(context).scale(13) + 24,
      );
      final sortItemHeight = math.max(kMinInteractiveDimension, textSize + 24);
      final wide = constraints.maxWidth >= 600 && textSize <= 18;
      final detailsInline = wide && (resultLabel != null || sort != null);
      final priceWidth =
          (constraints.maxWidth -
              60 -
              (trailing == null ? 0 : 48) -
              (detailsInline ? 24 : 0)) /
          (detailsInline ? (sort == null ? 2 : 3) : 1);
      final usePriceMenu =
          priceWidth < (showOwned ? 4 : 3) * math.max(48, textSize * 2 + 20);
      final details = [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              resultLabel ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ),
        ),
        if (sort != null)
          Flexible(
            child: Tooltip(
              message: '정렬: $sort',
              excludeFromSemantics: true,
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                label: '정렬 기준',
                child: DropdownButton<String>(
                  key: const ValueKey('catalog-sort'),
                  value: sort,
                  isExpanded: true,
                  isDense: false,
                  itemHeight: sortItemHeight,
                  underline: const SizedBox.shrink(),
                  dropdownColor: ExperienceFormStyle.surface(context),
                  style: ExperienceFormStyle.text(context, 12),
                  selectedItemBuilder: (context) => [
                    for (final value in const ['추천순', '이름순'])
                      Row(
                        children: [
                          const Icon(Icons.sort_rounded, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                  items: const [
                    DropdownMenuItem(
                      value: '추천순',
                      child: Text(
                        '추천순',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: '이름순',
                      child: Text(
                        '이름순',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: onSortChanged == null
                      ? null
                      : (value) {
                          if (value == null || value == sort) return;
                          HapticFeedback.selectionClick();
                          onSortChanged!(value);
                        },
                ),
              ),
            ),
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
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    label: '가격 필터',
                    child: usePriceMenu
                        ? DropdownButton<String>(
                            key: const ValueKey('catalog-price-filter'),
                            isExpanded: true,
                            value: price,
                            itemHeight: priceItemHeight,
                            underline: const SizedBox.shrink(),
                            dropdownColor: ExperienceFormStyle.surface(context),
                            style: ExperienceFormStyle.text(context, 13),
                            selectedItemBuilder: (context) => [
                              for (final value in [
                                '전체',
                                '무료',
                                '유료',
                                if (showOwned) '보유',
                              ])
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '가격 · $value',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            items: [
                              for (final value in [
                                '전체',
                                '무료',
                                '유료',
                                if (showOwned) '보유',
                              ])
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
                                    if (value == null || value == price) return;
                                    HapticFeedback.selectionClick();
                                    onPriceChanged(value);
                                  }
                                : null,
                          )
                        : SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              minimumSize: const Size(48, 48),
                              side: BorderSide.none,
                              backgroundColor: ExperienceFormStyle.surface(
                                context,
                              ),
                              foregroundColor: ExperienceFormStyle.ink(context),
                              selectedBackgroundColor:
                                  ExperienceFormStyle.selection(context),
                              selectedForegroundColor:
                                  ExperienceFormStyle.selectionInk(context),
                              visualDensity: VisualDensity.standard,
                              textStyle: ExperienceFormStyle.text(
                                context,
                                12,
                                weight: FontWeight.w600,
                              ),
                            ),
                            segments: [
                              const ButtonSegment(
                                value: '전체',
                                label: Text('전체'),
                                tooltip: '가격: 전체',
                              ),
                              const ButtonSegment(
                                value: '무료',
                                label: Text('무료'),
                                tooltip: '가격: 무료',
                              ),
                              const ButtonSegment(
                                value: '유료',
                                label: Text('유료'),
                                tooltip: '가격: 유료',
                              ),
                              if (showOwned)
                                const ButtonSegment(
                                  value: '보유',
                                  label: Text('보유'),
                                  tooltip: '보유한 디자인',
                                ),
                            ],
                            selected: {price},
                            onSelectionChanged: enabled
                                ? (value) {
                                    if (value.single == price) return;
                                    HapticFeedback.selectionClick();
                                    onPriceChanged(value.single);
                                  }
                                : null,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (trailing != null) trailing!,
              IconButton(
                tooltip: '즐겨찾기만 보기',
                isSelected: favoritesOnly,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onFavoritesChanged();
                },
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: favoritesOnly
                      ? ExperienceFormStyle.selection(context)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
          if (!wide && (resultLabel != null || sort != null)) ...[
            const SizedBox(height: 4),
            Row(children: details),
          ],
        ],
      );
    },
  );
}

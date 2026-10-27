import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'experience_form_style.dart';

class CatalogActiveFilter {
  const CatalogActiveFilter({
    required this.id,
    required this.label,
    required this.onRemove,
  });

  final String id;
  final String label;
  final VoidCallback onRemove;
}

/// Keep applied conditions visible, individually removable and readable with
/// large text. Ordinary layout changes need no animated or filtered layers.
class CatalogActiveFilters extends StatelessWidget {
  const CatalogActiveFilters({
    super.key,
    required this.filters,
    required this.onReset,
  });

  final List<CatalogActiveFilter> filters;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, bounds) => Semantics(
          container: true,
          explicitChildNodes: true,
          label: '적용된 필터',
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final filter in filters)
                ConstrainedBox(
                  key: ValueKey('catalog-active-filter-${filter.id}'),
                  constraints: BoxConstraints(maxWidth: bounds.maxWidth),
                  child: Tooltip(
                    message: filter.label,
                    excludeFromSemantics: true,
                    child: InputChip(
                      label: Text(
                        filter.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      labelStyle: ExperienceFormStyle.text(
                        context,
                        12,
                        weight: FontWeight.w600,
                        color: ExperienceFormStyle.ink(context),
                      ),
                      backgroundColor: ExperienceFormStyle.selection(context),
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      visualDensity: VisualDensity.standard,
                      deleteIcon: const Icon(Icons.close_rounded, size: 17),
                      deleteIconColor: ExperienceFormStyle.selectionInk(
                        context,
                      ),
                      deleteButtonTooltipMessage: '${filter.label} 조건 해제',
                      onDeleted: () {
                        HapticFeedback.selectionClick();
                        filter.onRemove();
                      },
                    ),
                  ),
                ),
              TextButton.icon(
                key: const ValueKey('catalog-reset-filters'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onReset();
                },
                style: TextButton.styleFrom(
                  foregroundColor: ExperienceFormStyle.ink(context),
                  minimumSize: const Size(0, 48),
                  textStyle: ExperienceFormStyle.text(context, 12),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('초기화'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

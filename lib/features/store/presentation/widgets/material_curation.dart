import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../data/store_curation_provider.dart';
import 'material_catalog_tile.dart';

class MaterialCurationItem {
  const MaterialCurationItem({
    required this.key,
    required this.title,
    required this.type,
    required this.preview,
    required this.onOpen,
  });
  final String key, title, type;
  final Widget preview;
  final VoidCallback onOpen;
}

/// Smaller than the album selection: materials stay readable at their own scale.
class MaterialCuration extends StatelessWidget {
  const MaterialCuration({
    super.key,
    required this.selection,
    required this.items,
  });
  final StoreCuration selection;
  final List<MaterialCurationItem> items;
  @override
  Widget build(BuildContext context) {
    final selected = selection.resolve(items, (item) => item.key);
    if (selected.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'THE MATERIAL EDIT',
          style: ExperienceFormStyle.text(
            context,
            10,
            secondary: true,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                selection.title,
                style: ExperienceFormStyle.text(
                  context,
                  19,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${selected.length}종',
              style: ExperienceFormStyle.text(context, 11, secondary: true),
            ),
          ],
        ),
        if (selection.subtitle.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            selection.subtitle,
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
        ],
        const SizedBox(height: 17),
        SizedBox(
          height: 132 + scale.scale(13) * 2.9 + 46,
          child: ListView.separated(
            key: const ValueKey('material-curation-shelf'),
            scrollDirection: Axis.horizontal,
            itemCount: selected.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = selected[i];
              return SizedBox(
                width: 156,
                child: MaterialCatalogTile(
                  key: ValueKey('material-curation-${item.key}'),
                  productKey: item.key,
                  title: item.title,
                  type: item.type,
                  preview: item.preview,
                  onOpen: item.onOpen,
                  compact: true,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

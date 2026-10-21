import 'package:flutter/material.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/entities/premium_template.dart';
import 'catalog_edition_artwork.dart';

class StoreTopicShelf extends StatelessWidget {
  const StoreTopicShelf({
    super.key,
    required this.categories,
    required this.templates,
    required this.selected,
    required this.onSelect,
  });
  final List<String> categories;
  final List<PremiumTemplate> templates;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      key: const ValueKey('store-topic-filters'),
      children: [
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: ValueKey('store-topic-$category'),
              selected: selected == category,
              onSelected: (_) => onSelect(category),
              showCheckmark: false,
              avatar: category == '전체'
                  ? null
                  : SizedBox(
                      width: 4,
                      height: 14,
                      child: ColoredBox(
                        color: CatalogEditionPalette.of(category).ink,
                      ),
                    ),
              label: Text(
                category,
                style: ExperienceFormStyle.text(
                  context,
                  13,
                  weight: selected == category
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: selected == category
                      ? ExperienceFormStyle.selectionInk(context)
                      : ExperienceFormStyle.ink(context),
                ),
              ),
              selectedColor: ExperienceFormStyle.selection(context),
              backgroundColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: selected == category
                    ? Colors.transparent
                    : ExperienceFormStyle.line(context),
              ),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
            ),
          ),
      ],
    ),
  );
}
